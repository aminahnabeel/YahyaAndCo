import 'package:flutter/material.dart';

import 'due_payments_report_screen.dart';

class RecoveryReportScreen extends StatelessWidget {
  final int businessId;

  const RecoveryReportScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return DuePaymentsReportScreen(
      businessId: businessId,
      title: 'Recovery Report',
      mode: 'recovery',
    );
  }
}
