import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../config/api_config.dart';

class EditSalonScreen extends StatefulWidget {
  final String salonId;

  const EditSalonScreen({super.key, required this.salonId});

  @override
  State<EditSalonScreen> createState() => _EditSalonScreenState();
}

class _EditSalonScreenState extends State<EditSalonScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _genderType = 'unisex';
  String? _coverImageUrl;
  int _advanceBookingDays = 15;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    _loadSalonData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadSalonData() async {
    try {
      setState(() => _isLoading = true);
      final res =
          await _api.get('${ApiConfig.salonDetail}/${widget.salonId}');
      final salon = res['data'] ?? {};

      _nameController.text = salon['name'] ?? '';
      _descriptionController.text = salon['description'] ?? '';
      _phoneController.text = salon['phone'] ?? '';
      _emailController.text = salon['email'] ?? '';
      _addressController.text = salon['address'] ?? '';
      _cityController.text = salon['city'] ?? '';
      _stateController.text = salon['state'] ?? '';
      _pincodeController.text = salon['pincode'] ?? '';
      _genderType = salon['gender_type'] ?? 'unisex';
      _coverImageUrl = salon['cover_image'];

      final bookingSettings = salon['booking_settings'] as Map<String, dynamic>?;
      if (bookingSettings != null) {
        _advanceBookingDays = (bookingSettings['advance_booking_days'] as num?)?.toInt() ?? 15;
      }

      final location = salon['location'];
      if (location != null) {
        final coords = location['coordinates'];
        if (coords != null && coords is List && coords.length >= 2) {
          _longitudeController.text = coords[0].toString();
          _latitudeController.text = coords[1].toString();
        }
      } else {
        _latitudeController.text =
            (salon['latitude'] ?? salon['lat'] ?? '').toString();
        _longitudeController.text =
            (salon['longitude'] ?? salon['lng'] ?? '').toString();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to load salon data');
      }
    }
  }

  Future<void> _onCoverImageTap() async {
    if (_isUploadingCover) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final url = await UploadService().pickAndUpload(
        folder: 'salons/${widget.salonId}/cover',
        source: source,
        preset: UploadPreset.cover,
      );
      if (url != null && mounted) {
        await _api.put(
          '${ApiConfig.salonDetail}/${widget.salonId}',
          body: {'cover_image': url},
        );
        setState(() => _coverImageUrl = url);
        if (mounted) SnackbarUtils.showSuccess(context, 'Cover image updated');
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _saveSalon() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'gender_type': _genderType,
        'booking_settings': {
          'advance_booking_days': _advanceBookingDays,
        },
      };

      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        body['latitude'] = double.tryParse(_latitudeController.text) ?? 0;
        body['longitude'] = double.tryParse(_longitudeController.text) ?? 0;
      }

      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: body,
      );

      setState(() => _isSaving = false);

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Salon updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        SnackbarUtils.showError(
          context,
          e.toString().contains('ApiException')
              ? e.toString()
              : 'Failed to update salon',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Salon Info'),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cover Image Section
                  _buildSectionHeader('Cover Image'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _onCoverImageTap,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.softSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        image: _coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  ApiConfig.imageUrl(_coverImageUrl) ?? _coverImageUrl!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _isUploadingCover
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            )
                          : _coverImageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: AppColors.textMuted),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to upload cover image',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.85),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 20, color: AppColors.white),
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  // Basic Information Section
                  _buildSectionHeader('Basic Information'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _nameController,
                    label: 'Salon Name',
                    hint: 'Enter salon name',
                    prefixIcon: Icons.store,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Salon name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Describe your salon',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter email address',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 28),
                  // Gender Type Section
                  _buildSectionHeader('Salon Type'),
                  const SizedBox(height: 12),
                  _buildGenderTypeChips(),

                  const SizedBox(height: 28),
                  // Address Section
                  _buildSectionHeader('Address'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _addressController,
                    label: 'Street Address',
                    hint: 'Enter full address',
                    prefixIcon: Icons.location_on_outlined,
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'City',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'State',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _pincodeController,
                    label: 'Pincode',
                    hint: 'Enter pincode',
                    prefixIcon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),

                  const SizedBox(height: 28),
                  // Location Coordinates Section
                  _buildSectionHeader('Coordinates'),
                  const SizedBox(height: 8),
                  Text(
                    'Used for map placement. Leave blank for auto-detection.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          hint: 'e.g. 23.0225',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          hint: 'e.g. 72.5714',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  // Booking Settings Section
                  _buildSectionHeader('Booking Settings'),
                  const SizedBox(height: 12),
                  _buildBookingWindowSelector(),

                  const SizedBox(height: 36),
                  // Save Button
                  AppButton(
                    text: 'Save Changes',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveSalon,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildBookingWindowSelector() {
    final options = [
      {'label': '1 Week', 'days': 7},
      {'label': '2 Weeks', 'days': 14},
      {'label': '15 Days', 'days': 15},
      {'label': '1 Month', 'days': 30},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How far in advance can customers book?',
          style: AppTextStyles.bodySmall,
        ),
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
                color: isSelected ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
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

  Widget _buildGenderTypeChips() {
    final options = ['men', 'women', 'unisex'];
    final labels = {
      'men': 'Men',
      'women': 'Women',
      'unisex': 'Unisex',
    };
    final icons = {
      'men': Icons.male,
      'women': Icons.female,
      'unisex': Icons.people,
    };

    return Wrap(
      spacing: 10,
      children: options.map((option) {
        final isSelected = _genderType == option;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icons[option],
                size: 18,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(labels[option]!),
            ],
          ),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          onSelected: (selected) {
            if (selected) {
              setState(() => _genderType = option);
            }
          },
        );
      }).toList(),
    );
  }
}
