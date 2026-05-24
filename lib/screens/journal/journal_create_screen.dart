import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../models/journal_entry_model.dart';
import '../../models/journal_line_model.dart';
import '../../services/account_service.dart';
import '../../services/accounting_service.dart';

class _JournalFormRow {
  AccountModel? account;
  final TextEditingController debitController = TextEditingController(text: '0.00');
  final TextEditingController creditController = TextEditingController(text: '0.00');
  final GlobalKey rowKey = GlobalKey(); // Har individual row ke liye unique key

  void dispose() {
    debitController.dispose();
    creditController.dispose();
  }
}

class JournalCreateScreen extends StatefulWidget {
  final int businessId;

  const JournalCreateScreen({super.key, required this.businessId});

  @override
  State<JournalCreateScreen> createState() => _JournalCreateScreenState();
}

class _JournalCreateScreenState extends State<JournalCreateScreen> {
  final AccountingService _accountingService = AccountingService();
  final AccountService _accountService = AccountService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _descriptionFieldKey = GlobalKey();
  final GlobalKey _dueDateFieldKey = GlobalKey();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  bool _isScrolling = false;

  final List<_JournalFormRow> _rows = [];
  List<AccountModel> _accounts = [];

  bool _saving = false;
  bool _loading = true;
  String _voucherType = 'JV';
  String _voucherNo = '';
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _descriptionController.dispose();
    _dueDateController.dispose();
    _dateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToField(GlobalKey key) async {
    if (!_scrollController.hasClients) return;
    if (_isScrolling) return;
    _isScrolling = true;
    
    // Keyboard open hone ka thoda wait karein taake safe calculation ho sake
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      _isScrolling = false;
      return;
    }
    final fieldContext = key.currentContext;
    if (fieldContext != null) {
      try {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.15, // Field ko viewport me clear aur upar rakhta hai
        );
      } catch (_) {
        // ignore exceptions
      }
    }
    _isScrolling = false;
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);

    await _accountService.ensureDefaultAccounts(widget.businessId);
    _accounts = await _accountService.getAccountsByBusiness(widget.businessId);

    if (_rows.isEmpty) {
      _rows.add(_createRow());
      _rows.add(_createRow());
    }

    _voucherNo = await _generateVoucherNo();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  _JournalFormRow _createRow() => _JournalFormRow();

  Future<String> _generateVoucherNo() {
    if (_voucherType == 'CP') {
      return _accountingService.generateCashVoucher();
    }
    return _accountingService.generateJournalVoucher();
  }

  Future<void> _switchVoucherType(String type) async {
    if (_voucherType == type) return;

    setState(() {
      _voucherType = type;
      _loading = true;
    });

    _voucherNo = await _generateVoucherNo();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _dateController.text = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _pickDueDate() async {
    final current = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _dueDate = picked;
      _dueDateController.text = picked.toIso8601String().split('T').first;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(_createRow());
    });
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;

    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  void _clearAmountIfDefault(TextEditingController controller) {
    if (controller.text == '0.00' || controller.text == '0') {
      controller.clear();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    double totalDebit = 0;
    double totalCredit = 0;
    final journalLines = <JournalLineModel>[];

    for (final row in _rows) {
      final account = row.account;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Har row mein account select karein')),
        );
        return;
      }

      final debit = double.tryParse(row.debitController.text) ?? 0;
      final credit = double.tryParse(row.creditController.text) ?? 0;

      if (debit <= 0 && credit <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit ya Credit mein se ek amount zaroor enter karein')),
        );
        return;
      }

      if (debit > 0 && credit > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Har row mein sirf Debit ya sirf Credit enter karein')),
        );
        return;
      }

      totalDebit += debit;
      totalCredit += credit;

      journalLines.add(
        JournalLineModel(
          journalId: 0,
          accountId: account.accountId!,
          debit: debit,
          credit: credit,
        ),
      );
    }

    if (totalDebit != totalCredit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debit aur Credit barabar hone chahiye')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final journalEntry = JournalEntryModel(
        businessId: widget.businessId,
        transactionId: null,
        voucherNo: _voucherNo,
        voucherType: _voucherType,
        description: _descriptionController.text.trim(),
        dueDate: _dueDate?.toIso8601String().split('T').first,
        remainingAmount: _dueDate == null ? 0 : totalDebit,
        paymentStatus: _accountingService.calculatePaymentStatus(
          amount: totalDebit,
          remainingAmount: _dueDate == null ? 0 : totalDebit,
          dueDate: _dueDate?.toIso8601String(),
        ),
        imageUrl: null,
        date: _dateController.text,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _accountingService.createCompleteJournal(
        journalEntry: journalEntry,
        journalLines: journalLines,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal saved successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Default safe resizing active rakhein
      appBar: AppBar(title: const Text('Add Journal Entry')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Voucher ki qism', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _switchVoucherType('JV'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _voucherType == 'JV' ? Colors.blue.shade50 : Colors.white,
                                side: BorderSide(color: _voucherType == 'JV' ? Colors.blue : Colors.black54),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Journal Voucher'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _switchVoucherType('CP'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _voucherType == 'CP' ? Colors.blue.shade50 : Colors.white,
                                side: BorderSide(color: _voucherType == 'CP' ? Colors.blue : Colors.black54),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cash Payment'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Text(_voucherNo, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dateController,
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickDueDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            key: _dueDateFieldKey,
                            controller: _dueDateController,
                            decoration: const InputDecoration(
                              labelText: 'Due Date (Optional)',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.event),
                              hintText: 'Select due date',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) _scrollToField(_descriptionFieldKey);
                        },
                        child: TextFormField(
                          key: _descriptionFieldKey,
                          controller: _descriptionController,
                          maxLines: 3,
                          textAlignVertical: TextAlignVertical.top,
                          textInputAction: TextInputAction.newline,
                          scrollPadding: const EdgeInsets.only(bottom: 200),
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Enter description',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Description required' : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Journal Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 5, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w700))),
                            Expanded(child: Text('Debit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Credit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_rows.length, (index) {
                        final row = _rows[index];
                        return Card(
                          key: row.rowKey, // Har card card ka unique key assigned kiya
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<AccountModel>(
                                  value: row.account != null && _accounts.any((a) => a.accountId == row.account!.accountId)
                                      ? row.account
                                      : null,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  ),
                                  items: _accounts
                                      .map(
                                        (account) => DropdownMenuItem<AccountModel>(
                                          value: account,
                                          child: Text(account.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      row.account = value;
                                    });
                                  },
                                  validator: (value) => value == null ? 'Select account' : null,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Focus(
                                        onFocusChange: (hasFocus) {
                                          if (hasFocus) {
                                            _scrollToField(row.rowKey); // Sahi card par focus scroll hoga
                                          }
                                        },
                                        child: TextFormField(
                                          controller: row.debitController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          textAlignVertical: TextAlignVertical.center,
                                          onTap: () => _clearAmountIfDefault(row.debitController),
                                          scrollPadding: const EdgeInsets.only(bottom: 240),
                                          decoration: const InputDecoration(
                                            labelText: 'Debit',
                                            border: OutlineInputBorder(),
                                            hintText: '0.00',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Focus(
                                        onFocusChange: (hasFocus) {
                                          if (hasFocus) {
                                            _scrollToField(row.rowKey); // Sahi card par focus scroll hoga
                                          }
                                        },
                                        child: TextFormField(
                                          controller: row.creditController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          textAlignVertical: TextAlignVertical.center,
                                          onTap: () => _clearAmountIfDefault(row.creditController),
                                          scrollPadding: const EdgeInsets.only(bottom: 240),
                                          decoration: const InputDecoration(
                                            labelText: 'Credit',
                                            border: OutlineInputBorder(),
                                            hintText: '0.00',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _removeRow(index),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Line add karein'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving ? const CircularProgressIndicator() : const Text('Save Journal Entry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}