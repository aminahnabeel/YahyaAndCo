import 'package:flutter/material.dart';

import '../../services/accounting_service.dart';

class CashBookScreen extends StatefulWidget {
  final int businessId;

  const CashBookScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  final AccountingService _accountingService = AccountingService();

  List<Map<String, dynamic>> cashBook = [];

  bool isLoading = true;

  double runningBalance = 0;

  @override
 void initState() {

    super.initState();

    loadCashBook();
  }

  Future loadCashBook() async {
    cashBook = await _accountingService.getCashBook(widget.businessId);

    if (cashBook.isEmpty) {
      cashBook = [];
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    runningBalance = 0;

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Cash Book',
        ),
      ),

      body: isLoading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : cashBook.isEmpty

              ? const Center(
                  child: Text(
                    'No Cash Book Found',
                  ),
                )

              : ListView.builder(

                  itemCount:
                      cashBook.length,

                  itemBuilder:
                      (context, index) {

                    final item =
                        cashBook[index];

                    double debit = item['debit'] == null ? 0 : (item['debit'] as num).toDouble();

                    double credit = item['credit'] == null ? 0 : (item['credit'] as num).toDouble();

                    final status = (item['payment_status'] ?? 'Paid').toString();

                    if (status != 'Paid') {
                      return const SizedBox.shrink();
                    }

                    runningBalance +=
                        debit -
                            credit;

                    return Card(

                      margin:
                          const EdgeInsets
                              .all(10),

                      child: ListTile(

                        title: Text(item['voucher_no'].toString()),

                        subtitle: Text('${item['account_name'] ?? 'Cash'} • ${item['date']}'),

                        trailing:
                            Column(

                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,

                          children: [

                            Text('Receipt: $debit'),
                            Text('Payment: $credit'),
                            Text('Balance: $runningBalance'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}