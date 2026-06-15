import 'package:flutter/material.dart';
import '../../services/accounting_service.dart';
import '../../theme.dart';

class TestDataGeneratorScreen extends StatefulWidget {
  final int businessId;

  const TestDataGeneratorScreen({super.key, required this.businessId});

  @override
  State<TestDataGeneratorScreen> createState() =>
      _TestDataGeneratorScreenState();
}

class _TestDataGeneratorScreenState extends State<TestDataGeneratorScreen> {
  final AccountingService _accountingService = AccountingService();
  bool _isGenerating = false;

  Future<void> _generateMultiMonthData() async {
    setState(() => _isGenerating = true);

    try {
      await _accountingService.addMultiMonthTestData(widget.businessId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✅ Multi-month test data generated successfully! (Jan-Jun 2026)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(
              context,
              true,
            ); // Return true to signal data was added
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Data Generator'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Multi-Month Report Data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This will generate realistic accounting data for all months in 2026:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• January 2026 → June 2026',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  Text(
                    '• Varying monthly transactions',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  Text(
                    '• Real DateTime-based dates',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  Text(
                    '• June 2026 = Latest data',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Perfect for testing filter & PDF download functionality!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateMultiMonthData,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.data_usage),
              label: Text(
                _isGenerating
                    ? 'Generating Data...'
                    : 'Generate Multi-Month Data',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After generation, navigate to Reports and:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Tap Filter icon to select different months',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              '2. Tap Download icon to generate PDF for selected month',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              '3. PDF will be saved to your device\'s Documents folder',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
