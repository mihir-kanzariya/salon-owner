import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/language_toggle.dart';
import '../../../../../services/api_service.dart';

/// Visual timeline view showing all stylists' schedules side-by-side for a
/// single day. Bookings appear as colored blocks, breaks as gray stripes,
/// smart slots as green dashed outlines.
class BookingCalendarScreen extends StatefulWidget {
  final String salonId;
  const BookingCalendarScreen({super.key, required this.salonId});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final ApiService _api = ApiService();

  // Timeline constants
  static const double _pixelsPerMinute = 2.0;
  static const int _dayStartHour = 9;
  static const int _dayEndHour = 18;
  static const int _dayStartMinutes = _dayStartHour * 60;
  static const int _dayEndMinutes = _dayEndHour * 60;
  static const double _timeColumnWidth = 60.0;
  static const double _stylistColumnWidth = 150.0;

  // State
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  late List<DateTime> _dates;
  List<Map<String, dynamic>> _stylists = [];
  List<Map<String, dynamic>> _bookings = [];
  // memberId -> list of break blocks
  Map<String, List<Map<String, dynamic>>> _breaks = {};
  // Smart slot discount info from salon booking_settings
  double _smartSlotDiscount = 10;
  String _smartSlotDiscountType = 'percentage';

  @override
  void initState() {
    super.initState();
    _dates = List.generate(15, (i) => DateTime.now().add(Duration(days: i)));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Fetch stylists, bookings, and salon data in parallel
      final results = await Future.wait([
        _api.get('${ApiConfig.salonDetail}/${widget.salonId}/members'),
        _api.get(
          '${ApiConfig.bookings}/salon/${widget.salonId}',
          queryParams: {'date': dateStr},
        ),
        _api.get('${ApiConfig.salonDetail}/${widget.salonId}'),
      ]);

      // Parse smart slot discount settings
      final salonData = results[2]['data'] as Map<String, dynamic>? ?? {};
      final bookingSettings = salonData['booking_settings'] as Map<String, dynamic>? ?? {};
      _smartSlotDiscount = (bookingSettings['smart_slot_discount'] as num?)?.toDouble() ?? 10;
      _smartSlotDiscountType = bookingSettings['smart_slot_discount_type']?.toString() ?? 'percentage';

      final membersData = results[0]['data'];
      _stylists = membersData is List
          ? membersData.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      final bookingsData = results[1]['data'];
      _bookings = bookingsData is List
          ? bookingsData.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      // Fetch availability / breaks per stylist
      _breaks = {};
      final breakFutures = <Future<void>>[];
      for (final stylist in _stylists) {
        final memberId = stylist['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;
        breakFutures.add(
          _api
              .get('${ApiConfig.stylists}/$memberId/availability')
              .then((res) {
            final data = res['data'];
            if (data is Map<String, dynamic>) {
              final breakList = data['breaks'];
              if (breakList is List) {
                _breaks[memberId] = breakList.cast<Map<String, dynamic>>();
              }
            }
          }).catchError((_) {
            // Availability might not exist for every stylist; ignore.
          }),
        );
      }
      await Future.wait(breakFutures);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e);
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  /// Parse an ISO or HH:mm time string into total minutes from midnight.
  int _parseMinutes(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    // Try ISO date-time first
    final dt = DateTime.tryParse(raw);
    if (dt != null) return dt.hour * 60 + dt.minute;
    // Fallback: "HH:mm"
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    }
    return 0;
  }

  String _formatTime(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _bookingsForStylist(String memberId) {
    return _bookings.where((b) {
      final bMemberId = b['stylist_member_id']?.toString()
          ?? b['member_id']?.toString()
          ?? b['memberId']?.toString()
          ?? '';
      return bMemberId == memberId;
    }).toList();
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.tr('schedule_calendar')),
        actions: const [LanguageToggle(), SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _stylists.isEmpty
                    ? Center(
                        child: Text(
                          l.tr('no_stylists_today'),
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : _buildTimeline(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showQuickActions,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Date picker strip
  // ---------------------------------------------------------------

  Widget _buildDatePicker() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(_selectedDate);
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadData();
            },
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primary : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textMuted,
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

  // ---------------------------------------------------------------
  // Timeline grid
  // ---------------------------------------------------------------

  Widget _buildTimeline() {
    final totalMinutes = _dayEndMinutes - _dayStartMinutes;
    final totalHeight = totalMinutes * _pixelsPerMinute;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _timeColumnWidth +
              _stylistColumnWidth * _stylists.length,
          child: Column(
            children: [
              // Stylist headers
              _buildStylistHeaders(),
              const Divider(height: 1, color: AppColors.border),
              // Timeline body
              SizedBox(
                height: totalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time labels column
                    _buildTimeLabels(totalHeight),
                    // One column per stylist
                    ..._stylists.map(_buildStylistColumn),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStylistHeaders() {
    return Row(
      children: [
        const SizedBox(width: _timeColumnWidth),
        ..._stylists.map((s) {
          final name = s['user']?['name']?.toString() ??
              s['name']?.toString() ??
              'Stylist';
          return SizedBox(
            width: _stylistColumnWidth,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeLabels(double totalHeight) {
    // Generate labels every 30 minutes
    final labels = <Widget>[];
    for (int m = _dayStartMinutes; m <= _dayEndMinutes; m += 30) {
      labels.add(
        Positioned(
          top: (m - _dayStartMinutes) * _pixelsPerMinute,
          left: 0,
          width: _timeColumnWidth,
          child: Text(
            _formatTime(m),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      );
    }
    return SizedBox(
      width: _timeColumnWidth,
      height: totalHeight,
      child: Stack(children: labels),
    );
  }

  Widget _buildStylistColumn(Map<String, dynamic> stylist) {
    final memberId = stylist['id']?.toString() ?? '';
    final stylistBookings = _bookingsForStylist(memberId);
    final stylistBreaks = _breaks[memberId] ?? [];
    final totalMinutes = _dayEndMinutes - _dayStartMinutes;
    final totalHeight = totalMinutes * _pixelsPerMinute;

    final children = <Widget>[];

    // Half-hour grid lines
    for (int m = _dayStartMinutes; m <= _dayEndMinutes; m += 30) {
      children.add(
        Positioned(
          top: (m - _dayStartMinutes) * _pixelsPerMinute,
          left: 0,
          right: 0,
          child: const Divider(height: 0.5, color: AppColors.border),
        ),
      );
    }

    // Break blocks (gray striped)
    for (final brk in stylistBreaks) {
      final startMin =
          _parseMinutes(brk['start_time']?.toString() ?? brk['startTime']?.toString());
      final endMin =
          _parseMinutes(brk['end_time']?.toString() ?? brk['endTime']?.toString());
      if (endMin <= startMin) continue;
      final top =
          ((startMin - _dayStartMinutes) * _pixelsPerMinute).clamp(0.0, totalHeight);
      final height =
          ((endMin - startMin) * _pixelsPerMinute).clamp(0.0, totalHeight - top);
      children.add(
        Positioned(
          top: top,
          left: 4,
          right: 4,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: CustomPaint(
              painter: _StripePainter(),
              child: Center(
                child: Text(
                  'Break',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Booking blocks
    for (final booking in stylistBookings) {
      final startMin = _parseMinutes(
          booking['start_time']?.toString() ?? booking['startTime']?.toString());
      final endMin = _parseMinutes(
          booking['end_time']?.toString() ?? booking['endTime']?.toString());
      if (endMin <= startMin) continue;

      final isSmart = booking['is_smart_slot'] == true ||
          booking['isSmartSlot'] == true;

      final top =
          ((startMin - _dayStartMinutes) * _pixelsPerMinute).clamp(0.0, totalHeight);
      final height =
          ((endMin - startMin) * _pixelsPerMinute).clamp(0.0, totalHeight - top);

      final customerName = booking['customer']?['name']?.toString() ??
          booking['customer_name']?.toString() ??
          booking['customerName']?.toString() ??
          '';
      final serviceName = booking['service']?['name']?.toString() ??
          booking['service_name']?.toString() ??
          booking['serviceName']?.toString() ??
          '';
      final timeRange =
          '${_formatTime(startMin)} - ${_formatTime(endMin)}';

      final blockColor =
          isSmart ? AppColors.success : AppColors.primary;

      children.add(
        Positioned(
          top: top,
          left: 4,
          right: 4,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              color: blockColor.withValues(alpha: 0.15),
              border: Border.all(color: blockColor),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSmart)
                  Text(
                    _smartSlotDiscountType == 'percentage'
                        ? '\u2605 Smart -${_smartSlotDiscount.toInt()}%'
                        : '\u2605 Smart -\u20B9${_smartSlotDiscount.toInt()}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  serviceName,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: _stylistColumnWidth,
      height: totalHeight,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Stack(children: children),
    );
  }

  // ---------------------------------------------------------------
  // FAB quick actions
  // ---------------------------------------------------------------

  void _showQuickActions() {
    final l = context.read<LocaleProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add,
                    color: AppColors.primary, size: 20),
              ),
              title: Text(l.tr('add_walk_in'),
                  style: AppTextStyles.labelLarge),
              subtitle: Text(l.tr('walk_in'),
                  style: AppTextStyles.caption),
              onTap: () {
                Navigator.pop(ctx);
                _createWalkIn();
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block,
                    color: AppColors.primary, size: 20),
              ),
              title: Text(l.tr('block_slots'),
                  style: AppTextStyles.labelLarge),
              subtitle: Text(l.tr('block_slots_desc'),
                  style: AppTextStyles.caption),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/salon/slot-blocking',
                  arguments: widget.salonId,
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _createWalkIn() {
    Navigator.pushNamed(
      context,
      '/salon/walk-in',
      arguments: widget.salonId,
    ).then((result) {
      if (result == true) _loadData();
    });
  }
}

/// Custom painter that draws diagonal stripes for break blocks.
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    const gap = 8.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
