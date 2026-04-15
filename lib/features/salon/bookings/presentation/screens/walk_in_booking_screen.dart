import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../services/api_service.dart';

class WalkInBookingScreen extends StatefulWidget {
  final String salonId;
  const WalkInBookingScreen({super.key, required this.salonId});

  @override
  State<WalkInBookingScreen> createState() => _WalkInBookingScreenState();
}

class _WalkInBookingScreenState extends State<WalkInBookingScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingSlots = false;

  // Services
  List<Map<String, dynamic>> _services = [];
  final Set<String> _selectedServiceIds = {};

  // Date
  DateTime _selectedDate = DateTime.now();

  // Stylists
  List<Map<String, dynamic>> _stylists = [];
  String? _selectedStylistId; // null = "Any"

  // Slots
  List<Map<String, dynamic>> _slots = [];
  String? _selectedSlotTime;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        _api.get('${ApiConfig.services}/salon/${widget.salonId}',
            queryParams: {'all': 'true'}),
        _api.get('${ApiConfig.salonDetail}/${widget.salonId}/members'),
      ]);

      final servicesData = results[0]['data'] as List<dynamic>? ?? [];
      _services = servicesData
          .map((s) => Map<String, dynamic>.from(s as Map))
          .where((s) => s['is_active'] == true)
          .toList();

      final membersData = results[1]['data'];
      _stylists = membersData is List
          ? membersData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((m) => (m['role'] ?? '').toString() == 'stylist')
              .toList()
          : <Map<String, dynamic>>[];

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackbarUtils.showError(context, 'Failed to load data');
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedServiceIds.isEmpty) {
      setState(() => _slots = []);
      return;
    }

    try {
      setState(() {
        _isLoadingSlots = true;
        _selectedSlotTime = null;
      });

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final queryParams = <String, dynamic>{
        'date': dateStr,
        'service_ids': _selectedServiceIds.join(','),
      };
      if (_selectedStylistId != null) {
        queryParams['stylist_member_id'] = _selectedStylistId!;
      }

      final res = await _api.get(
        '${ApiConfig.bookings}/salon/${widget.salonId}/slots',
        queryParams: queryParams,
      );

      final slotsData = res['data'] as List<dynamic>? ?? [];
      _slots = slotsData
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      setState(() => _isLoadingSlots = false);
    } catch (e) {
      setState(() => _isLoadingSlots = false);
      if (mounted) SnackbarUtils.showError(context, 'Failed to load slots');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceIds.isEmpty) {
      SnackbarUtils.showError(context, 'Please select at least one service');
      return;
    }
    if (_selectedSlotTime == null) {
      SnackbarUtils.showError(context, 'Please select a time slot');
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final body = <String, dynamic>{
        'salon_id': widget.salonId,
        'service_ids': _selectedServiceIds.toList(),
        'booking_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'start_time': _selectedSlotTime,
        'customer_phone': _phoneController.text.trim(),
        'payment_mode': 'pay_at_salon',
      };

      if (_nameController.text.trim().isNotEmpty) {
        body['customer_name'] = _nameController.text.trim();
      }
      if (_selectedStylistId != null) {
        body['stylist_member_id'] = _selectedStylistId;
      }
      if (_notesController.text.trim().isNotEmpty) {
        body['notes'] = _notesController.text.trim();
      }

      await _api.post(ApiConfig.bookings, body: body);

      setState(() => _isSubmitting = false);

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Walk-in booking created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        SnackbarUtils.showError(
          context,
          e.toString().contains('message')
              ? e.toString().replaceAll('Exception: ', '')
              : 'Failed to create booking',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Walk-in Booking')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader('Customer Details'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Customer Phone *',
                    hint: '10-digit mobile number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.trim().length != 10) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _nameController,
                    label: 'Customer Name (optional)',
                    hint: 'Enter name',
                    prefixIcon: Icons.person_outline,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Select Services'),
                  const SizedBox(height: 12),
                  _buildServiceSelector(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Date'),
                  const SizedBox(height: 12),
                  _buildDatePicker(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Stylist'),
                  const SizedBox(height: 12),
                  _buildStylistSelector(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Available Slots'),
                  const SizedBox(height: 12),
                  if (_selectedServiceIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Select services to see available slots',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (_isLoadingSlots)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else
                    _buildSlotSelector(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Notes'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _notesController,
                    label: 'Notes (optional)',
                    hint: 'Any special requests or notes',
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Create Walk-in Booking',
                    isLoading: _isSubmitting,
                    icon: Icons.person_add,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
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
        Text(title, style: AppTextStyles.h4),
      ],
    );
  }

  Widget _buildServiceSelector() {
    if (_services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No active services found',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _services.map((svc) {
        final id = svc['id'].toString();
        final name = svc['name'] ?? '';
        final price = svc['price'];
        final isSelected = _selectedServiceIds.contains(id);

        return FilterChip(
          label: Text('$name (\u20B9${_formatPrice(price)})'),
          selected: isSelected,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          checkmarkColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedServiceIds.add(id);
              } else {
                _selectedServiceIds.remove(id);
              }
            });
            _loadSlots();
          },
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppColors.primary,
                    ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _loadSlots();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 20, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
              style: AppTextStyles.bodyMedium,
            ),
            const Spacer(),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStylistSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Any stylist'),
          selected: _selectedStylistId == null,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(
            color: _selectedStylistId == null
                ? AppColors.white
                : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: _selectedStylistId == null
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          onSelected: (_) {
            setState(() => _selectedStylistId = null);
            _loadSlots();
          },
        ),
        ..._stylists.map((s) {
          final id = s['id']?.toString() ?? '';
          final name =
              s['user']?['name']?.toString() ?? s['name']?.toString() ?? 'Stylist';
          final isSelected = _selectedStylistId == id;
          return ChoiceChip(
            label: Text(name),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            labelStyle: TextStyle(
              color:
                  isSelected ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color:
                    isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            onSelected: (_) {
              setState(() => _selectedStylistId = id);
              _loadSlots();
            },
          );
        }),
      ],
    );
  }

  Widget _buildSlotSelector() {
    if (_slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No available slots for selected date and services',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final time = slot['start_time']?.toString() ??
            slot['time']?.toString() ??
            '';
        final isSmart =
            slot['is_smart_slot'] == true || slot['isSmartSlot'] == true;
        final isSelected = _selectedSlotTime == time;

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSmart) ...[
                Icon(Icons.auto_awesome,
                    size: 14,
                    color: isSelected
                        ? AppColors.white
                        : AppColors.success),
                const SizedBox(width: 4),
              ],
              Text(_formatSlotTime(time)),
            ],
          ),
          selected: isSelected,
          selectedColor:
              isSmart ? AppColors.success : AppColors.primary,
          backgroundColor: isSmart
              ? AppColors.successLight
              : AppColors.cardBackground,
          labelStyle: TextStyle(
            color: isSelected
                ? AppColors.white
                : isSmart
                    ? AppColors.success
                    : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? (isSmart ? AppColors.success : AppColors.primary)
                  : isSmart
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
            ),
          ),
          onSelected: (_) {
            setState(() => _selectedSlotTime = time);
          },
        );
      }).toList(),
    );
  }

  String _formatSlotTime(String time) {
    // Handle HH:mm format
    final parts = time.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }
    return time;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    if (p == p.truncateToDouble()) return p.toInt().toString();
    return p.toStringAsFixed(2);
  }
}
