import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class _DayHours {
  final String day;
  TimeOfDay openTime;
  TimeOfDay closeTime;
  bool isClosed;

  _DayHours({
    required this.day,
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'open': _formatTime(openTime),
      'close': _formatTime(closeTime),
      'is_closed': isClosed,
    };
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  factory _DayHours.fromJson(String day, Map<String, dynamic>? json) {
    if (json == null) {
      return _DayHours(
        day: day,
        openTime: const TimeOfDay(hour: 9, minute: 0),
        closeTime: const TimeOfDay(hour: 20, minute: 0),
        isClosed: false,
      );
    }
    return _DayHours(
      day: day,
      openTime: _parseTime(json['open'] ?? '09:00'),
      closeTime: _parseTime(json['close'] ?? '20:00'),
      isClosed: json['is_closed'] ?? false,
    );
  }
}

class OperatingHoursScreen extends StatefulWidget {
  final String salonId;

  const OperatingHoursScreen({super.key, required this.salonId});

  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final Map<String, String> _dayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  final Map<String, IconData> _dayIcons = {
    'monday': Icons.looks_one_outlined,
    'tuesday': Icons.looks_two_outlined,
    'wednesday': Icons.looks_3_outlined,
    'thursday': Icons.looks_4_outlined,
    'friday': Icons.looks_5_outlined,
    'saturday': Icons.looks_6_outlined,
    'sunday': Icons.weekend_outlined,
  };

  late List<_DayHours> _hours;

  @override
  void initState() {
    super.initState();
    _hours = _dayNames
        .map((day) => _DayHours(
              day: day,
              openTime: const TimeOfDay(hour: 9, minute: 0),
              closeTime: const TimeOfDay(hour: 20, minute: 0),
            ))
        .toList();
    _loadHours();
  }

  Future<void> _loadHours() async {
    try {
      setState(() => _isLoading = true);
      final res = await _api.get('${ApiConfig.salonDetail}/${widget.salonId}');
      final salon = res['data'] ?? {};
      final operatingHours = salon['operating_hours'];

      if (operatingHours != null && operatingHours is Map<String, dynamic>) {
        _hours = _dayNames
            .map((day) => _DayHours.fromJson(
                  day,
                  operatingHours[day] as Map<String, dynamic>?,
                ))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to load operating hours');
      }
    }
  }

  Future<void> _saveHours() async {
    try {
      setState(() => _isSaving = true);

      final operatingHours = <String, dynamic>{};
      for (final dayHour in _hours) {
        operatingHours[dayHour.day] = dayHour.toJson();
      }

      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {'operating_hours': operatingHours},
      );

      setState(() => _isSaving = false);

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Operating hours saved');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        SnackbarUtils.showError(
          context,
          e.toString().contains('ApiException')
              ? e.toString()
              : 'Failed to save operating hours',
        );
      }
    }
  }

  Future<void> _pickTime({
    required int dayIndex,
    required bool isOpenTime,
  }) async {
    final dayHour = _hours[dayIndex];
    final initialTime = isOpenTime ? dayHour.openTime : dayHour.closeTime;

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
        if (isOpenTime) {
          _hours[dayIndex].openTime = picked;
        } else {
          _hours[dayIndex].closeTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Operating Hours'),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading hours...')
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _hours.length,
                    itemBuilder: (context, index) {
                      return _buildDayCard(index);
                    },
                  ),
                ),
                // Save button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  child: AppButton(
                    text: 'Save Hours',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveHours,
                    icon: Icons.save_outlined,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDayCard(int index) {
    final dayHour = _hours[index];
    final label = _dayLabels[dayHour.day] ?? dayHour.day;
    final icon = _dayIcons[dayHour.day] ?? Icons.calendar_today;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dayHour.isClosed
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Day header row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: dayHour.isClosed
                        ? AppColors.softSurface
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: dayHour.isClosed
                        ? AppColors.textMuted
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: dayHour.isClosed
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayHour.isClosed
                            ? 'Closed'
                            : '${_formatTimeOfDay(dayHour.openTime)} - ${_formatTimeOfDay(dayHour.closeTime)}',
                        style: AppTextStyles.caption.copyWith(
                          color: dayHour.isClosed
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Open/Closed toggle
                Switch(
                  value: !dayHour.isClosed,
                  onChanged: (value) {
                    setState(() {
                      _hours[index].isClosed = !value;
                    });
                  },
                  activeThumbColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.border,
                ),
              ],
            ),
            // Time pickers (only when open)
            if (!dayHour.isClosed) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      label: 'Opens at',
                      time: dayHour.openTime,
                      onTap: () =>
                          _pickTime(dayIndex: index, isOpenTime: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimePicker(
                      label: 'Closes at',
                      time: dayHour.closeTime,
                      onTap: () =>
                          _pickTime(dayIndex: index, isOpenTime: false),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimeOfDay(time),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
