import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../theme.dart';
import '../../services/accounting_service.dart';
import '../../widgets/date_filter_dialog.dart';
import '../test_data_generator_screen.dart';

class TrialBalanceScreen extends StatefulWidget {
  final int businessId;

  const TrialBalanceScreen({super.key, required this.businessId});

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  final AccountingService _accountingService = AccountingService();
  List<Map<String, dynamic>> trialBalance = [];
  bool isLoading = true;
  double totalDebit = 0;
  double totalCredit = 0;
  bool isBalanced = false;
  int? selectedYear;
  int? selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    loadTrialBalance();
  }

  Future<void> loadTrialBalance() async {
    trialBalance = await _accountingService.getTrialBalanceForBusiness(
      widget.businessId,
      year: selectedYear,
      month: selectedMonth,
    );
    totalDebit = 0;
    totalCredit = 0;
    for (var item in trialBalance) {
      totalDebit += (item['total_debit'] == null
          ? 0
          : (item['total_debit'] as num).toDouble());
      totalCredit += (item['total_credit'] == null
          ? 0
          : (item['total_credit'] as num).toDouble());
    }
    isBalanced = (totalDebit - totalCredit).abs() < 0.01;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadTestData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _accountingService.addTestData(widget.businessId);
      await loadTrialBalance();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading test data: $e')));
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null || value == 0) return '₹0';
    double amount = (value is num) ? value.toDouble().abs() : 0;
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)}L';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  // Smart grouping that derives group name from account name
  Map<String, List<Map<String, dynamic>>> _groupAccountsByName() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var account in trialBalance) {
      String accountName = account['name']?.toString() ?? 'Other';
      String groupName = _extractGroupName(accountName);

      if (!grouped.containsKey(groupName)) {
        grouped[groupName] = [];
      }
      grouped[groupName]!.add(account);
    }

    return grouped;
  }

  String _extractGroupName(String accountName) {
    accountName = accountName.trim();
    List<String> words = accountName.split(' ');

    // Check for specific keywords first
    if (accountName.contains('Bank')) {
      return 'Bank\nAccount';
    }
    if (accountName.contains('Cash')) {
      return 'Cash\nAccount';
    }
    if (accountName.contains('Capital')) {
      return 'Capital';
    }
    if (accountName.contains('Employee') ||
        (words.length >= 2 && _isPersonName(accountName))) {
      return 'Employee\nAccount';
    }
    if (accountName.contains('Drawing')) {
      return 'Owner\nDrawing';
    }
    if (accountName.contains('Flour') ||
        accountName.contains('Mills') ||
        accountName.contains('Factory') ||
        accountName.contains('Cotton')) {
      return 'Company\nExpenses';
    }
    if (accountName.contains('Commission') ||
        accountName.contains('Sales') ||
        accountName.contains('Income') ||
        accountName.contains('Brokerage')) {
      return 'Direct\nIncome';
    }

    // Default: use first word as group name
    if (words.isNotEmpty) {
      return words[0];
    }

    return accountName;
  }

  bool _isPersonName(String name) {
    final commonPatterns = [
      'Muhammad',
      'Mian',
      'Abdul',
      'Ahmad',
      'Asif',
      'Khana',
      'Shah',
      'Khan',
      'Gul',
      'Ali',
      'Hassan',
    ];
    return commonPatterns.any((pattern) => name.contains(pattern));
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
          loadTrialBalance();
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
                  'Trial Balance Report',
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
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
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
                            'Account',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Debit',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Credit',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    ...trialBalance.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item['name']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              _formatCurrency(item['total_debit']),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              _formatCurrency(item['total_credit']),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            _formatCurrency(totalDebit),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            _formatCurrency(totalCredit),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/TrialBalance_${monthName}_$year.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: ${file.path}'),
            duration: const Duration(seconds: 2),
          ),
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

  void _openTestDataGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestDataGeneratorScreen(businessId: widget.businessId),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh the data after test data is generated
        loadTrialBalance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trial Balance'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _onFilterPressed,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _onDownloadPressed,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'test_data') {
                _openTestDataGenerator();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'test_data',
                child: Row(
                  children: [
                    Icon(Icons.data_usage, size: 20),
                    SizedBox(width: 8),
                    Text('Generate Test Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  color: isBalanced
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  child: Row(
                    children: [
                      Icon(
                        isBalanced ? Icons.check_circle : Icons.cancel,
                        color: isBalanced
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isBalanced
                            ? 'Trial Balance is Balanced'
                            : 'Trial Balance Not Balanced',
                        style: TextStyle(
                          color: isBalanced
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Header
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Code',
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Account',
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Debit',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Credit',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Content
                Expanded(
                  child: trialBalance.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No accounts found',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadTestData,
                                icon: const Icon(Icons.add),
                                label: const Text('Load Test Data'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(children: _buildGroupedTable()),
                        ),
                ),
                // Grand Total Footer
                Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Grand',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _formatCurrency(totalDebit),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFFC41C3B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _formatCurrency(totalCredit),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Total Debit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _formatCurrency(totalDebit),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(flex: 1, child: Container()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Total Credit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(flex: 1, child: Container()),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _formatCurrency(totalCredit),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
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
  }

  List<Widget> _buildGroupedTable() {
    if (trialBalance.isEmpty) {
      return [];
    }

    final grouped = _groupAccountsByName();
    List<Widget> rows = [];

    // Sort groups by a logical order
    final groupOrder = [
      'Bank\nAccount',
      'Capital',
      'Employee\nAccount',
      'Owner\nDrawing',
      'Direct\nIncome',
      'Company\nExpenses',
      'Cash\nAccount',
    ];

    final sortedGroups = grouped.keys.toList()
      ..sort((a, b) {
        int aIndex = groupOrder.indexOf(a);
        int bIndex = groupOrder.indexOf(b);
        if (aIndex == -1) aIndex = groupOrder.length;
        if (bIndex == -1) bIndex = groupOrder.length;
        return aIndex.compareTo(bIndex);
      });

    for (final groupName in sortedGroups) {
      final accounts = grouped[groupName] ?? [];
      if (accounts.isEmpty) continue;

      double groupDebit = 0;
      double groupCredit = 0;

      // Add group header
      rows.add(
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),
              Expanded(flex: 2, child: Container()),
            ],
          ),
        ),
      );

      // Add individual accounts
      for (var account in accounts) {
        final debit =
            (account['total_debit'] == null
                    ? 0
                    : (account['total_debit'] as num).toDouble())
                .toDouble();
        final credit =
            (account['total_credit'] == null
                    ? 0
                    : (account['total_credit'] as num).toDouble())
                .toDouble();

        groupDebit += debit;
        groupCredit += credit;

        rows.add(
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    account['account_id']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    account['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    debit > 0 ? _formatCurrency(debit) : '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFC41C3B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    credit > 0 ? _formatCurrency(credit) : '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Add group total
      rows.add(
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Group\nTotal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.grey[700],
                    height: 1.2,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  groupDebit > 0 ? _formatCurrency(groupDebit) : '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: const Color(0xFFC41C3B),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  groupCredit > 0 ? _formatCurrency(groupCredit) : '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      rows.add(const SizedBox(height: 1));
    }

    return rows;
  }
}
