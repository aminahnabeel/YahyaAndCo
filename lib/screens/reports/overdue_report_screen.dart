import 'package:flutter/material.dart';

import 'due_payments_report_screen.dart';

class OverdueReportScreen extends StatelessWidget {
  final int businessId;

  const OverdueReportScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return DuePaymentsReportScreen(
      businessId: businessId,
      title: 'Overdue Report',
      mode: 'overdue',
    );
  }
}
