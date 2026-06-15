import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/accounting_service.dart';
import '../../services/notification_service.dart';
import '../../services/pdf_download_service.dart';
import '../../theme.dart';
import '../../widgets/date_filter_dialog.dart';

class ProfitLossScreen extends StatefulWidget {
  final int businessId;
  const ProfitLossScreen({super.key, required this.businessId});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final AccountingService _accountingService = AccountingService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  int? selectedYear;
  int? selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await _accountingService.getProfitLoss(
      widget.businessId,
      year: selectedYear,
      month: selectedMonth,
    );
    setState(() => _loading = false);
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0.00';

    // Format with comma separators in Indian style
    String formatted = value.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    // Add comma separators
    StringBuffer result = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 2 || (count > 2 && (count - 2) % 2 == 0)) {
        result.write(',');
      }
      result.write(integerPart[i]);
      count++;
    }

    String reversedInteger = result.toString().split('').reversed.join('');
    return '₹$reversedInteger.$decimalPart';
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
          _load();
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
                  'Profit & Loss Report',
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
                pw.Text(
                  'REVENUE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                ...((_data?['incomeAccounts'] as List?) ?? []).map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(item['name']?.toString() ?? ''),
                        pw.Text(
                          _formatCurrency(_asDouble(item['total_credit'])),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Revenue',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _formatCurrency(_asDouble(_data?['income'])),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'EXPENSES',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                ...((_data?['expenseAccounts'] as List?) ?? []).map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(item['name']?.toString() ?? ''),
                        pw.Text(
                          _formatCurrency(_asDouble(item['total_debit'])),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Expenses',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _formatCurrency(_asDouble(_data?['expense'])),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'NET PROFIT / LOSS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        _formatCurrency(_asDouble(_data?['profit'])),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final fileName = 'ProfitLoss_${monthName}_$year.pdf';

      // Save PDF to Downloads folder with Android 10+ scoped storage support
      final filePath = await PdfDownloadService.savePdfToDownloads(
        pdfBytes: await pdf.save(),
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Show notification with clickable action to open PDF
        await NotificationService().showDownloadNotification(
          filePath: filePath,
          fileName: fileName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // REVENUE SECTION
                    _buildSectionHeader('REVENUE'),
                    ...((_data?['incomeAccounts'] as List?) ?? []).map((item) {
                      return _buildLineItem(
                        code: item['account_id']?.toString() ?? '',
                        description: item['name']?.toString() ?? '',
                        amount: _asDouble(item['total_credit']),
                        color: const Color(0xFF06B6D4), // Cyan
                      );
                    }),
                    _buildTotalRow(
                      label: 'Total Revenue',
                      amount: _data?['income'] ?? 0,
                      backgroundColor: const Color(0xFFDEF7F4),
                      textColor: Colors.black87,
                    ),
                    const SizedBox(height: 24),

                    // EXPENSES SECTION
                    _buildSectionHeader('EXPENSES'),
                    ...((_data?['expenseAccounts'] as List?) ?? []).map((item) {
                      return _buildLineItem(
                        code: item['account_id']?.toString() ?? '',
                        description: item['name']?.toString() ?? '',
                        amount: _asDouble(item['total_debit']),
                        color: const Color(0xFFF87171), // Red
                      );
                    }),
                    _buildTotalRow(
                      label: 'Total Expenses',
                      amount: _data?['expense'] ?? 0,
                      backgroundColor: const Color(0xFFFFEDED),
                      textColor: Colors.black87,
                    ),
                    const SizedBox(height: 24),

                    // NET PROFIT / LOSS
                    _buildNetProfitRow(
                      profit: (_data?['profit'] ?? 0).toDouble(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey[800],
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLineItem({
    required String code,
    required String description,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              code,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(amount),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow({
    required String label,
    required double amount,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetProfitRow({required double profit}) {
    final isProfit = profit >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isProfit ? const Color(0xFFDEFCE0) : const Color(0xFFFFEDED),
        border: Border.all(
          color: isProfit ? const Color(0xFF10B981) : const Color(0xFFF87171),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isProfit ? 'NET PROFIT / (LOSS)' : 'NET PROFIT / (LOSS)',
            style: TextStyle(
              fontSize: 13,
              color: isProfit
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            _formatCurrency(profit.abs()),
            style: TextStyle(
              fontSize: 14,
              color: isProfit
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF87171),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
