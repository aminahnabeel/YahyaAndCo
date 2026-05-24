import 'package:flutter/material.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_screen.dart';
import 'balance_sheet_screen.dart';
import 'cash_book_screen.dart';

class ReportsScreen extends StatelessWidget {
  final int businessId;
  const ReportsScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _reportCard(context, title: 'Trial Balance', icon: Icons.balance, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrialBalanceScreen(businessId: businessId)))),
                _reportCard(context, title: 'Profit & Loss', icon: Icons.show_chart, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfitLossScreen(businessId: businessId)))),
                _reportCard(context, title: 'Balance Sheet', icon: Icons.account_tree_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BalanceSheetScreen(businessId: businessId)))),
                _reportCard(context, title: 'Cash Book', icon: Icons.menu_book, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CashBookScreen(businessId: businessId)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0,2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
