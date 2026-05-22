import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/accounting_service.dart';
import '../../services/payment_reminder_service.dart';
import '../../theme.dart';
import '../accounts/account_screen.dart';
import '../calculator_screen.dart';
import '../journal/journal_create_screen.dart';
import '../journal/journal_list_screen.dart';
import '../reports/cash_book_screen.dart';
import '../reports/ledger_screen.dart';
import '../reports/trial_balance_screen.dart';
import '../reports/reports_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int businessId;

  const DashboardScreen({super.key, required this.businessId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AccountingService _accountingService = AccountingService();
  late Future<Map<String, double>> _summaryFuture;
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _summaryFuture = _accountingService.getDashboardSummary(widget.businessId);
    unawaited(PaymentReminderService.instance.syncDueReminders(widget.businessId));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshSummary() async {
    setState(() {
      _summaryFuture = _accountingService.getDashboardSummary(widget.businessId);
    });
    await _summaryFuture;
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Transactions';
      case 1:
        return 'Reports';
      case 2:
        return 'Home';
      case 3:
        return 'Accounts';
      default:
        return 'Calculator';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              _buildHomeTab(),
              _buildTransactionTab(),
              _buildReportsTab(),
              _buildAccountsTab(),
              _buildCalculatorTab(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade400,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        },
        items: [
          BottomNavigationBarItem(icon: _navIcon(Icons.home, 0), activeIcon: _navIcon(Icons.home, 0, selected: true), label: 'Home'),
          BottomNavigationBarItem(icon: _navIcon(Icons.swap_horiz, 1), activeIcon: _navIcon(Icons.swap_horiz, 1, selected: true), label: 'Transactions'),
          BottomNavigationBarItem(icon: _navIcon(Icons.assessment, 2), activeIcon: _navIcon(Icons.assessment, 2, selected: true), label: 'Reports'),
          BottomNavigationBarItem(icon: _navIcon(Icons.account_balance, 3), activeIcon: _navIcon(Icons.account_balance, 3, selected: true), label: 'Accounts'),
          BottomNavigationBarItem(icon: _navIcon(Icons.calculate, 4), activeIcon: _navIcon(Icons.calculate, 4, selected: true), label: 'Calculator'),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {bool selected = false}) {
    final isActive = _selectedIndex == index;
    return AnimatedScale(
      scale: selected || isActive ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Icon(icon),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _refreshSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, double>>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data ?? <String, double>{};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financial Cards - Like in the mockup
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  children: [
                    _financialCard('Total Balance', summary['totalCash'] ?? 0, Colors.blue, Icons.account_balance_wallet),
                    _financialCard('Cash in Hand', summary['totalCash'] ?? 0, Colors.green, Icons.money),
                    _financialCard('Debit', summary['totalDebit'] ?? 0, Colors.orange, Icons.trending_up),
                    _financialCard('Credit', summary['totalCredit'] ?? 0, Colors.red, Icons.trending_down),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Quick Actions Section Header
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                // Quick Action Cards - 2 per row
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  children: [
                    _quickActionCard(
                      title: 'Add Transaction',
                      icon: Icons.add_circle,
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddTransactionScreen(businessId: widget.businessId)),
                      ),
                    ),
                    _quickActionCard(
                      title: 'Add Journal Entry',
                      icon: Icons.receipt_long,
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JournalCreateScreen(businessId: widget.businessId)),
                      ),
                    ),
                    _quickActionCard(
                      title: 'View Journal Entry',
                      icon: Icons.description,
                      color: Colors.deepOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JournalListScreen(businessId: widget.businessId)),
                      ),
                    ),
                    _quickActionCard(
                      title: 'Ledger',
                      icon: Icons.book_outlined,
                      color: Colors.brown,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LedgerScreen(businessId: widget.businessId)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Full-Width Add Account Button
                _quickActionCard(
                  title: 'Add Account',
                  icon: Icons.add_box,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AccountScreen(businessId: widget.businessId)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _financialCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_money(value)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.08),
                color.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _reportButton(
          title: 'All Reports',
          icon: Icons.assessment,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReportsScreen(businessId: widget.businessId)),
          ),
        ),
        _reportButton(
          title: 'Ledger',
          icon: Icons.book_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LedgerScreen(businessId: widget.businessId)),
          ),
        ),
        _reportButton(
          title: 'Trial Balance',
          icon: Icons.balance,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrialBalanceScreen(businessId: widget.businessId)),
          ),
        ),
        _reportButton(
          title: 'Cash Book',
          icon: Icons.menu_book,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CashBookScreen(businessId: widget.businessId)),
          ),
        ),
      ],
    );
  }

  Widget _reportButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return AccountScreen(businessId: widget.businessId);
  }

  Widget _buildTransactionTab() {
    return TransactionListScreen(businessId: widget.businessId);
  }

  Widget _buildCalculatorTab() {
    return const CalculatorScreen();
  }
}