import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../theme.dart';

class PayReceiveScreen extends StatefulWidget {
  final int businessId;

  const PayReceiveScreen({super.key, required this.businessId});

  @override
  State<PayReceiveScreen> createState() => _PayReceiveScreenState();
}

class _PayReceiveScreenState extends State<PayReceiveScreen> {
  late Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _loadAccounts();
  }

  Future<List<Map<String, dynamic>>> _loadAccounts() {
    return DatabaseHelper.instance.getPayReceiveAccounts(widget.businessId);
  }

  Future<void> _refresh() async {
    setState(() {
      _accountsFuture = _loadAccounts();
    });
    await _accountsFuture;
  }

  double _debit(Map<String, dynamic> entry) {
    return (entry['debit'] as num?)?.toDouble() ?? 0;
  }

  double _credit(Map<String, dynamic> entry) {
    return (entry['credit'] as num?)?.toDouble() ?? 0;
  }

  String _money(double amount) {
    final value = amount.abs();
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} Lac';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load payables and receivables.'),
            );
          }

          final entries = snapshot.data ?? const <Map<String, dynamic>>[];
          final receivableEntries = entries
              .where((entry) => _debit(entry) > 0)
              .toList();
          final payableEntries = entries
              .where((entry) => _credit(entry) > 0)
              .toList();
          final receivables = receivableEntries.fold<double>(
            0,
            (sum, entry) => sum + _debit(entry),
          );
          final payables = payableEntries.fold<double>(
            0,
            (sum, entry) => sum + _credit(entry),
          );
          final groupedReceivables = _groupByAccount(receivableEntries);
          final groupedPayables = _groupByAccount(payableEntries);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        title: 'Total Receivables',
                        amount: receivables,
                        color: Colors.green,
                        icon: Icons.south_west,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        title: 'Total Payables',
                        amount: payables,
                        color: Colors.red,
                        icon: Icons.north_east,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No pending payables or receivables.'),
                    ),
                  )
                else ...[
                  if (groupedReceivables.isNotEmpty) ...[
                    _sectionTitle('To Take', Colors.green),
                    ...groupedReceivables.map(
                      (account) => _accountTile(account, isReceivable: true),
                    ),
                  ],
                  if (groupedPayables.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('To Pay', Colors.red),
                    ...groupedPayables.map(
                      (account) => _accountTile(account, isReceivable: false),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      height: 140,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 22),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }

  List<Map<String, dynamic>> _groupByAccount(
    List<Map<String, dynamic>> entries,
  ) {
    final groups = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      final accountId = entry['account_id']?.toString() ?? '';
      final accountName = (entry['account_name'] ?? 'Account').toString();
      final key = accountId.isEmpty ? accountName.toLowerCase() : accountId;
      final group = groups.putIfAbsent(
        key,
        () => {
          'account_id': entry['account_id'],
          'account_name': accountName,
          'account_type': entry['account_type'],
          'amount': 0.0,
          'entries': <Map<String, dynamic>>[],
        },
      );
      group['amount'] =
          (group['amount'] as double) +
          (_debit(entry) > 0 ? _debit(entry) : _credit(entry));
      (group['entries'] as List<Map<String, dynamic>>).add(entry);
    }
    return groups.values.toList();
  }

  Widget _accountTile(
    Map<String, dynamic> account, {
    required bool isReceivable,
  }) {
    final amount = (account['amount'] as num?)?.toDouble() ?? 0;
    final color = isReceivable ? Colors.green : Colors.red;
    final accountName = (account['account_name'] ?? 'Account').toString();
    final accountType = (account['account_type'] ?? '').toString();
    final voucherEntries = account['entries'] as List<Map<String, dynamic>>;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showVoucherDetails(
          accountName,
          voucherEntries,
          isReceivable: isReceivable,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(
            isReceivable ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(
          accountName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$accountType • ${voucherEntries.length} voucher(s)'),
        trailing: SizedBox(
          width: 105,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _money(amount),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                isReceivable ? 'To Receive' : 'To Give',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoucherDetails(
    String accountName,
    List<Map<String, dynamic>> entries, {
    required bool isReceivable,
  }) async {
    final color = isReceivable ? Colors.green : Colors.red;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                accountName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(isReceivable ? 'To Receive' : 'To Give', style: TextStyle(color: color)),
              const SizedBox(height: 16),
              ...entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((entry['voucher_no'] ?? '-').toString()),
                  subtitle: Text(
                    '${entry['voucher_type'] ?? ''} • ${entry['entry_date'] ?? '-'} • ${entry['payment_status'] ?? ''}',
                  ),
                  trailing: Text(
                    _money(isReceivable ? _debit(entry) : _credit(entry)),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
