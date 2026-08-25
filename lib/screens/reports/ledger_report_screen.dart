import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/accounting_service.dart';
import '../../services/pdf_download_service.dart';
import '../../theme.dart';

class LedgerReportScreen extends StatefulWidget {
  final int businessId;
  final int accountId;
  final String accountName;

  const LedgerReportScreen({
    super.key,
    required this.businessId,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends State<LedgerReportScreen> {
  final AccountingService _accountingService = AccountingService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  DateTime? _selectedMonth;
  
  // Date range filter
  String _dateRangeFilter = '1month'; // Default: 1 month

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _rows = await _accountingService.getLedgerForAccount(widget.businessId, widget.accountId);
    setState(() => _loading = false);
  }

  DateTime _getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getMonthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  // Get date range based on filter
  Map<String, DateTime> _getDateRange() {
    final baseDate = _selectedMonth ?? DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (_dateRangeFilter) {
      case '3months':
        startDate = DateTime(baseDate.year, baseDate.month - 2, 1);
        endDate = DateTime(baseDate.year, baseDate.month + 1, 0);
        break;
      case '6months':
        startDate = DateTime(baseDate.year, baseDate.month - 5, 1);
        endDate = DateTime(baseDate.year, baseDate.month + 1, 0);
        break;
      case '1year':
        startDate = DateTime(baseDate.year - 1, baseDate.month, 1);
        endDate = DateTime(baseDate.year, baseDate.month + 1, 0);
        break;
      case '1month':
      default:
        startDate = _getMonthStart(baseDate);
        endDate = _getMonthEnd(baseDate);
    }

    return {'start': startDate, 'end': endDate};
  }

  // Get all months from account creation to now
  List<Map<String, dynamic>> _getAllMonths() {
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];

    // Go back 12 months from now (can adjust if needed)
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add({
        'date': date,
        'label': '${_getMonthName(date.month)} ${date.year}',
      });
    }

    return months;
  }

  String _getDateRangeLabel() {
    final range = _getDateRange();
    final start = range['start']!;
    final end = range['end']!;
    
    switch (_dateRangeFilter) {
      case '3months':
        return '${_getMonthName(start.month)} ${start.year} - ${_getMonthName(end.month)} ${end.year}';
      case '6months':
        return '${_getMonthName(start.month)} ${start.year} - ${_getMonthName(end.month)} ${end.year}';
      case '1year':
        return '${_getMonthName(start.month)} ${start.year} - ${_getMonthName(end.month)} ${end.year}';
      case '1month':
      default:
        return '${_formatDate(start)} to ${_formatDate(end)}';
    }
  }

  List<Map<String, dynamic>> _getMonthlyLedger() {
    final range = _getDateRange();
    final startDate = range['start']!;
    final endDate = range['end']!;

    final filtered = _rows.where((row) {
      try {
        final date = DateTime.parse(row['date']?.toString() ?? '');
        return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();

    // Preserve database ordering (journal_id, line_id) returned by the query

    return filtered;
  }

  double _calculateOpeningBalance(DateTime startDate) {
    double balance = 0;
    for (var row in _rows) {
      try {
        final date = DateTime.parse(row['date']?.toString() ?? '');
        if (date.isBefore(startDate)) {
          final debit = (row['debit'] ?? 0) as num;
          final credit = (row['credit'] ?? 0) as num;
          balance += credit.toDouble() - debit.toDouble();
        }
      } catch (_) {
        continue;
      }
    }
    return balance;
  }

  Future<void> _downloadPDF() async {
    try {
      final monthlyData = _getMonthlyLedger();
      final range = _getDateRange();
      final monthStart = range['start']!;
      final monthEnd = range['end']!;

      final openingBalance = _calculateOpeningBalance(monthStart);

      // Create PDF document
      final pdf = pw.Document();
      double finalBalance = openingBalance;
      double totalDebit = 0;
      double totalCredit = 0;

      // Calculate data for PDF
      final pdfRows = <Map<String, dynamic>>[];
      pdfRows.add({
        'date': _formatDate(monthStart),
        'voucher': 'Opening Balance',
        'debit': openingBalance < 0 ? openingBalance.abs() : 0.0,
        'credit': openingBalance > 0 ? openingBalance : 0.0,
        'balance': finalBalance,
        'status': '',
      });

      for (var row in monthlyData) {
        final debit = (row['debit'] ?? 0) as num;
        final credit = (row['credit'] ?? 0) as num;
        totalDebit += debit.toDouble();
        totalCredit += credit.toDouble();
        finalBalance += credit.toDouble() - debit.toDouble();
        pdfRows.add({
          'date': row['date']?.toString() ?? '-',
          'voucher': row['voucher_no']?.toString() ?? '-',
          'debit': debit.toDouble(),
          'credit': credit.toDouble(),
          'balance': finalBalance,
          'status': row['payment_status']?.toString() ?? 'Paid',
        });
      }

      // Build PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'LEDGER REPORT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Account: ${widget.accountName}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                'Period: ${_formatDate(monthStart)} to ${_formatDate(monthEnd)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Generated: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Final Balance: ${_formatCurrency(finalBalance)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.0),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildPdfCell('Date', bold: true),
                    _buildPdfCell('Voucher', bold: true),
                    _buildPdfCell('Debit', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Credit', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Balance', bold: true, align: pw.TextAlign.right),
                    _buildPdfCell('Status', bold: true, align: pw.TextAlign.center),
                  ],
                ),
                // Data Rows
                ...pdfRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final row = entry.value;
                  final bgColor = idx.isEven ? PdfColors.white : PdfColors.grey50;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bgColor),
                    children: [
                      _buildPdfCell(row['date'], bgColor: bgColor),
                      _buildPdfCell(row['voucher'], bgColor: bgColor),
                      _buildPdfCell(
                        row['debit'].toStringAsFixed(2),
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        color: row['debit'] > 0
                            ? PdfColors.red
                            : PdfColors.grey,
                      ),
                      _buildPdfCell(
                        row['credit'].toStringAsFixed(2),
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        color: row['credit'] > 0
                            ? PdfColors.green
                            : PdfColors.grey,
                      ),
                      _buildPdfCell(
                        row['balance'].toStringAsFixed(2),
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.black,
                      ),
                      _buildPdfCell(
                        row['status'],
                        bgColor: bgColor,
                        align: pw.TextAlign.center,
                        color: _statusColor(row['status']?.toString() ?? ''),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),
            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Debit',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _formatCurrency(totalDebit),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Credit',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _formatCurrency(totalCredit),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Final Balance',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _formatCurrency(finalBalance),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Entries',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        pdfRows.length.toString(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // Create filename
      final fileName =
          'Ledger_${widget.accountName}_${_selectedMonth!.year}_${_selectedMonth!.month.toString().padLeft(2, '0')}.pdf';
      final filePath = await PdfDownloadService.savePdfToDownloads(
        pdfBytes: await pdf.save(),
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF Downloaded Successfully!\n\n$filePath\n${pdfRows.length} Entries\nBalance: ${_formatCurrency(finalBalance)}',
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ PDF Download Failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
    PdfColor bgColor = PdfColors.white,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      color: bgColor,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  PdfColor _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'paid') {
      return PdfColors.green;
    }
    if (normalized == 'pending') {
      return PdfColors.orange;
    }
    if (normalized == 'overdue') {
      return PdfColors.red;
    }
    return PdfColors.black;
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _dateRangeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _dateRangeFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final monthlyData = _getMonthlyLedger();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ledger - ${widget.accountName}'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.accountName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ledger Report',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date Range Filter Buttons
                  Text(
                    'Filter by Range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterButton('1M', '1month'),
                        const SizedBox(width: 8),
                        _buildFilterButton('3M', '3months'),
                        const SizedBox(width: 8),
                        _buildFilterButton('6M', '6months'),
                        const SizedBox(width: 8),
                        _buildFilterButton('1Y', '1year'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Months Selection Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Month',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _getAllMonths()
                                .map((month) {
                              final isSelected = _dateRangeFilter == '1month' &&
                                  _selectedMonth?.year == (month['date'] as DateTime).year &&
                                  _selectedMonth?.month == (month['date'] as DateTime).month;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMonth = month['date'];
                                      _dateRangeFilter = '1month';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      month['label'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date and Download Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getDateRangeLabel(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${monthlyData.length} entries',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: monthlyData.isEmpty ? null : _downloadPDF,
                        icon: const Icon(Icons.download, size: 22),
                        tooltip: 'Download PDF',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              monthlyData.isEmpty ? Colors.grey.shade300 : AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info Message
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select month or filter range, then download.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
