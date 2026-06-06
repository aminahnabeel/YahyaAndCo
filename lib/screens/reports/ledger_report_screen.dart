import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/accounting_service.dart';
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

  List<Map<String, dynamic>> _getMonthlyLedger() {
    if (_selectedMonth == null) return [];
    final monthStart = _getMonthStart(_selectedMonth!);
    final monthEnd = _getMonthEnd(_selectedMonth!);

    return _rows.where((row) {
      try {
        final date = DateTime.parse(row['date']?.toString() ?? '');
        return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            date.isBefore(monthEnd.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Future<void> _downloadPDF() async {
    try {
      final monthlyData = _getMonthlyLedger();
      final monthStart = _getMonthStart(_selectedMonth!);
      final monthEnd = _getMonthEnd(_selectedMonth!);

      // Create PDF document
      final pdf = pw.Document();
      double finalBalance = 0;

      // Calculate data for PDF
      final pdfRows = <Map<String, dynamic>>[];
      for (var row in monthlyData) {
        final debit = (row['debit'] ?? 0) as num;
        final credit = (row['credit'] ?? 0) as num;
        finalBalance += debit.toDouble() - credit.toDouble();
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
                        '₹${row['debit'].toStringAsFixed(2)}',
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        color: row['debit'] > 0
                            ? PdfColors.green
                            : PdfColors.grey,
                      ),
                      _buildPdfCell(
                        '₹${row['credit'].toStringAsFixed(2)}',
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        color: row['credit'] > 0
                            ? PdfColors.red
                            : PdfColors.grey,
                      ),
                      _buildPdfCell(
                        '₹${row['balance'].toStringAsFixed(2)}',
                        bgColor: bgColor,
                        align: pw.TextAlign.right,
                        bold: true,
                        color: row['balance'] >= 0
                            ? PdfColors.green
                            : PdfColors.red,
                      ),
                      _buildPdfCell(
                        row['status'],
                        bgColor: bgColor,
                        align: pw.TextAlign.center,
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
                        'Final Balance',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _formatCurrency(finalBalance),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: finalBalance >= 0
                              ? PdfColors.green
                              : PdfColors.red,
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

      // Get downloads directory
      final outputDir = await getDownloadsDirectory();
      if (outputDir == null) throw Exception('Downloads directory not available');

      // Create filename
      final fileName =
          'Ledger_${widget.accountName}_${_selectedMonth!.year}_${_selectedMonth!.month.toString().padLeft(2, '0')}.pdf';
      final file = await File('${outputDir.path}/$fileName').create(recursive: true);

      // Save PDF
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ PDF Downloaded Successfully!\n\n📄 $fileName\n📊 ${pdfRows.length} Entries\n💰 Balance: ${_formatCurrency(finalBalance)}',
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₹0.00';
    final num = double.tryParse(value.toString()) ?? 0;
    return '₹${num.toStringAsFixed(2)}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth!.year, _selectedMonth!.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlyData = _getMonthlyLedger();
    final monthStart = _getMonthStart(_selectedMonth!);
    final monthEnd = _getMonthEnd(_selectedMonth!);
    final monthName = _getMonthName(monthStart.month);
    final year = monthStart.year;

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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.accountName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Account Ledger Report',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Month Selector
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Month Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _previousMonth,
                              icon: const Icon(Icons.chevron_left),
                              color: AppColors.primary,
                              tooltip: 'Previous Month',
                            ),
                            Column(
                              children: [
                                Text(
                                  monthName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  year.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: _nextMonth,
                              icon: const Icon(Icons.chevron_right),
                              color: AppColors.primary,
                              tooltip: 'Next Month',
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Simple Date and Download Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatDate(monthStart)} to ${_formatDate(monthEnd)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${monthlyData.length} Entries',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: monthlyData.isEmpty ? null : _downloadPDF,
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text('Download PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info Message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
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
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Navigate months using arrows above, then download the PDF.',
                            style: TextStyle(
                              fontSize: 12,
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
