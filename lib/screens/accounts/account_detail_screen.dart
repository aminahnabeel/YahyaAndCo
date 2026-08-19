import 'package:flutter/material.dart';
import '../../models/account_model.dart';
import '../../models/journal_line_model.dart';
import '../../models/transaction_model.dart';
import '../../services/account_service.dart';

import '../../theme.dart';

class AccountDetailScreen extends StatefulWidget {
  final AccountModel account;

  const AccountDetailScreen({
    super.key,
    required this.account,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController openingBalanceController;
  late String selectedType;
  bool isLoading = false;
  bool isEditing = false;
  double openingBalanceDisplay = 0;

  final AccountService _accountService = AccountService();
  

  final List<String> accountTypes = [
    'Asset',
    'Liability',
    'Equity',
    'Revenue',
    'Expense',
    'Customer',
    'Supplier',
    'Cash',
    'Bank',
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.account.name);
    phoneController = TextEditingController(text: widget.account.phone ?? '');
    addressController = TextEditingController(text: widget.account.address ?? '');
    openingBalanceController = TextEditingController(
      text: widget.account.openingBalance == 0
          ? ''
          : widget.account.openingBalance.toString(),
    );
    selectedType = widget.account.type;
    openingBalanceDisplay = widget.account.openingBalance;
    _loadOpeningBalance();
  }

  Future<void> _loadOpeningBalance() async {
    if (widget.account.accountId == null) return;

    final openingBalance =
        await _accountService.getAccountOpeningBalanceFromJournal(widget.account.accountId!);

    if (mounted) {
      setState(() {
        openingBalanceDisplay = openingBalance;
        openingBalanceController.text =
            openingBalance == 0 ? '' : openingBalance.toStringAsFixed(2);
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _updateAccount() async {
    setState(() => isLoading = true);

    try {
      final parsedOpeningBalance = _parseAmount(openingBalanceController.text);

      final updatedAccount = AccountModel(
        accountId: widget.account.accountId,
        businessId: widget.account.businessId,
        name: nameController.text.trim(),
        type: selectedType,
        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
        openingBalance: parsedOpeningBalance,
        createdAt: widget.account.createdAt,
      );

      await _accountService.updateAccount(updatedAccount);
      final refreshedOpeningBalance = await _accountService.getAccountOpeningBalanceFromJournal(widget.account.accountId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account Updated Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          isEditing = false;
          openingBalanceDisplay = refreshedOpeningBalance;
          openingBalanceController.text = refreshedOpeningBalance == 0
              ? ''
              : refreshedOpeningBalance.toStringAsFixed(2);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double _parseAmount(String raw) {
    final normalized = raw
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(normalized) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _accountService.getAccountClosingBalance(widget.account.accountId!),
      builder: (context, snapshot) {
        final closingBalance = snapshot.data ?? openingBalanceDisplay;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Account Details'),
            backgroundColor: AppColors.primary,
            actions: [
              if (!isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() => isEditing = true);
                  },
                ),
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: isLoading ? null : _updateAccount,
                ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Balance Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Opening Balance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${openingBalanceDisplay.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Closing Balance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${closingBalance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!isEditing) ...[
                        // Transactions and Journal Entries Section
                        _buildTransactionsList(),
                        const SizedBox(height: 20),
                      ],

                      // Account Details Form
                      if (isEditing) ...[
                        TextField(
                          controller: nameController,
                          enabled: isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Account Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          onChanged: (value) {
                            setState(() {
                              selectedType = value!;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Account Type',
                            border: OutlineInputBorder(),
                          ),
                          items: accountTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          enabled: isEditing,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: addressController,
                          enabled: isEditing,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: openingBalanceController,
                          enabled: isEditing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Opening Balance',
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        // Display Account Details
                        _buildDetailRow('Account Name', widget.account.name),
                        _buildDetailRow('Account Type', widget.account.type),
                        if (widget.account.phone != null)
                          _buildDetailRow('Phone', widget.account.phone!),
                        if (widget.account.address != null)
                          _buildDetailRow('Address', widget.account.address!),
                        _buildDetailRow(
                          'Created Date',
                          DateTime.parse(widget.account.createdAt).toString().split('.')[0],
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Transactions & Entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TransactionModel>>(
          future: _accountService.getTransactionsByAccountId(widget.account.accountId!),
          builder: (context, txSnapshot) {
            return FutureBuilder<List<JournalLineModel>>(
              future: _accountService.getJournalLinesByAccountId(widget.account.accountId!),
              builder: (context, jlSnapshot) {
                final transactions = txSnapshot.data ?? [];
                final journalLines = jlSnapshot.data ?? [];

                if (transactions.isEmpty && journalLines.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('No transactions or journal entries found'),
                    ),
                  );
                }

                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Transactions
                    if (transactions.isNotEmpty) ...[
                      const Text(
                        'Transactions',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...transactions.map((tx) => _buildTransactionTile(tx)),
                      const SizedBox(height: 16),
                    ],
                    // Journal Entries
                    if (journalLines.isNotEmpty) ...[
                      const Text(
                        'Journal Entries',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...journalLines.map((jl) => _buildJournalLineTile(jl)),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    final isDebit = transaction.type.toLowerCase() == 'debit' || transaction.type.toLowerCase() == 'deposit';
    final color = isDebit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.note,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${isDebit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalLineTile(JournalLineModel line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journal Entry #${line.journalId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (line.debit > 0) ...[
                      Text(
                        'Debit: ₹${line.debit.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (line.credit > 0) ...[
                      Text(
                        'Credit: ₹${line.credit.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
