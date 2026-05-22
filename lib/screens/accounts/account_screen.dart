import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../services/account_service.dart';
import 'add_account_screen.dart';
import 'account_detail_screen.dart';

class AccountScreen extends StatefulWidget {

  final int businessId;

  const AccountScreen({

    super.key,

    required this.businessId,
  });

  @override
  State<AccountScreen> createState() =>
      _AccountScreenState();
}

class _AccountScreenState
    extends State<AccountScreen> {

  final AccountService
      _accountService =
      AccountService();

  List<AccountModel> accounts = [];

  bool isLoading = true;

  @override
  void initState() {

    super.initState();

    loadAccounts();
  }

  // =========================
  // LOAD ACCOUNTS
  // =========================

  Future loadAccounts() async {

    accounts =
        await _accountService
            .getAccountsByBusiness(
      widget.businessId,
    );

    setState(() {

      isLoading = false;
    });
  }

  // =========================
  // DELETE ACCOUNT
  // =========================

  Future deleteAccount(
    int accountId,
  ) async {

    await _accountService
        .deleteAccount(
      accountId,
    );

    loadAccounts();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Accounts',
        ),
      ),

      floatingActionButton:
          FloatingActionButton(

        onPressed: () async {

          await Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) =>
                  AddAccountScreen(

                businessId:
                    widget.businessId,
              ),
            ),
          );

          loadAccounts();
        },

        child: const Icon(
          Icons.add,
        ),
      ),

      body: isLoading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : accounts.isEmpty

              ? const Center(
                  child: Text(
                    'No Accounts Found',
                  ),
                )

              : ListView.builder(

                  itemCount:
                      accounts.length,

                  itemBuilder:
                      (context, index) {

                    final account =
                        accounts[index];

                    return FutureBuilder<double>(
                      future: _accountService.getAccountClosingBalance(account.accountId!),
                      builder: (context, snapshot) {
                        final closingBalance = snapshot.data ?? 0;

                        return Card(

                          margin:
                              const EdgeInsets
                                  .all(10),

                          child: ListTile(

                            leading:
                                CircleAvatar(

                              child: Text(

                                account.name[0]
                                    .toUpperCase(),
                              ),
                            ),

                            title: Text(
                              account.name,
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.type,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Balance: ₹${closingBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),

                            trailing: PopupMenuButton(

                              itemBuilder:
                                  (context) {

                                return [

                                  const PopupMenuItem(

                                    value: 'delete',

                                    child: Text(
                                      'Delete',
                                    ),
                                  ),
                                ];
                              },

                              onSelected:
                                  (value) {

                                if (value ==
                                    'delete') {

                                  deleteAccount(
                                    account
                                        .accountId!,
                                  );
                                }
                              },
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AccountDetailScreen(
                                    account:
                                        account,
                                  ),
                                ),
                              ).then((_) {
                                loadAccounts();
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}