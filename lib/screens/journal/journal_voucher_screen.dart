import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../models/journal_entry_model.dart';
import '../../models/journal_line_model.dart';

import '../../services/account_service.dart';
import '../../services/accounting_service.dart';

class JournalVoucherScreen
    extends StatefulWidget {

  final int businessId;

  const JournalVoucherScreen({

    super.key,

    required this.businessId,
  });

  @override
  State<JournalVoucherScreen>
      createState() =>
          _JournalVoucherScreenState();
}

class _JournalVoucherScreenState
    extends State<JournalVoucherScreen> {

  final AccountingService
      _accountingService =
      AccountingService();

  final AccountService
      _accountService =
      AccountService();

  final TextEditingController
      descriptionController =
      TextEditingController();

  DateTime? dueDate;

  List<AccountModel> accounts = [];

  List<Map<String, dynamic>>
      journalRows = [];

  bool isLoading = false;

  @override
  void initState() {

    super.initState();

    loadAccounts();
  }

  @override
  void dispose() {
    for (final row in journalRows) {
      final controller = row['amountController'] as TextEditingController?;
      controller?.dispose();
    }
    descriptionController.dispose();
    super.dispose();
  }

  // =========================
  // LOAD ACCOUNTS
  // =========================

  Future loadAccounts() async {

    await _accountService.ensureDefaultAccounts(widget.businessId);

    accounts =
        await _accountService
            .getAccountsByBusiness(
      widget.businessId,
    );

    if (journalRows.isEmpty) {
      addNewRow();
    }

    setState(() {});
  }

  // =========================
  // ADD ROW
  // =========================

  void addNewRow() {

    final amountController = TextEditingController(text: '0.00');

    journalRows.add({

      'account': null,

      'side': 'Debit',

      'amountController': amountController,
    });

    setState(() {});
  }

  void _clearAmountIfDefault(TextEditingController controller) {
    if (controller.text == '0.00' || controller.text == '0') {
      controller.clear();
    }
  }

  Future<void> pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      dueDate = picked;
    });
  }

  // =========================
  // SAVE JOURNAL
  // =========================

  Future saveJournal() async {

    if (journalRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one row')),
      );
      return;
    }

    setState(() {

      isLoading = true;
    });

    try {

      String voucherNo =
          await _accountingService
              .generateJournalVoucher();

      List<JournalLineModel>
          journalLines = [];

        double totalAmount = 0;

      for (var row in journalRows) {

        AccountModel? account =
            row['account'];

        final amountController = row['amountController'] as TextEditingController;

        double amount =
            double.tryParse(
                  amountController.text,
                ) ??
                0;

        final side = row['side'] as String? ?? 'Debit';

        if (account == null) {
          throw Exception('Please select an account for each row');
        }

        if (amount <= 0) {
          throw Exception('Amount must be greater than zero');
        }

        totalAmount += amount;

        journalLines.add(

          JournalLineModel(

            journalId: 0,

            accountId:
                account.accountId!,

            debit: side == 'Debit' ? amount : 0,

            credit: side == 'Credit' ? amount : 0,
          ),
        );
      }

      final totalDebit = journalLines.fold<double>(0, (sum, line) => sum + line.debit);
      final totalCredit = journalLines.fold<double>(0, (sum, line) => sum + line.credit);

      if (totalDebit != totalCredit) {
        throw Exception('Debit and Credit must be equal');
      }

      JournalEntryModel
          journalEntry =
          JournalEntryModel(

        businessId:
            widget.businessId,

        transactionId: null,

        voucherNo:
            voucherNo,

        voucherType: 'JV',

        description:
            descriptionController
                .text,

        dueDate:
          dueDate?.toIso8601String().split('T').first,

        remainingAmount:
          dueDate == null ? 0 : totalAmount,

        paymentStatus:
          _accountingService.calculatePaymentStatus(
          amount: totalAmount,
          remainingAmount: dueDate == null ? 0 : totalAmount,
          dueDate: dueDate?.toIso8601String(),
        ),

        imageUrl: null,

        date:
            DateTime.now()
                .toString(),

        createdAt:
            DateTime.now()
                .toString(),
      );

      await _accountingService
          .createCompleteJournal(

        journalEntry:
            journalEntry,

        journalLines:
            journalLines,
      );

      setState(() {

        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            'Journal Voucher Saved',
          ),
        ),
      );

      Navigator.pop(context);

    } catch (e) {

      setState(() {

        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        SnackBar(

          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Journal Voucher',
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: addNewRow,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: pickDueDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dueDate == null ? 'Due Date (Optional)' : dueDate!.toIso8601String().split('T').first,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                itemCount: journalRows.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = journalRows[index];
                  final amountController = row['amountController'] as TextEditingController;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<AccountModel>(
                            value: row['account'] as AccountModel?,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                              border: OutlineInputBorder(),
                            ),
                            items: accounts.map((account) {
                              return DropdownMenuItem(
                                value: account,
                                child: Text('${account.name} (ID: ${account.accountId})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                row['account'] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: row['side'] as String,
                            decoration: const InputDecoration(
                              labelText: 'Side',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Debit', child: Text('Debit')),
                              DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                row['side'] = value ?? 'Debit';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTap: () => _clearAmountIfDefault(amountController),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: '0.00',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveJournal,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Voucher'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}