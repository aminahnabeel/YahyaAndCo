import 'package:flutter/material.dart';

import '../../services/accounting_service.dart';
import '../../theme.dart';

class DuePaymentsReportScreen extends StatefulWidget {
  final int businessId;
  final String title;
  final String mode;

  const DuePaymentsReportScreen({
    super.key,
    required this.businessId,
    required this.title,
    required this.mode,
  });

  @override
  State<DuePaymentsReportScreen> createState() => _DuePaymentsReportScreenState();
}

class _DuePaymentsReportScreenState extends State<DuePaymentsReportScreen> {
  final AccountingService _accountingService = AccountingService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _voucherTypeFilter = 'All';
  String _paymentMethodFilter = 'All';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _records = await _accountingService.getAllOutstandingRecords(widget.businessId);
    setState(() => _loading = false);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  bool _matchesFilters(Map<String, dynamic> record) {
    final voucherNo = (record['voucher_no'] ?? '').toString().toLowerCase();
    final accountName = (record['account_name'] ?? '').toString().toLowerCase();
    final description = (record['description'] ?? '').toString().toLowerCase();
    final paymentMethod = (record['payment_method'] ?? '').toString().toLowerCase();
    final status = (record['payment_status'] ?? 'Pending').toString();
    final voucherType = (record['voucher_type'] ?? '').toString();
    final dueDateText = (record['due_date'] ?? '').toString();
    final dueDate = DateTime.tryParse(dueDateText);
    final query = _searchQuery.trim().toLowerCase();

    final searchMatch = query.isEmpty ||
        voucherNo.contains(query) ||
        accountName.contains(query) ||
        description.contains(query) ||
        paymentMethod.contains(query);

    final statusMatch = _statusFilter == 'All' || status.toLowerCase() == _statusFilter.toLowerCase();
    final voucherTypeMatch = _voucherTypeFilter == 'All' || voucherType.toLowerCase().contains(_voucherTypeFilter.toLowerCase());
    final paymentMethodMatch = _paymentMethodFilter == 'All' || paymentMethod == _paymentMethodFilter.toLowerCase();

    bool dateMatch = true;
    if (_dateRange != null && dueDate != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
      dateMatch = !dueDate.isBefore(start) && !dueDate.isAfter(end);
    }

    bool modeMatch = true;
    final amount = (record['amount'] ?? 0 as num).toDouble();
    final remaining = (record['remaining_amount'] ?? 0 as num).toDouble();
    switch (widget.mode) {
      case 'overdue':
        modeMatch = status.toLowerCase() == 'overdue' || (dueDate != null && dueDate.isBefore(DateTime.now()) && remaining > 0);
        break;
      case 'recovery':
        modeMatch = remaining > 0 && remaining < amount;
        break;
      default:
        modeMatch = remaining > 0;
    }

    return searchMatch && statusMatch && voucherTypeMatch && paymentMethodMatch && dateMatch && modeMatch;
  }

  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where(_matchesFilters).toList();
  }

  Future<void> _openFilters() async {
    String tempStatus = _statusFilter;
    String tempVoucherType = _voucherTypeFilter;
    String tempPaymentMethod = _paymentMethodFilter;
    DateTimeRange? tempRange = _dateRange;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tempStatus,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                      ],
                      onChanged: (value) => setModalState(() => tempStatus = value ?? 'All'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tempVoucherType,
                      decoration: const InputDecoration(labelText: 'Voucher Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'JV', child: Text('JV')),
                        DropdownMenuItem(value: 'CP', child: Text('CP')),
                        DropdownMenuItem(value: 'Transaction', child: Text('Transaction')),
                      ],
                      onChanged: (value) => setModalState(() => tempVoucherType = value ?? 'All'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tempPaymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank')),
                        DropdownMenuItem(value: 'online', child: Text('Online')),
                      ],
                      onChanged: (value) => setModalState(() => tempPaymentMethod = value ?? 'All'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: tempRange,
                        );
                        if (picked != null) {
                          setModalState(() => tempRange = picked);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(tempRange == null
                          ? 'Date Range'
                          : '${tempRange!.start.toIso8601String().split('T').first} - ${tempRange!.end.toIso8601String().split('T').first}'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'All';
                                tempVoucherType = 'All';
                                tempPaymentMethod = 'All';
                                tempRange = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _statusFilter = tempStatus;
        _voucherTypeFilter = tempVoucherType;
        _paymentMethodFilter = tempPaymentMethod;
        _dateRange = tempRange;
      });
    }
  }

  Widget _buildCard(Map<String, dynamic> record) {
    final status = (record['payment_status'] ?? 'Pending').toString();
    final dueDate = (record['due_date'] ?? '').toString();
    final amount = (record['amount'] ?? 0 as num).toDouble();
    final remaining = (record['remaining_amount'] ?? 0 as num).toDouble();
    final accountName = (record['account_name'] ?? 'Unknown').toString();
    final voucherNo = (record['voucher_no'] ?? '').toString();
    final voucherType = (record['voucher_type'] ?? '').toString();
    final description = (record['description'] ?? '').toString();
    final typeLabel = (record['record_type'] ?? 'Entry').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(voucherNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(accountName, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(description.isEmpty ? 'No description' : description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Type: $typeLabel'),
                _chip('Voucher: ${voucherType.isEmpty ? '-' : voucherType}'),
                _chip('Amount: ₹${amount.toStringAsFixed(2)}'),
                _chip('Remaining: ₹${remaining.toStringAsFixed(2)}'),
                _chip('Due: ${dueDate.isEmpty ? '-' : dueDate}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final totalAmount = filtered.fold<double>(0, (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble());
    final totalRemaining = filtered.fold<double>(0, (sum, item) => sum + ((item['remaining_amount'] ?? 0) as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search voucher, account, notes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: _summaryCard('Rows', filtered.length.toString(), Colors.blue)),
                      const SizedBox(width: 8),
                      Expanded(child: _summaryCard('Amount', '₹${totalAmount.toStringAsFixed(2)}', Colors.green)),
                      const SizedBox(width: 8),
                      Expanded(child: _summaryCard('Remaining', '₹${totalRemaining.toStringAsFixed(2)}', Colors.red)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No records found'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _buildCard(filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
