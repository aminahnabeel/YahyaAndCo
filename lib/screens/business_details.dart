import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';
import '../services/business_service.dart';
import '../models/business_model.dart';
import '../theme.dart';

class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final _businessNameController = TextEditingController();
  final _businessService = BusinessService();
  String? _selectedBusinessType;
  bool _isLoading = false;

  final List<String> businessTypeKeys = [
    'retail',
    'service',
    'manufacturing',
    'wholesale',
    'distribution',
    'import_export',
    'other',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _createBusiness() async {
    final localization = LocalizationService.instance;

    if (_businessNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.t('please_enter_business_name')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.t('please_select_business_type')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final business = BusinessModel(
        name: _businessNameController.text.trim(),
        type: _selectedBusinessType!,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _businessService.createBusiness(business);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.t('business_created_success')),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to next screen after 1 second
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/business-details');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, lang, _) {
        final localization = LocalizationService.instance;
        final mediaQuery = MediaQuery.of(context);

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: Text(localization.t('business_details')),
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    localization.t('business_details'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localization.t('enter_business_info'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  // Business Name Input
                  Text(
                    localization.t('business_name'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _businessNameController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: localization.t('business_name'),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Business Type Dropdown
                  Text(
                    localization.t('business_type'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade50,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBusinessType,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            localization.t('select_type'),
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ),
                        items: businessTypeKeys.map((typeKey) {
                          return DropdownMenuItem<String>(
                            value: typeKey,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                localization.t(typeKey),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedBusinessType = value;
                                });
                              },
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.expand_more,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createBusiness,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              localization.t('next'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
