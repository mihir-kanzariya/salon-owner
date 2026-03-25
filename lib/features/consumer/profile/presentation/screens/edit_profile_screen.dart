import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedGender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email ?? '';
      _selectedGender = user.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      _nameController.text.trim(),
      _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      _selectedGender,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      SnackbarUtils.showSuccess(context, 'Profile updated successfully');
      Navigator.pop(context, true);
    } else {
      SnackbarUtils.showError(
        context,
        auth.error.isNotEmpty ? auth.error : 'Failed to update profile',
      );
    }
  }

  bool _isUploadingPhoto = false;

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
        await ApiService().put(ApiConfig.userProfile, body: {'profile_photo': url});
        await context.read<AuthProvider>().refreshProfile();
        if (mounted) SnackbarUtils.showSuccess(context, 'Photo updated');
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),

            // Profile photo section
            Center(
              child: GestureDetector(
                onTap: _onPhotoTap,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: user?.profilePhoto != null
                          ? NetworkImage(ApiConfig.imageUrl(user!.profilePhoto)!)
                          : null,
                      child: _isUploadingPhoto
                          ? const CircularProgressIndicator(color: AppColors.white)
                          : user?.profilePhoto == null
                              ? Text(
                                  (user?.name ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBackground,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tap to change photo',
                style: AppTextStyles.caption,
              ),
            ),

            const SizedBox(height: 28),

            // Personal information card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
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
                      const Text('Personal Information',
                          style: AppTextStyles.h4),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  AppTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your name',
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Email field
                  AppTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter your email (optional)',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Phone (read-only)
                  AppTextField(
                    label: 'Phone Number',
                    hint: user?.phone ?? '',
                    prefixIcon: Icons.phone_outlined,
                    enabled: false,
                    controller: TextEditingController(
                      text: '+91 ${user?.phone ?? ''}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Phone number cannot be changed',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Gender selection card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      const Text('Gender', style: AppTextStyles.h4),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGenderChips(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            AppButton(
              text: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveProfile,
              icon: Icons.check,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChips() {
    final genders = ['Male', 'Female', 'Other'];
    final genderIcons = {
      'Male': Icons.male,
      'Female': Icons.female,
      'Other': Icons.transgender,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: genders.map((gender) {
        final value = gender.toLowerCase();
        final isSelected = _selectedGender == value;

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                genderIcons[gender],
                size: 18,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(gender),
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
            setState(() {
              _selectedGender = selected ? value : null;
            });
          },
        );
      }).toList(),
    );
  }
}
