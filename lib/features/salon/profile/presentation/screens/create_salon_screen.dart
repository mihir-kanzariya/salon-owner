import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../config/api_config.dart';

class CreateSalonScreen extends StatefulWidget {
  const CreateSalonScreen({super.key});

  @override
  State<CreateSalonScreen> createState() => _CreateSalonScreenState();
}

class _CreateSalonScreenState extends State<CreateSalonScreen> {
  final ApiService _api = ApiService();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form keys for each step
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // Step 1 - Basic Info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _genderType = 'unisex';
  String? _coverImageUrl;
  bool _isUploadingCover = false;

  // Step 2 - Location
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Step 3 - Settings
  final _commissionController = TextEditingController(text: '20');
  final _advanceTimeController = TextEditingController(text: '30');
  final _cancellationPolicyController = TextEditingController();
  final List<String> _selectedAmenities = [];

  final List<Map<String, dynamic>> _amenityOptions = [
    {'label': 'WiFi', 'icon': Icons.wifi},
    {'label': 'AC', 'icon': Icons.ac_unit},
    {'label': 'Parking', 'icon': Icons.local_parking},
    {'label': 'TV', 'icon': Icons.tv},
    {'label': 'Beverages', 'icon': Icons.local_cafe},
    {'label': 'Cards Accepted', 'icon': Icons.credit_card},
  ];

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
    _commissionController.dispose();
    _advanceTimeController.dispose();
    _cancellationPolicyController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        return _step3Key.currentState?.validate() ?? false;
      default:
        return false;
    }
  }

  void _onStepContinue() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      _submitSalon();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _onStepTapped(int step) {
    // Only allow tapping to previous steps, or current step validation passes
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    } else if (step == _currentStep + 1 && _validateCurrentStep()) {
      setState(() => _currentStep = step);
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
        folder: 'salons/new/cover',
        source: source,
        preset: UploadPreset.cover,
      );
      if (url != null && mounted) {
        setState(() => _coverImageUrl = url);
        SnackbarUtils.showSuccess(context, 'Cover image selected');
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _submitSalon() async {
    if (!_validateCurrentStep()) return;

    try {
      setState(() => _isSubmitting = true);

      final body = <String, dynamic>{
        // Basic Info
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'gender_type': _genderType,

        // Location
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),

        // Settings
        'commission_percentage':
            int.tryParse(_commissionController.text) ?? 20,
        'booking_advance_time':
            int.tryParse(_advanceTimeController.text) ?? 30,
        'cancellation_policy': _cancellationPolicyController.text.trim(),
        'amenities': _selectedAmenities,
      };

      if (_coverImageUrl != null) {
        body['cover_image'] = _coverImageUrl;
      }

      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        body['latitude'] =
            double.tryParse(_latitudeController.text) ?? 0;
        body['longitude'] =
            double.tryParse(_longitudeController.text) ?? 0;
      }

      await _api.post(ApiConfig.createSalon, body: body);

      setState(() => _isSubmitting = false);

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Salon created successfully!',
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/salon-home',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        SnackbarUtils.showError(
          context,
          e.toString().contains('ApiException')
              ? e.toString()
              : 'Failed to create salon. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Salon'),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressBar(),

          // Stepper content
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: _isSubmitting ? null : _onStepContinue,
              onStepCancel: _isSubmitting ? null : _onStepCancel,
              onStepTapped: _isSubmitting ? null : _onStepTapped,
              type: StepperType.vertical,
              elevation: 0,
              connectorColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return AppColors.border;
              }),
              controlsBuilder: (context, details) {
                return _buildStepControls(details);
              },
              steps: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.cardBackground,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of 3',
                style: AppTextStyles.labelMedium,
              ),
              const Spacer(),
              Text(
                _stepTitle(_currentStep),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Location';
      case 2:
        return 'Settings';
      default:
        return '';
    }
  }

  Widget _buildStepControls(ControlsDetails details) {
    final isLastStep = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              text: isLastStep ? 'Create Salon' : 'Continue',
              isLoading: _isSubmitting,
              icon: isLastStep ? Icons.check_circle : Icons.arrow_forward,
              onPressed:
                  _isSubmitting ? null : details.onStepContinue,
            ),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: AppButton(
                text: 'Back',
                isOutlined: true,
                onPressed:
                    _isSubmitting ? null : details.onStepCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Step 1: Basic Info ─────────────────────────────────────────────

  Step _buildStep1() {
    return Step(
      title: const Text('Basic Information', style: AppTextStyles.labelLarge),
      subtitle: const Text('Name, contact & salon type'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text('Cover Image', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text('This image will be shown on the salon listing',
                style: AppTextStyles.caption),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _onCoverImageTap,
              child: Container(
                height: 160,
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
                              Icon(Icons.add_a_photo, size: 36, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text('Tap to upload cover image',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
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
                              child: const Icon(Icons.camera_alt, size: 18, color: AppColors.white),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _nameController,
              label: 'Salon Name *',
              hint: 'Enter your salon name',
              prefixIcon: Icons.store,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Salon name is required';
                }
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Tell customers about your salon',
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _phoneController,
              label: 'Phone Number *',
              hint: 'Enter contact number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (value.trim().length < 10) {
                  return 'Enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter email address (optional)',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const Text('Salon Type *', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Who does your salon serve?',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            _buildGenderTypeChips(),
          ],
        ),
      ),
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
                color: isSelected
                    ? AppColors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(labels[option]!),
            ],
          ),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(
            color: isSelected
                ? AppColors.white
                : AppColors.textPrimary,
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

  // ─── Step 2: Location ───────────────────────────────────────────────

  Step _buildStep2() {
    return Step(
      title: const Text('Location', style: AppTextStyles.labelLarge),
      subtitle: const Text('Address & coordinates'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            AppTextField(
              controller: _addressController,
              label: 'Street Address *',
              hint: 'Enter full street address',
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
                    label: 'City *',
                    hint: 'City',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'City is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _stateController,
                    label: 'State *',
                    hint: 'State',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'State is required';
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
            const SizedBox(height: 20),
            // Auto-detect location button
            OutlinedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Auto-detect Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    hint: 'e.g. 23.0225',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    hint: 'e.g. 72.5714',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _detectLocation() {
    // Placeholder for location detection
    // In production, use geolocator package
    SnackbarUtils.showInfo(
      context,
      'Location detection coming soon. Please enter coordinates manually.',
    );
  }

  // ─── Step 3: Settings ───────────────────────────────────────────────

  Step _buildStep3() {
    return Step(
      title: const Text('Settings', style: AppTextStyles.labelLarge),
      subtitle: const Text('Commission, policies & amenities'),
      isActive: _currentStep >= 2,
      state: StepState.indexed,
      content: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            AppTextField(
              controller: _commissionController,
              label: 'Commission Percentage',
              hint: 'Default: 20%',
              prefixIcon: Icons.percent,
              keyboardType: TextInputType.number,
              maxLength: 3,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final val = int.tryParse(value);
                  if (val == null || val < 0 || val > 100) {
                    return 'Enter a value between 0 and 100';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _advanceTimeController,
              label: 'Booking Advance Time (minutes)',
              hint: 'Minimum time before a booking',
              prefixIcon: Icons.schedule,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _cancellationPolicyController,
              label: 'Cancellation Policy',
              hint: 'Describe your cancellation terms',
              prefixIcon: Icons.policy_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Amenities', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Select the amenities your salon offers',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            _buildAmenityChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenityOptions.map((amenity) {
        final label = amenity['label'] as String;
        final icon = amenity['icon'] as IconData;
        final isSelected = _selectedAmenities.contains(label);

        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          checkmarkColor: AppColors.white,
          labelStyle: TextStyle(
            color: isSelected
                ? AppColors.white
                : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAmenities.add(label);
              } else {
                _selectedAmenities.remove(label);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
