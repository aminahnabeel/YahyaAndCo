import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/accounting_service.dart';
import '../../widgets/date_filter_dialog.dart';

class BalanceSheetScreen extends StatefulWidget {
  final int businessId;
  const BalanceSheetScreen({super.key, required this.businessId});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  final AccountingService _accountingService = AccountingService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  int? selectedYear;
  int? selectedMonth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await _accountingService.getBalanceSheet(widget.businessId);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Sheet'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Banner
                  if (!(_data?['isBalanced'] ?? false))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      color: const Color(0xFFFFEDED),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cancel,
                            color: Color(0xFFF87171),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Balance Sheet Not Balanced',
                            style: TextStyle(
                              color: Color(0xFFF87171),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      color: const Color(0xFFDEF7F4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Balance Sheet is Balanced',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ASSETS SECTION
                        _buildSectionHeader('Assets'),
                        ...((_data?['assets'] as List?) ?? []).map((item) {
                          return _buildLineItem(
                            code: item['account_id']?.toString() ?? '',
                            description: item['name']?.toString() ?? '',
                            amount: _asDouble(item['balance']),
                            color: const Color(0xFF10B981), // Green
                          );
                        }),
                        const SizedBox(height: 12),

                        // LIABILITIES SECTION
                        _buildSectionHeader('Liabilities'),
                        ...((_data?['liabilities'] as List?) ?? []).map((item) {
                          return _buildLineItem(
                            code: item['account_id']?.toString() ?? '',
                            description: item['name']?.toString() ?? '',
                            amount: _asDouble(item['balance']),
                            color: const Color(0xFFF87171), // Red
                          );
                        }),
                        const SizedBox(height: 12),

                        // EQUITY SECTION
                        if ((_data?['equity'] as List?)?.isNotEmpty ??
                            false) ...[
                          _buildSectionHeader('Equity'),
                          ...((_data?['equity'] as List?) ?? []).map((item) {
                            return _buildLineItem(
                              code: item['account_id']?.toString() ?? '',
                              description: item['name']?.toString() ?? '',
                              amount: _asDouble(item['balance']),
                              color: const Color(0xFF8B5CF6), // Purple
                            );
                          }),
                          const SizedBox(height: 24),
                        ],

                        // TOTALS FOOTER
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Assets',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(
                                        _asDouble(_data?['totalAssets']),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Liabilities',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(
                                        _asDouble(_data?['totalLiabilities']) +
                                            _asDouble(_data?['totalEquity']),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFF87171),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      color: Colors.grey[100],
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[800],
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
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
            flex: 1,
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

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
