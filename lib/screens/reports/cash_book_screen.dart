import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/journal_entry_model.dart';
import '../../screens/journal/journal_detail_screen.dart';
import '../../services/accounting_service.dart';
import '../../services/pdf_download_service.dart';
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

    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    loadCashBook();
  }

  Future loadCashBook() async {
    cashBook = await _accountingService.getCashBook(
      widget.businessId,
      year: selectedYear,
      month: selectedMonth,
    );

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
              content: Text('Filter applied: ${_getMonthName(month)} $year'),
            ),
          );
          // Reload data after filter is applied
          loadCashBook();
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
      'Dec',
    ];
    return months[month - 1];
  }

  void _onDownloadPressed() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

      final pdf = pw.Document();
      final monthName = _getMonthName(selectedMonth ?? DateTime.now().month);
      final year = selectedYear ?? DateTime.now().year;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Cash Book Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Month: $monthName $year',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Date',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Description',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Inflow',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Outflow',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Balance',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    ...cashBook.map((item) {
                      double debit = item['debit'] == null
                          ? 0
                          : (item['debit'] as num).toDouble();
                      double credit = item['credit'] == null
                          ? 0
                          : (item['credit'] as num).toDouble();
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item['date']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item['description']?.toString() ?? '',
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatPdfCurrency(debit)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatPdfCurrency(credit)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatPdfCurrency(credit - debit)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final fileName = 'CashBook_${monthName}_$year.pdf';
      final filePath = await PdfDownloadService.savePdfToDownloads(
        pdfBytes: await pdf.save(),
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF saved: $filePath',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generating PDF: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0';
    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatPdfCurrency(double value) {
    return _formatCurrency(value).replaceFirst('₹', '');
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _cashAmountText('Receipt', debit),
                        _cashAmountText('Payment', credit),
                        _cashAmountText('Balance', runningBalance),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _cashAmountText(String label, double amount) {
    return Text(
      '$label: ${_formatCurrency(amount)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, height: 1.15),
    );
  }
}
