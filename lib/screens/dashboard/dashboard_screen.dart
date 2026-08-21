import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
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
import '../settings_screen.dart';

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

  Future<List<Map<String, dynamic>>> _getBankAccountsWithAmounts() async {
    final accounts = await DatabaseHelper.instance.getAccountsByBusiness(widget.businessId);
    final bankAccounts = accounts.where((account) {
      final name = (account.name ?? '').toString().toLowerCase();
      final type = (account.type ?? '').toString().toLowerCase();
      return type == 'bank' || name.contains('bank');
    }).toList();

    final results = <Map<String, dynamic>>[];
    for (final account in bankAccounts) {
      final accountId = account.accountId;
      if (accountId == null) continue;

      final amount = await _accountingService.getAccountBalance(accountId);
      results.add({
        'name': account.name,
        'amount': amount,
      });
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _getCashAndOwnerCapitalAccounts() async {
    final accounts = await DatabaseHelper.instance.getAccountsByBusiness(widget.businessId);
    final targeted = accounts.where((account) {
      final name = (account.name ?? '').toString().trim().toLowerCase();
      final type = (account.type ?? '').toString().trim().toLowerCase();
      return name == 'cash' ||
          name == 'cash in hand' ||
          name == 'owner capital' ||
          type == 'cash' ||
          (name.contains('cash') && name.contains('hand')) ||
          (name.contains('capital') && type == 'equity');
    }).toList();

    final results = <Map<String, dynamic>>[];
    for (final account in targeted) {
      final accountId = account.accountId;
      if (accountId == null) continue;

      final amount = await _accountingService.getAccountBalance(accountId);
      results.add({
        'name': account.name,
        'amount': amount,
      });
    }
    return results;
  }

  Future<void> _showBreakdownDialog({
    required String title,
    required List<Map<String, dynamic>> rows,
  }) async {
    final total = rows.fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble());

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: rows.isEmpty
                ? const Text('No account data found.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...rows.map((row) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    (row['name'] ?? 'Account').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  _money((row['amount'] as num).toDouble()),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            _money(total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _money(double value) => value.toStringAsFixed(2);

  void _openSettingsSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
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
            final totalBankBalance = summary['totalBankBalance'] ?? summary['totalBalance'] ?? 0;
            final cashInHand = summary['cashInHand'] ?? summary['totalCash'] ?? 0;

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
                    _financialCard(
                      title: 'Total Bank Balance',
                      value: totalBankBalance,
                      color: Colors.blue,
                      icon: Icons.account_balance_wallet,
                      onTap: () async {
                        final rows = await _getBankAccountsWithAmounts();
                        if (!mounted) return;
                        await _showBreakdownDialog(title: 'Bank Accounts', rows: rows);
                      },
                    ),
                    _financialCard(
                      title: 'Cash in Hand',
                      value: cashInHand,
                      color: Colors.orange,
                      icon: Icons.money,
                      onTap: () async {
                        final rows = await _getCashAndOwnerCapitalAccounts();
                        if (!mounted) return;
                        await _showBreakdownDialog(title: 'Cash & Owner Capital', rows: rows);
                      },
                    ),
                    _financialCard(
                      title: 'Debit',
                      value: summary['totalDebit'] ?? 0,
                      color: Colors.green,
                      icon: Icons.trending_up,
                      onTap: null,
                    ),
                    _financialCard(
                      title: 'Credit',
                      value: summary['totalCredit'] ?? 0,
                      color: Colors.red,
                      icon: Icons.trending_down,
                      onTap: null,
                    ),
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

  Widget _financialCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final card = Container(
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

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
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