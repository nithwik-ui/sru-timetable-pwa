import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants.dart';
import 'core/storage.dart';
import 'core/api.dart';
import 'core/notifications.dart';
import 'core/sync.dart';
import 'core/ad_service.dart';
import 'core/analytics_service.dart';
import 'features/onboarding/mode_selection_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/sraap/sraap_session_manager.dart';
import 'core/widget_updater.dart';
import 'core/android_gatekeeper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Hive.initFlutter();
    await StorageService.init();
    await NotificationService.init();
    
    if (message.data['type'] == 'calendar_override_updated') {
      final mode = message.data['target_mode'];
      final currentMode = StorageService.getUserMode() ?? 'student';
      
      if (mode == 'both' || mode == currentMode) {
        final overrides = await ApiService.fetchCalendarOverrides('', currentMode);
        if (currentMode == 'faculty') {
          await StorageService.saveFacultyCalendarOverridesCache(overrides);
        } else {
          await StorageService.saveStudentCalendarOverridesCache(overrides);
        }
        await NotificationService.reconcileReminders();
      }
    } else if (message.data['change_type'] != null) {
      // Backend fcm.ts sends change_type and batch_id
      final currentMode = StorageService.getUserMode();
      
      if (currentMode == 'student' && message.data['batch_id'] != null) {
        final selection = StorageService.getSelection();
        if (selection != null && selection['batchId'] == message.data['batch_id']) {
          // Fetch updated timetable and changes directly
          try {
            final list = await ApiService.fetchTimetable(selection['batchId']!);
            await StorageService.saveTimetableCache(list);
            
            final changesList = await ApiService.fetchChanges(selection['batchId']!);
            await StorageService.saveChangesCache(changesList);
            
            if (StorageService.isClassRemindersEnabled()) {
              await NotificationService.reconcileReminders();
            }
          } catch (_) {}
        }
      } else if (currentMode == 'faculty' && message.data['faculty_id'] != null) {
        final selection = StorageService.getFacultySelection();
        if (selection != null && selection['facultyId'] == message.data['faculty_id']) {
          try {
            final list = await ApiService.fetchFacultyTimetable(selection['facultyId']!);
            await StorageService.saveFacultyTimetableCache(list);
            
            if (StorageService.isClassRemindersEnabled()) {
              await NotificationService.reconcileReminders();
            }
          } catch (_) {}
        }
      }
    }
  } catch (e) {
    debugPrint("Background handler error: $e");
  }
}

Future<void> _initFirebaseSafely() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD9_WzJsEJSi-0ke0rdZVdA6ohgX_yib-Q",
          appId: "1:712842876134:web:6a81c13779ec2828949727",
          messagingSenderId: "712842876134",
          projectId: "timetable-77a7d",
          authDomain: "timetable-77a7d.firebaseapp.com",
          storageBucket: "timetable-77a7d.firebasestorage.app",
          measurementId: "G-WRP2DM4ZRL",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    
    await AnalyticsService.instance.init();
    await AnalyticsService.instance.logAppOpen();
    
    final messaging = FirebaseMessaging.instance;
    
    if (kIsWeb) {
      // Request permission on web
      await messaging.requestPermission();
      // Required for Web Push
      final vapidKey = "BLfXNackp6Rs_phEfbaIPWdKm7HADbl3RYGEhjU2qocshKk7CbeIX0Gb5zLQ9EH84nkSaZSiJCcENw4wWf7e12M";
      await messaging.getToken(vapidKey: vapidKey);
    }
    
    // Subscribe to global topic for broadcasts in background
    if (!kIsWeb) {
      // Topics are not fully supported on Web Push out of the box without Cloud Functions
      messaging.subscribeToTopic('sru_all_users').catchError((_) {});
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground message handler using local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Filter stale messages based on TTL
        final expiresAtStr = message.data['expiresAt']?.toString();
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            debugPrint('[FCM] Discarding stale foreground message');
            return;
          }
        }
        
        NotificationService.showForegroundNotification(
          message.notification!.title,
          message.notification!.body,
          message.data,
        );
      }
    });

    // Handle background notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
        (route) => false,
      );
    });

    // Auto-refresh token if server rotates it
    messaging.onTokenRefresh.listen((fcmToken) async {
      final userMode = StorageService.getUserMode() ?? 'student';
      final batchId = StorageService.getSelection()?['batchId'] ?? '';
      final facultyId = StorageService.getFacultySelection()?['facultyId'];

      try {
        await ApiService.registerDevice(
          fcmToken,
          batchId,
          userMode: userMode,
          facultyId: facultyId,
        );
      } catch (_) {}
    });

  } catch (e) {
    debugPrint('Firebase initialization failed (graceful fallback): $e');
  }
}

void main() {
  // Ensure Flutter engine bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Enable genuine Android Edge-to-Edge with transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  // Launch the UI immediately to prevent black screen delay
  runApp(const MyApp());

  // Initialize non-critical background services
  Future.microtask(() async {
    // 1. Initialize AdMob SDK immediately (non-blocking)
    try {
      AdService.instance.init();
    } catch (e) {
      debugPrint('AdMob initialization failed (non-fatal): $e');
    }

    // 2. Initialize local notifications
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }

    // 3. Initialize Firebase & Analytics
    await _initFirebaseSafely();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile reminders and sync when app comes to foreground
      NotificationService.reconcileReminders();
      SyncService.instance.syncTimetable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRU Timetable',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppConstants.background,
        colorScheme: ColorScheme.light(
          primary: AppConstants.primary,
          secondary: AppConstants.primaryContainer,
          tertiary: AppConstants.primaryContainer,
          surface: AppConstants.surface,
          error: AppConstants.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppConstants.textPrimary,
          outline: AppConstants.outline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppConstants.textPrimary),
        ),
      ),
      navigatorKey: navigatorKey,
      home: const AndroidGatekeeper(
        child: SplashController(),
      ),
    );
  }
}

class SplashController extends StatefulWidget {
  const SplashController({super.key});

  @override
  State<SplashController> createState() => _SplashControllerState();
}

class _SplashControllerState extends State<SplashController> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await StorageService.init();
      // Restore SRAAP session from secure storage
      await SraapSessionManager.instance.restoreSession();
      
      // Safely schedule reminders based on stored state on app startup
      await NotificationService.reconcileReminders();
      
      // Trigger background sync on startup
      SyncService.instance.syncTimetable();
      
      // Update widget info
      await WidgetUpdater.updateWidgetInfo();
    } catch (e) {
      debugPrint('Local storage initialization failed: $e');
    }

    if (!mounted) return;

    final userMode = StorageService.getUserMode();
    final hasStudent = StorageService.hasSelection();
    final hasFaculty = StorageService.hasFacultySelection();
    
    bool launchedFromNotification = false;
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        launchedFromNotification = true;
      }
    } catch (_) {}

    if (!mounted) return;
    
    Widget nextScreen;
    if (userMode == 'student' && hasStudent) {
      nextScreen = DashboardScreen(initialTab: launchedFromNotification ? 0 : 0); // Always default to 0
    } else if (userMode == 'faculty' && hasFaculty) {
      nextScreen = DashboardScreen(initialTab: launchedFromNotification ? 0 : 0);
    } else {
      nextScreen = const ModeSelectionScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 64,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppConstants.primary),
          ],
        ),
      ),
    );
  }
}
