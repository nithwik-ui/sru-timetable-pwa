import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/sync.dart';
import 'dashboard_screen.dart';
import 'widgets/live_class_progress.dart';
import 'widgets/live_free_slot_progress.dart';
import '../../widgets/class_details_bottom_sheet.dart';
import '../../core/widget_updater.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _greeting = 'Good morning';
  String? _userName;
  String _contextLine = '';
  String? _degree;
  String? _year;
  String? _batchCode;
  String _freshnessText = 'Syncing...';
  
  Map<String, dynamic>? _upNextClass;
  String _upNextStatus = '';
  List<dynamic> _todayClasses = [];
  String? _todayHolidayTitle;
  String? _todayHolidayMessage;
  Map<String, dynamic>? _currentFreeSlot;
  
  bool _isOffline = false;
  bool _isRefreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    
    // Auto-update freshness text and class statuses every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateFreshnessAndTimetable();
        WidgetUpdater.updateWidgetInfo(); // Keep widget synced when app is foregrounded
      }
    });
    
    SyncService.instance.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      if (!SyncService.instance.isSyncing) {
        setState(() => _isRefreshing = false);
        _updateFreshnessAndTimetable();
      } else {
        setState(() => _isRefreshing = true);
      }
    }
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncUpdate);
    _timer?.cancel();
    super.dispose();
  }

  void _loadLocalData() {
    final mode = StorageService.getUserMode();
    final name = mode == 'student' 
        ? StorageService.getUserName() 
        : StorageService.getFacultySelection()?['facultyName'];
    
    final selection = StorageService.getSelection();

    // Greeting time calculation (local timezone context)
    final nowLocal = DateTime.now();
    final hour = nowLocal.hour;
    String greet;
    if (hour < 12) {
      greet = 'Good morning';
    } else if (hour < 17) {
      greet = 'Good afternoon';
    } else {
      greet = 'Good evening';
    }

    setState(() {
      _greeting = greet;
      _userName = name;
      if (mode == 'student' && selection != null) {
        _degree = selection['degree'];
        _year = selection['year'];
        _batchCode = selection['batchCode'];
      } else if (mode == 'faculty') {
        _contextLine = 'Faculty Schedule';
      }
    });
    
    _updateFreshnessAndTimetable();
  }

  void _updateFreshnessAndTimetable() {
    final userMode = StorageService.getUserMode();
    final lastSynced = userMode == 'faculty' ? StorageService.getFacultyLastSyncedAt() : StorageService.getLastSyncedAt();
    
    if (lastSynced == null) {
      setState(() {
        _freshnessText = 'Never updated';
      });
    } else {
      final diff = DateTime.now().difference(lastSynced);
      String timeStr;
      if (diff.inMinutes < 1) {
        timeStr = 'just now';
      } else if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes} min ago';
      } else {
        timeStr = '${diff.inHours} hr ago';
      }

      final syncState = SyncService.instance.syncState;
      if (syncState == SyncState.offline) {
        setState(() => _freshnessText = 'Offline · Last synced $timeStr');
      } else if (syncState == SyncState.serverUnavailable || syncState == SyncState.syncTimeout) {
        setState(() => _freshnessText = 'Sync failed · Tap to retry');
      } else {
        setState(() => _freshnessText = '✓ Synced $timeStr');
      }
    }

    // Refresh timetable from cache
    final timetable = userMode == 'faculty' ? StorageService.getFacultyTimetableCache() : StorageService.getTimetableCache();
    if (timetable.isNotEmpty) {
      _calculateSchedules(timetable);
    } else {
      setState(() {
        _upNextClass = null;
        _upNextStatus = '';
        _todayClasses = [];
        _currentFreeSlot = null;
      });
    }
  }

  void _calculateSchedules(List<dynamic> timetable) {
    // Current Local Time
    final nowLocal = DateTime.now();
    final weekdayIndex = nowLocal.weekday;
    
    // Mappings: Flutter weekday (1 = Mon, 7 = Sun) -> DB Day values
    final weekdays = [
      'Sunday', // 0
      'Monday', // 1
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday' // 7
    ];
    final currentDay = weekdays[weekdayIndex].toLowerCase();
    final currentMinutes = nowLocal.hour * 60 + nowLocal.minute;

    // Filter today's classes
    final rawToday = timetable.where((e) => e['day']?.toString().toLowerCase() == currentDay).toList();
    
    // Apply calendar overrides
    final userMode = StorageService.getUserMode() ?? 'student';
    final overrides = userMode == 'faculty' 
        ? StorageService.getFacultyCalendarOverridesCache() 
        : StorageService.getStudentCalendarOverridesCache();
    final formattedDate = "${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}";
    
    List<dynamic> today = [];
    String? holidayTitle;
    String? holidayMessage;
    for (final rawCls in rawToday) {
      final cls = Map<String, dynamic>.from(rawCls);
      bool isCancelled = false;
      for (final override in overrides) {
        if (override['override_date'] == formattedDate) {
          final targetMode = override['target_mode'];
          if (targetMode == 'both' || targetMode == userMode) {
            holidayTitle = override['title'];
            holidayMessage = override['message'];
            final oStart = override['start_time'];
            final oEnd = override['end_time'];
            if (oStart != null && oStart.toString().isNotEmpty && oEnd != null && oEnd.toString().isNotEmpty) {
               final cStart = cls['start_time']?.toString() ?? '';
               if (cStart.compareTo(oStart) >= 0 && cStart.compareTo(oEnd) <= 0) {
                 isCancelled = true;
                 break;
               }
            } else {
              isCancelled = true; // Full day
              break;
            }
          }
        }
      }
      cls['isCancelled'] = isCancelled;
      today.add(cls);
    }
    
    // Sort chronologically
    today.sort((a, b) => (a['start_time']?.toString() ?? '').compareTo(b['start_time']?.toString() ?? ''));

    // Calculate remaining classes (where end_time has not passed)
    // Keep cancelled classes in the list so they can be shown as struck through
    final remaining = today.where((e) {
      final endStr = e['end_time']?.toString() ?? '';
      final endParts = endStr.split(':').map(int.tryParse).toList();
      if (endParts.length < 2 || endParts[0] == null || endParts[1] == null) return true;
      final endMinutes = endParts[0]! * 60 + endParts[1]!;
      return endMinutes > currentMinutes;
    }).toList();

    Map<String, dynamic>? nextClass;
    String status = '';

    // Find the first NON-CANCELLED class for "Up Next"
    final activeRemaining = remaining.where((e) => e['isCancelled'] != true).toList();

    if (activeRemaining.isNotEmpty) {
      // Check if first active remaining class is currently in progress
      final first = activeRemaining.first;
      final startStr = first['start_time']?.toString() ?? '';
      final startParts = startStr.split(':').map(int.tryParse).toList();
      if (startParts.length < 2 || startParts[0] == null || startParts[1] == null) return;
      final startMinutes = startParts[0]! * 60 + startParts[1]!;

      if (currentMinutes >= startMinutes) {
        nextClass = Map<String, dynamic>.from(first);
        status = 'Ongoing';
      } else {
        nextClass = Map<String, dynamic>.from(first);
        final diff = startMinutes - currentMinutes;
        status = 'Starts in $diff min';
        
        // Find free slot
        final pastClasses = today.where((e) {
          final endStr = e['end_time']?.toString() ?? '';
          final endParts = endStr.split(':').map(int.tryParse).toList();
          if (endParts.length < 2 || endParts[0] == null || endParts[1] == null) return false;
          final endMins = endParts[0]! * 60 + endParts[1]!;
          return endMins <= currentMinutes && e['isCancelled'] != true;
        }).toList();
        
        if (pastClasses.isNotEmpty) {
           final lastPast = pastClasses.last;
           if (lastPast['end_time'] != first['start_time']) {
             _currentFreeSlot = {
                'start_time': lastPast['end_time'],
                'end_time': first['start_time'],
             };
           }
        }
      }
    } else {
      _currentFreeSlot = null;
    }

    setState(() {
      _upNextClass = nextClass;
      _upNextStatus = status;
      _todayHolidayTitle = holidayTitle;
      _todayHolidayMessage = holidayMessage;
      
      // Filter out the active "Up Next" class from the remaining classes feed, but keep cancelled classes
      if (nextClass != null) {
        final activeNext = nextClass;
        // Use start_time+subject as unique key since injected entries have no id
        _todayClasses = remaining.where((e) {
          return e['start_time']?.toString() != activeNext['start_time']?.toString() ||
                 e['subject']?.toString() != activeNext['subject']?.toString();
        }).toList();
      } else {
        _todayClasses = remaining;
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // (App bar is rendered by DashboardScreen > SruAppBar)
            const SizedBox(height: 4),
            // Offline banner
            if (_isOffline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.errorContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: AppConstants.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You\'re offline',
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.error),
                            ),
                            Text(
                              'Showing last synchronized timetable.',
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isOffline = false);
                          SyncService.instance.syncTimetable();
                        },
                        child: Text(
                          'Try again',
                          style: AppConstants.getBodyMedium(color: AppConstants.error).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Holiday banner
            if (_todayHolidayTitle != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.infoContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    border: Border.all(color: AppConstants.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy, color: AppConstants.info, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _todayHolidayTitle!,
                              style: AppConstants.getHeadline().copyWith(fontSize: 14, color: AppConstants.info),
                            ),
                            if (_todayHolidayMessage != null && _todayHolidayMessage!.isNotEmpty)
                              Text(
                                _todayHolidayMessage!,
                                style: AppConstants.getBodyMedium(color: AppConstants.info.withOpacity(0.9)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: RefreshIndicator(
                color: AppConstants.primary,
                onRefresh: () async {
                  await SyncService.instance.syncTimetable();
                },
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: AppConstants.paddingContainer,
                    right: AppConstants.paddingContainer,
                    bottom: 20,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Greeting & context
                    Text(
                      _userName != null ? '$_greeting, $_userName' : _greeting,
                      style: AppConstants.getDisplay().copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    if (StorageService.getUserMode() == 'student') ...[
                      if (_degree != null) Text('Degree: $_degree', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                      if (_year != null) Text('Year: $_year', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                      if (_batchCode != null) Text('Batch: $_batchCode', style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)),
                    ] else ...[
                      Text(
                        _contextLine,
                        style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Sync Refresh row
                    Row(
                      children: [
                        const Icon(Icons.sync, color: AppConstants.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _freshnessText,
                          style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                        ),
                        if (_isRefreshing) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppConstants.textSecondary),
                          )
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // "Up Next" Section
                    Text(
                      'Up Next',
                      style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (_currentFreeSlot != null) ...[
                      LiveFreeSlotProgressIndicator(
                        startTime: _currentFreeSlot!['start_time'],
                        endTime: _currentFreeSlot!['end_time'],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_upNextClass != null) ...[
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ClassDetailsBottomSheet(
                              classEvent: _upNextClass!,
                              status: _upNextStatus,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel2,
                          border: Border.all(color: AppConstants.primary.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // State Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _upNextStatus == 'Ongoing' 
                                    ? AppConstants.successContainer 
                                    : AppConstants.infoContainer,
                                borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                              ),
                              child: Text(
                                _upNextStatus,
                                style: AppConstants.getLabelSmall(
                                  color: _upNextStatus == 'Ongoing' 
                                      ? AppConstants.success 
                                      : AppConstants.info
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _upNextClass!['subject'] as String,
                              style: AppConstants.getHeadline().copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppConstants.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${TimeUtils.format12Hour(_upNextClass!['start_time'])} - ${TimeUtils.format12Hour(_upNextClass!['end_time'])}',
                                  style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                LiveClassProgressIndicator(
                                  startTime: _upNextClass!['start_time'] as String,
                                  endTime: _upNextClass!['end_time'] as String,
                                  isToday: true,
                                ),
                                const SizedBox(width: 12),
                                if ((_upNextClass!['options'] as List<dynamic>?)?.isNotEmpty == true) ...[
                                  const Icon(Icons.place_outlined, size: 16, color: AppConstants.textSecondary),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppConstants.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text('Multiple Options', style: AppConstants.getLabelSmall(color: AppConstants.primary)),
                                  ),
                                ] else ...[
                                  Text(
                                    '📍 ${(_upNextClass!['room'] as String? ?? 'No Room').split('_')[0]}',
                                    style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                            if ((_upNextClass!['options'] as List<dynamic>?)?.isEmpty ?? true) ...[
                              if (_upNextClass!['faculty'] != null && (_upNextClass!['faculty'] as String).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: AppConstants.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _upNextClass!['faculty'] as String,
                                        style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ]
                          ],
                        ),
                      ),
                      ),
                    ] else if (_upNextClass == null) ...[
                      // Empty state (no Up Next and no Today classes)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: Center(
                          child: Text(
                            'No upcoming classes.',
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // "Today" Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today',
                          style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 1)),
                              (route) => false,
                            );
                          },
                          child: Text(
                            'View All',
                            style: AppConstants.getBodyMedium(color: AppConstants.primary).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_todayClasses.isNotEmpty) ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _todayClasses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = _todayClasses[index];
                          final options = c['options'] as List<dynamic>?;
                          final isChoice = options != null && options.isNotEmpty;
                          
                          if (isChoice) {
                            return SizedBox(
                              height: 120, // fixed height for PageView
                              child: PageView.builder(
                                controller: PageController(viewportFraction: 0.93),
                                padEnds: false,
                                itemCount: options.length,
                                itemBuilder: (context, optIndex) {
                                  final opt = options[optIndex];
                                  return Padding(
                                    padding: EdgeInsets.only(right: optIndex == options.length - 1 ? 0 : 10),
                                    child: _buildClassCard(opt, isCancelled: c['isCancelled'] == true, optionIndex: optIndex, totalOptions: options.length),
                                  );
                                },
                              ),
                            );
                          } else {
                            return _buildClassCard(c, isCancelled: c['isCancelled'] == true);
                          }
                        },
                      ),
                    ] else if (_upNextClass == null) ...[
                      // Empty state (no Up Next and no Today classes)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          boxShadow: AppConstants.shadowLevel1,
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppConstants.success, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Day complete',
                              style: AppConstants.getHeadline().copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No more classes today.',
                              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, {required bool isCancelled, int? optionIndex, int? totalOptions}) {
    final room = (c['room'] as String? ?? 'No Room').split('_')[0];
    final ltp = c['ltp'] as String? ?? '';
    final isLab = ltp.toLowerCase().contains('lab') || ltp.toLowerCase().contains('practical') || ltp == 'P';

    return GestureDetector(
      onTap: () {
        // Determine status for this class
        String status = '';
        if (isCancelled) {
          status = 'Cancelled';
        } else {
          final nowLocal = DateTime.now();
          final currentMinutes = nowLocal.hour * 60 + nowLocal.minute;
          
          final startStr = c['start_time']?.toString() ?? '';
          final endStr = c['end_time']?.toString() ?? '';
          final startParts = startStr.split(':').map(int.tryParse).toList();
          final endParts = endStr.split(':').map(int.tryParse).toList();
          
          if (startParts.length >= 2 && startParts[0] != null && endParts.length >= 2 && endParts[0] != null) {
            final startMins = startParts[0]! * 60 + startParts[1]!;
            final endMins = endParts[0]! * 60 + endParts[1]!;
            
            if (currentMinutes < startMins) {
              status = 'Starts in ${startMins - currentMinutes} min';
            } else if (currentMinutes >= startMins && currentMinutes < endMins) {
              status = 'Ongoing';
            } else {
              status = 'Completed';
            }
          }
        }
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ClassDetailsBottomSheet(
            classEvent: c,
            status: status,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCancelled ? AppConstants.surface.withOpacity(0.5) : AppConstants.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
          boxShadow: isCancelled ? null : AppConstants.shadowLevel1,
          border: isCancelled ? Border.all(color: AppConstants.outline) : Border.all(color: AppConstants.outline.withOpacity(0.5)),
        ),
        child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isCancelled ? AppConstants.textSecondary.withOpacity(0.3) : (isLab ? AppConstants.warning : AppConstants.primary),
              borderRadius: BorderRadius.circular(AppConstants.radiusTag),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c['subject'] as String,
                        style: AppConstants.getHeadline().copyWith(
                          fontSize: 16,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                          color: isCancelled ? AppConstants.textSecondary : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (optionIndex != null && totalOptions != null)
                       Text('${optionIndex + 1} / $totalOptions', style: AppConstants.getLabelSmall(color: AppConstants.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${TimeUtils.format12Hour(c['start_time'])} - ${TimeUtils.format12Hour(c['end_time'])}',
                      style: AppConstants.getBodyMedium(color: AppConstants.textSecondary).copyWith(
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isCancelled) ...[
                      LiveClassProgressIndicator(
                        startTime: c['start_time'] as String,
                        endTime: c['end_time'] as String,
                        isToday: true,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        isCancelled ? 'Cancelled' : room,
                        style: AppConstants.getBodyMedium(
                          color: isCancelled ? AppConstants.error : AppConstants.textSecondary
                        ).copyWith(
                          fontWeight: isCancelled ? FontWeight.bold : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (c['faculty'] != null && c['faculty'].toString().isNotEmpty) ...[
                   const SizedBox(height: 4),
                   Text(
                     c['faculty'].toString(),
                     style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ],
            ),
          ),
          if (ltp.isNotEmpty && !isCancelled)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLab 
                    ? AppConstants.warningContainer.withOpacity(0.5) 
                    : AppConstants.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusTag),
              ),
              child: Text(
                ltp,
                style: AppConstants.getLabelSmall(
                  color: isLab ? AppConstants.warning : AppConstants.textSecondary
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

