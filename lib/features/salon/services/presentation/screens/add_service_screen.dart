import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class AddServiceScreen extends StatefulWidget {
  final String salonId;
  final String? serviceId;

  const AddServiceScreen({
    super.key,
    required this.salonId,
    this.serviceId,
  });

  bool get isEditMode => serviceId != null;

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  // Form state
  String? _selectedCategoryId;
  int _durationMinutes = 30;
  String _genderType = 'unisex';
  bool _isActive = true;

  // Screen state
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _categories = [];

  static const List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Data loading
  // ------------------------------------------------------------------

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Load categories
      final catRes = await _api.get(ApiConfig.serviceCategories);
      final catList = catRes['data'] ?? [];
      _categories = List<Map<String, dynamic>>.from(
        catList.map((c) => Map<String, dynamic>.from(c as Map)),
      );

      // If edit mode, load existing service
      if (widget.isEditMode) {
        final svcRes =
            await _api.get('${ApiConfig.services}/${widget.serviceId}');
        final svc = svcRes['data'] as Map<String, dynamic>? ?? {};

        _nameController.text = svc['name']?.toString() ?? '';
        _descriptionController.text = svc['description']?.toString() ?? '';
        _priceController.text = _extractPrice(svc['price']);
        _selectedCategoryId = (svc['category_id'] ?? svc['category']?['id'])
            ?.toString();
        _durationMinutes = svc['duration_minutes'] is int
            ? svc['duration_minutes']
            : int.tryParse(svc['duration_minutes']?.toString() ?? '') ?? 30;
        _genderType = (svc['gender'] ?? svc['gender_type'])?.toString() ?? 'unisex';
        _isActive = svc['is_active'] == true;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _extractPrice(dynamic price) {
    if (price == null) return '';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }
    return p.toStringAsFixed(2);
  }

  // ------------------------------------------------------------------
  // Save
  // ------------------------------------------------------------------

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final body = <String, dynamic>{
      'salon_id': widget.salonId,
      'category_id': _selectedCategoryId,
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'duration_minutes': _durationMinutes,
      'price': num.tryParse(_priceController.text.trim()) ?? 0,
      'gender': _genderType,
      'is_active': _isActive,
    };

    try {
      if (widget.isEditMode) {
        await _api.put(
          '${ApiConfig.services}/${widget.serviceId}',
          body: body,
        );
      } else {
        await _api.post(ApiConfig.services, body: body);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Service updated successfully'
                : 'Service created successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
        title: Text(widget.isEditMode ? 'Edit Service' : 'Add Service'),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Name ---
                    AppTextField(
                      controller: _nameController,
                      label: 'Service Name',
                      hint: 'e.g. Men\'s Haircut',
                      prefixIcon: Icons.content_cut,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Service name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Description ---
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Brief description of the service',
                      prefixIcon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // --- Category dropdown ---
                    _buildCategoryDropdown(),
                    const SizedBox(height: 16),

                    // --- Duration dropdown ---
                    _buildDurationDropdown(),
                    const SizedBox(height: 16),

                    // --- Price ---
                    AppTextField(
                      controller: _priceController,
                      label: 'Price (\u20B9)',
                      hint: 'e.g. 500',
                      prefixIcon: Icons.currency_rupee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Price is required';
                        }
                        final parsed = num.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Gender type ---
                    const Text('Gender Type', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 10),
                    _buildGenderChips(),
                    const SizedBox(height: 24),

                    // --- Active toggle ---
                    _buildActiveToggle(),
                    const SizedBox(height: 32),

                    // --- Save button ---
                    AppButton(
                      text: widget.isEditMode ? 'Update Service' : 'Save Service',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveService,
                      icon: widget.isEditMode ? Icons.check : Icons.add,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ------------------------------------------------------------------
  // Widgets
  // ------------------------------------------------------------------

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(
          Icons.category_outlined,
          color: AppColors.textMuted,
          size: 22,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
      ),
      items: _categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat['id'].toString(),
          child: Text(
            cat['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Category is required';
        }
        return null;
      },
      dropdownColor: AppColors.cardBackground,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
    );
  }

  Widget _buildDurationDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _durationOptions.contains(_durationMinutes)
          ? _durationMinutes
          : _durationOptions.first,
      decoration: InputDecoration(
        labelText: 'Duration',
        prefixIcon: const Icon(
          Icons.schedule,
          color: AppColors.textMuted,
          size: 22,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
      ),
      items: _durationOptions.map((min) {
        final label =
            min >= 60 ? '${min ~/ 60} hr${min > 60 ? ' ${min % 60} min' : ''}' : '$min min';
        return DropdownMenuItem<int>(
          value: min,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _durationMinutes = value);
      },
      dropdownColor: AppColors.cardBackground,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
    );
  }

  Widget _buildGenderChips() {
    const options = ['men', 'women', 'unisex'];
    const labels = {'men': 'Men', 'women': 'Women', 'unisex': 'Unisex'};
    const icons = {
      'men': Icons.male,
      'women': Icons.female,
      'unisex': Icons.group,
    };

    return Row(
      children: options.map((option) {
        final isSelected = _genderType == option;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ChoiceChip(
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
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            showCheckmark: false,
            onSelected: (_) => setState(() => _genderType = option),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active', style: AppTextStyles.labelLarge),
              const SizedBox(height: 2),
              Text(
                _isActive
                    ? 'Service is visible to customers'
                    : 'Service is hidden from customers',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
