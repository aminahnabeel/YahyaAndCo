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

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attached Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showImageViewer(t.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        t.imageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 160,
                            color: Colors.grey.shade300,
                            child: const Center(child: Text('Failed to load image')),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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
