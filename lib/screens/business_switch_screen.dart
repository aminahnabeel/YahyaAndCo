import 'package:flutter/material.dart';

import '../models/business_model.dart';
import '../services/business_service.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import 'business_details.dart';
import 'dashboard/dashboard_screen.dart';
import 'enter_pin_screen.dart';

class BusinessSwitchScreen extends StatefulWidget {
  final int currentBusinessId;

  const BusinessSwitchScreen({super.key, required this.currentBusinessId});

  @override
  State<BusinessSwitchScreen> createState() => _BusinessSwitchScreenState();
}

class _BusinessSwitchScreenState extends State<BusinessSwitchScreen> {
  final BusinessService _businessService = BusinessService();
  late Future<List<BusinessModel>> _businessesFuture;

  @override
  void initState() {
    super.initState();
    _businessesFuture = _businessService.getBusinesses();
  }

  Future<void> _openBusiness(BusinessModel business) async {
    final businessId = business.businessId;
    if (businessId == null) return;

    if (business.pin != null && business.pin!.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EnterPinScreen(businessId: businessId),
        ),
        (route) => false,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          businessId: businessId,
          businessName: business.name,
        ),
      ),
      (route) => false,
    );
  }

  void _addNewBusiness() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
    );
  }

  Future<void> _deleteBusiness(BusinessModel business) async {
    final businessId = business.businessId;
    if (businessId == null) return;

    final localization = LocalizationService.instance;

    // 1. Pehle check karein agar context valid hai tabhi dialog open ho
    if (!mounted) return;

    final pinController = TextEditingController();

    // Dialog directly show karein aur fresh validation dialog ke andar handle karein ya directly check karein
    final verifiedPin = await showDialog<String?>(
      context: context,
      barrierDismissible: false, // User majboor ho cancel ya delete dabane par
      builder: (dialogContext) {
        bool showPin = false;
        String? errorText;
        final expectedPin = business.pin ?? '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(localization.t('delete_business')),
              content: SingleChildScrollView(
                // Keyboard open hone par overflow nahi hoga
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${localization.t('enter_pin_for_delete')} "${business.name}" ${localization.t('to_delete_business')}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      obscureText: !showPin,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: localization.t('business_pin'),
                        errorText: errorText == null
                          ? null
                          : localization.t('incorrect_pin'),
                        suffixIcon: IconButton(
                          icon: Icon(showPin ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setDialogState(() => showPin = !showPin);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, null); // Clear closing
                  },
                  child: Text(localization.t('cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    final enteredPin = pinController.text.trim();

                    if (expectedPin.isNotEmpty && enteredPin != expectedPin) {
                      setDialogState(() {
                        errorText = localization.t('incorrect_pin');
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, enteredPin);
                  },
                  child: Text(localization.t('delete')),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();

    // Agar user ne cancel kiya to yahin se return ho jaye
    if (verifiedPin == null) return;

    try {
      // 2. Business delete operation perform karein
      await _businessService.deleteBusiness(businessId);

      // 3. CRITICAL: Check karein ke widget abhi bhi tree mein mounted hai ya nahi
      if (!mounted) return;

      // Screen ko yahin par refresh karein bina kahin navigate kiye
      setState(() {
        _businessesFuture = _businessService.getBusinesses();
      });

      // Success message show karwein
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      debugPrint('Business delete error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Switch Business'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<BusinessModel>>(
        future: _businessesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final businesses = snapshot.data ?? <BusinessModel>[];

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Your Businesses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (businesses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('No business found. Add your first business below.'),
                  )
                else
                  ...businesses.map((business) {
                    final isCurrent = business.businessId == widget.currentBusinessId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? AppColors.primary : Colors.grey.shade200,
                          child: Icon(
                            Icons.storefront,
                            color: isCurrent ? Colors.white : AppColors.primary,
                          ),
                        ),
                        title: Text(business.name),
                        subtitle: Text('${business.type}${isCurrent ? ' • Current' : ''}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'open') {
                              _openBusiness(business);
                            } else if (value == 'delete') {
                              _deleteBusiness(business);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 18),
                                  SizedBox(width: 8),
                                  Text('Open'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openBusiness(business),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addNewBusiness,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add New Business'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}