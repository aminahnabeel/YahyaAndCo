import 'package:flutter/material.dart';
import '../../services/accounting_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await _accountingService.getProfitLoss(widget.businessId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Income Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...((_data?['incomeAccounts'] as List?) ?? []).map((item) {
                      return Card(
                        child: ListTile(
                          title: Text(item['name'].toString()),
                          subtitle: Text('Credit: ${(item['total_credit'] ?? 0).toString()}'),
                          trailing: Text(
                            'Net: ${(item['net_balance'] ?? 0).toString()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text('Expense Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...((_data?['expenseAccounts'] as List?) ?? []).map((item) {
                      return Card(
                        child: ListTile(
                          title: Text(item['name'].toString()),
                          subtitle: Text('Debit: ${(item['total_debit'] ?? 0).toString()}'),
                          trailing: Text(
                            'Net: ${(item['net_balance'] ?? 0).toString()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.grey.shade200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${(_data?['profit'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
