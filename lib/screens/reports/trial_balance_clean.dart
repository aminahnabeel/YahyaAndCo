import 'package:flutter/material.dart';
import '../../services/accounting_service.dart';

class TrialBalanceScreen extends StatefulWidget {
  final int businessId;

  const TrialBalanceScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
  final AccountingService _accountingService = AccountingService();
  List<Map<String, dynamic>> trialBalance = [];
  bool isLoading = true;
  double totalDebit = 0;
  double totalCredit = 0;

  @override
  void initState() {
    super.initState();
    loadTrialBalance();
  }

  Future<void> loadTrialBalance() async {
    trialBalance = await _accountingService.getTrialBalanceForBusiness(widget.businessId);
    totalDebit = 0;
    totalCredit = 0;
    for (var item in trialBalance) {
      totalDebit += (item['total_debit'] == null ? 0 : (item['total_debit'] as num).toDouble());
      totalCredit += (item['total_credit'] == null ? 0 : (item['total_credit'] as num).toDouble());
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trial Balance')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: trialBalance.length,
                    itemBuilder: (context, index) {
                      final item = trialBalance[index];
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(item['name'].toString()),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Debit: ${item['total_debit'] ?? 0}'),
                              Text('Credit: ${item['total_credit'] ?? 0}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Debit: $totalDebit',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total Credit: $totalCredit',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
