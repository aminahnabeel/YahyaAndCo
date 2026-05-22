import 'package:flutter/material.dart';

import 'due_payments_report_screen.dart';

class OutstandingReportScreen extends StatelessWidget {
  final int businessId;

  const OutstandingReportScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return DuePaymentsReportScreen(
      businessId: businessId,
      title: 'Outstanding Report',
      mode: 'outstanding',
    );
  }
}
