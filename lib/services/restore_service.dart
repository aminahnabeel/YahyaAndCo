import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../db/database_helper.dart';
import '../models/business_model.dart';

class RestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getBusinessDocsForUser(User user) async {
    final nestedDocs = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('businesses')
        .get();

    final nestedBusinessDocs = nestedDocs.docs.where((doc) {
      final data = doc.data();
      final ownerUid = data['owner_uid'];
      return ownerUid == null || ownerUid == user.uid;
    }).toList();

    if (nestedBusinessDocs.isNotEmpty) {
      return nestedBusinessDocs;
    }

    final rootDocs = await _firestore.collection('businesses').get();

    final rootBusinessDocs = rootDocs.docs.where((doc) {
      final data = doc.data();
      final ownerUid = data['owner_uid'];
      return ownerUid == null || ownerUid == user.uid;
    }).toList();

    if (rootBusinessDocs.isNotEmpty) {
      return rootBusinessDocs;
    }

    return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  Future<bool> restoreUserDataOnLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('RestoreService: no current user');
      return false;
    }

    try {
      print(
        'RestoreService: checking Firestore businesses for user ${user.uid}',
      );
      final businessesDocs = await _getBusinessDocsForUser(user);
      print(
        'RestoreService: found ${businessesDocs.length} business documents',
      );
      if (businessesDocs.isEmpty) {
        return false;
      }

      var restoredBusinessFound = false;

      for (final businessDoc in businessesDocs) {
        try {
          final businessData = businessDoc.data();
          final businessId = businessDoc.id;
          final accountIdByFirestoreId = <String, int>{};
          final accountIdByName = <String, int>{};
          final restoredAccountIdsInOrder = <int>[];

          final localBusinessId = await DatabaseHelper.instance.upsertBusiness(
            BusinessModel(
              businessId: null,
              firestoreId: businessId,
              name: (businessData['name'] ?? 'Business').toString(),
              type: (businessData['type'] ?? 'General').toString(),
              pin: businessData['pin']?.toString(),
              createdAt: _asText(businessData['created_at']),
            ),
          );
          restoredBusinessFound = true;

          final businessRef = businessDoc.reference;
          final journalEntriesSnapshot = await businessRef
              .collection('journal_entries')
              .get();
          final obAccountFirestoreIds = <String>{};

          for (final journalDoc in journalEntriesSnapshot.docs) {
            final journalData = journalDoc.data();
            if ((journalData['voucher_type'] ?? '').toString().toUpperCase() !=
                'OB') {
              continue;
            }

            final linesSnapshot = await journalDoc.reference
                .collection('journal_lines')
                .get();
            for (final lineDoc in linesSnapshot.docs) {
              final lineData = lineDoc.data();
              final lineAccountFirestoreId =
                  (lineData['account_firestore_id'] ?? '').toString();
              if (lineAccountFirestoreId.isNotEmpty) {
                obAccountFirestoreIds.add(lineAccountFirestoreId);
              }
            }
          }

          final accountsSnapshot = await businessRef
              .collection('accounts')
              .get();
          final sortedAccountDocs = accountsSnapshot.docs.toList()
            ..sort((left, right) {
              final leftCreated = (left.data()['created_at'] ?? '').toString();
              final rightCreated = (right.data()['created_at'] ?? '')
                  .toString();
              return leftCreated.compareTo(rightCreated);
            });

          for (final accountDoc in sortedAccountDocs) {
            final accountData = accountDoc.data();
            final normalizedAccount = {
              'account_id': null,
              'business_id': localBusinessId,
              'firestore_id': accountDoc.id,
              'name': accountData['name'] ?? 'Account',
              'type': accountData['type'] ?? 'Asset',
              'phone': accountData['phone'],
              'address': accountData['address'],
              'opening_balance': obAccountFirestoreIds.contains(accountDoc.id)
                  ? 0.0
                  : (accountData['opening_balance'] as num?)?.toDouble() ?? 0.0,
              'created_at': _asText(accountData['created_at']),
            };

            final localAccountId = await DatabaseHelper.instance.upsertAccount(
              normalizedAccount,
            );
            accountIdByFirestoreId[accountDoc.id] = localAccountId;
            final legacyAccountId = _asInt(accountData['account_id']);
            if (legacyAccountId != null) {
              accountIdByFirestoreId[legacyAccountId.toString()] =
                  localAccountId;
            }
            accountIdByName[(accountData['name'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase()] =
                localAccountId;
            restoredAccountIdsInOrder.add(localAccountId);
          }

          for (final journalDoc in journalEntriesSnapshot.docs) {
            final journalData = journalDoc.data();
            final normalizedJournal = {
              'journal_id': null,
              'business_id': localBusinessId,
              // Remote transaction IDs are not local SQLite IDs. The link is
              // restored after all transactions have been inserted.
              'transaction_id': null,
              'firestore_id': journalDoc.id,
              'description': journalData['description'] ?? '',
              'image_url': journalData['image_url']?.toString(),
              'date': _asDate(journalData['date']),
              'voucher_no': (journalData['voucher_no'] ?? '').toString(),
              'voucher_type': (journalData['voucher_type'] ?? 'JV').toString(),
              'due_date': _asNullableText(journalData['due_date']),
              'payment_status': (journalData['payment_status'] ?? 'Paid')
                  .toString(),
              'remaining_amount':
                  (journalData['remaining_amount'] as num?)?.toDouble() ?? 0.0,
              'created_at': _asText(journalData['created_at']),
            };

            final localJournalId = await DatabaseHelper.instance
                .upsertJournalEntry(normalizedJournal);

            final linesSnapshot = await journalDoc.reference
                .collection('journal_lines')
                .get();

            for (final lineDoc in linesSnapshot.docs) {
              final lineData = lineDoc.data();
              final lineAccountFirestoreId =
                  (lineData['account_firestore_id'] ?? '').toString();
              final lineAccountName = (lineData['account_name'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final legacyAccountId = (lineData['account_id'] as num?)?.toInt();

              int? resolvedAccountId =
                  accountIdByFirestoreId[lineAccountFirestoreId];
              resolvedAccountId ??= accountIdByName[lineAccountName];
              if (resolvedAccountId == null &&
                  legacyAccountId != null &&
                  legacyAccountId > 0) {
                final legacyIndex = legacyAccountId - 1;
                if (legacyIndex >= 0 &&
                    legacyIndex < restoredAccountIdsInOrder.length) {
                  resolvedAccountId = restoredAccountIdsInOrder[legacyIndex];
                }
              }

              final normalizedLine = {
                'line_id': null,
                'journal_id': localJournalId,
                'account_id': resolvedAccountId,
                'firestore_id': lineDoc.id,
                'account_firestore_id': lineAccountFirestoreId.isEmpty
                    ? null
                    : lineAccountFirestoreId,
                'account_name': lineAccountName.isEmpty
                    ? null
                    : lineAccountName,
                'debit': (lineData['debit'] as num?)?.toDouble() ?? 0.0,
                'credit': (lineData['credit'] as num?)?.toDouble() ?? 0.0,
              };

              if (resolvedAccountId == null) {
                print(
                  'RestoreService: skipping journal line ${lineDoc.id}; account mapping not found',
                );
                continue;
              }

              await DatabaseHelper.instance.upsertJournalLine(normalizedLine);
            }
          }

          final transactionsSnapshot = await businessRef
              .collection('transactions')
              .get();
          final localTransactionIdsByRemoteId = <String, int>{};

          for (final transactionDoc in transactionsSnapshot.docs) {
            try {
              final transactionData = transactionDoc.data();
              final transactionAccountFirestoreId = _firstText(
                transactionData,
                const ['account_firestore_id', 'accountFirestoreId'],
              );
              final transactionAccountName = _firstText(transactionData, const [
                'account_name',
                'accountName',
              ]).trim().toLowerCase();
              final transactionLegacyAccountId = _asInt(
                transactionData['account_id'],
              );
              final accountIdValue = transactionData['account_id'];
              final transactionAccountKey =
                  transactionAccountFirestoreId.isNotEmpty
                  ? transactionAccountFirestoreId
                  : accountIdValue is String
                  ? accountIdValue
                  : '';
              final transactionToAccountFirestoreId = _firstText(
                transactionData,
                const ['to_account_firestore_id', 'toAccountFirestoreId'],
              );
              final transactionToAccountName = _firstText(
                transactionData,
                const ['to_account_name', 'toAccountName'],
              ).trim().toLowerCase();
              final transactionLegacyToAccountId = _asInt(
                transactionData['to_account_id'],
              );
              final toAccountIdValue = transactionData['to_account_id'];
              final transactionToAccountKey =
                  transactionToAccountFirestoreId.isNotEmpty
                  ? transactionToAccountFirestoreId
                  : toAccountIdValue is String
                  ? toAccountIdValue
                  : '';

              int? resolvedTransactionAccountId =
                  accountIdByFirestoreId[transactionAccountKey];
              resolvedTransactionAccountId ??=
                  accountIdByName[transactionAccountName];
              if (resolvedTransactionAccountId == null &&
                  transactionLegacyAccountId != null &&
                  transactionLegacyAccountId > 0) {
                final legacyIndex = transactionLegacyAccountId - 1;
                if (legacyIndex >= 0 &&
                    legacyIndex < restoredAccountIdsInOrder.length) {
                  resolvedTransactionAccountId =
                      restoredAccountIdsInOrder[legacyIndex];
                }
                resolvedTransactionAccountId ??=
                    accountIdByFirestoreId[transactionLegacyAccountId
                        .toString()];
              }

              int? resolvedToAccountId =
                  accountIdByFirestoreId[transactionToAccountKey];
              resolvedToAccountId ??= accountIdByName[transactionToAccountName];
              if (resolvedToAccountId == null &&
                  transactionLegacyToAccountId != null &&
                  transactionLegacyToAccountId > 0) {
                final legacyIndex = transactionLegacyToAccountId - 1;
                if (legacyIndex >= 0 &&
                    legacyIndex < restoredAccountIdsInOrder.length) {
                  resolvedToAccountId = restoredAccountIdsInOrder[legacyIndex];
                }
                resolvedToAccountId ??=
                    accountIdByFirestoreId[transactionLegacyToAccountId
                        .toString()];
              }

              final normalizedTransaction = {
                'transaction_id': null,
                'business_id': localBusinessId,
                'account_id': resolvedTransactionAccountId,
                'to_account_id': resolvedToAccountId,
                'firestore_id': transactionDoc.id,
                'account_firestore_id': transactionAccountFirestoreId.isEmpty
                    ? null
                    : transactionAccountFirestoreId,
                'account_name': transactionAccountName.isEmpty
                    ? null
                    : transactionAccountName,
                'to_account_firestore_id':
                    transactionToAccountFirestoreId.isEmpty
                    ? null
                    : transactionToAccountFirestoreId,
                'to_account_name': transactionToAccountName.isEmpty
                    ? null
                    : transactionToAccountName,
                'amount':
                    (transactionData['amount'] as num?)?.toDouble() ?? 0.0,
                'type': (transactionData['type'] ?? 'Expense').toString(),
                'note': (transactionData['note'] ?? '').toString(),
                'payment_method': (transactionData['payment_method'] ?? 'Cash')
                    .toString(),
                'due_date': _asNullableText(transactionData['due_date']),
                'payment_status': (transactionData['payment_status'] ?? 'Paid')
                    .toString(),
                'remaining_amount':
                    (transactionData['remaining_amount'] as num?)?.toDouble() ??
                    0.0,
                'image_url': transactionData['image_url']?.toString(),
                'date': _asDate(transactionData['date']),
                'created_at': _asText(transactionData['created_at']),
              };

              if (resolvedTransactionAccountId == null) {
                print(
                  'RestoreService: skipping transaction ${transactionDoc.id}; account mapping not found',
                );
                continue;
              }

              final localTransactionId = await DatabaseHelper.instance
                  .upsertTransaction(normalizedTransaction);
              localTransactionIdsByRemoteId[transactionDoc.id] =
                  localTransactionId;
              final legacyTransactionId = transactionData['transaction_id'];
              if (legacyTransactionId is num) {
                localTransactionIdsByRemoteId[legacyTransactionId
                        .toInt()
                        .toString()] =
                    localTransactionId;
              }
            } catch (e, stackTrace) {
              print(
                'RestoreService: transaction ${transactionDoc.id} failed: $e',
              );
              print(stackTrace);
            }
          }

          for (final journalDoc in journalEntriesSnapshot.docs) {
            final journalData = journalDoc.data();
            final remoteTransactionId = journalData['transaction_id']
                ?.toString();
            final localJournalId = await DatabaseHelper.instance
                .getJournalEntryByFirestoreId(journalDoc.id);
            final localTransactionId = remoteTransactionId == null
                ? null
                : localTransactionIdsByRemoteId[remoteTransactionId];

            if (localJournalId != null && localTransactionId != null) {
              await DatabaseHelper.instance.updateJournalTransactionId(
                localJournalId,
                localTransactionId,
              );
            }
          }
        } catch (e, stackTrace) {
          print('RestoreService: business ${businessDoc.id} failed: $e');
          print(stackTrace);
        }
      }

      return restoredBusinessFound;
    } catch (e) {
      print('RestoreService error: $e');
      return false;
    }
  }

  String _asText(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value.toString();
  }

  String _asDate(dynamic value) {
    return _asText(value).split('T').first;
  }

  String? _asNullableText(dynamic value) {
    if (value == null) return null;
    return _asText(value);
  }

  String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
