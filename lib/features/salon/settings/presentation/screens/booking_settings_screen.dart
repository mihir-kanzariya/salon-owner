import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../services/api_service.dart';

class BookingSettingsScreen extends StatefulWidget {
  final String salonId;
  const BookingSettingsScreen({super.key, required this.salonId});

  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Field values
  int _slotDurationMinutes = 15;
  int _bufferBetweenBookingsMinutes = 5;
  int _advanceBookingDays = 15;
  bool _autoAcceptBookings = false;
  bool _requirePrepayment = false;
  double _tokenAmount = 0;
  int _cancellationPolicyHours = 2;
  bool _smartSlotEnabled = true;
  double _smartSlotDiscount = 10;
  String _smartSlotDiscountType = 'percentage';
  bool _autoStartBookings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      final res = await _api.get('${ApiConfig.salonDetail}/${widget.salonId}');
      final salon = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
      final raw = salon['booking_settings'];
      final s = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      setState(() {
        _slotDurationMinutes = _parseInt(s['slot_duration_minutes']) ?? 15;
        _bufferBetweenBookingsMinutes =
            _parseInt(s['buffer_between_bookings_minutes']) ?? 5;
        _advanceBookingDays =
            _parseInt(s['advance_booking_days'] ?? s['max_advance_days']) ?? 15;
        _autoAcceptBookings =
            s['auto_accept_bookings'] ?? s['auto_confirm'] ?? false;
        _requirePrepayment =
            s['require_prepayment'] ?? s['require_payment'] ?? false;
        _tokenAmount = _parseDouble(s['token_amount']) ?? 0;
        _cancellationPolicyHours =
            _parseInt(s['cancellation_policy_hours']) ?? 2;
        _smartSlotEnabled = s['smart_slot_enabled'] ?? true;
        _smartSlotDiscount = _parseDouble(s['smart_slot_discount']) ?? 10;
        _smartSlotDiscountType =
            s['smart_slot_discount_type']?.toString() ?? 'percentage';
        _autoStartBookings = s['auto_start_bookings'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackbarUtils.showError(context, 'Failed to load settings');
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _isSaving = true);

      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {
          'booking_settings': {
            'slot_duration_minutes': _slotDurationMinutes,
            'buffer_between_bookings_minutes': _bufferBetweenBookingsMinutes,
            'advance_booking_days': _advanceBookingDays,
            'auto_accept_bookings': _autoAcceptBookings,
            'require_prepayment': _requirePrepayment,
            'token_amount': _tokenAmount,
            'cancellation_policy_hours': _cancellationPolicyHours,
            'smart_slot_enabled': _smartSlotEnabled,
            'smart_slot_discount': _smartSlotDiscount,
            'smart_slot_discount_type': _smartSlotDiscountType,
            'auto_start_bookings': _autoStartBookings,
          },
        },
      );

      setState(() => _isSaving = false);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Booking settings saved');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to save settings');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Booking Settings')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Slot Configuration'),
                const SizedBox(height: 12),
                _buildSlotDurationDropdown(),
                const SizedBox(height: 16),
                _buildNumberField(
                  label: 'Buffer between bookings (min)',
                  value: _bufferBetweenBookingsMinutes,
                  icon: Icons.timelapse,
                  onChanged: (v) =>
                      setState(() => _bufferBetweenBookingsMinutes = v),
                ),
                const SizedBox(height: 16),
                _buildAdvanceBookingSelector(),

                const SizedBox(height: 28),
                _buildSectionHeader('Booking Behaviour'),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Auto-accept bookings',
                  subtitle:
                      'Automatically confirm new bookings without manual review',
                  value: _autoAcceptBookings,
                  onChanged: (v) =>
                      setState(() => _autoAcceptBookings = v),
                ),
                _buildToggle(
                  title: 'Auto-start bookings',
                  subtitle:
                      'Automatically move confirmed bookings to in-progress at start time',
                  value: _autoStartBookings,
                  onChanged: (v) =>
                      setState(() => _autoStartBookings = v),
                ),

                const SizedBox(height: 28),
                _buildSectionHeader('Payment'),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Require prepayment',
                  subtitle: 'Customer must pay a token amount to confirm',
                  value: _requirePrepayment,
                  onChanged: (v) =>
                      setState(() => _requirePrepayment = v),
                ),
                if (_requirePrepayment) ...[
                  const SizedBox(height: 12),
                  _buildTokenAmountField(),
                ],

                const SizedBox(height: 28),
                _buildSectionHeader('Cancellation'),
                const SizedBox(height: 12),
                _buildNumberField(
                  label: 'Cancellation window (hours)',
                  value: _cancellationPolicyHours,
                  icon: Icons.cancel_outlined,
                  onChanged: (v) =>
                      setState(() => _cancellationPolicyHours = v),
                  hint:
                      'Customers can cancel free up to this many hours before',
                ),

                const SizedBox(height: 28),
                _buildSectionHeader('Smart Slots'),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Smart slots enabled',
                  subtitle:
                      'Offer discounted slots that fill schedule gaps',
                  value: _smartSlotEnabled,
                  onChanged: (v) =>
                      setState(() => _smartSlotEnabled = v),
                ),
                if (_smartSlotEnabled) ...[
                  const SizedBox(height: 12),
                  _buildSmartSlotDiscountField(),
                  const SizedBox(height: 12),
                  _buildDiscountTypeToggle(),
                ],

                const SizedBox(height: 36),
                AppButton(
                  text: 'Save Settings',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveSettings,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ----- Widgets -----

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

  Widget _buildSlotDurationDropdown() {
    final options = [15, 30, 45, 60];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Slot duration', style: AppTextStyles.bodyMedium),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: options.contains(_slotDurationMinutes)
                  ? _slotDurationMinutes
                  : 15,
              items: options
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text('$v min',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.primary)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _slotDurationMinutes = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceBookingSelector() {
    final options = [
      {'label': '1 Week', 'days': 7},
      {'label': '2 Weeks', 'days': 14},
      {'label': '15 Days', 'days': 15},
      {'label': '1 Month', 'days': 30},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Advance booking window',
            style: AppTextStyles.bodyMedium),
        const SizedBox(height: 4),
        Text('How far in advance can customers book?',
            style: AppTextStyles.caption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: options.map((option) {
            final days = option['days'] as int;
            final isSelected = _advanceBookingDays == days;
            return ChoiceChip(
              label: Text(option['label'] as String),
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
              onSelected: (selected) {
                if (selected) {
                  setState(() => _advanceBookingDays = days);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        title: Text(title, style: AppTextStyles.labelLarge),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required IconData icon,
    required ValueChanged<int> onChanged,
    String? hint,
  }) {
    final controller = TextEditingController(text: value.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: AppTextStyles.bodyMedium),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) onChanged(parsed);
                  },
                ),
              ),
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(hint, style: AppTextStyles.caption),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenAmountField() {
    final controller =
        TextEditingController(text: _tokenAmount.toStringAsFixed(0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_rupee,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child:
                Text('Token amount', style: AppTextStyles.bodyMedium),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primary),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: '\u20B9 ',
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) _tokenAmount = parsed;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSlotDiscountField() {
    final controller =
        TextEditingController(text: _smartSlotDiscount.toStringAsFixed(0));
    final isPercent = _smartSlotDiscountType == 'percentage';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.discount_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Smart slot discount',
                style: AppTextStyles.bodyMedium),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.primary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                suffixText: isPercent ? '%' : '\u20B9',
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  setState(() => _smartSlotDiscount = parsed);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountTypeToggle() {
    final isPercent = _smartSlotDiscountType == 'percentage';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Discount type',
                style: AppTextStyles.bodyMedium),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'percentage', label: Text('%')),
              ButtonSegment(value: 'flat', label: Text('\u20B9')),
            ],
            selected: {_smartSlotDiscountType},
            onSelectionChanged: (v) {
              setState(() => _smartSlotDiscountType = v.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return AppColors.cardBackground;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.white;
                }
                return AppColors.textPrimary;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
