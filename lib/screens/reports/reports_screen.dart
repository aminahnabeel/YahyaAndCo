import 'package:flutter/material.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_screen.dart';
import 'balance_sheet_screen.dart';
import 'cash_book_screen.dart';
import 'expense_report_screen.dart';
import '../reminders/reminder_screen.dart';
import 'outstanding_report_screen.dart';
import 'overdue_report_screen.dart';
import 'recovery_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  final int businessId;
  const ReportsScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            ListTile(
              title: const Text('Trial Balance'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrialBalanceScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Profit & Loss'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfitLossScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Balance Sheet'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BalanceSheetScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Cash Book'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CashBookScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Expense Report'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseReportScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Reminder'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Outstanding Report'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OutstandingReportScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Overdue Report'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OverdueReportScreen(businessId: businessId))),
            ),
            ListTile(
              title: const Text('Recovery Report'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecoveryReportScreen(businessId: businessId))),
            ),
          ],
        ),
      ),
    );
  }
}
