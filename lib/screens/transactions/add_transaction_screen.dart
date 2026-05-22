import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../models/journal_entry_model.dart';
import '../../models/journal_line_model.dart';
import '../../models/transaction_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../services/account_service.dart';
import '../../services/accounting_service.dart';
import '../../services/localization_service.dart';
import '../../services/transaction_service.dart';

class AddTransactionScreen
    extends StatefulWidget {

  final int businessId;

  const AddTransactionScreen({

    super.key,

    required this.businessId,
  });

  @override
  State<AddTransactionScreen>
      createState() =>
          _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends State<AddTransactionScreen> {

  final _formKey =
      GlobalKey<FormState>();

  final TransactionService
      _transactionService =
      TransactionService();

  final AccountingService
      _accountingService =
      AccountingService();

  final AccountService
      _accountService =
      AccountService();

  final TextEditingController
      amountController =
      TextEditingController();

  final TextEditingController
      noteController =
      TextEditingController();

  List<AccountModel> accounts = [];

  AccountModel? selectedAccount;

  int? cashAccountId;

  String transactionType =
      'Payment';

  String paymentMethod =
      'Cash';

  bool isLoading = false;

  String side = 'Debit'; // 'Debit' or 'Credit'

  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  String? _imagePath;

  @override
  void initState() {

    super.initState();

    loadAccounts();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }


  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    setState(() {
      _dueDate = date;
    });
  }
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() {
          _imagePath = file.path;
        });
      }
    } catch (e) {
      // ignore image picker errors
    }
  }

  // =========================
  // LOAD ACCOUNTS
  // =========================
  // Loads all accounts EXCEPT Cash (Cash is counter-account automatically)

  Future loadAccounts() async {

    await _accountService.ensureDefaultAccounts(widget.businessId);

    cashAccountId = await _accountingService.getCashAccountId(widget.businessId);

    final allAccounts =
        await _accountService
            .getAccountsByBusiness(
      widget.businessId,
    );

    // Filter out Cash account - it's used as counter-account automatically
    accounts = allAccounts
        .where((account) => 
            account.accountId != cashAccountId)
        .toList();

    if (accounts.isNotEmpty) {
      selectedAccount = accounts.first;
    } else {
      selectedAccount = null;
    }

    setState(() {});
  }

  // =========================
  // SAVE TRANSACTION
  // =========================
  // Creates proper double-entry journal:
  // 
  // If Debit selected:
  //   - Selected Account: Debit (amount increases)
  //   - Cash Account: Credit (cash decreases)
  //   Example: Expense of 1000
  //   - Expense: Debit 1000 (expense increases)
  //   - Cash: Credit 1000 (cash decreases)
  //
  // If Credit selected:
  //   - Cash Account: Debit (cash increases)
  //   - Selected Account: Credit (amount increases)
  //   Example: Income of 1000
  //   - Cash: Debit 1000 (cash increases)
  //   - Income: Credit 1000 (income increases)

  Future saveTransaction() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select account')),
      );
      return;
    }

    if (cashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.instance.t('cash_account_required')),
        ),
      );
      return;
    }

    // Validate: Selected account should NOT be Cash
    if (selectedAccount!.accountId == cashAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select Cash account. Use journal entry for cash transfers.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Generate voucher number
      String voucherNo = await _accountingService.generateCashVoucher();

      // Parse amount once and reuse
      double amount = double.parse(amountController.text);

      // Create transaction record
      TransactionModel transaction = TransactionModel(
        businessId: widget.businessId,
        accountId: selectedAccount!.accountId!,
        amount: amount,
        type: side,
        note: noteController.text,
        paymentMethod: paymentMethod,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        remainingAmount: _dueDate == null ? 0 : amount,
        paymentStatus: _accountingService.calculatePaymentStatus(
          amount: amount,
          remainingAmount: _dueDate == null ? 0 : amount,
          dueDate: _dueDate?.toIso8601String(),
        ),
        imageUrl: _imagePath,
        date: _selectedDate.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );

      int transactionId = await _transactionService.createTransaction(transaction);

      // Create journal entry header
      JournalEntryModel journalEntry = JournalEntryModel(
        businessId: widget.businessId,
        transactionId: transactionId,
        voucherNo: voucherNo,
        voucherType: 'CP',
        description: noteController.text,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        remainingAmount: _dueDate == null ? 0 : amount,
        paymentStatus: _accountingService.calculatePaymentStatus(
          amount: amount,
          remainingAmount: _dueDate == null ? 0 : amount,
          dueDate: _dueDate?.toIso8601String(),
        ),
        imageUrl: _imagePath,
        date: _selectedDate.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );

      // Create double-entry journal lines
      // ====================================
      // ACCOUNTING RULE:
      // - Debit increases: Assets, Expenses
      // - Credit increases: Liabilities, Equity, Income
      // 
      // For each transaction between Cash and Another Account:
      // One gets Debit, other gets Credit (always balances)
      // ====================================

      List<JournalLineModel> journalLines = [];

      if (side == 'Debit') {
        // DEBIT SIDE: Amount going OUT of cash
        // Selected account increases (Debit it)
        // Cash decreases (Credit it)
        
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: selectedAccount!.accountId!,
            debit: amount,  // Selected account: Debit increases
            credit: 0,
          ),
        );
        
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: cashAccountId!,
            debit: 0,
            credit: amount,  // Cash: Credit decreases
          ),
        );
      } else {
        // CREDIT SIDE: Amount coming INTO cash
        // Cash increases (Debit it)
        // Selected account increases (Credit it)
        
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: cashAccountId!,
            debit: amount,  // Cash: Debit increases
            credit: 0,
          ),
        );
        
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: selectedAccount!.accountId!,
            debit: 0,
            credit: amount,  // Selected account: Credit increases
          ),
        );
      }

      // Save complete journal with double-entry validation
      // (validates SUM(debit) = SUM(credit))
      await _accountingService.createCompleteJournal(
        journalEntry: journalEntry,
        journalLines: journalLines,
      );

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);

    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Add Transaction',
        ),
      ),

      body: Padding(

        padding:
            EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),

        child: Form(

          key: _formKey,

          child: SafeArea(

            child: ListView(

            children: [

              // =====================
              // ACCOUNT
              // =====================

              DropdownButtonFormField<
                  AccountModel>(

                value: (selectedAccount != null && accounts.any((account) => account.accountId == selectedAccount!.accountId))
                    ? selectedAccount
                    : null,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Select Account',

                  border:
                      OutlineInputBorder(),
                ),

                items: accounts.map(
                  (account) {

                    return DropdownMenuItem(

                      value: account,

                      child: Text(
                        account.name,
                      ),
                    );
                  },
                ).toList(),

                onChanged: (value) {

                  setState(() {

                    selectedAccount =
                        value;
                  });
                },
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // AMOUNT
              // =====================

              TextFormField(

                controller:
                    amountController,

                keyboardType:
                    TextInputType.number,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Amount',

                  border:
                      OutlineInputBorder(),
                ),

                validator: (value) {

                  if (value == null ||
                      value.isEmpty) {

                    return 'Enter amount';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // TRANSACTION TYPE (Debit/Credit with clear labels)
              // =====================

              Text(
                'Transaction Type',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    // Debit Option
                    InkWell(
                      onTap: () => setState(() => side = 'Debit'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Debit',
                            groupValue: side,
                            onChanged: (value) => setState(() => side = value!),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Debit (Money Out)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                                ),
                                Text(
                                  'Expense, Cost, Asset Purchase',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                    
                    // Credit Option
                    InkWell(
                      onTap: () => setState(() => side = 'Credit'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Credit',
                            groupValue: side,
                            onChanged: (value) => setState(() => side = value!),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Credit (Money In)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                ),
                                Text(
                                  'Income, Revenue, Liability',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // =====================
              // HELP TEXT
              // =====================

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cash account is automatically added as counter-entry',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // DATE & TIME PICKER
              // =====================
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${_selectedDate.toString().split('.').first}'),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Due date
              InkWell(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Due Date: ${_dueDate == null ? 'Optional' : _dueDate.toString().split(' ').first}'),
                      const Icon(Icons.event_available),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Image picker
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach Image'),
                  ),
                  const SizedBox(width: 12),
                  if (_imagePath != null)
                    Expanded(
                      child: Image.file(File(_imagePath!), height: 60, fit: BoxFit.cover),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              // =====================
              // PAYMENT METHOD
              // =====================

              DropdownButtonFormField(

                value:
                    paymentMethod,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Payment Method',

                  border:
                      OutlineInputBorder(),
                ),

                items: [

                  'Cash',

                  'Bank',

                  'Online',
                ].map(
                  (method) {

                    return DropdownMenuItem(

                      value: method,

                      child: Text(
                        method,
                      ),
                    );
                  },
                ).toList(),

                onChanged: (value) {

                  setState(() {

                    paymentMethod =
                        value!;
                  });
                },
              ),

              const SizedBox(
                height: 15,
              ),


              // =====================
              // SAVE BUTTON
              // =====================

              SizedBox(

                height: 55,

                child: ElevatedButton(

                  onPressed:
                      isLoading
                          ? null
                          : saveTransaction,

                  child: isLoading

                      ? const
                          CircularProgressIndicator()

                      : const Text(
                          'Save Transaction',
                        ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}