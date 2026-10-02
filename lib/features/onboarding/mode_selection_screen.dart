import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants.dart';
import '../../core/api.dart';
import '../../core/storage.dart';
import '../../core/notifications.dart';
import '../../core/sync.dart';
import 'welcome_screen.dart';
import 'faculty_selection_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../../core/analytics_service.dart';

class ModeSelectionScreen extends StatefulWidget {
  final bool isSwitching;

  const ModeSelectionScreen({super.key, this.isSwitching = false});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  bool _isLoading = false;

  void _selectStudent(BuildContext context) async {
    if (StorageService.hasSelection()) {
      setState(() => _isLoading = true);
      try {
        AnalyticsService.instance.logModeSwitched(targetMode: 'student');
        await NotificationService.clearModeReminders('faculty');
        await StorageService.setUserMode('student');
        await NotificationService.reconcileReminders();
        
        // Trigger background sync for the newly selected mode
        SyncService.instance.syncTimetable();

        // Re-register device as student in the background
        final batchId = StorageService.getSelection()?['batchId'] ?? '';
        FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3)).then((token) {
          if (token != null) {
            ApiService.registerDevice(token, batchId, userMode: 'student');
          }
        }).catchError((_) {});
      } catch (_) {}

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } else {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  void _selectFaculty(BuildContext context) async {
    if (StorageService.hasFacultySelection()) {
      setState(() => _isLoading = true);
      try {
        AnalyticsService.instance.logModeSwitched(targetMode: 'faculty');
        await NotificationService.clearModeReminders('student');
        await StorageService.setUserMode('faculty');
        await NotificationService.reconcileReminders();
        
        // Trigger background sync for the newly selected mode
        SyncService.instance.syncTimetable();

        // Re-register device as faculty in the background
        final facultyId = StorageService.getFacultySelection()?['facultyId'];
        FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3)).then((token) {
          if (token != null) {
            ApiService.registerDevice(token, '', userMode: 'faculty', facultyId: facultyId);
          }
        }).catchError((_) {});
      } catch (_) {}

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } else {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const FacultySelectionScreen()),
        );
      }
    }
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppConstants.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          boxShadow: AppConstants.shadowLevel1,
          border: Border.all(color: AppConstants.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppConstants.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppConstants.getHeadline().copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppConstants.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: widget.isSwitching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.isSwitching) const SizedBox(height: 24),
                  if (!widget.isSwitching)
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  const Spacer(flex: 1),
                  Text(
                    'Choose your timetable',
                    style: AppConstants.getHeadline().copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildCard(
                    context: context,
                    title: 'Student',
                    subtitle: 'View your class timetable',
                    icon: Icons.school,
                    onTap: () => _selectStudent(context),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    context: context,
                    title: 'Faculty',
                    subtitle: 'View your faculty timetable',
                    icon: Icons.person,
                    onTap: () => _selectFaculty(context),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
