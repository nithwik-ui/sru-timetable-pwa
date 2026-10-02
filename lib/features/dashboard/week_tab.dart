import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/sync.dart';
import 'widgets/live_class_progress.dart';
import 'widgets/live_free_slot_progress.dart';
import '../../widgets/class_details_bottom_sheet.dart';

class WeekTab extends StatefulWidget {
  const WeekTab({super.key});

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> {
  late DateTime _startOfWeek;
  late int _selectedDayIndex; // 0 = Mon, 6 = Sun
  
  List<dynamic> _timetable = [];
  Map<String, dynamic>? _nextClassToday;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _calculateCurrentWeek();
    _loadLocalData();
    SyncService.instance.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      if (!SyncService.instance.isSyncing) {
        _loadLocalData();
      }
    }
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _calculateCurrentWeek() {
    // Current Local Time
    final nowLocal = DateTime.now();
    
    // Find the Monday of the current week
    final weekday = nowLocal.weekday; // 1 = Mon, 7 = Sun
    _startOfWeek = nowLocal.subtract(Duration(days: weekday - 1));
    
    // Select current day index by default (0-6)
    _selectedDayIndex = weekday - 1;
  }

  void _loadLocalData() {
    final userMode = StorageService.getUserMode();
    final cached = userMode == 'faculty'
        ? StorageService.getFacultyTimetableCache()
        : StorageService.getTimetableCache();
        
    setState(() {
      _timetable = cached;
    });
    _calculateNextClassHighlight();
  }

  void _calculateNextClassHighlight() {
    if (_timetable.isEmpty) return;

    final nowLocal = DateTime.now();
    final currentDayIndex = nowLocal.weekday - 1;
    
    // Highlight is only computed if the selected day index matches today
    if (_selectedDayIndex != currentDayIndex) {
      setState(() => _nextClassToday = null);
      return;
    }

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = weekdays[currentDayIndex];
    final currentMinutes = nowLocal.hour * 60 + nowLocal.minute;

    final todayClasses = _timetable.where((e) => e['day'] == currentDay).toList();
    todayClasses.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

    // Find first class starting in the future
    Map<String, dynamic>? next;
    for (final c in todayClasses) {
      final startParts = (c['start_time'] as String).split(':').map(int.parse).toList();
      final startMinutes = startParts[0] * 60 + startParts[1];
      if (startMinutes > currentMinutes) {
        next = Map<String, dynamic>.from(c);
        break;
      }
    }

    setState(() {
      _nextClassToday = next;
    });
  }



  @override
  Widget build(BuildContext context) {
    final weekdaysNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = weekdaysNames[_selectedDayIndex];
    final selectedDate = _startOfWeek.add(Duration(days: _selectedDayIndex));
    
    // Format headers
    final subHeadlineText = DateFormat('EEEE, d MMMM').format(selectedDate);
    final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final userMode = StorageService.getUserMode() ?? 'student';
    final overrides = userMode == 'faculty' 
        ? StorageService.getFacultyCalendarOverridesCache() 
        : StorageService.getStudentCalendarOverridesCache();

    String? holidayTitle;
    String? holidayMessage;
    List<dynamic> dayClasses = [];
    final rawToday = _timetable.where((e) => (e['day'] as String).toLowerCase() == selectedDayName.toLowerCase()).toList();
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
               final cStart = cls['start_time'] as String;
               if (cStart.compareTo(oStart) >= 0 && cStart.compareTo(oEnd) <= 0) {
                 isCancelled = true;
                 break;
               }
            } else {
              isCancelled = true;
              break;
            }
          }
        }
      }
      cls['isCancelled'] = isCancelled;
      dayClasses.add(cls);
    }
    dayClasses.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));

    // Inject free slots
    List<dynamic> listItems = [];
    for (int i = 0; i < dayClasses.length; i++) {
       listItems.add(dayClasses[i]);
       if (dayClasses[i]['isCancelled'] != true) {
          int nextActiveIndex = -1;
          for (int j = i + 1; j < dayClasses.length; j++) {
             if (dayClasses[j]['isCancelled'] != true) {
                nextActiveIndex = j;
                break;
             }
          }
          if (nextActiveIndex != -1) {
             final c1 = dayClasses[i];
             final c2 = dayClasses[nextActiveIndex];
             if (c1['end_time'] != c2['start_time']) {
                listItems.add({
                   'is_gap': true,
                   'start_time': c1['end_time'],
                   'end_time': c2['start_time'],
                });
             }
          }
       }
    }

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
                    border: Border.all(color: AppConstants.error.withValues(alpha: 0.3)),
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
                              style: AppConstants.getBodyMedium(color: AppConstants.error.withValues(alpha: 0.8)),
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
            
            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer, vertical: 8),
              child: Text(
                'This week.',
                style: AppConstants.getDisplay().copyWith(fontSize: 24),
              ),
            ),

            // Horizontal Day Pills Row
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = _startOfWeek.add(Duration(days: index));
                  final isSelected = _selectedDayIndex == index;
                  
                  final shortDay = DateFormat('E').format(date).substring(0, 2); // Mo, Tu, We...
                  final dateNum = DateFormat('d').format(date);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDayIndex = index;
                        });
                        _calculateNextClassHighlight();
                      },
                      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                      child: Container(
                        width: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? AppConstants.primary : AppConstants.surface,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                          border: Border.all(
                            color: isSelected ? AppConstants.primary : AppConstants.outline,
                          ),
                          boxShadow: isSelected ? AppConstants.shadowLevel2 : AppConstants.shadowLevel1,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shortDay,
                              style: AppConstants.getLabelSmall(
                                color: isSelected ? Colors.white70 : AppConstants.textSecondary,
                              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateNum,
                              style: AppConstants.getHeadline(
                                color: isSelected ? Colors.white : AppConstants.textPrimary,
                              ).copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Selected Day date Sub-headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subHeadlineText,
                    style: AppConstants.getHeadline().copyWith(fontSize: 16, color: AppConstants.textSecondary),
                  ),
                  if (holidayTitle != null)
                    Expanded(
                      child: Text(
                        holidayMessage != null && holidayMessage.isNotEmpty 
                            ? '$holidayTitle - $holidayMessage'
                            : holidayTitle,
                        style: AppConstants.getBodyMedium(color: AppConstants.info).copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Class Feed
            Expanded(
              child: listItems.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
                      itemCount: listItems.length + 1, // list + end of classes divider
                      itemBuilder: (context, index) {
                        if (index == listItems.length) {
                          // End of classes indicator
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                '— End of classes —',
                                style: AppConstants.getLabelSmall(color: AppConstants.textSecondary),
                              ),
                            ),
                          );
                        }

                        final item = listItems[index];
                        if (item['is_gap'] == true) {
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 12),
                             child: LiveFreeSlotProgressIndicator(
                               startTime: item['start_time'],
                               endTime: item['end_time'],
                               isToday: _selectedDayIndex == DateTime.now().weekday - 1,
                             ),
                           );
                        }

                        final c = item as Map<String, dynamic>;
                        final isCancelled = c['isCancelled'] == true;
                        
                        // Check if this class is the "Next" class highlighted
                        final isNext = !isCancelled && _nextClassToday != null &&
                            _nextClassToday!['day'] == c['day'] &&
                            _nextClassToday!['start_time'] == c['start_time'] &&
                            _nextClassToday!['subject'] == c['subject'];

                        final options = c['options'] as List<dynamic>?;
                        final isChoice = options != null && options.isNotEmpty;
                        
                          if (isChoice) {
                            return SizedBox(
                              height: 120, // fixed height for PageView
                              child: _ChoiceCarousel(
                                options: options,
                                isCancelled: isCancelled,
                                isNext: isNext,
                                buildCard: _buildClassCard,
                              ),
                            );
                          } else {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildClassCard(c, isCancelled: isCancelled, isNext: isNext),
                          );
                        }
                      },
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_food_beverage_outlined, color: AppConstants.primary, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No classes today',
                          style: AppConstants.getHeadline().copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enjoy your free day!',
                          style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, {required bool isCancelled, required bool isNext, int? optionIndex, int? totalOptions}) {
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
          final currentDayIndex = nowLocal.weekday - 1;
          
          if (_selectedDayIndex > currentDayIndex) {
             status = 'Upcoming Class';
          } else if (_selectedDayIndex < currentDayIndex) {
             status = 'Completed';
          } else {
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
            } else {
               status = 'Upcoming Class';
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
          border: Border.all(
            color: isNext ? AppConstants.primary : (isCancelled ? AppConstants.outline : AppConstants.outline.withOpacity(0.5)),
            width: isNext ? 1.5 : 1.0,
          ),
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
                        isToday: _selectedDayIndex == DateTime.now().weekday - 1,
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
          if (!isCancelled && (isNext || ltp.isNotEmpty))
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNext)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.primary,
                        borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                      ),
                      child: Text(
                        'Next',
                        style: AppConstants.getLabelSmall(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (ltp.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLab
                            ? AppConstants.warningContainer.withOpacity(0.5)
                            : AppConstants.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppConstants.radiusTag),
                      ),
                      child: Text(
                        ltp,
                        style: AppConstants.getLabelSmall(
                          color: isLab ? AppConstants.warning : AppConstants.textSecondary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }
}

class _ChoiceCarousel extends StatefulWidget {
  final List<dynamic> options;
  final bool isCancelled;
  final bool isNext;
  final Widget Function(Map<String, dynamic>, {required bool isCancelled, required bool isNext, int? optionIndex, int? totalOptions}) buildCard;

  const _ChoiceCarousel({
    super.key,
    required this.options,
    required this.isCancelled,
    required this.isNext,
    required this.buildCard,
  });

  @override
  State<_ChoiceCarousel> createState() => _ChoiceCarouselState();
}

class _ChoiceCarouselState extends State<_ChoiceCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      padEnds: false,
      itemCount: widget.options.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12, right: index == widget.options.length - 1 ? 0 : 10),
          child: widget.buildCard(
            widget.options[index] as Map<String, dynamic>,
            isCancelled: widget.isCancelled,
            isNext: widget.isNext,
            optionIndex: index,
            totalOptions: widget.options.length,
          ),
        );
      },
    );
  }
}
