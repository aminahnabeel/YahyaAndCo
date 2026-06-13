import 'package:flutter/material.dart';

import '../../models/journal_entry_model.dart';
import '../../screens/journal/journal_detail_screen.dart';
import '../../services/accounting_service.dart';
import '../../widgets/date_filter_dialog.dart';

class CashBookScreen extends StatefulWidget {
  final int businessId;

  const CashBookScreen({super.key, required this.businessId});

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  final AccountingService _accountingService = AccountingService();

  List<Map<String, dynamic>> cashBook = [];

  bool isLoading = true;

  double runningBalance = 0;
  int? selectedYear;
  int? selectedMonth;

  @override
  void initState() {
    super.initState();

    loadCashBook();
  }

  Future loadCashBook() async {
    cashBook = await _accountingService.getCashBook(widget.businessId);

    if (cashBook.isEmpty) {
      cashBook = [];
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = false;
    });
  }

  void _onFilterPressed() {
    showDialog(
      context: context,
      builder: (context) => DateFilterDialog(
        initialYear: selectedYear,
        initialMonth: selectedMonth,
        onApply: (year, month) {
          setState(() {
            selectedYear = year;
            selectedMonth = month;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Filter applied: ${_getMonthName(month)} $year',
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _onDownloadPressed() {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    runningBalance = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _onFilterPressed,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _onDownloadPressed,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cashBook.isEmpty
          ? const Center(child: Text('No Cash Book Found'))
          : ListView.builder(
              itemCount: cashBook.length,

              itemBuilder: (context, index) {
                final item = cashBook[index];

                double debit = item['debit'] == null
                    ? 0
                    : (item['debit'] as num).toDouble();
                double credit = item['credit'] == null
                    ? 0
                    : (item['credit'] as num).toDouble();
                final status = (item['payment_status'] ?? 'Paid').toString();
                final journalId = item['journal_id'] as int?;
                final isPaid = status.toLowerCase() == 'paid';

                if (isPaid) {
                  runningBalance += credit - debit;
                }

                return Card(
                  margin: const EdgeInsets.all(10),

                  child: ListTile(
                    onTap: journalId != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JournalDetailScreen(
                                  journal: JournalEntryModel(
                                    journalId: journalId,
                                    businessId: widget.businessId,
                                    transactionId: null,
                                    voucherNo:
                                        item['voucher_no']?.toString() ?? '',
                                    voucherType: 'CP',
                                    description:
                                        item['description']?.toString() ?? '',
                                    dueDate: item['due_date']?.toString(),
                                    paymentStatus: status,
                                    remainingAmount:
                                        (item['remaining_amount'] as num?)
                                            ?.toDouble() ??
                                        0,
                                    imageUrl: null,
                                    date: item['date']?.toString() ?? '',
                                    createdAt: item['date']?.toString() ?? '',
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                    title: Text(item['voucher_no'].toString()),
                    subtitle: Text(
                      '${item['account_name'] ?? 'Cash'} • ${item['date']} • $status',
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,

                      children: [
                        Text('Receipt: $debit'),
                        Text('Payment: $credit'),
                        Text('Balance: $runningBalance'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
