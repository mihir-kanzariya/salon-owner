import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/utils/time_utils.dart';
import '../../../../consumer/booking/data/models/booking_model.dart';
import '../../../../consumer/booking/data/repositories/booking_repository.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingRepository _repo = BookingRepository();

  List<BookingModel> _upcoming = [];
  List<BookingModel> _completed = [];
  List<BookingModel> _cancelled = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // Per-tab pagination state
  int _upcomingPage = 1;
  int _completedPage = 1;
  int _cancelledPage = 1;
  bool _upcomingHasMore = true;
  bool _completedHasMore = true;
  bool _cancelledHasMore = true;

  // Scroll controllers for each tab
  late ScrollController _upcomingScrollController;
  late ScrollController _completedScrollController;
  late ScrollController _cancelledScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _upcomingScrollController = ScrollController()..addListener(() => _onScroll('upcoming'));
    _completedScrollController = ScrollController()..addListener(() => _onScroll('completed'));
    _cancelledScrollController = ScrollController()..addListener(() => _onScroll('cancelled'));
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upcomingScrollController.dispose();
    _completedScrollController.dispose();
    _cancelledScrollController.dispose();
    super.dispose();
  }

  void _onScroll(String tab) {
    final controller = switch (tab) {
      'upcoming' => _upcomingScrollController,
      'completed' => _completedScrollController,
      'cancelled' => _cancelledScrollController,
      _ => _upcomingScrollController,
    };
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) {
      _loadMore(tab);
    }
  }

  Future<void> _loadBookings() async {
    try {
      setState(() { _isLoading = true; });

      // Reset pagination state
      _upcomingPage = 1;
      _completedPage = 1;
      _cancelledPage = 1;
      _upcomingHasMore = true;
      _completedHasMore = true;
      _cancelledHasMore = true;

      final results = await Future.wait([
        _repo.getMyBookingsPaginated(status: 'upcoming', page: 1),
        _repo.getMyBookingsPaginated(status: 'completed', page: 1),
        _repo.getMyBookingsPaginated(status: 'cancelled', page: 1),
      ]);

      _upcoming = results[0].items;
      _upcomingHasMore = results[0].hasMore;

      _completed = results[1].items;
      _completedHasMore = results[1].hasMore;

      _cancelled = results[2].items;
      _cancelledHasMore = results[2].hasMore;

      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadMore(String tab) async {
    if (_isLoadingMore) return;

    final hasMore = switch (tab) {
      'upcoming' => _upcomingHasMore,
      'completed' => _completedHasMore,
      'cancelled' => _cancelledHasMore,
      _ => false,
    };
    if (!hasMore) return;

    setState(() { _isLoadingMore = true; });

    try {
      final nextPage = switch (tab) {
        'upcoming' => _upcomingPage + 1,
        'completed' => _completedPage + 1,
        'cancelled' => _cancelledPage + 1,
        _ => 1,
      };

      final result = await _repo.getMyBookingsPaginated(
        status: tab,
        page: nextPage,
      );

      setState(() {
        switch (tab) {
          case 'upcoming':
            _upcoming = [..._upcoming, ...result.items];
            _upcomingPage = nextPage;
            _upcomingHasMore = result.hasMore;
            break;
          case 'completed':
            _completed = [..._completed, ...result.items];
            _completedPage = nextPage;
            _completedHasMore = result.hasMore;
            break;
          case 'cancelled':
            _cancelled = [..._cancelled, ...result.items];
            _cancelledPage = nextPage;
            _cancelledHasMore = result.hasMore;
            break;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() { _isLoadingMore = false; });
    }
  }

  Widget _buildBookingCard(BookingModel booking) {
    Color statusColor;
    switch (booking.status) {
      case 'confirmed': statusColor = AppColors.primary; break;
      case 'in_progress': statusColor = AppColors.accent; break;
      case 'completed': statusColor = AppColors.success; break;
      case 'cancelled': statusColor = AppColors.error; break;
      default: statusColor = AppColors.textMuted;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/booking-detail', arguments: booking.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('#${booking.bookingNumber}', style: AppTextStyles.labelMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(booking.statusDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (booking.salon != null)
                Text(booking.salon!['name'] ?? '', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(booking.bookingDate, style: AppTextStyles.bodySmall),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(formatTimeRange12h(booking.startTime, booking.endTime), style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('${booking.totalDurationMinutes} min', style: AppTextStyles.caption),
                      const SizedBox(width: 10),
                      // G.3: Payment status indicator
                      Icon(
                        booking.paymentStatus == 'paid' ? Icons.check_circle : Icons.pending,
                        size: 14,
                        color: booking.paymentStatus == 'paid' ? AppColors.success : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        booking.paymentStatus == 'paid'
                            ? (booking.paymentMode == 'pay_at_salon' ? 'Cash' : 'Online')
                            : 'Unpaid',
                        style: AppTextStyles.caption.copyWith(
                          color: booking.paymentStatus == 'paid' ? AppColors.success : AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text('₹${booking.totalAmount.toStringAsFixed(0)}', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<BookingModel> bookings,
    String emptyMessage,
    ScrollController scrollController,
    bool hasMore,
  ) {
    if (_isLoading) return const SkeletonList(child: BookingCardSkeleton());
    if (bookings.isEmpty) {
      return EmptyStateWidget(icon: Icons.calendar_today_outlined, title: emptyMessage);
    }
    final itemCount = bookings.length + (hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index < bookings.length) {
            return _buildBookingCard(bookings[index]);
          }
          // Loading indicator at bottom
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_upcoming, 'No upcoming bookings', _upcomingScrollController, _upcomingHasMore),
          _buildList(_completed, 'No completed bookings', _completedScrollController, _completedHasMore),
          _buildList(_cancelled, 'No cancelled bookings', _cancelledScrollController, _cancelledHasMore),
        ],
      ),
    );
  }
}
