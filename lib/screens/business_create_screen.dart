import 'package:flutter/material.dart';

import '../models/business_model.dart';
import '../services/business_service.dart';
import 'dashboard/dashboard_screen.dart';

class BusinessCreateScreen extends StatefulWidget {
  const BusinessCreateScreen({super.key});

  @override
  State<BusinessCreateScreen> createState() => _BusinessCreateScreenState();
}

class _BusinessCreateScreenState extends State<BusinessCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _type = 'Retail';
  final TextEditingController _pinController = TextEditingController();
  final BusinessService _service = BusinessService();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final business = BusinessModel(
      name: _nameController.text.trim(),
      type: _type,
      pin: _pinController.text.isEmpty ? null : _pinController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final id = await _service.createBusiness(business);

    // Navigate to the new business dashboard and replace stack
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DashboardScreen(businessId: id, businessName: business.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Business')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'Retail', child: Text('Retail')),
                  DropdownMenuItem(value: 'Services', child: Text('Services')),
                  DropdownMenuItem(value: 'Wholesale', child: Text('Wholesale')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'Retail'),
                decoration: const InputDecoration(labelText: 'Business type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'Optional PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create and Open'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
