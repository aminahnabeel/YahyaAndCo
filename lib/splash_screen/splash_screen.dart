import 'package:flutter/material.dart';

import '../screens/startup_gate.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: colorScheme.onSurface,
      fontSize: 30,
      height: 1.15,
      letterSpacing: -0.4,
    );

    final subtitleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.65),
      fontSize: 15,
      height: 1.7,
      letterSpacing: 0.1,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            // Top image with rounded bottom corners to match design
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    'assets/1.jpeg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),

            // Bottom white card area
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).shadowColor.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      const SizedBox(height: 5),
                      Text(
                        'Say goodbye to messy records.',
                        style: titleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'With our smart ledger app, easily track your daily expenses, monitor your income, and stay financially organized without any hassle.',
                        style: subtitleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 72,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const StartupGate(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Continue'),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
