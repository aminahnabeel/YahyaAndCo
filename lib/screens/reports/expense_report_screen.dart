import 'package:flutter/material.dart';

class ExpenseReportScreen extends StatelessWidget {
  final int businessId;
  const ExpenseReportScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Report')),
      body: const Center(child: Text('Expense Report not implemented yet')),
    );
  }
}
