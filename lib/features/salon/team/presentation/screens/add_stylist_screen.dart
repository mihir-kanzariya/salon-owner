import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../config/api_config.dart';

class AddStylistScreen extends StatefulWidget {
  final String? salonId;
  final String? stylistId;
  final Map<String, dynamic>? existingStylist;

  const AddStylistScreen({
    super.key,
    this.salonId,
    this.stylistId,
    this.existingStylist,
  });

  @override
  State<AddStylistScreen> createState() => _AddStylistScreenState();
}

class _AddStylistScreenState extends State<AddStylistScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _commissionController = TextEditingController();

  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLoadingServices = true;
  bool _isUploadingPhoto = false;

  // Found user
  Map<String, dynamic>? _foundUser;
  String? _searchError;
  String? _profilePhotoUrl;

  // Form state
  String _selectedRole = 'stylist';
  final List<String> _selectedSpecializations = [];
  List<dynamic> _availableServices = [];

  // Edit mode
  bool get _isEditMode => widget.stylistId != null;

  @override
  void initState() {
    super.initState();
    _loadServices();
    if (_isEditMode && widget.existingStylist != null) {
      _populateEditData();
    }
  }

  void _populateEditData() {
    final stylist = widget.existingStylist!;
    _selectedRole = stylist['role'] ?? 'stylist';
    _commissionController.text = (stylist['commission_percentage'] ?? '').toString();

    final specs = stylist['specializations'] as List<dynamic>? ?? [];
    for (final spec in specs) {
      if (spec is Map) {
        _selectedSpecializations.add(spec['id']?.toString() ?? spec['name']?.toString() ?? '');
      } else {
        _selectedSpecializations.add(spec.toString());
      }
    }

    // Pre-fill user data in edit mode
    final user = stylist['user'];
    if (user != null) {
      _foundUser = user;
      _phoneController.text = user['phone'] ?? '';
      _profilePhotoUrl = user['profile_photo'];
    }
  }

  Future<void> _loadServices() async {
    try {
      setState(() => _isLoadingServices = true);

      final salonId = widget.salonId;
      if (salonId != null) {
        final res = await _api.get(
          '${ApiConfig.services}/salon/$salonId',
        );
        _availableServices = res['data'] ?? [];
      }

      setState(() => _isLoadingServices = false);
    } catch (_) {
      setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _searchError = 'Enter a valid 10-digit phone number');
      return;
    }

    try {
      setState(() {
        _isSearching = true;
        _searchError = null;
        _foundUser = null;
      });

      final salonId = widget.salonId;
      final res = await _api.post(
        '${ApiConfig.salonDetail}/$salonId/search-member',
        body: {'phone': phone},
      );

      final userData = res['data'];
      if (userData != null) {
        setState(() {
          _foundUser = userData;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchError = 'No user found with this phone number';
          _isSearching = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _searchError = e.message;
        _isSearching = false;
      });
    } catch (_) {
      setState(() {
        _searchError = 'Failed to search. Please try again.';
        _isSearching = false;
      });
    }
  }

  void _toggleSpecialization(String serviceId) {
    setState(() {
      if (_selectedSpecializations.contains(serviceId)) {
        _selectedSpecializations.remove(serviceId);
      } else {
        _selectedSpecializations.add(serviceId);
      }
    });
  }

  Future<void> _onPhotoTap() async {
    if (_isUploadingPhoto) return;

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

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await UploadService().pickAndUpload(
        folder: 'profiles',
        source: source,
        preset: UploadPreset.avatar,
      );
      if (url != null && mounted) {
        setState(() => _profilePhotoUrl = url);

        // If in edit mode, update immediately via backend
        if (_isEditMode && widget.stylistId != null) {
          await _api.put(
            '${ApiConfig.stylists}/${widget.stylistId}',
            body: {'profile_photo': url},
          );
          if (mounted) SnackbarUtils.showSuccess(context, 'Photo updated');
        }
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_foundUser == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a user first'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      final commission = double.tryParse(_commissionController.text.trim()) ?? 0;

      if (_isEditMode) {
        // Update existing stylist
        await _api.put(
          '${ApiConfig.stylists}/${widget.stylistId}',
          body: {
            'role': _selectedRole,
            'specializations': _selectedSpecializations,
            'commission_percentage': commission,
          },
        );
      } else {
        // Create new stylist
        await _api.post(
          ApiConfig.stylists,
          body: {
            'salon_id': widget.salonId,
            'user_id': _foundUser!['id'],
            'role': _selectedRole,
            'specializations': _selectedSpecializations,
            'commission_percentage': commission,
          },
        );
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Text(_isEditMode ? 'Team member updated' : 'Team member added'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Team Member' : 'Add Team Member'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.schedule),
              tooltip: 'Manage Availability',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/salon/stylist-availability',
                  arguments: widget.stylistId,
                );
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile photo section (edit mode or after user found)
              if (_isEditMode || _foundUser != null) ...[
                _buildPhotoSection(),
                const SizedBox(height: 24),
              ],

              // Search user by phone
              _buildSearchSection(),
              const SizedBox(height: 24),

              // Role selection
              _buildRoleSection(),
              const SizedBox(height: 24),

              // Specializations
              _buildSpecializationsSection(),
              const SizedBox(height: 24),

              // Commission
              _buildCommissionSection(),
              const SizedBox(height: 32),

              // Save button
              AppButton(
                text: _isEditMode ? 'Update Member' : 'Add Member',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final name = _foundUser?['name'] ?? 'U';
    final photoUrl = _profilePhotoUrl;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditMode ? _onPhotoTap : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(ApiConfig.imageUrl(photoUrl) ?? photoUrl)
                      : null,
                  child: _isUploadingPhoto
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : photoUrl == null
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                ),
                if (_isEditMode)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cardBackground, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: AppColors.white),
                    ),
                  ),
              ],
            ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 6),
            Text('Tap to change photo', style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Find User', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          const Text(
            'Search by phone number to add an existing user to your team.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter 10-digit phone',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_isEditMode,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isEditMode || _isSearching ? null : _searchByPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                            ),
                          )
                        : const Icon(Icons.search, color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),

          // Search error
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Found user card
          if (_foundUser != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (_foundUser!['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
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
                          _foundUser!['name'] ?? 'Unknown User',
                          style: AppTextStyles.labelLarge,
                        ),
                        if (_foundUser!['phone'] != null)
                          Text(
                            _foundUser!['phone'],
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Role', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          const Text(
            'Select the role for this team member.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: 'stylist', child: Text('Stylist')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
              DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedRole = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Specializations', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          const Text(
            'Select services this member specializes in.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_isLoadingServices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (_availableServices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.softSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No services found. Add services to your salon first.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableServices.map<Widget>((service) {
                final serviceId = service['id']?.toString() ?? '';
                final serviceName = service['name'] ?? 'Service';
                final isSelected = _selectedSpecializations.contains(serviceId);

                return FilterChip(
                  selected: isSelected,
                  label: Text(
                    serviceName,
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.softSurface,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  checkmarkColor: AppColors.white,
                  onSelected: (_) => _toggleSpecialization(serviceId),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCommissionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Commission', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          const Text(
            'Set the commission percentage for this member.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _commissionController,
            label: 'Commission Percentage',
            hint: 'e.g. 30',
            prefixIcon: Icons.percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final num = double.tryParse(value);
                if (num == null || num < 0 || num > 100) {
                  return 'Enter a value between 0 and 100';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
