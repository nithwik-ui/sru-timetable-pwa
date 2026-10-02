import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

class AndroidGatekeeper extends StatelessWidget {
  final Widget child;
  const AndroidGatekeeper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If it's running on the web, AND the user agent / platform is Android, block the PWA.
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
                  'Get the Official App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'For the best experience, including precise class reminders, widgets, and offline support, please download the official SRU Timetable app from the Google Play Store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Redirect to the Play Store link
                      launchUrl(
                        Uri.parse('https://play.google.com/store/apps/details?id=com.srutimetable.mobile'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      'Download on Google Play',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
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
}
