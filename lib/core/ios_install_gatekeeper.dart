import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';
import 'pwa_helper.dart';

class IosInstallGatekeeper extends StatelessWidget {
  final Widget child;
  const IosInstallGatekeeper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && isIosWeb() && !isStandaloneWeb()) {
      return Scaffold(
        backgroundColor: AppConstants.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 32),
                  const Text(
                    'Install SRU Timetable',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppConstants.shadowLevel1,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'To use this app, you must add it to your Home Screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppConstants.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Tap the Share icon at the bottom of Safari',
                                style: TextStyle(fontSize: 15, color: AppConstants.textSecondary),
                              ),
                            ),
                            const Icon(Icons.ios_share, color: AppConstants.primary),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppConstants.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Select "Add to Home Screen"',
                                style: TextStyle(fontSize: 15, color: AppConstants.textSecondary),
                              ),
                            ),
                            const Icon(Icons.add_box_outlined, color: AppConstants.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_downward, color: AppConstants.primary, size: 40),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return child;
  }
}
