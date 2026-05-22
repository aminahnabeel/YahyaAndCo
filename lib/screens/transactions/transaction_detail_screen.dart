import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../services/account_service.dart';
import '../../services/journal_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final AccountService _accountService = AccountService();
  final JournalService _journalService = JournalService();

  String _accountName = '';
  String? _voucherNo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final acct = await _accountService.getAccountById(widget.transaction.accountId);
    final journal = await _journalService.getJournalByTransactionId(widget.transaction.transactionId!);
    setState(() {
      _accountName = acct?.name ?? 'Unknown';
      _voucherNo = journal?.voucherNo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${t.amount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Account: $_accountName'),
            const SizedBox(height: 8),
            Text('Payment: ${t.paymentMethod}'),
            const SizedBox(height: 8),
            Text('Voucher: ${_voucherNo ?? '-'}'),
            const SizedBox(height: 12),
            if (t.imageUrl != null && t.imageUrl!.isNotEmpty)
              SizedBox(
                height: 160,
                child: Image.file(File(t.imageUrl!)),
              ),
            const SizedBox(height: 12),
            Text('Date: ${t.date}'),
            const SizedBox(height: 12),
            Text('Note: ${t.note}'),
          ],
        ),
      ),
    );
  }
}
