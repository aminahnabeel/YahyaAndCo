import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../models/journal_entry_model.dart';
import '../../models/journal_line_model.dart';
import '../../models/transaction_model.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/account_service.dart';
import '../../services/accounting_service.dart';
import '../../services/localization_service.dart';
import '../../services/transaction_service.dart';
import '../../services/image_upload_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final int businessId;

  const AddTransactionScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TransactionService _transactionService = TransactionService();
  final AccountingService _accountingService = AccountingService();
  final AccountService _accountService = AccountService();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _amountFieldKey = GlobalKey();
  final GlobalKey _noteFieldKey = GlobalKey();
  bool _isScrolling = false;

  List<AccountModel> accounts = [];
  AccountModel? selectedAccount;
  int? cashAccountId;
  String transactionType = 'Payment';
  String paymentMethod = 'Cash';
  bool isLoading = false;
  String side = 'Debit'; // 'Debit' or 'Credit'

  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  String? _imageUrl;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToField(GlobalKey key) async {
    if (!_scrollController.hasClients) return;
    if (_isScrolling) return;
    _isScrolling = true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      _isScrolling = false;
      return;
    }
    final fieldContext = key.currentContext;
    if (fieldContext != null) {
      try {
        final RenderBox renderBox = fieldContext.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final offset = _scrollController.offset + position.dy - 100;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = offset.clamp(0.0, maxScroll);
        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    }
    _isScrolling = false;
  }

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    setState(() {
      _dueDate = date;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() {
          _isUploadingImage = true;
        });

        final uploadedUrl = await ImageUploadService().uploadImage(file.path);
        
        if (uploadedUrl != null) {
          setState(() {
            _imageUrl = uploadedUrl;
            _isUploadingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _isUploadingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageViewer() {
    if (_imageUrl == null) return;
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
                  _imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
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

  Future loadAccounts() async {
    await _accountService.ensureDefaultAccounts(widget.businessId);
    cashAccountId = await _accountingService.getCashAccountId(widget.businessId);

    final allAccounts = await _accountService.getAccountsByBusiness(
      widget.businessId,
    );

    accounts = allAccounts.where((account) => account.accountId != cashAccountId).toList();

    if (accounts.isNotEmpty) {
      selectedAccount = accounts.first;
    } else {
      selectedAccount = null;
    }

    setState(() {});
  }

  Future saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select account')),
      );
      return;
    }

    if (cashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.instance.t('cash_account_required')),
        ),
      );
      return;
    }

    if (selectedAccount!.accountId == cashAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select Cash account. Use journal entry for cash transfers.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String voucherNo = await _accountingService.generateCashVoucher();
      double amount = double.parse(amountController.text);

      TransactionModel transaction = TransactionModel(
        businessId: widget.businessId,
        accountId: selectedAccount!.accountId!,
        amount: amount,
        type: side,
        note: noteController.text,
        paymentMethod: paymentMethod,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        remainingAmount: _dueDate == null ? 0 : amount,
        paymentStatus: _accountingService.calculatePaymentStatus(
          amount: amount,
          remainingAmount: _dueDate == null ? 0 : amount,
          dueDate: _dueDate?.toIso8601String(),
        ),
        imageUrl: _imageUrl,
        date: _selectedDate.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );

      int transactionId = await _transactionService.createTransaction(transaction);

      JournalEntryModel journalEntry = JournalEntryModel(
        businessId: widget.businessId,
        transactionId: transactionId,
        voucherNo: voucherNo,
        voucherType: 'CP',
        description: noteController.text,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        remainingAmount: _dueDate == null ? 0 : amount,
        paymentStatus: _accountingService.calculatePaymentStatus(
          amount: amount,
          remainingAmount: _dueDate == null ? 0 : amount,
          dueDate: _dueDate?.toIso8601String(),
        ),
        imageUrl: _imageUrl,
        date: _selectedDate.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );

      List<JournalLineModel> journalLines = [];

      if (side == 'Debit') {
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: selectedAccount!.accountId!,
            debit: amount,
            credit: 0,
          ),
        );
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: cashAccountId!,
            debit: 0,
            credit: amount,
          ),
        );
      } else {
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: cashAccountId!,
            debit: amount,
            credit: 0,
          ),
        );
        journalLines.add(
          JournalLineModel(
            journalId: 0,
            accountId: selectedAccount!.accountId!,
            debit: 0,
            credit: amount,
          ),
        );
      }

      await _accountingService.createCompleteJournal(
        journalEntry: journalEntry,
        journalLines: journalLines,
      );

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Let Scaffold automatically handle view insets
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: SafeArea(
        // Removed AnimatedPadding with MediaQuery viewInsets bottom
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              // =====================
              // ACCOUNT
              // =====================
              DropdownButtonFormField<AccountModel>(
                value: (selectedAccount != null &&
                        accounts.any((account) => account.accountId == selectedAccount!.accountId))
                    ? selectedAccount
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Select Account',
                  border: OutlineInputBorder(),
                ),
                items: accounts.map((account) {
                  return DropdownMenuItem(
                    value: account,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAccount = value;
                  });
                },
              ),
              const SizedBox(height: 15),

              // =====================
              // AMOUNT
              // =====================
              Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) _scrollToField(_amountFieldKey);
                },
                child: TextFormField(
                  key: _amountFieldKey,
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 240), // Increased to give comfortable separation from keyboard
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter amount';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 15),

              // =====================
              // TRANSACTION TYPE
              // =====================
              Text(
                'Transaction Type',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => side = 'Debit'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Debit',
                            groupValue: side,
                            onChanged: (value) => setState(() => side = value!),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Debit (Money Out)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                                ),
                                Text(
                                  'Expense, Cost, Asset Purchase',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                    InkWell(
                      onTap: () => setState(() => side = 'Credit'),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Credit',
                            groupValue: side,
                            onChanged: (value) => setState(() => side = value!),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Credit (Money In)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                ),
                                Text(
                                  'Income, Revenue, Liability',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // =====================
              // HELP TEXT
              // =====================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cash account is automatically added as counter-entry',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // =====================
              // DATE & TIME PICKER
              // =====================
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${_selectedDate.toString().split('.').first}'),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Due date
              InkWell(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Due Date: ${_dueDate == null ? 'Optional' : _dueDate.toString().split(' ').first}'),
                      const Icon(Icons.event_available),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Image picker
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingImage ? null : _pickImage,
                    icon: const Icon(Icons.attach_file),
                    label: _isUploadingImage ? const Text('Uploading...') : const Text('Attach Image'),
                  ),
                  const SizedBox(width: 12),
                  if (_isUploadingImage)
                    const Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Uploading image...'),
                        ],
                      ),
                    )
                  else if (_imageUrl != null)
                    Expanded(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showImageViewer,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                _imageUrl!,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 60,
                                    color: Colors.grey.shade300,
                                    child: const Center(child: Text('Failed to load')),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _imageUrl = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(0),
                                    topRight: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) _scrollToField(_noteFieldKey);
                },
                child: TextFormField(
                  key: _noteFieldKey,
                  controller: noteController,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  textInputAction: TextInputAction.newline,
                  scrollPadding: const EdgeInsets.only(bottom: 240), // Increased scroll margin
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // =====================
              // PAYMENT METHOD
              // =====================
              DropdownButtonFormField(
                value: paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Cash',
                  'Bank',
                  'Online',
                ].map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    paymentMethod = value!;
                  });
                },
              ),
              const SizedBox(height: 15),

              // =====================
              // SAVE BUTTON
              // =====================
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveTransaction,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}