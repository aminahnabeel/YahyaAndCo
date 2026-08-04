import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/accounting_service.dart';
import '../../services/payment_reminder_service.dart';
import '../../theme.dart';
import '../accounts/account_screen.dart';
import '../calculator_screen.dart';
import '../journal/journal_create_screen.dart';
import '../journal/journal_list_screen.dart';
import '../reports/ledger_screen.dart';
import '../reports/reports_screen.dart';
import '../reminders/reminder_screen.dart';
import '../business_switch_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int businessId;
  final String businessName;

  const DashboardScreen({super.key, required this.businessId, required this.businessName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AccountingService _accountingService = AccountingService();
  late Future<Map<String, double>> _summaryFuture;
  late final PageController _pageController;
  int _selectedIndex = 2;
  int _pressedIndex = -1;
  static const double _navHeight = 74.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
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

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Settings screen will be added here.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Business details'),
                  subtitle: const Text('Manage business information'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage('assets/logo.png'),
          ),
        ),
        title: Text(
          widget.businessName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BusinessSwitchScreen(
                    currentBusinessId: widget.businessId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.swap_vert_rounded),
            tooltip: 'Switch Business',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettingsSheet,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          final velocity = details.primaryVelocity!;
          if (velocity > 300) {
            _animateToIndex(_selectedIndex - 1);
          } else if (velocity < -300) {
            _animateToIndex(_selectedIndex + 1);
          }
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            _buildTransactionTab(),
            _buildReportsTab(),
            _buildHomeTab(),
            _buildAccountsTab(),
            _buildCalculatorTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: SizedBox(
              height: _navHeight,
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: Colors.grey.shade400,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                iconSize: 20,
                elevation: 0,
                onTap: (index) async {
                  setState(() {
                    _pressedIndex = index;
                  });

                  await Future.delayed(const Duration(milliseconds: 120));

                  _animateToIndex(index);

                  setState(() {
                    _pressedIndex = -1;
                  });
                },
                items: [
                  BottomNavigationBarItem(
                    icon: _navIcon(Icons.swap_horiz, 0),
                    activeIcon: _navIcon(Icons.swap_horiz, 0, selected: true),
                    label: 'Transactions',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(Icons.assessment, 1),
                    activeIcon: _navIcon(Icons.assessment, 1, selected: true),
                    label: 'Reports',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(Icons.home, 2),
                    activeIcon: _navIcon(Icons.home, 2, selected: true),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(Icons.account_balance, 3),
                    activeIcon: _navIcon(Icons.account_balance, 3, selected: true),
                    label: 'Accounts',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(Icons.calculate, 4),
                    activeIcon: _navIcon(Icons.calculate, 4, selected: true),
                    label: 'Calculator',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {bool selected = false}) {
    final isActive = _selectedIndex == index;
    final isPressed = _pressedIndex == index;
    final isHomeIcon = index == 2;

    final double scale = isPressed
        ? 0.9
        : isActive
            ? (isHomeIcon ? 1.08 : 1.0)
            : 1.0;

    if (!isHomeIcon) {
      return AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Icon(icon, size: 20),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      padding: isActive ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.14) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Icon(icon, size: 20),
      ),
    );
  }

  void _animateToIndex(int index) {
    final target = index.clamp(0, 4);
    setState(() {
      _selectedIndex = target;
    });
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildHomeTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      onRefresh: _refreshSummary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _navHeight + bottomInset),
        child: FutureBuilder<Map<String, double>>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data ?? <String, double>{};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  children: [
                    _financialCard('Total Balance', summary['totalBalance'] ?? 0, Colors.blue, Icons.account_balance_wallet),
                    _financialCard('Cash in Hand', summary['totalCash'] ?? 0, Colors.green, Icons.money),
                    _financialCard('Debit', summary['totalDebit'] ?? 0, Colors.orange, Icons.trending_up),
                    _financialCard('Credit', summary['totalCredit'] ?? 0, Colors.red, Icons.trending_down),
                  ],
                ),
                const SizedBox(height: 24),
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
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
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
                      title: 'Add Journal',
                      icon: Icons.receipt_long,
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JournalCreateScreen(businessId: widget.businessId)),
                      ),
                    ),
                    _quickActionCard(
                      title: 'View Journals',
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
                    _quickActionCard(
                      title: 'Reminders',
                      icon: Icons.notifications_active,
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReminderScreen(businessId: widget.businessId)),
                      ),
                    ),
                    _quickActionCard(
                      title: 'Add Account',
                      icon: Icons.add_box,
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AccountScreen(businessId: widget.businessId)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 6),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _financialCard(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
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
        mainAxisAlignment: MainAxisAlignment.start,
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
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(value),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return ReportsScreen(businessId: widget.businessId);
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