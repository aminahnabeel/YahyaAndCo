import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/accounting_service.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_screen.dart';
import 'balance_sheet_screen.dart';
import 'cash_book_screen.dart';

class ReportsScreen extends StatefulWidget {
  final int businessId;
  const ReportsScreen({super.key, required this.businessId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportsDataFuture;
  final AccountingService _accountingService = AccountingService();

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  void _loadReportsData() {
    _reportsDataFuture = _accountingService.getReportsCardData(
      widget.businessId,
    );
  }

  void _refreshData() {
    setState(() {
      _loadReportsData();
    });
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(2)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  String _getTrialBalanceStatus(List<Map<String, dynamic>> trialBalance) {
    bool isBalanced = true;
    for (var row in trialBalance) {
      final debit = (row['total_debit'] as num?)?.toDouble() ?? 0;
      final credit = (row['total_credit'] as num?)?.toDouble() ?? 0;
      if ((debit - credit).abs() > 0.01) {
        isBalanced = false;
        break;
      }
    }
    return isBalanced ? 'Balanced' : 'Unbalanced';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading reports'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final trialBalance =
              (data['trialBalance'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
          final cashBalance = (data['cashBalance'] as num?)?.toDouble() ?? 0;
          final profitMargin = (data['profitMargin'] as String?) ?? '0%';
          final balanceSheetStatus =
              (data['balanceSheetStatus'] as String?) ?? 'Healthy';
          final trialBalanceStatus = _getTrialBalanceStatus(trialBalance);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ListView(
              children: [
                _reportCard(
                  context,
                  icon: Icons.balance_outlined,
                  iconBgColor: const Color(0xFFFFA500),
                  title: 'Trial Balance',
                  description: 'Baba debit and credit summary snapshot',
                  badge: trialBalanceStatus,
                  badgeColor: const Color(0xFFFFA500),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TrialBalanceScreen(businessId: widget.businessId),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _reportCard(
                  context,
                  icon: Icons.attach_money_outlined,
                  iconBgColor: const Color(0xFFFFA500),
                  title: 'Cash Book',
                  description: 'Baba cash inflows and outflows',
                  badge: _formatCurrency(cashBalance),
                  badgeColor: const Color(0xFFFFA500),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CashBookScreen(businessId: widget.businessId),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _reportCard(
                  context,
                  icon: Icons.trending_up_outlined,
                  iconBgColor: const Color(0xFF06B6D4),
                  title: 'Profit & Loss',
                  description: 'Baba revenue versus expenses overview',
                  badge: profitMargin,
                  badgeColor: const Color(0xFF06B6D4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfitLossScreen(businessId: widget.businessId),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _reportCard(
                  context,
                  icon: Icons.grid_on_outlined,
                  iconBgColor: const Color(0xFF8B5CF6),
                  title: 'Balance Sheet',
                  description: 'Baba assets, liabilities, and equity snapshot',
                  badge: balanceSheetStatus,
                  badgeColor: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BalanceSheetScreen(businessId: widget.businessId),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reportCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String description,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconBgColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
