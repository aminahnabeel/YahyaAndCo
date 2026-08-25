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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ListView(
              children: [
                _reportCard(
                  context,
                  icon: Icons.balance_outlined,
                  iconBgColor: const Color(0xFFFFA500),
                  title: 'Trial Balance',
                  description: 'debit and credit summary snapshot',
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
                  description: 'cash inflows and outflows',
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
                  description: 'Revenue versus expenses overview',
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
                  description: 'Assets, liabilities, and equity snapshot',
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
            ],
          ),
        ),
      ),
    );
  }
}
