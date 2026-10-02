import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/room_block_parser.dart';
import 'ad_banner.dart';
import '../../core/analytics_service.dart';

class FreeRoomsScreen extends StatefulWidget {
  const FreeRoomsScreen({super.key});

  @override
  State<FreeRoomsScreen> createState() => _FreeRoomsScreenState();
}

class _FreeRoomsScreenState extends State<FreeRoomsScreen> {
  String? _selectedDay;
  String? _selectedTime;
  
  String? _selectedBlock;
  Map<String, List<Map<String, dynamic>>> _roomsByBlock = {};
  List<String> _availableBlocks = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _rooms = [];
  bool _hasSearched = false;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final List<String> _times = [
    '08:30', '09:30', '10:30', '11:30', '12:30', '13:30', '14:30', '15:30', '16:30'
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logFreeClassroomsOpened();

    // Default to current day if weekday
    final now = DateTime.now();
    if (now.weekday <= 5) {
      _selectedDay = _days[now.weekday - 1];
    } else {
      _selectedDay = _days[0]; // fallback to Monday
    }
    
    // Default to nearest time block
    final hour = now.hour;
    if (hour >= 8 && hour <= 16) {
      _selectedTime = '${hour.toString().padLeft(2, '0')}:30';
    } else {
      _selectedTime = _times[1]; // fallback to 09:30
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  Future<void> _search() async {
    if (_selectedDay == null || _selectedTime == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      _availableBlocks = [];
      _roomsByBlock = {};
      _rooms = [];
    });

    try {
      final rooms = await ApiService.fetchFreeRooms(_selectedDay!, _selectedTime!);
      
      // Categorize into blocks using deterministic parser
      final Map<String, List<Map<String, dynamic>>> blocksMap = {};
      for (final room in rooms) {
        final name = room['name'] as String;
        final block = RoomBlockParser.extractBlock(name);
        
        blocksMap.putIfAbsent(block, () => []).add(room);
      }
      
      // Naturally sort blocks: Block 1, Block 2, ..., Block 10, Block 11, Other
      final blocks = blocksMap.keys.toList()..sort(RoomBlockParser.compareBlocks);
      
      // Determine priority block safely without crashing
      String? priorityBlock;
      try {
        final userMode = StorageService.getUserMode();
        final timetable = userMode == 'faculty'
            ? StorageService.getFacultyTimetableCache()
            : StorageService.getTimetableCache();
        
        final now = DateTime.now();
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final todayStr = dayNames[now.weekday - 1];
        
        if (todayStr == _selectedDay && timetable.isNotEmpty) {
          final dayData = timetable.firstWhere(
            (e) => e['day'] == todayStr,
            orElse: () => null,
          );
          
          if (dayData != null) {
            final classes = dayData['classes'] as List<dynamic>? ?? [];
            final currentMinutes = now.hour * 60 + now.minute;
            
            Map<String, dynamic>? runningClass;
            Map<String, dynamic>? lastCompletedClass;
            Map<String, dynamic>? nearestUpcomingClass;
            int minUpcomingDiff = 9999;
            int minCompletedDiff = 9999;
            
            for (final cls in classes) {
              final startStr = cls['start_time'] as String?;
              final endStr = cls['end_time'] as String? ?? startStr;
              if (startStr == null) continue;
              
              final startParts = startStr.split(':').map((s) => int.tryParse(s) ?? 0).toList();
              if (startParts.length < 2) continue;
              final startMins = startParts[0] * 60 + startParts[1];
              
              final endParts = (endStr ?? startStr).split(':').map((s) => int.tryParse(s) ?? 0).toList();
              final endMins = endParts.length >= 2 ? endParts[0] * 60 + endParts[1] : startMins + 60;
              
              if (currentMinutes >= startMins && currentMinutes <= endMins) {
                runningClass = Map<String, dynamic>.from(cls);
                break;
              } else if (currentMinutes > endMins) {
                final diff = currentMinutes - endMins;
                if (diff < minCompletedDiff) {
                  minCompletedDiff = diff;
                  lastCompletedClass = Map<String, dynamic>.from(cls);
                }
              } else if (currentMinutes < startMins) {
                final diff = startMins - currentMinutes;
                if (diff < minUpcomingDiff) {
                  minUpcomingDiff = diff;
                  nearestUpcomingClass = Map<String, dynamic>.from(cls);
                }
              }
            }
            
            final targetClass = runningClass ?? lastCompletedClass ?? nearestUpcomingClass;
            if (targetClass != null) {
              final roomStr = targetClass['room'] as String? ?? '';
              priorityBlock = RoomBlockParser.extractBlock(roomStr);
            }
          }
        }
      } catch (err) {
        debugPrint('[FreeRooms] Safe priority block determination skipped: $err');
      }
      
      String? initialBlock = blocks.isNotEmpty ? blocks.first : null;
      if (priorityBlock != null && blocks.contains(priorityBlock)) {
        initialBlock = priorityBlock;
        blocks.remove(priorityBlock);
        blocks.insert(0, priorityBlock);
      }
      
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _roomsByBlock = blocksMap;
          _availableBlocks = blocks;
          _selectedBlock = initialBlock;
          _isLoading = false;
        });
      }
    } on FreeRoomsException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Couldn't load free classrooms. Check your connection and try again.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Free Classrooms'),
        elevation: 0,
        backgroundColor: AppConstants.surface,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Search Form
            Container(
              color: AppConstants.surface,
              padding: const EdgeInsets.all(AppConstants.paddingContainer),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Day',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedDay,
                          items: _days.map((day) => DropdownMenuItem(
                            value: day,
                            child: Text(day),
                          )).toList(),
                          onChanged: _isLoading ? null : (val) => setState(() => _selectedDay = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: _selectedTime,
                          items: _times.map((time) => DropdownMenuItem(
                            value: time,
                            child: Text(time),
                          )).toList(),
                          onChanged: _isLoading ? null : (val) => setState(() => _selectedTime = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedDay != null && _selectedTime != null && !_isLoading) 
                          ? _search 
                          : null,
                      icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.search),
                      label: Text(_isLoading ? 'Searching...' : 'Find Free Rooms'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Area (Loading, Error with Retry, Empty State, or Results)
            Expanded(
              child: _buildContent(),
            ),
            
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Searching available classrooms...',
              style: AppConstants.getBodyMedium(color: AppConstants.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingContainer * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: AppConstants.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppConstants.getHeadline().copyWith(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasSearched && _rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingContainer),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                size: 56,
                color: AppConstants.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No free rooms found for this slot.',
                style: AppConstants.getBodyLarge(color: AppConstants.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Horizontal Block Selector Chips
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingContainer),
            itemCount: _availableBlocks.length,
            itemBuilder: (context, index) {
              final block = _availableBlocks[index];
              final isSelected = _selectedBlock == block;
              final count = _roomsByBlock[block]?.length ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$block ($count)'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedBlock = block);
                    }
                  },
                  selectedColor: AppConstants.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppConstants.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),

        // Room List for Selected Block
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingContainer),
            itemCount: _selectedBlock != null ? _roomsByBlock[_selectedBlock!]?.length ?? 0 : 0,
            itemBuilder: (context, index) {
              final room = _roomsByBlock[_selectedBlock!]![index];
              final rawName = room['name'] as String;
              final cleanName = RoomBlockParser.cleanRoomName(rawName);
              final type = room['type'] as String;
              final isLab = type.toLowerCase().contains('lab');
              final isComputing = type.toLowerCase().contains('computing');
              
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppConstants.outline),
                  borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLab 
                        ? AppConstants.warningContainer 
                        : isComputing
                            ? AppConstants.infoContainer
                            : AppConstants.primaryContainer,
                    child: Icon(
                      isLab 
                          ? Icons.biotech 
                          : isComputing 
                              ? Icons.computer 
                              : Icons.meeting_room,
                      color: isLab 
                          ? AppConstants.warning 
                          : isComputing
                              ? AppConstants.info
                              : AppConstants.primary,
                    ),
                  ),
                  title: Text(
                    cleanName,
                    style: AppConstants.getHeadline().copyWith(fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppConstants.outline),
                          ),
                          child: Text(
                            _selectedBlock ?? 'Room',
                            style: AppConstants.getLabelSmall().copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type,
                            style: AppConstants.getBodyMedium(color: AppConstants.textSecondary)
                                .copyWith(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
