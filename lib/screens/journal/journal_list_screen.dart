import 'package:flutter/material.dart';

import '../../models/journal_entry_model.dart';
import '../../services/journal_service.dart';
import '../../theme.dart';
import 'journal_create_screen.dart';
import 'journal_detail_screen.dart';

class JournalListScreen extends StatefulWidget {
  final int businessId;

  const JournalListScreen({super.key, required this.businessId});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  final JournalService _journalService = JournalService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _voucherTypeFilter = 'All';
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
    _rows = await _journalService.getJournalRowsByBusiness(widget.businessId);
    setState(() => _loading = false);
  }

  String _normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().toLowerCase();
    if (status == 'paid') return 'Paid';
    if (status == 'overdue') return 'Overdue';
    return 'Pending';
  }

  bool _matches(Map<String, dynamic> row) {
    final query = _searchQuery.trim().toLowerCase();
    final voucherNo = (row['voucher_no'] ?? '').toString().toLowerCase();
    final accountName = (row['account_name'] ?? '').toString().toLowerCase();
    final description = (row['description'] ?? '').toString().toLowerCase();
    final status = _normalizeStatus(row['payment_status']);
    final voucherType = (row['voucher_type'] ?? '').toString().toLowerCase();
    final dueText = (row['due_date'] ?? '').toString();
    final dateText = (row['date'] ?? '').toString();
    final compareDate = DateTime.tryParse(
      dueText.isNotEmpty ? dueText : dateText,
    );

    final searchMatch =
        query.isEmpty ||
        voucherNo.contains(query) ||
        accountName.contains(query) ||
        description.contains(query);
    final statusMatch =
        _statusFilter == 'All' ||
        status.toLowerCase() == _statusFilter.toLowerCase();
    final voucherTypeMatch =
        _voucherTypeFilter == 'All' ||
        voucherType.contains(_voucherTypeFilter.toLowerCase());

    bool dateMatch = true;
    if (_dateRange != null && compareDate != null) {
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

    return searchMatch && statusMatch && voucherTypeMatch && dateMatch;
  }

  List<Map<String, dynamic>> get _filteredRows =>
      _rows.where(_matches).toList();

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

  Future<void> _openFilters() async {
    String tempStatus = _statusFilter;
    String tempVoucherType = _voucherTypeFilter;
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
                      value: tempVoucherType,
                      decoration: const InputDecoration(
                        labelText: 'Voucher Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'JV', child: Text('JV')),
                        DropdownMenuItem(value: 'CP', child: Text('CP')),
                      ],
                      onChanged: (value) =>
                          setModalState(() => tempVoucherType = value ?? 'All'),
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
                                tempVoucherType = 'All';
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
        _dateRange = tempRange;
      });
    }
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

  Widget _buildRow(Map<String, dynamic> row) {
    final amount = ((row['remaining_amount'] ?? 0) as num).toDouble();
    final status = _normalizeStatus(row['payment_status']);
    final accountName = (row['account_name'] ?? 'Unknown').toString();
    final voucherNo = (row['voucher_no'] ?? '').toString();
    final description = (row['description'] ?? '').toString();
    final voucherType = (row['voucher_type'] ?? '').toString();
    final dueDate = (row['due_date'] ?? '').toString();
    final journalId = row['journal_id'] as int?;

    final hasImage =
        row['image_url'] != null && (row['image_url'] as String).isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: hasImage
            ? GestureDetector(
                onTap: () => _showImageViewer(row['image_url'] as String),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    row['image_url'] as String,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image_not_supported, size: 24),
                      );
                    },
                  ),
                ),
              )
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(
                voucherNo,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(accountName, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              description.isEmpty ? 'No description' : description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Type: ${voucherType.isEmpty ? '-' : voucherType}'),
                _chip('Amount: ₹${amount.toStringAsFixed(2)}'),
                _chip('Due: ${dueDate.isEmpty ? '-' : dueDate}'),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalCreateScreen(
                      businessId: widget.businessId,
                      journalId: journalId,
                    ),
                  ),
                );
                _load();
              },
            ),
            PopupMenuItem(
              value: 'delete',
              child: const Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () async {
                if (journalId != null) {
                  await _journalService.deleteJournalEntry(journalId);
                  _load();
                }
              },
            ),
          ],
        ),
        onTap: journalId == null
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalDetailScreen(
                      journal: JournalEntryModel.fromMap(row),
                    ),
                  ),
                );
                _load();
              },
      ),
    );
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryBox(String label, String value, Color color) {
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;
    final totalsByJournal = <String, double>{};
    for (final row in rows) {
      final journalId = row['journal_id']?.toString();
      if (journalId == null || totalsByJournal.containsKey(journalId)) {
        continue;
      }
      totalsByJournal[journalId] = ((row['remaining_amount'] ?? 0) as num)
          .toDouble();
    }
    final total = totalsByJournal.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Vouchers'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  JournalCreateScreen(businessId: widget.businessId),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add),
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
                      hintText: 'Search voucher, account, description...',
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _summaryBox(
                          'Rows',
                          rows.length.toString(),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _summaryBox(
                          'Remaining',
                          '₹${total.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('No journal entries found'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: rows.length,
                            itemBuilder: (context, index) =>
                                _buildRow(rows[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
