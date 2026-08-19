import 'package:flutter/material.dart';

import '../../models/account_model.dart';
import '../../services/account_service.dart';

class AddAccountScreen
    extends StatefulWidget {

  final int businessId;

  const AddAccountScreen({

    super.key,

    required this.businessId,
  });

  @override
  State<AddAccountScreen>
      createState() =>
          _AddAccountScreenState();
}

class _AddAccountScreenState
    extends State<AddAccountScreen> {

  final _formKey =
      GlobalKey<FormState>();

  final AccountService
      _accountService =
      AccountService();

  final TextEditingController
      nameController =
      TextEditingController();

  final TextEditingController
      phoneController =
      TextEditingController();

  final TextEditingController
      addressController =
      TextEditingController();

  final TextEditingController
      openingBalanceController =
      TextEditingController();

  String selectedType = 'Asset';

  bool isLoading = false;

  final List<String> accountTypes = [

    'Asset',

    'Liability',

    'Equity',

    'Revenue',

    'Expense',

    'Customer',

    'Supplier',

    'Cash',

    'Bank',
  ];

  // =========================
  // SAVE ACCOUNT
  // =========================

  double _parseAmount(String raw) {
    final normalized = raw
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(normalized) ?? 0;
  }

  Future saveAccount() async {

    if (!_formKey.currentState!
        .validate()) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            'Please fill all required fields',
          ),
        ),
      );

      return;
    }

    setState(() {

      isLoading = true;
    });

    try {

      AccountModel account =
          AccountModel(

        businessId:
            widget.businessId,

        name:
            nameController.text.trim(),

        type: selectedType,

        phone:
            phoneController.text.trim(),

        address:
            addressController.text.trim(),

        openingBalance:
          _parseAmount(
            openingBalanceController
              .text,
          ),

        createdAt:
            DateTime.now()
                .toString(),
      );

      await _accountService
          .createAccount(
        account,
      );

      setState(() {

        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            'Account Saved Successfully',
          ),
        ),
      );

      Navigator.pop(context);

    } catch (e) {

      setState(() {

        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        SnackBar(

          content: Text(
            'Error: ${e.toString()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          'Add Account',
        ),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(16),

        child: Form(

          key: _formKey,

          child: ListView(

            children: [

              // =====================
              // ACCOUNT NAME
              // =====================

              TextFormField(

                controller:
                    nameController,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Account Name',

                  border:
                      OutlineInputBorder(),
                ),

                validator: (value) {

                  if (value == null ||
                      value.isEmpty) {

                    return 'Enter account name';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // ACCOUNT TYPE
              // =====================

              DropdownButtonFormField(

                value: selectedType,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Account Type',

                  border:
                      OutlineInputBorder(),
                ),

                items: accountTypes
                    .map(
                  (type) {

                    return DropdownMenuItem(

                      value: type,

                      child: Text(
                        type,
                      ),
                    );
                  },
                ).toList(),

                onChanged: (value) {

                  setState(() {

                    selectedType =
                        value!;
                  });
                },
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // PHONE
              // =====================

              TextFormField(

                controller:
                    phoneController,

                keyboardType:
                    TextInputType.phone,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Phone',

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // ADDRESS
              // =====================

              TextFormField(

                controller:
                    addressController,

                keyboardType:
                    TextInputType.text,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Address',

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =====================
              // OPENING BALANCE
              // =====================

              TextFormField(

                controller:
                    openingBalanceController,

                keyboardType:
                    TextInputType.number,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Opening Balance',

                  hintText:
                    '0.00',

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // =====================
              // SAVE BUTTON
              // =====================

              SizedBox(

                height: 55,

                child: ElevatedButton(

                  onPressed:
                      isLoading
                          ? null
                          : saveAccount,

                  child: isLoading

                      ? const
                          CircularProgressIndicator()

                      : const Text(
                          'Save Account',
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