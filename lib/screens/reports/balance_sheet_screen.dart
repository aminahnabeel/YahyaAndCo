import 'package:flutter/material.dart';

class BalanceSheetScreen extends StatelessWidget {
  final int businessId;
  const BalanceSheetScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Sheet')),
      body: const Center(child: Text('Balance Sheet not implemented yet')),
    );
  }
}
