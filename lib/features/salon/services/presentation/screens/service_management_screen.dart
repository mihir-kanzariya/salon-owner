import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import 'package:provider/provider.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../providers/salon_provider.dart';
import 'add_service_screen.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  State<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _salonId;
  String? _errorMessage;

  /// Services grouped by category name.
  /// Key = category name, Value = list of service maps.
  Map<String, List<Map<String, dynamic>>> _groupedServices = {};

  @override
  void initState() {
    super.initState();
    _loadSalonAndServices();
  }

  // ------------------------------------------------------------------
  // Data loading
  // ------------------------------------------------------------------

  Future<void> _loadSalonAndServices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _salonId = context.read<SalonProvider>().salonId;

      if (_salonId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No salon found. Please create a salon first.';
        });
        return;
      }

      await _loadServices();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final res = await _api.get('${ApiConfig.services}/salon/$_salonId', queryParams: {'all': 'true'});
      final List<dynamic> services = res['data'] ?? [];

      // Group services by category name
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final svc in services) {
        final map = Map<String, dynamic>.from(svc as Map);
        final categoryName =
            (map['category']?['name'] ?? map['category_name'] ?? 'Uncategorized')
                .toString();
        grouped.putIfAbsent(categoryName, () => []);
        grouped[categoryName]!.add(map);
      }

      setState(() {
        _groupedServices = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _toggleActive(Map<String, dynamic> service) async {
    final serviceId = service['id'].toString();
    final currentlyActive = service['is_active'] == true;

    try {
      await _api.put(
        '${ApiConfig.services}/$serviceId',
        body: {'is_active': !currentlyActive},
      );
      await _loadServices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final serviceId = service['id'].toString();
    final serviceName = service['name'] ?? 'this service';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "$serviceName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.delete('${ApiConfig.services}/$serviceId');
      await _loadServices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToAddService() async {
    if (_salonId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddServiceScreen(salonId: _salonId!),
      ),
    );
    if (result == true) {
      _loadServices();
    }
  }

  void _navigateToEditService(Map<String, dynamic> service) async {
    if (_salonId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddServiceScreen(
          salonId: _salonId!,
          serviceId: service['id'].toString(),
        ),
      ),
    );
    if (result == true) {
      _loadServices();
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Services'),
      ),
      floatingActionButton: _salonId != null
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddService,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: AppColors.white),
              label: const Text(
                'Add Service',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList(child: ServiceCardSkeleton(), count: 5);
    }

    if (_errorMessage != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: _errorMessage,
        actionText: 'Retry',
        onAction: _loadSalonAndServices,
      );
    }

    if (_groupedServices.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.content_cut,
        title: 'No services yet',
        subtitle: 'Add your first service to get started.',
        actionText: 'Add Service',
        onAction: _navigateToAddService,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _groupedServices.length,
        itemBuilder: (context, index) {
          final category = _groupedServices.keys.elementAt(index);
          final services = _groupedServices[category]!;
          return _buildCategorySection(category, services);
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Category section
  // ------------------------------------------------------------------

  Widget _buildCategorySection(
      String category, List<Map<String, dynamic>> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.toUpperCase(),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${services.length})',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        ...services.map((svc) => _buildServiceCard(svc)),
        const SizedBox(height: 8),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Service card
  // ------------------------------------------------------------------

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final name = service['name'] ?? '';
    final duration = service['duration_minutes'] ?? 0;
    final price = service['price'];
    final genderType = (service['gender'] ?? service['gender_type'] ?? 'unisex').toString();
    final isActive = service['is_active'] == true;

    return Dismissible(
      key: Key(service['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        await _deleteService(service);
        // Return false because _deleteService handles the refresh itself.
        return false;
      },
      child: GestureDetector(
        onTap: () => _navigateToEditService(service),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Leading icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.softSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.content_cut,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Name, duration, gender chip
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.labelLarge.copyWith(
                        color:
                            isActive ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$duration min',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(width: 12),
                        _GenderChip(genderType: genderType),
                      ],
                    ),
                  ],
                ),
              ),

              // Price + toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\u20B9${_formatPrice(price)}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: isActive,
                      onChanged: (_) => _toggleActive(service),
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }
    return p.toStringAsFixed(2);
  }
}

// ------------------------------------------------------------------
// Gender type chip
// ------------------------------------------------------------------

class _GenderChip extends StatelessWidget {
  final String genderType;

  const _GenderChip({required this.genderType});

  @override
  Widget build(BuildContext context) {
    final label = _label;
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String get _label {
    switch (genderType.toLowerCase()) {
      case 'men':
        return 'Men';
      case 'women':
        return 'Women';
      default:
        return 'Unisex';
    }
  }

  Color get _color {
    switch (genderType.toLowerCase()) {
      case 'men':
        return AppColors.primary;
      case 'women':
        return const Color(0xFFE91E63);
      default:
        return AppColors.accent;
    }
  }
}
