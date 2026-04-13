import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/utils/time_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../providers/salon_provider.dart';

class SalonBookingsScreen extends StatefulWidget {
  const SalonBookingsScreen({super.key});

  @override
  State<SalonBookingsScreen> createState() => _SalonBookingsScreenState();
}

class _SalonBookingsScreenState extends State<SalonBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  String? _salonId;
  List<dynamic> _todayBookings = [];
  List<dynamic> _upcomingBookings = [];
  List<dynamic> _pastBookings = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Pagination state for past bookings
  int _pastPage = 1;
  bool _pastHasMore = true;
  bool _pastLoadingMore = false;
  static const int _pastLimit = 15;
  final ScrollController _pastScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pastScrollController.addListener(_onPastScroll);
    _loadData();
  }

  @override
  void dispose() {
    _pastScrollController.removeListener(_onPastScroll);
    _pastScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onPastScroll() {
    if (_pastScrollController.position.pixels >=
        _pastScrollController.position.maxScrollExtent - 200) {
      _loadMorePast();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() { _isLoading = true; _hasError = false; });

      final sp = context.read<SalonProvider>();
      _salonId = sp.salonId;

      if (_salonId != null) {
        final today = DateTime.now().toIso8601String().split('T')[0];

        final stylistFilter = <String, dynamic>{};
        if (sp.isStylist && sp.memberId != null) {
          stylistFilter['stylist_member_id'] = sp.memberId!;
        }

        final results = await Future.wait([
          _api.get('${ApiConfig.bookings}/salon/$_salonId',
              queryParams: {'date': today, ...stylistFilter}),
          _api.get('${ApiConfig.bookings}/salon/$_salonId',
              queryParams: {'filter': 'upcoming', ...stylistFilter}),
          _api.get('${ApiConfig.bookings}/salon/$_salonId',
              queryParams: {
                'filter': 'past',
                'page': '1',
                'limit': '$_pastLimit',
                ...stylistFilter,
              }),
        ]);

        _todayBookings = results[0]['data'] ?? [];
        _upcomingBookings = results[1]['data'] ?? [];

        final pastRes = results[2];
        _pastBookings = pastRes['data'] ?? [];
        final pastMeta = pastRes['meta'] as Map<String, dynamic>? ?? {};
        _pastPage = 1;
        _pastHasMore = _pastPage < (pastMeta['totalPages'] ?? 1);
      }

      setState(() => _isLoading = false);
    } catch (_) {
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _loadMorePast() async {
    if (_pastLoadingMore || !_pastHasMore || _salonId == null) return;

    setState(() => _pastLoadingMore = true);

    try {
      final sp = context.read<SalonProvider>();
      final stylistFilter = <String, dynamic>{};
      if (sp.isStylist && sp.memberId != null) {
        stylistFilter['stylist_member_id'] = sp.memberId!;
      }

      final nextPage = _pastPage + 1;
      final res = await _api.get(
        '${ApiConfig.bookings}/salon/$_salonId',
        queryParams: {
          'filter': 'past',
          'page': '$nextPage',
          'limit': '$_pastLimit',
          ...stylistFilter,
        },
      );

      final newItems = res['data'] as List<dynamic>? ?? [];
      final meta = res['meta'] as Map<String, dynamic>? ?? {};

      setState(() {
        _pastBookings.addAll(newItems);
        _pastPage = nextPage;
        _pastHasMore = _pastPage < (meta['totalPages'] ?? 1);
        _pastLoadingMore = false;
      });
    } catch (_) {
      setState(() => _pastLoadingMore = false);
    }
  }

  Future<void> _confirmCollectPayment(String bookingId, String customerName, dynamic totalAmount) async {
    final amount = totalAmount is num ? totalAmount.toDouble() : double.tryParse(totalAmount.toString()) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tr('invalid_amount')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    // Get commission from salon data (falls back to platform default 10%)
    final salonData = context.read<SalonProvider>().salonData;
    final commissionPercent = double.tryParse(salonData?['commission_override']?.toString() ?? '') ?? 10.0;
    final commissionAmount = (amount * commissionPercent) / 100;
    final netAmount = amount - commissionAmount;

    final l = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.tr('collect_payment'), style: AppTextStyles.h4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l.tr('collect')} \u20B9${amount.toStringAsFixed(0)} from $customerName?',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildBreakdownRow(l.tr('total_amount'), '\u20B9${amount.toStringAsFixed(0)}', AppColors.textPrimary),
                  const Divider(height: 16, color: AppColors.border),
                  _buildBreakdownRow(l.tr('platform_commission'), '-\u20B9${commissionAmount.toStringAsFixed(0)}', AppColors.error),
                  const Divider(height: 16, color: AppColors.border),
                  _buildBreakdownRow(l.tr('your_earnings'), '\u20B9${netAmount.toStringAsFixed(0)}', AppColors.success),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.tr('cancel'), style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(l.tr('collect'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _collectPayment(bookingId);
    }
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(value, style: AppTextStyles.labelLarge.copyWith(color: valueColor, fontSize: 13)),
      ],
    );
  }

  Future<void> _collectPayment(String bookingId) async {
    try {
      await _api.post('${ApiConfig.bookings}/$bookingId/collect-payment');
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Text(l.tr('payment_collected')),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (_) {
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tr('failed_collect_payment')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _notifyCustomer(String bookingId) async {
    try {
      await _api.post('${ApiConfig.bookings}/$bookingId/notify-customer');
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tr('customer_notified')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tr('failed_notification')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showCancelReasonDialog(String bookingId) async {
    String? selectedReason;
    final otherController = TextEditingController();
    final reasons = [
      'Customer requested',
      'Stylist unavailable',
      'Salon closed',
      'Double booking',
      'Other',
    ];

    String? result;
    try {
    result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Cancel Booking', style: AppTextStyles.h4),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a reason for cancellation:',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    hint: const Text('Select reason'),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: AppTextStyles.bodyMedium))).toList(),
                    onChanged: (v) => setDialogState(() => selectedReason = v),
                  ),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherController,
                      maxLines: 2,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter reason...',
                        hintStyle: AppTextStyles.caption,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Back', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null ||
                          (selectedReason == 'Other' && otherController.text.trim().isEmpty)
                      ? null
                      : () {
                          final reason = selectedReason == 'Other'
                              ? otherController.text.trim()
                              : selectedReason!;
                          Navigator.pop(ctx, reason);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
    } finally {
      otherController.dispose();
    }

    if (result != null) {
      _updateBookingStatus(bookingId, 'cancelled', cancellationReason: result);
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status, {String? cancellationReason}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (cancellationReason != null) {
        body['cancellation_reason'] = cancellationReason;
      }
      await _api.put(
        '${ApiConfig.bookings}/$bookingId/status',
        body: body,
      );
      if (mounted) {
        final l = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.tr('booking')} ${_formatStatus(status).toLowerCase()}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('message')
            ? e.toString()
            : 'Failed to update booking status';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.accent;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatStatus(String? status) {
    if (status == null || status.isEmpty) return '';
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.tr('bookings')),
        actions: [const LanguageToggle(), const SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          tabs: [
            Tab(text: l.tr('today')),
            Tab(text: l.tr('upcoming')),
            Tab(text: l.tr('past')),
          ],
        ),
      ),
      body: _isLoading
          ? const SkeletonList(child: BookingCardSkeleton())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load bookings', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _hasError = false);
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(
                  bookings: _todayBookings,
                  emptyIcon: Icons.event_available,
                  emptyTitle: l.tr('no_bookings_today'),
                  emptySubtitle: l.tr('new_bookings_appear'),
                ),
                _buildBookingList(
                  bookings: _upcomingBookings,
                  emptyIcon: Icons.upcoming_outlined,
                  emptyTitle: l.tr('no_upcoming_bookings'),
                  emptySubtitle: l.tr('future_bookings_appear'),
                ),
                _buildBookingList(
                  bookings: _pastBookings,
                  emptyIcon: Icons.history,
                  emptyTitle: l.tr('no_past_bookings'),
                  emptySubtitle: l.tr('completed_bookings_show'),
                  scrollController: _pastScrollController,
                  hasMore: _pastHasMore,
                  loadingMore: _pastLoadingMore,
                ),
              ],
            ),
    );
  }

  Widget _buildBookingList({
    required List<dynamic> bookings,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    ScrollController? scrollController,
    bool hasMore = false,
    bool loadingMore = false,
  }) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyStateWidget(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            ),
          ),
        ),
      );
    }

    final itemCount = bookings.length + (hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= bookings.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          return _buildBookingCard(bookings[index]);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final customer = booking['customer'] as Map<String, dynamic>?;
    final customerName = customer?['name'] ?? 'Customer';
    final customerPhone = customer?['phone'] as String?;
    final initial = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C';
    final status = booking['status'] as String? ?? 'pending';
    final bookingId = booking['id']?.toString() ?? '';
    final bookingNumber = booking['booking_number'] ?? bookingId;
    final date = booking['booking_date'] ?? booking['date'] ?? '';
    final startTime = booking['start_time'] ?? '';
    final endTime = booking['end_time'] ?? '';
    final services = booking['services'] as List<dynamic>? ?? [];
    final totalAmount = booking['total_amount'] ?? booking['amount'] ?? 0;
    final paymentStatus = (booking['payment_status'] ?? 'pending').toString().toLowerCase();
    final color = _statusColor(status);
    final isPaid = paymentStatus == 'paid';

    return Container(
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Header row: avatar + name + notify button + status badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        '#$bookingNumber',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                // Call customer button
                if (customerPhone != null && customerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, size: 20),
                    color: AppColors.success,
                    tooltip: 'Call $customerName',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () async {
                      final uri = Uri.parse('tel:$customerPhone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                // Notify button for pending/confirmed
                if (bookingId.isNotEmpty && (status == 'pending' || status == 'confirmed'))
                  IconButton(
                    icon: const Icon(Icons.notifications_active_outlined, size: 20),
                    color: AppColors.accent,
                    tooltip: context.watch<LocaleProvider>().tr('notify_customer'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _notifyCustomer(bookingId),
                  ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Details row: date, time, services, amount
            Row(
              children: [
                _buildDetail(Icons.calendar_today, date),
                const SizedBox(width: 16),
                _buildDetail(Icons.access_time, formatTimeRange12h(startTime, endTime)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDetail(Icons.content_cut, '${services.length} service${services.length != 1 ? 's' : ''}'),
                const SizedBox(width: 16),
                // Show payment status badge
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.currency_rupee,
                        size: 14,
                        color: isPaid ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaid ? context.watch<LocaleProvider>().tr('paid') : '\u20B9$totalAmount',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isPaid ? AppColors.success : null,
                          fontWeight: isPaid ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Action buttons
            if (bookingId.isNotEmpty && (status == 'pending' || status == 'confirmed' || status == 'in_progress')) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              _buildActionButtons(bookingId, status, paymentStatus, totalAmount, customerName: customerName),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String bookingId, String status, String paymentStatus, dynamic totalAmount, {String customerName = 'Customer'}) {
    final l = context.watch<LocaleProvider>();
    final showCollect = (status == 'confirmed' || status == 'in_progress' || status == 'completed') &&
        paymentStatus != 'paid';

    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCancelReasonDialog(bookingId),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(l.tr('cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateBookingStatus(bookingId, 'confirmed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(l.tr('confirm_booking'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    if (status == 'confirmed') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateBookingStatus(bookingId, 'in_progress'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(l.tr('start'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          if (showCollect) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCollectPayment(bookingId, customerName, totalAmount),
                icon: const Icon(Icons.currency_rupee, size: 16),
                label: Text('${l.tr('collect')} \u20B9$totalAmount'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (status == 'in_progress') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateBookingStatus(bookingId, 'no_show'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(l.tr('mark_no_show'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateBookingStatus(bookingId, 'completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(l.tr('complete_service'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (showCollect) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCollectPayment(bookingId, customerName, totalAmount),
                icon: const Icon(Icons.currency_rupee, size: 16),
                label: Text('${l.tr('collect')} \u20B9$totalAmount'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
