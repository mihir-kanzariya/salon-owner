import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class AmenitiesScreen extends StatefulWidget {
  final String salonId;

  const AmenitiesScreen({super.key, required this.salonId});

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _selectedAmenities = [];

  static const List<Map<String, dynamic>> _availableAmenities = [
    {'label': 'WiFi', 'icon': Icons.wifi},
    {'label': 'AC', 'icon': Icons.ac_unit},
    {'label': 'Parking', 'icon': Icons.local_parking},
    {'label': 'Card Payment', 'icon': Icons.credit_card},
    {'label': 'UPI Payment', 'icon': Icons.qr_code},
    {'label': 'TV', 'icon': Icons.tv},
    {'label': 'Music', 'icon': Icons.music_note},
    {'label': 'Magazines', 'icon': Icons.menu_book},
    {'label': 'Beverages', 'icon': Icons.local_cafe},
    {'label': 'Kids Area', 'icon': Icons.child_care},
    {'label': 'Wheelchair Access', 'icon': Icons.accessible},
    {'label': 'Sanitized Tools', 'icon': Icons.cleaning_services},
    {'label': 'Disposable Towels', 'icon': Icons.dry_cleaning},
    {'label': 'Locker', 'icon': Icons.lock},
  ];

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  Future<void> _loadAmenities() async {
    try {
      setState(() => _isLoading = true);
      final res = await _api.get('${ApiConfig.salonDetail}/${widget.salonId}');
      final salon = res['data'] ?? {};
      final amenities = salon['amenities'] as List<dynamic>? ?? [];
      _selectedAmenities = amenities.map((a) => a.toString()).toList();
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    try {
      setState(() => _isSaving = true);
      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {'amenities': _selectedAmenities},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amenities updated'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update amenities'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _toggleAmenity(String label) {
    setState(() {
      if (_selectedAmenities.contains(label)) {
        _selectedAmenities.remove(label);
      } else {
        _selectedAmenities.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Amenities')),
      body: _isLoading
          ? const LoadingWidget()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the amenities your salon offers',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableAmenities.map((amenity) {
                        final label = amenity['label'] as String;
                        final icon = amenity['icon'] as IconData;
                        final isSelected = _selectedAmenities.contains(label);

                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(label),
                            ],
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.cardBackground,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 14,
                          ),
                          side: BorderSide(
                            color:
                                isSelected ? AppColors.primary : AppColors.border,
                          ),
                          checkmarkColor: AppColors.white,
                          onSelected: (_) => _toggleAmenity(label),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Save Amenities',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
