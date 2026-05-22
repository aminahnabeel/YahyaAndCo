import 'package:flutter/material.dart';

import '../../services/accounting_service.dart';
import '../../theme.dart';

class ReminderScreen extends StatefulWidget {
  final int businessId;

  const ReminderScreen({super.key, required this.businessId});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final AccountingService _accountingService = AccountingService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTimeRange? _dateRange;

  List<Map<String, dynamic>> _dueToday = [];
  List<Map<String, dynamic>> _pendingTransactions = [];
  List<Map<String, dynamic>> _pendingJournals = [];
  List<Map<String, dynamic>> _overdueTransactions = [];
  List<Map<String, dynamic>> _overdueJournals = [];
  List<Map<String, dynamic>> _upcomingPayments = [];

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
    _dueToday = await _accountingService.getDueToday(widget.businessId);
    _pendingTransactions = await _accountingService.getPendingTransactions(widget.businessId);
    _pendingJournals = await _accountingService.getPendingJournals(widget.businessId);
    _overdueTransactions = await _accountingService.getOverdueTransactions(widget.businessId);
    _overdueJournals = await _accountingService.getOverdueJournals(widget.businessId);
    _upcomingPayments = await _accountingService.getUpcomingDuePayments(widget.businessId);
    setState(() => _loading = false);
  }

  bool _matches(Map<String, dynamic> item) {
    final query = _searchQuery.trim().toLowerCase();
    final voucher = (item['voucher_no'] ?? '').toString().toLowerCase();
    final account = (item['account_name'] ?? '').toString().toLowerCase();
    final description = (item['description'] ?? '').toString().toLowerCase();
    final status = (item['payment_status'] ?? '').toString();
    final dueDateText = (item['due_date'] ?? '').toString();
    final dueDate = DateTime.tryParse(dueDateText);

    final searchMatch = query.isEmpty || voucher.contains(query) || account.contains(query) || description.contains(query);
    final statusMatch = _statusFilter == 'All' || status.toLowerCase() == _statusFilter.toLowerCase();

    bool dateMatch = true;
    if (_dateRange != null && dueDate != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
      dateMatch = !dueDate.isBefore(start) && !dueDate.isAfter(end);
    }

    return searchMatch && statusMatch && dateMatch;
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        break;
      case 'partial':
        color = Colors.blue;
        break;
      case 'overdue':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final amount = (item['amount'] ?? 0 as num).toDouble();
    final remaining = (item['remaining_amount'] ?? 0 as num).toDouble();
    final status = (item['payment_status'] ?? 'Pending').toString();

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
                  child: Text((item['voucher_no'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text((item['account_name'] ?? 'Unknown').toString(), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text((item['description'] ?? 'No description').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Type: ${(item['record_type'] ?? 'Entry').toString()}'),
                _chip('Amount: ₹${amount.toStringAsFixed(2)}'),
                _chip('Remaining: ₹${remaining.toStringAsFixed(2)}'),
                _chip('Due: ${(item['due_date'] ?? '-').toString()}'),
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

  Future<void> _openFilters() async {
    String tempStatus = _statusFilter;
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tempStatus,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                        DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      ],
                      onChanged: (value) => setModalState(() => tempStatus = value ?? 'All'),
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
        _dateRange = tempRange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ..._dueToday,
      ..._pendingTransactions,
      ..._pendingJournals,
      ..._overdueTransactions,
      ..._overdueJournals,
      ..._upcomingPayments,
    ].where(_matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(onPressed: _openFilters, icon: const Icon(Icons.filter_list)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  TextField(
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
                  const SizedBox(height: 12),
                  _section('Due Today', _dueToday.where(_matches).toList()),
                  _section('Pending Payments', [
                    ..._pendingTransactions.where(_matches),
                    ..._pendingJournals.where(_matches),
                  ].toList()),
                  _section('Overdue Payments', [
                    ..._overdueTransactions.where(_matches),
                    ..._overdueJournals.where(_matches),
                  ].toList()),
                  _section('Upcoming Payments', _upcomingPayments.where(_matches).toList()),
                  const SizedBox(height: 12),
                  Text('Visible Records: ${allItems.length}', style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text('No records'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...items.map(_buildCard),
        ],
      ),
    );
  }
}
