import 'package:flutter/material.dart';
import '../../services/accounting_service.dart';

class LedgerReportScreen extends StatefulWidget {
  final int businessId;
  final int accountId;
  final String accountName;

  const LedgerReportScreen({super.key, required this.businessId, required this.accountId, required this.accountName});

  @override
  State<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends State<LedgerReportScreen> {
  final AccountingService _accountingService = AccountingService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _rows = await _accountingService.getLedgerForAccount(widget.businessId, widget.accountId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    double balance = 0;
    return Scaffold(
      appBar: AppBar(title: Text('Ledger - ${widget.accountName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Voucher')),
                      DataColumn(label: Text('Debit')),
                      DataColumn(label: Text('Credit')),
                      DataColumn(label: Text('Due Date')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Balance')),
                    ],
                    rows: _rows.map((r) {
                      final debit = (r['debit'] ?? 0) as num;
                      final credit = (r['credit'] ?? 0) as num;
                      balance += debit.toDouble() - credit.toDouble();
                      return DataRow(cells: [
                        DataCell(Text(r['date'] ?? '')),
                        DataCell(Text(r['voucher_no'] ?? '')),
                        DataCell(Text(debit.toString())),
                        DataCell(Text(credit.toString())),
                        DataCell(Text((r['due_date'] ?? '').toString())),
                        DataCell(Text((r['payment_status'] ?? 'Paid').toString())),
                        DataCell(Text(balance.toStringAsFixed(2))),
                      ]);
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
