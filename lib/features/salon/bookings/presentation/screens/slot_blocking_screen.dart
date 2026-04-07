import '../../../../../config/api_config.dart';
import '../../../../../core/i18n/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../services/api_service.dart';
import '../../../providers/salon_provider.dart';

class SlotBlockingScreen extends StatefulWidget {
  final String salonId;

  const SlotBlockingScreen({super.key, required this.salonId});

  @override
  State<SlotBlockingScreen> createState() => _SlotBlockingScreenState();
}

class _SlotBlockingScreenState extends State<SlotBlockingScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Selected date
  DateTime _selectedDate = DateTime.now();
  final List<DateTime> _weekDates = [];

  // Existing blocks for selected date
  List<Map<String, dynamic>> _blocks = [];

  // New block form
  TimeOfDay _blockStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _blockEnd = const TimeOfDay(hour: 14, minute: 0);
  final TextEditingController _reasonController = TextEditingController();
  bool _isRecurring = false;

  String? _memberId;

  @override
  void initState() {
    super.initState();
    _generateWeekDates();
    final sp = context.read<SalonProvider>();
    _memberId = sp.memberId;
    _loadBlocks();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _generateWeekDates() {
    final now = DateTime.now();
    _weekDates.clear();
    for (int i = 0; i < 14; i++) {
      _weekDates.add(DateTime(now.year, now.month, now.day).add(Duration(days: i)));
    }
  }

  Future<void> _loadBlocks() async {
    if (_memberId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final res = await _api.get('${ApiConfig.stylists}/$_memberId/availability');
      final data = res['data'] as List<dynamic>? ?? [];

      // Find breaks for the selected day of week
      final dayOfWeek = _selectedDate.weekday; // 1=Monday, 7=Sunday
      final blocks = <Map<String, dynamic>>[];

      for (final item in data) {
        final itemDay = item['day_of_week'] as int? ?? 0;
        if (itemDay == dayOfWeek) {
          final breaks = item['breaks'] as List<dynamic>? ?? [];
          for (final b in breaks) {
            blocks.add({
              'id': b['id']?.toString(),
              'start_time': b['start_time']?.toString() ?? '',
              'end_time': b['end_time']?.toString() ?? '',
              'reason': b['reason']?.toString() ?? '',
              'is_recurring': b['is_recurring'] ?? true,
            });
          }
        }
      }

      _blocks = blocks;
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
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

  String _formatTimeStrDisplay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      return _formatTimeDisplay(time);
    } catch (_) {
      return timeStr;
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _blockStart : _blockEnd,
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
        if (isStart) {
          _blockStart = picked;
        } else {
          _blockEnd = picked;
        }
      });
    }
  }

  Future<void> _addBlock() async {
    if (_memberId == null) return;

    try {
      setState(() => _isSaving = true);

      await _api.post(
        '${ApiConfig.stylists}/$_memberId/breaks',
        body: {
          'start_time': _formatTime(_blockStart),
          'end_time': _formatTime(_blockEnd),
          'reason': _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
          'day_of_week': _selectedDate.weekday,
          'is_recurring': _isRecurring,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        },
      );

      _reasonController.clear();
      setState(() => _isSaving = false);

      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Text(l.tr('block_added')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadBlocks();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeBlock(String? breakId) async {
    if (breakId == null) return;

    try {
      await _api.delete('${ApiConfig.stylists}/breaks/$breakId');

      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Text(l.tr('block_removed')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadBlocks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.tr('block_slots')),
      ),
      body: Column(
        children: [
          // Horizontal date picker
          _buildDatePicker(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadBlocks,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current blocks
                          _buildCurrentBlocks(l),
                          const SizedBox(height: 24),

                          // Add block section
                          _buildAddBlockSection(l),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadBlocks();
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.softSurface,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.white : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.white.withValues(alpha: 0.8) : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentBlocks(LocaleProvider l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l.tr('block_slots')} - ${DateFormat('d MMM yyyy').format(_selectedDate)}',
          style: AppTextStyles.h4,
        ),
        const SizedBox(height: 12),
        if (_blocks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text(l.tr('no_blocks'), style: AppTextStyles.bodyMedium),
              ],
            ),
          )
        else
          ..._blocks.map((block) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.block, color: AppColors.accentDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatTimeStrDisplay(block['start_time'])} - ${_formatTimeStrDisplay(block['end_time'])}',
                          style: AppTextStyles.labelLarge,
                        ),
                        if ((block['reason'] as String).isNotEmpty)
                          Text(block['reason'] as String, style: AppTextStyles.caption),
                        if (block['is_recurring'] == true)
                          Text(
                            l.tr('recurring'),
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    onPressed: () => _removeBlock(block['id'] as String?),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAddBlockSection(LocaleProvider l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.tr('add_block'), style: AppTextStyles.h4),
          const SizedBox(height: 16),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  label: l.tr('block_start'),
                  time: _blockStart,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePicker(
                  label: l.tr('block_end'),
                  time: _blockEnd,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reason field
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: l.tr('block_reason'),
              hintText: 'Lunch break, Personal, Maintenance...',
              hintStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Block type toggle
          Row(
            children: [
              Expanded(
                child: _BlockTypeChip(
                  label: l.tr('one_time'),
                  isSelected: !_isRecurring,
                  onTap: () => setState(() => _isRecurring = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BlockTypeChip(
                  label: l.tr('recurring'),
                  isSelected: _isRecurring,
                  onTap: () => setState(() => _isRecurring = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Block button
          AppButton(
            text: l.tr('add_block'),
            icon: Icons.block,
            onPressed: _isSaving ? null : _addBlock,
            isLoading: _isSaving,
          ),
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
}

class _BlockTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BlockTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.softSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
