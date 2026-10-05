import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';
import 'web_platform_utils.dart';

class PwaPlatformGate extends StatelessWidget {
  final Widget child;

  const PwaPlatformGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final isMobileApple = WebPlatformUtils.isAppleMobileWeb;
    final isStandalone = WebPlatformUtils.isStandalonePwa;
    final isDesktop = WebPlatformUtils.isDesktopWeb;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppConstants.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', height: 80),
                const SizedBox(height: 32),
                const Text(
                  'Unsupported Device',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The SRU Timetable Web App is only available for iOS devices as an installed Home Screen application. Please visit this link on your iPhone or iPad, or download the official Android app from the Google Play Store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isMobileApple && !isStandalone) {
      return Scaffold(
        backgroundColor: AppConstants.background,
        body: Center(
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
                const Text(
                  'To use the app, you must install it to your Home Screen for the best experience and performance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppConstants.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppConstants.shadowLevel1,
                  ),
                  child: Column(
                    children: [
                      _buildInstallStep(Icons.ios_share, '1. Tap the Share button below'),
                      const Divider(height: 32),
                      _buildInstallStep(Icons.add_box_outlined, '2. Tap "Add to Home Screen"'),
                      const Divider(height: 32),
                      _buildInstallStep(Icons.touch_app, '3. Tap "Add" in the top right'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }

  Widget _buildInstallStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppConstants.primary, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppConstants.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
