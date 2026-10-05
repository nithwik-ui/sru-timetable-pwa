import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../core/sraap/models/sraap_academic_data.dart';
import '../core/storage.dart';
import '../features/academic/academic_dashboard.dart';
import '../features/dashboard/dashboard_screen.dart';

class ClassDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> classEvent;
  final String status;

  const ClassDetailsBottomSheet({
    Key? key,
    required this.classEvent,
    required this.status,
  }) : super(key: key);

  @override
  State<ClassDetailsBottomSheet> createState() => _ClassDetailsBottomSheetState();
}

class _ClassDetailsBottomSheetState extends State<ClassDetailsBottomSheet> {
  SraapSubjectAttendance? _attendance;
  bool _isLoadingAttendance = true;
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  void _loadAttendance() {
    // Only attempt to load attendance if student mode
    if (StorageService.getUserMode() != 'student') {
      setState(() {
        _isLoadingAttendance = false;
      });
      return;
    }

    final raw = StorageService.getSraapAcademicCache();
    if (raw != null) {
      try {
        final data = SraapAcademicData.fromJson(raw);
        _lastSynced = data.lastSynced;
        final timetableSubject = (widget.classEvent['subject'] as String?) ?? '';
        
        // Find matching subject
        _attendance = _findMatchingSubject(timetableSubject, data.subjects);
      } catch (e) {
        // ignore
      }
    }
    
    setState(() {
      _isLoadingAttendance = false;
    });
  }

  SraapSubjectAttendance? _findMatchingSubject(String timetableSubject, List<SraapSubjectAttendance> subjects) {
    if (timetableSubject.isEmpty) return null;

    final normTimetable = _normalizeForMatch(timetableSubject);

    // 1. Exact match after basic normalization
    for (var s in subjects) {
      if (_normalizeForMatch(s.subjectName) == normTimetable) {
        return s;
      }
    }

    // 2. Contains match (be careful not to match lab with theory erroneously)
    // E.g., if timetable is "DBMS" and sraap is "DBMS - CSE302"
    final isLab = normTimetable.contains('lab') || normTimetable.contains('practical');
    
    for (var s in subjects) {
      final normSraap = _normalizeForMatch(s.subjectName);
      final sraapIsLab = normSraap.contains('lab') || normSraap.contains('practical');
      
      if (isLab == sraapIsLab) {
        if (normSraap.contains(normTimetable) || normTimetable.contains(normSraap)) {
          return s;
        }
      }
    }

    return null;
  }

  String _normalizeForMatch(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classEvent;
    final subject = c['subject'] as String? ?? 'Unknown Subject';
    final room = c['room'] as String? ?? '';
    final faculty = c['faculty'] as String? ?? '';
    final ltp = c['ltp'] as String? ?? '';
    final isLab = ltp.toLowerCase().contains('lab') || ltp.toLowerCase().contains('practical') || ltp == 'P';
    
    // We assume the classEvent might have 'isCancelled' injected by the caller, or 'status' might be 'Cancelled'
    final isCancelled = c['isCancelled'] == true || widget.status.toLowerCase() == 'cancelled';
    
    // Formatting Day
    final dayStr = c['day']?.toString() ?? '';
    final formattedDay = dayStr.length > 1 ? '${dayStr[0].toUpperCase()}${dayStr.substring(1).toLowerCase()}' : dayStr;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppConstants.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: AppConstants.getHeadline().copyWith(
                        fontSize: 22,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                        color: isCancelled ? AppConstants.textSecondary : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(isCancelled).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCancelled ? 'Cancelled' : widget.status,
                        style: AppConstants.getLabelSmall(
                          color: _getStatusColor(isCancelled)
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppConstants.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Time
          _buildInfoRow(
            icon: Icons.access_time,
            title: 'Time',
            content: '${TimeUtils.format12Hour(c['start_time'])} - ${TimeUtils.format12Hour(c['end_time'])}',
          ),
          
          if (room.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppConstants.surface),
            ),
            _buildInfoRow(
              icon: Icons.place_outlined,
              title: 'Room',
              content: room,
            ),
          ],
          
          if (faculty.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppConstants.surface),
            ),
            _buildInfoRow(
              icon: Icons.person_outline,
              title: 'Faculty',
              content: faculty,
            ),
          ],

          if (!_isLoadingAttendance && _attendance != null && !isCancelled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppConstants.surface),
            ),
            _buildAttendanceRow(),
          ],

          if (ltp.isNotEmpty) ...[
             const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppConstants.surface),
            ),
            _buildInfoRow(
              icon: Icons.category_outlined,
              title: 'Class Type',
              content: isLab ? 'Lab' : (ltp == 'T' || ltp.toLowerCase().contains('tutorial') ? 'Tutorial' : 'Theory'),
            ),
          ],

          if (formattedDay.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppConstants.surface),
            ),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              title: 'Today',
              content: formattedDay,
            ),
          ],

          const SizedBox(height: 24),

          // View Attendance Button
          if (StorageService.getUserMode() == 'student')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 2)),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.surface,
                foregroundColor: AppConstants.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppConstants.primary.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('View Full Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppConstants.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppConstants.getLabelSmall(color: AppConstants.textSecondary)),
              const SizedBox(height: 2),
              Text(
                content,
                style: AppConstants.getBodyMedium().copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRow() {
    final present = _attendance!.presentCount ?? 0;
    final total = _attendance!.totalCount ?? 0;
    final percentage = _attendance!.attendancePercentage;
    
    // Choose color based on percentage
    Color attColor = AppConstants.success;
    if (percentage < 75) {
      attColor = AppConstants.error;
    } else if (percentage < 80) {
      attColor = AppConstants.warning;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.surface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bar_chart, size: 20, color: AppConstants.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance', style: AppConstants.getLabelSmall(color: AppConstants.textSecondary)),
              const SizedBox(height: 2),
              if (total > 0)
                Text(
                  '$present / $total classes',
                  style: AppConstants.getBodyMedium(),
                )
              else
                Text('No classes conducted yet', style: AppConstants.getBodyMedium()),
              if (_lastSynced != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Last updated: ${_formatTimeAgo(_lastSynced!)}',
                    style: AppConstants.getLabelSmall(color: AppConstants.textSecondary.withOpacity(0.7)),
                  ),
                ),
            ],
          ),
        ),
        if (total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: attColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: attColor.withOpacity(0.3)),
            ),
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppConstants.getHeadline().copyWith(
                fontSize: 16,
                color: attColor,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  Color _getStatusColor(bool isCancelled) {
    if (isCancelled) return AppConstants.error;
    final s = widget.status.toLowerCase();
    if (s.contains('ongoing') || s.contains('now')) return AppConstants.success;
    if (s.contains('start') || s.contains('upcoming')) return AppConstants.primary;
    if (s.contains('completed')) return AppConstants.textSecondary;
    return AppConstants.primary;
  }
}
