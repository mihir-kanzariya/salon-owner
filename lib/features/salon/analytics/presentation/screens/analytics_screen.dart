import '../../../../../config/api_config.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String salonId;

  const AnalyticsScreen({super.key, required this.salonId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _DateRange { today, thisWeek, thisMonth, custom }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  _DateRange _selectedRange = _DateRange.today;

  // Stats
  double _totalRevenue = 0;
  int _totalBookings = 0;
  double _completionRate = 0;
  double _avgBookingValue = 0;

  // Top services & customers
  List<Map<String, dynamic>> _topServices = [];
  List<Map<String, dynamic>> _topCustomers = [];

  // Custom date range
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _dateFrom {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _DateRange.today:
        return DateTime(now.year, now.month, now.day);
      case _DateRange.thisWeek:
        return now.subtract(Duration(days: now.weekday - 1));
      case _DateRange.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _DateRange.custom:
        return _customRange?.start ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _dateTo {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _DateRange.today:
        return now;
      case _DateRange.thisWeek:
        return now;
      case _DateRange.thisMonth:
        return now;
      case _DateRange.custom:
        return _customRange?.end ?? now;
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final dateFrom = DateFormat('yyyy-MM-dd').format(_dateFrom);
      final dateTo = DateFormat('yyyy-MM-dd').format(_dateTo);

      // Load stats, bookings, and earnings in parallel
      final results = await Future.wait([
        _api.get('${ApiConfig.salonDetail}/${widget.salonId}/stats').catchError((_) => <String, dynamic>{}),
        _api.get(
          '${ApiConfig.bookings}/salon/${widget.salonId}',
          queryParams: {'date_from': dateFrom, 'date_to': dateTo, 'limit': '500'},
        ).catchError((_) => <String, dynamic>{}),
        _api.get(
          ApiConfig.salonEarnings(widget.salonId),
          queryParams: {'from': dateFrom, 'to': dateTo},
        ).catchError((_) => <String, dynamic>{}),
      ]);

      final statsData = results[0]['data'] as Map<String, dynamic>? ?? {};
      final bookings = (results[1]['data'] as List<dynamic>?) ?? [];
      final earningsData = results[2]['data'] as Map<String, dynamic>? ?? {};

      // Calculate revenue
      _totalRevenue = double.tryParse(earningsData['total_earned']?.toString() ?? '0') ?? 0;
      if (_totalRevenue == 0) {
        _totalRevenue = double.tryParse(statsData['today_revenue']?.toString() ?? '0') ?? 0;
      }

      // Calculate bookings count
      _totalBookings = bookings.length;
      if (_totalBookings == 0) {
        _totalBookings = int.tryParse(earningsData['total_bookings']?.toString() ?? '0') ?? 0;
      }

      // Calculate completion rate
      final completed = bookings.where((b) => b['status'] == 'completed').length;
      final cancelled = bookings.where((b) => b['status'] == 'cancelled').length;
      final total = completed + cancelled;
      _completionRate = total > 0 ? (completed / total) * 100 : 0;

      // Avg booking value
      _avgBookingValue = _totalBookings > 0 ? _totalRevenue / _totalBookings : 0;

      // Aggregate top services
      final serviceMap = <String, Map<String, dynamic>>{};
      for (final booking in bookings) {
        final services = booking['services'] as List<dynamic>? ?? [];
        for (final svc in services) {
          final name = svc['service_name']?.toString() ?? svc['name']?.toString() ?? 'Unknown';
          final price = double.tryParse(svc['price']?.toString() ?? '0') ?? 0;
          if (serviceMap.containsKey(name)) {
            serviceMap[name]!['count'] = (serviceMap[name]!['count'] as int) + 1;
            serviceMap[name]!['revenue'] = (serviceMap[name]!['revenue'] as double) + price;
          } else {
            serviceMap[name] = {'name': name, 'count': 1, 'revenue': price};
          }
        }
      }
      _topServices = serviceMap.values.toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      if (_topServices.length > 5) _topServices = _topServices.sublist(0, 5);

      // Aggregate top customers
      final customerMap = <String, Map<String, dynamic>>{};
      for (final booking in bookings) {
        final customer = booking['customer'] as Map<String, dynamic>?;
        if (customer == null) continue;
        final name = customer['name']?.toString() ?? 'Customer';
        final id = customer['id']?.toString() ?? name;
        final amount = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0;
        if (customerMap.containsKey(id)) {
          customerMap[id]!['visits'] = (customerMap[id]!['visits'] as int) + 1;
          customerMap[id]!['spent'] = (customerMap[id]!['spent'] as double) + amount;
        } else {
          customerMap[id] = {'name': name, 'visits': 1, 'spent': amount};
        }
      }
      _topCustomers = customerMap.values.toList()
        ..sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));
      if (_topCustomers.length > 5) _topCustomers = _topCustomers.sublist(0, 5);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
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
        _customRange = picked;
        _selectedRange = _DateRange.custom;
      });
      _loadData();
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.tr('analytics')),
        actions: [
          const LanguageToggle(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickCustomDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range chips
                    _buildDateRangeChips(l),
                    const SizedBox(height: 20),

                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _AnalyticsStatCard(
                          title: l.tr('total_revenue'),
                          value: _formatCurrency(_totalRevenue),
                          icon: Icons.currency_rupee,
                          color: AppColors.success,
                          bgColor: AppColors.successLight,
                        ),
                        _AnalyticsStatCard(
                          title: l.tr('total_bookings_stat'),
                          value: '$_totalBookings',
                          icon: Icons.calendar_today,
                          color: AppColors.primary,
                          bgColor: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        _AnalyticsStatCard(
                          title: l.tr('completion_rate'),
                          value: '${_completionRate.toStringAsFixed(1)}%',
                          icon: Icons.percent,
                          color: AppColors.accent,
                          bgColor: AppColors.accentLight,
                        ),
                        _AnalyticsStatCard(
                          title: l.tr('avg_booking_value'),
                          value: _formatCurrency(_avgBookingValue),
                          icon: Icons.currency_rupee,
                          color: Colors.blue,
                          bgColor: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Top Services
                    Text(l.tr('top_services'), style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    _buildTopServicesList(l),
                    const SizedBox(height: 24),

                    // Top Customers
                    Text(l.tr('top_customers'), style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    _buildTopCustomersList(l),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateRangeChips(LocaleProvider l) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DateChip(
            label: l.tr('today'),
            isSelected: _selectedRange == _DateRange.today,
            onTap: () {
              setState(() => _selectedRange = _DateRange.today);
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          _DateChip(
            label: l.tr('this_week'),
            isSelected: _selectedRange == _DateRange.thisWeek,
            onTap: () {
              setState(() => _selectedRange = _DateRange.thisWeek);
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          _DateChip(
            label: l.tr('this_month'),
            isSelected: _selectedRange == _DateRange.thisMonth,
            onTap: () {
              setState(() => _selectedRange = _DateRange.thisMonth);
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          _DateChip(
            label: l.tr('custom'),
            isSelected: _selectedRange == _DateRange.custom,
            onTap: _pickCustomDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildTopServicesList(LocaleProvider l) {
    if (_topServices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(l.tr('no_data'), style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Column(
      children: _topServices.asMap().entries.map((entry) {
        final index = entry.key;
        final svc = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
                      svc['name'] as String,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${svc['count']} ${l.tr('bookings').toLowerCase()}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(svc['revenue'] as double),
                style: AppTextStyles.h4.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopCustomersList(LocaleProvider l) {
    if (_topCustomers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(l.tr('no_data'), style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Column(
      children: _topCustomers.map((customer) {
        final name = customer['name'] as String;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${customer['visits']} ${l.tr('visits')}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(customer['spent'] as double),
                style: AppTextStyles.h4.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AnalyticsStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _AnalyticsStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
