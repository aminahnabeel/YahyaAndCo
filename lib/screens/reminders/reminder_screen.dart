import 'package:flutter/material.dart';

import '../../services/journal_service.dart';
import '../../services/reminder_service.dart';
import '../../theme.dart';

class ReminderScreen extends StatefulWidget {
  final int businessId;

  const ReminderScreen({super.key, required this.businessId});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final ReminderService _reminderService = ReminderService();
  final JournalService _journalService = JournalService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _typeFilter = 'All';
  DateTimeRange? _dateRange;

  List<Map<String, dynamic>> _entries = [];

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

  String _normalizeStatus(dynamic rawStatus) {
    final value = (rawStatus ?? '').toString().toLowerCase();
    if (value == 'paid') return 'Paid';
    if (value == 'overdue') return 'Overdue';
    if (value == 'pending') return 'Pending';
    return 'Pending';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _entries = await _reminderService.loadReminders(widget.businessId);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  bool _matches(Map<String, dynamic> item) {
    final query = _searchQuery.trim().toLowerCase();
    final voucher = (item['voucher_no'] ?? '').toString().toLowerCase();
    final account = (item['account_name'] ?? '').toString().toLowerCase();
    final description = (item['description'] ?? '').toString().toLowerCase();
    final paymentMethod = (item['payment_method'] ?? '')
        .toString()
        .toLowerCase();
    final voucherType = (item['voucher_type'] ?? '').toString().toLowerCase();
    final status = _normalizeStatus(item['payment_status']);
    final recordType = (item['record_type'] ?? '').toString();
    final dueDate = DateTime.tryParse((item['due_date'] ?? '').toString());
    final date = DateTime.tryParse((item['date'] ?? '').toString());

    final searchMatch =
        query.isEmpty ||
        voucher.contains(query) ||
        account.contains(query) ||
        description.contains(query) ||
        paymentMethod.contains(query) ||
        voucherType.contains(query);

    final statusMatch =
        _statusFilter == 'All' ||
        status.toLowerCase() == _statusFilter.toLowerCase();
    final typeMatch =
        _typeFilter == 'All' ||
        recordType.toLowerCase() == _typeFilter.toLowerCase();

    bool dateMatch = true;
    if (_dateRange != null) {
      final compareDate = dueDate ?? date;
      if (compareDate != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        dateMatch = !compareDate.isBefore(start) && !compareDate.isAfter(end);
      }
    }

    return searchMatch && statusMatch && typeMatch && dateMatch;
  }

  List<Map<String, dynamic>> get _filteredEntries {
    final uniqueEntries = <String, Map<String, dynamic>>{};
    for (final entry in _entries.where(_matches)) {
      final recordType = (entry['record_type'] ?? '').toString().toLowerCase();
      final recordId = entry['record_id']?.toString() ?? '';
      final voucherNo = (entry['voucher_no'] ?? '').toString().trim();
      final key = recordId.isNotEmpty
          ? '$recordType:$recordId'
          : '$recordType:$voucherNo';
      uniqueEntries.putIfAbsent(key, () => entry);
    }
    return uniqueEntries.values.toList();
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

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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

  Widget _quickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyQuickFilter({String? status, String? type}) async {
    setState(() {
      if (status != null) _statusFilter = status;
      if (type != null) _typeFilter = type;
    });
  }

  Future<void> _markAsPaid(Map<String, dynamic> item) async {
    final recordType = (item['record_type'] ?? '').toString();
    final id = (item['record_id'] as num?)?.toInt();
    if (id == null) return;

    await _reminderService.markAsPaid(
      sourceTable: item['source_table'].toString(),
      recordId: id,
    );

    await _load();
  }

  Future<void> _showReceipt(Map<String, dynamic> item) async {
    final recordType = (item['record_type'] ?? '').toString();
    final status = _normalizeStatus(item['payment_status']);
    final journalId = (item['journal_id'] as num?)?.toInt();
    final journalLinesFuture = journalId == null
        ? Future.value(<Map<String, dynamic>>[])
        : _journalService.getJournalLines(journalId);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: journalLinesFuture,
          builder: (context, snapshot) {
            final lines = snapshot.data ?? <Map<String, dynamic>>[];
            final amount =
                ((item['amount'] ?? item['remaining_amount'] ?? 0) as num)
                    .toDouble();
            final remaining = ((item['remaining_amount'] ?? 0) as num)
                .toDouble();
            final dueDate = (item['due_date'] ?? '').toString();
            final date = (item['date'] ?? '').toString();
            final description = (item['description'] ?? '').toString();
            final accountName = (item['account_name'] ?? 'Unknown').toString();
            final paymentMethod = (item['payment_method'] ?? '-').toString();
            final voucherType = (item['voucher_type'] ?? '-').toString();
            final color = _statusColor(status);

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['voucher_no'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recordType,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.14)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _metaRow('Account', accountName),
                          const SizedBox(height: 8),
                          _metaRow('Amount', '₹${amount.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _metaRow(
                            'Remaining',
                            '₹${remaining.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _metaRow(
                            'Date',
                            date.isEmpty ? '-' : date.split('T').first,
                          ),
                          const SizedBox(height: 8),
                          _metaRow('Due Date', dueDate.isEmpty ? '-' : dueDate),
                          const SizedBox(height: 8),
                          _metaRow('Payment Method', paymentMethod),
                          const SizedBox(height: 8),
                          _metaRow('Voucher Type', voucherType),
                          const SizedBox(height: 8),
                          Text(
                            description.isEmpty
                                ? 'No description'
                                : description,
                          ),
                        ],
                      ),
                    ),
                    if (recordType.toLowerCase() == 'journal' &&
                        snapshot.connectionState ==
                            ConnectionState.waiting) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (recordType.toLowerCase() == 'journal' &&
                        lines.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Journal Lines',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...lines.map((line) {
                        final debit = ((line['debit'] ?? 0) as num).toDouble();
                        final credit = ((line['credit'] ?? 0) as num)
                            .toDouble();
                        return Card(
                          child: ListTile(
                            title: Text(
                              (line['account_name'] ?? 'Account').toString(),
                            ),
                            subtitle: Text(
                              'Debit: ${debit.toStringAsFixed(2)}  |  Credit: ${credit.toStringAsFixed(2)}',
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: status == 'Paid'
                                ? null
                                : () async {
                                    await _markAsPaid(item);
                                    if (Navigator.of(sheetContext).canPop()) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                            child: const Text('Mark as Paid'),
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

    if (mounted) {
      await _load();
    }
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _quickFilters() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.22,
      children: [
        _quickActionCard(
          title: 'All',
          icon: Icons.grid_view,
          color: AppColors.primary,
          onTap: () => _applyQuickFilter(status: 'All', type: 'All'),
        ),
        _quickActionCard(
          title: 'Paid',
          icon: Icons.check_circle,
          color: Colors.green,
          onTap: () => _applyQuickFilter(status: 'Paid'),
        ),
        _quickActionCard(
          title: 'Pending',
          icon: Icons.schedule,
          color: Colors.orange,
          onTap: () => _applyQuickFilter(status: 'Pending'),
        ),
        _quickActionCard(
          title: 'Overdue',
          icon: Icons.warning,
          color: Colors.red,
          onTap: () => _applyQuickFilter(status: 'Overdue'),
        ),
        _quickActionCard(
          title: 'Transactions',
          icon: Icons.swap_horiz,
          color: Colors.indigo,
          onTap: () => _applyQuickFilter(type: 'Transaction'),
        ),
        _quickActionCard(
          title: 'Journals',
          icon: Icons.receipt_long,
          color: Colors.teal,
          onTap: () => _applyQuickFilter(type: 'Journal'),
        ),
      ],
    );
  }

  Future<void> _openFilters() async {
    String tempStatus = _statusFilter;
    String tempType = _typeFilter;
    DateTimeRange? tempRange = _dateRange;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Overdue',
                          child: Text('Overdue'),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => tempStatus = value ?? 'All'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tempType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Transaction',
                          child: Text('Transaction'),
                        ),
                        DropdownMenuItem(
                          value: 'Journal',
                          child: Text('Journal'),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => tempType = value ?? 'All'),
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
                      label: Text(
                        tempRange == null
                            ? 'Date Range'
                            : '${tempRange!.start.toIso8601String().split('T').first} - ${tempRange!.end.toIso8601String().split('T').first}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'All';
                                tempType = 'All';
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
        _typeFilter = tempType;
        _dateRange = tempRange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final visibleCount = entries.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search voucher, account, note...',
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _quickFilters(),
                  const SizedBox(height: 14),
                  if (entries.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('No records found'),
                    )
                  else
                    ...entries.map((item) {
                      final status = _normalizeStatus(item['payment_status']);
                      final amount =
                          ((item['amount'] ?? item['remaining_amount'] ?? 0)
                                  as num)
                              .toDouble();
                      final remaining = ((item['remaining_amount'] ?? 0) as num)
                          .toDouble();
                      final dueDate = (item['due_date'] ?? '').toString();
                      final date = (item['date'] ?? '').toString();
                      final recordType = (item['record_type'] ?? '').toString();
                      final voucherType = (item['voucher_type'] ?? '')
                          .toString();
                      final accountName = (item['account_name'] ?? 'Unknown')
                          .toString();
                      final description = (item['description'] ?? '')
                          .toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          onTap: () => _showReceipt(item),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (item['voucher_no'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _statusChip(status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                '$recordType • $accountName',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description.isEmpty
                                    ? 'No description'
                                    : description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip(
                                    'Amount: ₹${amount.toStringAsFixed(2)}',
                                  ),
                                  _chip(
                                    'Remaining: ₹${remaining.toStringAsFixed(2)}',
                                  ),
                                  _chip(
                                    'Date: ${date.isEmpty ? '-' : date.split('T').first}',
                                  ),
                                  _chip(
                                    'Due: ${dueDate.isEmpty ? '-' : dueDate}',
                                  ),
                                  if (voucherType.isNotEmpty)
                                    _chip('Type: $voucherType'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text(
                    'Visible Records: $visibleCount',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
    );
  }
}
