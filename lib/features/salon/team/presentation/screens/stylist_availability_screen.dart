import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class StylistAvailabilityScreen extends StatefulWidget {
  final String stylistId;

  const StylistAvailabilityScreen({super.key, required this.stylistId});

  @override
  State<StylistAvailabilityScreen> createState() => _StylistAvailabilityScreenState();
}

class _StylistAvailabilityScreenState extends State<StylistAvailabilityScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Day schedule data
  final List<_DaySchedule> _schedule = [];

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
    _loadAvailability();
  }

  void _initializeSchedule() {
    for (int i = 0; i < 7; i++) {
      _schedule.add(_DaySchedule(
        dayOfWeek: i + 1,
        dayName: _dayNames[i],
        isOff: false,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 0),
        breaks: [],
      ));
    }
  }

  Future<void> _loadAvailability() async {
    try {
      setState(() => _isLoading = true);

      final res = await _api.get('${ApiConfig.stylists}/${widget.stylistId}/availability');
      final data = res['data'] as List<dynamic>? ?? [];

      for (final item in data) {
        final dayOfWeek = item['day_of_week'] as int? ?? 1;
        final index = dayOfWeek - 1;
        if (index >= 0 && index < 7) {
          _schedule[index].isOff = item['is_off'] ?? false;
          _schedule[index].startTime = _parseTime(item['start_time']);
          _schedule[index].endTime = _parseTime(item['end_time']);

          // Load breaks
          final breaks = item['breaks'] as List<dynamic>? ?? [];
          _schedule[index].breaks = breaks.map<_BreakSlot>((b) {
            return _BreakSlot(
              startTime: _parseTime(b['start_time']),
              endTime: _parseTime(b['end_time']),
            );
          }).toList();
        }
      }

      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({
    required int dayIndex,
    required bool isStart,
    int? breakIndex,
  }) async {
    final schedule = _schedule[dayIndex];
    TimeOfDay initialTime;

    if (breakIndex != null) {
      initialTime = isStart
          ? schedule.breaks[breakIndex].startTime
          : schedule.breaks[breakIndex].endTime;
    } else {
      initialTime = isStart ? schedule.startTime : schedule.endTime;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (breakIndex != null) {
          if (isStart) {
            schedule.breaks[breakIndex].startTime = picked;
          } else {
            schedule.breaks[breakIndex].endTime = picked;
          }
        } else {
          if (isStart) {
            schedule.startTime = picked;
          } else {
            schedule.endTime = picked;
          }
        }
      });
    }
  }

  void _addBreak(int dayIndex) {
    setState(() {
      _schedule[dayIndex].breaks.add(_BreakSlot(
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 0),
      ));
    });
  }

  void _removeBreak(int dayIndex, int breakIndex) {
    setState(() {
      _schedule[dayIndex].breaks.removeAt(breakIndex);
    });
  }

  Future<void> _save() async {
    try {
      setState(() => _isSaving = true);

      final availability = _schedule.map((day) {
        final data = <String, dynamic>{
          'day_of_week': day.dayOfWeek,
          'start_time': _formatTime(day.startTime),
          'end_time': _formatTime(day.endTime),
          'is_off': day.isOff,
        };

        if (day.breaks.isNotEmpty) {
          data['breaks'] = day.breaks.map((b) {
            return {
              'start_time': _formatTime(b.startTime),
              'end_time': _formatTime(b.endTime),
            };
          }).toList();
        }

        return data;
      }).toList();

      await _api.put(
        '${ApiConfig.stylists}/${widget.stylistId}/availability',
        body: {'availability': availability},
      );

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Availability updated successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Availability'),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading schedule...')
          : Column(
              children: [
                // Schedule list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      return _buildDayCard(index);
                    },
                  ),
                ),

                // Save button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: AppButton(
                      text: 'Save Availability',
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDayCard(int index) {
    final day = _schedule[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: day.isOff
            ? Border.all(color: AppColors.border)
            : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Day header with toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                // Day indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: day.isOff
                        ? AppColors.softSurface
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      day.dayName.substring(0, 3),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: day.isOff ? AppColors.textMuted : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.dayName,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: day.isOff ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        day.isOff
                            ? 'Day Off'
                            : '${_formatTimeDisplay(day.startTime)} - ${_formatTimeDisplay(day.endTime)}',
                        style: AppTextStyles.caption.copyWith(
                          color: day.isOff ? AppColors.textMuted : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: !day.isOff,
                  onChanged: (value) {
                    setState(() => day.isOff = !value);
                  },
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // Time pickers (shown when not off)
          if (!day.isOff) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Working hours
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Start Time',
                          time: day.startTime,
                          onTap: () => _pickTime(dayIndex: index, isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'End Time',
                          time: day.endTime,
                          onTap: () => _pickTime(dayIndex: index, isStart: false),
                        ),
                      ),
                    ],
                  ),

                  // Breaks section
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Breaks',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () => _addBreak(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Add Break',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (day.breaks.isEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.softSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'No breaks scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Break slots
                  ...List.generate(day.breaks.length, (breakIdx) {
                    final breakSlot = day.breaks[breakIdx];
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.coffee_outlined,
                            size: 18,
                            color: AppColors.accentDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                _buildBreakTimePicker(
                                  time: breakSlot.startTime,
                                  onTap: () => _pickTime(
                                    dayIndex: index,
                                    isStart: true,
                                    breakIndex: breakIdx,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'to',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                _buildBreakTimePicker(
                                  time: breakSlot.endTime,
                                  onTap: () => _pickTime(
                                    dayIndex: index,
                                    isStart: false,
                                    breakIndex: breakIdx,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeBreak(index, breakIdx),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _formatTimeDisplay(time),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakTimePicker({
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _formatTimeDisplay(time),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// Internal data models

class _DaySchedule {
  final int dayOfWeek;
  final String dayName;
  bool isOff;
  TimeOfDay startTime;
  TimeOfDay endTime;
  List<_BreakSlot> breaks;

  _DaySchedule({
    required this.dayOfWeek,
    required this.dayName,
    required this.isOff,
    required this.startTime,
    required this.endTime,
    required this.breaks,
  });
}

class _BreakSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;

  _BreakSlot({
    required this.startTime,
    required this.endTime,
  });
}
