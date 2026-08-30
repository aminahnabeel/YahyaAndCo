import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/business_model.dart';
import '../services/business_service.dart';
import '../services/localization_service.dart';
import 'auth_screen.dart';
import 'business_switch_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int businessId;
  final String initialBusinessName;
  final String initialBusinessType;

  const SettingsScreen({
    super.key,
    required this.businessId,
    required this.initialBusinessName,
    this.initialBusinessType = 'retail',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _businessName;
  late String _businessType;

  @override
  void initState() {
    super.initState();
    _businessName = widget.initialBusinessName;
    _businessType = widget.initialBusinessType;
    _loadBusinessDetails();
  }

  Future<void> _loadBusinessDetails() async {
    final business = await DatabaseHelper.instance.getBusinessById(
      widget.businessId,
    );

    if (!mounted || business == null) return;

    setState(() {
      _businessName = business.name;
      _businessType = business.type;
    });
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A2342).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade700,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to sign out?',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A2342),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _handleSignOut();
  }

  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }
  }

  Future<void> _handleChangePin() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangePinEditorScreen(
          businessId: widget.businessId,
        ),
      ),
    );
  }

  Future<void> _handleDeleteBusiness() async {
    final localization = LocalizationService.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                localization.t('delete_business'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2342),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                localization.t('delete_business_warning'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A2342),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(localization.t('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(localization.t('delete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BusinessService().deleteBusiness(widget.businessId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const BusinessSwitchScreen(currentBusinessId: -1),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localization.t('could_not_delete_business')}: $e')),
      );
    }
  }

  String _formatBusinessType(String value) {
    return formatBusinessType(value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, language, _) => Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(LocalizationService.instance.t('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context, {
            'name': _businessName,
            'type': _businessType,
          }),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _ProfileCard(
              name: _businessName,
              type: _businessType,
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: LocalizationService.instance.t('business'),
              items: [
                _SettingsItem(
                  icon: Icons.storefront_outlined,
                  title: LocalizationService.instance.t('business_details'),
                  subtitle: '$_businessName • ${_formatBusinessType(_businessType)}',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final result = await navigator.push(
                      MaterialPageRoute(
                        builder: (_) => BusinessDetailsEditorScreen(
                          businessId: widget.businessId,
                          initialBusinessName: _businessName,
                          initialBusinessType: _businessType,
                        ),
                      ),
                    );

                    if (!mounted || result == null) return;

                    final updated = result as Map<String, dynamic>;
                    final updatedName = updated['name']?.toString() ?? _businessName;
                    final updatedType = updated['type']?.toString() ?? _businessType;

                    if (!mounted) return;

                    setState(() {
                      _businessName = updatedName;
                      _businessType = updatedType;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: LocalizationService.instance.t('security'),
              items: [
                _SettingsItem(
                  icon: Icons.lock_outline,
                  title: LocalizationService.instance.t('change_pin'),
                  subtitle: LocalizationService.instance.t('update_security_pin'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleChangePin,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: LocalizationService.instance.t('notifications'),
              items: [
                _SettingsItem(
                  icon: Icons.notifications_active_outlined,
                  title: LocalizationService.instance.t('payment_reminders'),
                  subtitle: LocalizationService.instance.t('due_payment_alerts'),
                  trailing: Switch(
                    value: true,
                    activeThumbColor: const Color(0xFF0A2342),
                    onChanged: (_) {},
                  ),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: LocalizationService.instance.t('preferences'),
              items: [
                _SettingsItem(
                  icon: Icons.language_outlined,
                  title: LocalizationService.instance.t('language'),
                  subtitle: language == 'en'
                      ? LocalizationService.instance.t('english')
                      : LocalizationService.instance.t('roman'),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: language,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(LocalizationService.instance.t('english')),
                        ),
                        DropdownMenuItem(
                          value: 'roman',
                          child: Text(LocalizationService.instance.t('roman')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          LocalizationService.instance.setLanguage(value);
                        }
                      },
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.instance.t('danger_zone'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsItem(
                    icon: Icons.delete_outline,
                    title: LocalizationService.instance.t('delete_business'),
                    subtitle: LocalizationService.instance.t('permanently_remove_business'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.red),
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: _handleDeleteBusiness,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(LocalizationService.instance.t('sign_out')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      ),
    );
  }
}

String formatBusinessType(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'Retail';

  const labels = {
    'retail': 'Retail',
    'service': 'Service',
    'manufacturing': 'Manufacturing',
    'wholesale': 'Wholesale',
    'distribution': 'Distribution',
    'import_export': 'Import/Export',
    'other': 'Other',
  };

  return labels[normalized] ?? normalized;
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String type;

  const _ProfileCard({required this.name, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF164E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2342).withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatBusinessType(type),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePinEditorScreen extends StatefulWidget {
  final int businessId;

  const ChangePinEditorScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<ChangePinEditorScreen> createState() => _ChangePinEditorScreenState();
}

class _ChangePinEditorScreenState extends State<ChangePinEditorScreen> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _showCurrentPin = false;
  bool _showNewPin = false;
  bool _showConfirmPin = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final localization = LocalizationService.instance;
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.t('all_pin_fields_required'))),
      );
      return;
    }

    final business = await DatabaseHelper.instance.getBusinessById(widget.businessId);
    if (!mounted || business == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.t('business_not_found'))),
        );
      }
      return;
    }

    final savedPin = (business.pin ?? '').trim();

    if (savedPin.isNotEmpty && currentPin != savedPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.t('current_pin_incorrect'))),
      );
      return;
    }

    if (newPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4 digits')),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedBusiness = BusinessModel(
        businessId: business.businessId,
        firestoreId: business.firestoreId,
        name: business.name,
        type: business.type,
        pin: newPin,
        createdAt: business.createdAt,
      );

      await BusinessService().updateBusiness(updatedBusiness);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.t('pin_changed_successfully'))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localization.t('error')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, language, _) => Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(LocalizationService.instance.t('change_pin')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.instance.t('update_pin'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocalizationService.instance.t('change_pin_description'),
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      LocalizationService.instance.t('current_pin'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _currentPinController,
                      obscureText: !_showCurrentPin,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: LocalizationService.instance.t('current_pin'),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
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
                            color: Color(0xFF0A2342),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showCurrentPin = !_showCurrentPin),
                          icon: Icon(
                            _showCurrentPin ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      LocalizationService.instance.t('new_pin'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newPinController,
                      obscureText: !_showNewPin,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: LocalizationService.instance.t('new_pin'),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
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
                            color: Color(0xFF0A2342),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showNewPin = !_showNewPin),
                          icon: Icon(
                            _showNewPin ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      LocalizationService.instance.t('confirm_new_pin'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: !_showConfirmPin,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: LocalizationService.instance.t('confirm_new_pin'),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
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
                            color: Color(0xFF0A2342),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showConfirmPin = !_showConfirmPin),
                          icon: Icon(
                            _showConfirmPin ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2342),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                              LocalizationService.instance.t('save_changes'),
                                style: TextStyle(
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
          ),
        ),
      ),
      ),
    );
  }
}

class BusinessDetailsEditorScreen extends StatefulWidget {
  final int businessId;
  final String initialBusinessName;
  final String initialBusinessType;

  const BusinessDetailsEditorScreen({
    super.key,
    required this.businessId,
    required this.initialBusinessName,
    required this.initialBusinessType,
  });

  @override
  State<BusinessDetailsEditorScreen> createState() =>
      _BusinessDetailsEditorScreenState();
}

class _BusinessDetailsEditorScreenState extends State<BusinessDetailsEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  late String _selectedType;
  bool _isSaving = false;

  final List<Map<String, String>> _businessTypes = const [
    {'value': 'retail', 'label': 'Retail'},
    {'value': 'service', 'label': 'Service'},
    {'value': 'manufacturing', 'label': 'Manufacturing'},
    {'value': 'wholesale', 'label': 'Wholesale'},
    {'value': 'distribution', 'label': 'Distribution'},
    {'value': 'import_export', 'label': 'Import/Export'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialBusinessName;
    _selectedType = widget.initialBusinessType.isNotEmpty
        ? widget.initialBusinessType
        : 'retail';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveBusinessDetails() async {
    final localization = LocalizationService.instance;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.t('business_name_required'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final business = await DatabaseHelper.instance.getBusinessById(
        widget.businessId,
      );

      if (business == null) {
        throw Exception(localization.t('business_not_found'));
      }

      final updatedBusiness = BusinessModel(
        businessId: business.businessId,
        firestoreId: business.firestoreId,
        name: name,
        type: _selectedType,
        pin: business.pin,
        createdAt: business.createdAt,
      );

      await BusinessService().updateBusiness(updatedBusiness);

      if (!mounted) return;
      Navigator.pop(context, {'name': name, 'type': _selectedType});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localization.t('could_not_update_business')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, language, _) => Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(LocalizationService.instance.t('business_details')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.instance.t('update_business_info'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocalizationService.instance.t('edit_business_info_descriptive'),
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      LocalizationService.instance.t('business_name'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: LocalizationService.instance.t('business_name'),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
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
                            color: Color(0xFF0A2342),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      LocalizationService.instance.t('business_type'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownMenu<String>(
                      initialSelection: _businessTypes.any(
                        (type) => type['value'] == _selectedType,
                      )
                          ? _selectedType
                          : 'retail',
                      width: double.infinity,
                      menuStyle: MenuStyle(
                        backgroundColor: const WidgetStatePropertyAll(Colors.white),
                        surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
                        maximumSize: const WidgetStatePropertyAll(Size.fromHeight(260)),
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF0A2342),
                      ),
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(
                          14,
                          16,
                          8,
                          16,
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
                            color: Color(0xFF0A2342),
                            width: 2,
                          ),
                        ),
                      ),
                      dropdownMenuEntries: _businessTypes.map((type) {
                        return DropdownMenuEntry<String>(
                          value: type['value'] ?? 'retail',
                                label: LocalizationService.instance.t(type['value'] ?? 'other'),
                        );
                      }).toList(),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() => _selectedType = value);
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveBusinessDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2342),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                              LocalizationService.instance.t('save_changes'),
                                style: TextStyle(
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
          ),
        ),
      ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SectionCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A2342),
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.iconColor = const Color(0xFF0A2342),
    this.textColor = const Color(0xFF0A2342),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
