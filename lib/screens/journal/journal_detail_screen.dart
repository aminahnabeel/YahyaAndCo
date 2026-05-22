import 'package:flutter/material.dart';
import '../../models/journal_entry_model.dart';
import '../../services/journal_service.dart';
import '../../theme.dart';

class JournalDetailScreen extends StatefulWidget {
  final JournalEntryModel journal;
  const JournalDetailScreen({super.key, required this.journal});

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  final JournalService _journalService = JournalService();
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _lines = await _journalService.getJournalLines(widget.journal.journalId!);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    double totalDebit = 0;
    double totalCredit = 0;

    for (final line in _lines) {
      totalDebit += ((line['debit'] ?? 0) as num).toDouble();
      totalCredit += ((line['credit'] ?? 0) as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Voucher ${widget.journal.voucherNo}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.journal.voucherNo,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              _metaRow('Date', widget.journal.date.split('T').first),
                              const SizedBox(height: 8),
                              _metaRow('Description', widget.journal.description),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Journal Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Expanded(flex: 3, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w700))),
                            Expanded(child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                            SizedBox(width: 16),
                            Expanded(child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        ),
                        const Divider(height: 20),
                        ..._lines.map((line) {
                          final debit = ((line['debit'] ?? 0) as num).toDouble();
                          final credit = ((line['credit'] ?? 0) as num).toDouble();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    (line['account_name'] ?? 'Account ${line['account_id']}').toString(),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    debit == 0 ? '—' : debit.toStringAsFixed(0),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    credit == 0 ? '—' : credit.toStringAsFixed(0),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Debit'),
                                Text(
                                  totalDebit.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Credit'),
                                Text(
                                  totalCredit.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}
