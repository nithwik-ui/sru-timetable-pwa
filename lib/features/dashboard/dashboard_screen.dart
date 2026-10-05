import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../../core/updater.dart';
import '../../core/notifications.dart';
import 'home_tab.dart';
import 'week_tab.dart';
import '../academic/academic_tab.dart';
import 'profile_tab.dart';
import 'changes_tab.dart';
import 'ad_banner.dart';
import 'widgets/sru_app_bar.dart';
import '../../core/analytics_service.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTab;

  const DashboardScreen({super.key, this.initialTab = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  bool _hasUnreadChanges = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    final initialTabName = _currentIndex == 1 ? 'Week' : (_currentIndex == 2 ? 'Academic' : (_currentIndex == 3 ? 'Profile' : 'Home'));
    AnalyticsService.instance.logScreenView(initialTabName);
    
    // Explicitly restore/schedule exact alarms on startup for existing timetable
    final userMode = StorageService.getUserMode();
    final cachedTimetable = userMode == 'faculty' 
        ? StorageService.getFacultyTimetableCache() 
        : StorageService.getTimetableCache();
        
    if (cachedTimetable.isNotEmpty) {
      NotificationService.reconcileReminders();
    }
    
    _checkAndRefreshTimetable();
    if (userMode == 'student') {
      _checkForChanges();
    }
    
    // Check for updates silently on startup (after 3 seconds politeness delay)
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        _checkForUpdatesSilently();
        try {
          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _checkAndRefreshTimetable() async {
    final userMode = StorageService.getUserMode();
    
    if (userMode == 'faculty') {
      final selection = StorageService.getFacultySelection();
      if (selection == null) return;
      
      final lastSynced = StorageService.getFacultyLastSyncedAt();
      if (lastSynced != null) {
        final diff = DateTime.now().difference(lastSynced);
        if (diff.inMinutes < 60) return;
      }

      try {
        final facultyId = selection['facultyId']!;
        final newTimetable = await ApiService.fetchFacultyTimetable(facultyId);
        await StorageService.saveFacultyTimetableCache(newTimetable);
        await StorageService.saveFacultyLastSyncedAt(DateTime.now());
        
        await NotificationService.reconcileReminders();
      } catch (_) {}
    } else {
      final selection = StorageService.getSelection();
      if (selection == null) return;
      
      final lastSynced = StorageService.getLastSyncedAt();
      if (lastSynced != null) {
        final diff = DateTime.now().difference(lastSynced);
        if (diff.inMinutes < 60) return;
      }

      try {
        final batchId = selection['batchId']!;
        final newTimetable = await ApiService.fetchTimetable(batchId);
        await StorageService.saveTimetableCache(newTimetable);
        await StorageService.saveLastSyncedAt(DateTime.now());
        _checkForChanges();
        
        await NotificationService.reconcileReminders();
      } catch (_) {}
    }
  }

  void _checkForChanges() async {
    final selection = StorageService.getSelection();
    if (selection == null) return;
    final batchId = selection['batchId']!;

    try {
      final list = await ApiService.fetchChanges(batchId);
      if (list.isNotEmpty) {
        // Compare with cached changes count to see if there is something new
        final cachedCount = StorageService.getChangesCache().length;
        if (list.length > cachedCount) {
          setState(() {
            _hasUnreadChanges = true;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = StorageService.getUserMode() == 'student';

    final List<Widget> tabs = isStudent 
        ? const [HomeTab(), WeekTab(), AcademicTab(), ProfileTab()]
        : const [HomeTab(), WeekTab(), ChangesTab(), ProfileTab()];

    // Ensure _currentIndex is valid when switching modes (e.g. from 3 back to 2)
    if (_currentIndex >= tabs.length) {
      _currentIndex = tabs.length - 1;
    }

    final bottomNavItems = isStudent
        ? [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_view_week_outlined), activeIcon: Icon(Icons.calendar_view_week), label: 'Week'),
            const BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: 'Academic'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ]
        : [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_view_week_outlined), activeIcon: Icon(Icons.calendar_view_week), label: 'Week'),
            const BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Changes'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ];

    final tabNames = isStudent ? ['Home', 'Week', 'Academic', 'Profile'] : ['Home', 'Week', 'Changes', 'Profile'];

    return Scaffold(
      appBar: SruAppBar(
        hasUnreadChanges: _hasUnreadChanges,
        onChangesTapped: () {
          setState(() {
            _hasUnreadChanges = false;
          });
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
          const AdBanner(),
        ],
      ),
      bottomNavigationBar: Container(
        color: AppConstants.surface,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppConstants.outline, width: 1.0),
              ),
            ),
            child: Row(
              children: List.generate(bottomNavItems.length, (index) {
                final item = bottomNavItems[index];
                final isSelected = _currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_currentIndex != index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        if (index < tabNames.length) {
                          AnalyticsService.instance.logScreenView(tabNames[index]);
                        }
                      }
                    },
                    child: Container(
                      height: 60, // Ensure generous hit target
                      color: Colors.transparent, // Crucial for Flutter Web HitTestBehavior.opaque
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          isSelected ? item.activeIcon : item.icon,
                          const SizedBox(height: 4),
                          Text(
                            item.label ?? '',
                            style: AppConstants.getLabelSmall(
                              color: isSelected ? AppConstants.primary : AppConstants.textSecondary,
                            ).copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _checkForUpdatesSilently() async {
    final result = await UpdateService.checkForUpdates();
    if (result['status'] == 'update_available') {
      if (mounted) {
        _showUpdateDialog(result['latestTag'], result['downloadUrl']);
      }
    }
  }

  void _showUpdateDialog(String latestTag, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version of SRU Timetable ($latestTag) is available on GitHub. Would you like to download it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open download link.')),
                    );
                  }
                }
              },
              child: const Text('Download', style: TextStyle(color: AppConstants.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
