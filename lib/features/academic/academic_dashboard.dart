import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/sraap/sraap_academic_service.dart';
import '../../core/sraap/models/sraap_academic_data.dart';
import 'academic_login_screen.dart';

class _AcaColors {
  static const primary = Color(0xFF003870);
  static const onSurface = Color(0xFF141b2b);
  static const onSurfaceVariant = Color(0xFF424751);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFe1e8fd);
  static const surfaceHighest = Color(0xFFdce2f7);
  static const secondary = Color(0xFF585f6c);
  static const primaryFixed = Color(0xFFd5e3ff);
  static const onPrimaryFixed = Color(0xFF001b3c);
  static const background = Color(0xFFf9f9ff);
  static const outline = Color(0xFF727782);
  static const error = Color(0xFFba1a1a);
}

class AcademicDashboard extends StatefulWidget {
  const AcademicDashboard({super.key});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard> {
  bool _isLoading = true;
  bool _isSyncing = false;
  SraapAcademicData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (!forceRefresh) _isLoading = true;
        _isSyncing = forceRefresh;
        _error = null;
      });
    }

    try {
      final data = await SraapAcademicService.instance.getAcademicData(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Session expired. Please reconnect.';
          _isLoading = false;
          _isSyncing = false;
        });
      }
    }
  }
  
  Future<void> _disconnect() async {
    await SraapAcademicService.instance.disconnect();
    if (mounted) {
      setState(() {
        _data = null;
        _error = null;
      });
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AcaColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: _AcaColors.primary,
          child: _isLoading && _data == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 48, color: _AcaColors.outline),
            const SizedBox(height: 16),
            Text(_error ?? 'Not connected to SRAAP.', style: const TextStyle(fontSize: 16, color: _AcaColors.onSurfaceVariant)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _AcaColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.link),
              label: const Text('Connect SRAAP', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AcademicLoginScreen()),
                ).then((_) => _loadData());
              },
            ),
          ],
        ),
      );
    }

    final data = _data!;
    
    // Fallbacks
    final attendance = data.overallAttendance ?? 0.0;
    final cgpa = data.cgpa ?? '0.0';
    final mentorName = data.mentor?.name ?? 'Not Assigned';
    final mentorDept = data.mentor?.department ?? 'Department';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Overall Attendance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _AcaColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OVERALL ATTENDANCE',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _AcaColors.onSurfaceVariant, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${attendance.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _AcaColors.primary, letterSpacing: -0.5),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '/ 100%',
                            style: TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _AcaColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(attendance >= 75 ? Icons.verified : Icons.warning_amber_rounded, size: 16, color: attendance >= 75 ? _AcaColors.primary : _AcaColors.error),
                        const SizedBox(width: 4),
                        Text(
                          attendance >= 75 ? 'Good Standing' : 'Low Attendance',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: attendance >= 75 ? _AcaColors.primary : _AcaColors.error),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: attendance / 100,
                  backgroundColor: _AcaColors.surfaceHighest,
                  color: attendance >= 75 ? _AcaColors.primary : _AcaColors.error,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 14, color: _AcaColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Updated ${_formatTimeAgo(data.lastSynced)}', style: const TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Text('Min 75% required', style: TextStyle(fontSize: 12, color: _AcaColors.primary, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),
        ),
        
        const SizedBox(height: 12),

        // 2. Subject-wise Attendance
        if (data.subjects.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _AcaColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 1))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.subject, size: 20, color: _AcaColors.primary),
                        SizedBox(width: 8),
                        Text('Subject Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _AcaColors.onSurface)),
                      ],
                    ),
                    Text('${data.subjects.length} Courses Enrolled', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _AcaColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.subjects.length,
                  separatorBuilder: (_, __) => Container(height: 1, color: _AcaColors.surfaceHighest.withOpacity(0.7), margin: const EdgeInsets.symmetric(vertical: 4)),
                  itemBuilder: (context, index) {
                    final sub = data.subjects[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // Optional: Show detail
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sub.subjectName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _AcaColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('${sub.presentCount ?? 0} / ${sub.totalCount ?? 0} Classes', style: const TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Text('${sub.attendancePercentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub.attendancePercentage >= 75 ? _AcaColors.primary : _AcaColors.onSurface)),
                                    const SizedBox(width: 4),
                                    Icon(
                                      sub.attendancePercentage >= 75 ? Icons.trending_up : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: sub.attendancePercentage >= 75 ? _AcaColors.primary : _AcaColors.error,
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: sub.attendancePercentage / 100,
                                backgroundColor: _AcaColors.surfaceHighest,
                                color: sub.attendancePercentage >= 75 ? _AcaColors.primary : _AcaColors.error,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 3 & 4. CGPA and Mentor Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 140, // Fixed height to match
                decoration: BoxDecoration(
                  color: _AcaColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OVERALL CGPA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _AcaColors.onSurfaceVariant, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(cgpa, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _AcaColors.primary, letterSpacing: -0.5)),
                            const SizedBox(width: 4),
                            const Text('/ 10', style: TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Icon(Icons.grade, size: 16, color: _AcaColors.primary),
                        SizedBox(width: 4),
                        Text('Cumulative', style: TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 140,
                decoration: BoxDecoration(
                  color: _AcaColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('FACULTY MENTOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _AcaColors.onSurfaceVariant, letterSpacing: 0.5)),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(color: _AcaColors.primaryFixed, shape: BoxShape.circle),
                              child: const Icon(Icons.person, size: 18, color: _AcaColors.onPrimaryFixed),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(mentorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AcaColors.onSurface, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(mentorDept, style: const TextStyle(fontSize: 12, color: _AcaColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    /*Row(
                      children: [
                        const Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _AcaColors.primary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 14, color: _AcaColors.primary),
                      ],
                    )*/
                  ],
                ),
              ),
            ),
          ],
        ),

        // SRAAP Academic Account card removed per user request
      ],
    );
  }
}
