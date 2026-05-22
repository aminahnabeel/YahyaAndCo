import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../services/account_service.dart';
import '../../theme.dart';
import 'ledger_report_screen.dart';

class LedgerScreen
    extends StatefulWidget {

  final int businessId;

  const LedgerScreen({super.key, required this.businessId});

  @override
  State<LedgerScreen>
      createState() =>
          _LedgerScreenState();
}

class _LedgerScreenState
    extends State<LedgerScreen> {

  final AccountService _accountService = AccountService();

  List<AccountModel> accounts = [];

  bool isLoading = true;

  @override
  void initState() {

    super.initState();

    loadLedger();
  }

  Future loadLedger() async {
    accounts = await _accountService.getAccountsByBusiness(widget.businessId);

    setState(() {

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Ledger',
        ),
      ),

      body: isLoading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : accounts.isEmpty

              ? const Center(
                  child: Text(
                    'No Accounts Found',
                  ),
                )

              : ListView.builder(

                  itemCount: accounts.length,

                  itemBuilder:
                      (context, index) {

                    final account = accounts[index];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(account.name.isNotEmpty ? account.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(account.name),
                        subtitle: Text('${account.type} • ID ${account.accountId}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LedgerReportScreen(
                                businessId: account.businessId,
                                accountId: account.accountId!,
                                accountName: account.name,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}