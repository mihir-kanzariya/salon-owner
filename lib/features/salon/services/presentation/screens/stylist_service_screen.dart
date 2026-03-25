import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../providers/salon_provider.dart';

class StylistServiceScreen extends StatefulWidget {
  const StylistServiceScreen({super.key});

  @override
  State<StylistServiceScreen> createState() => _StylistServiceScreenState();
}

class _StylistServiceScreenState extends State<StylistServiceScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      setState(() => _isLoading = true);
      final sp = context.read<SalonProvider>();
      if (sp.memberId != null) {
        final res = await _api.get('${ApiConfig.stylists}/${sp.memberId}/profile');
        final data = res['data'] ?? {};
        _services = data['stylist_services'] ?? [];
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTiming(String serviceId, int durationMinutes) async {
    try {
      final sp = context.read<SalonProvider>();
      await _api.put(
        '${ApiConfig.stylists}/${sp.memberId}/services/$serviceId/timing',
        body: {'custom_duration_minutes': durationMinutes},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duration updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update duration'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDurationPicker(Map<String, dynamic> stylistService) {
    final service = stylistService['service'] ?? {};
    final currentDuration = stylistService['custom_duration_minutes'] ??
        service['duration_minutes'] ??
        30;
    final controller = TextEditingController(text: '$currentDuration');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${service['name'] ?? 'Service'} Duration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (minutes)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                Navigator.pop(ctx);
                _updateTiming(service['id'], minutes);
                setState(() {
                  stylistService['custom_duration_minutes'] = minutes;
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Services')),
      body: _isLoading
          ? const LoadingWidget()
          : _services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_cut_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('No services assigned', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Contact your salon manager to assign services',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadServices,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ss = _services[index] as Map<String, dynamic>;
                      final service = ss['service'] as Map<String, dynamic>? ?? {};
                      final duration = ss['custom_duration_minutes'] ??
                          service['duration_minutes'] ??
                          30;
                      final price = ss['custom_price'] ?? service['price'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
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
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.content_cut, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service['name'] ?? 'Service',
                                    style: AppTextStyles.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\u20B9$price',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _showDurationPicker(ss),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.softSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${duration}m',
                                      style: AppTextStyles.labelMedium,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 14, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
