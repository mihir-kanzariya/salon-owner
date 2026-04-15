import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class ServiceStylistsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final num basePrice;
  final int baseDuration;
  final String salonId;

  const ServiceStylistsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.basePrice,
    required this.baseDuration,
    required this.salonId,
  });

  @override
  State<ServiceStylistsScreen> createState() => _ServiceStylistsScreenState();
}

class _ServiceStylistsScreenState extends State<ServiceStylistsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isAssigningAll = false;
  String? _errorMessage;

  /// Stylists currently assigned to this service.
  List<Map<String, dynamic>> _assignedStylists = [];

  /// All salon members (to find unassigned ones).
  List<Map<String, dynamic>> _allMembers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ------------------------------------------------------------------
  // Data loading
  // ------------------------------------------------------------------

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        _api.get('${ApiConfig.services}/${widget.serviceId}/stylists'),
        _api.get('${ApiConfig.salonDetail}/${widget.salonId}/members'),
      ]);

      final assignedData = results[0]['data'];
      final membersData = results[1]['data'];

      _assignedStylists = List<Map<String, dynamic>>.from(
        (assignedData is List ? assignedData : []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      _allMembers = List<Map<String, dynamic>>.from(
        (membersData is List ? membersData : []).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Set<String> get _assignedMemberIds {
    return _assignedStylists
        .map((s) => (s['member_id'] ?? s['id'] ?? '').toString())
        .toSet();
  }

  List<Map<String, dynamic>> get _unassignedMembers {
    final assigned = _assignedMemberIds;
    return _allMembers.where((m) {
      final memberId = m['id'].toString();
      final role = (m['role'] ?? '').toString();
      return !assigned.contains(memberId) && role == 'stylist';
    }).toList();
  }

  String _getMemberName(Map<String, dynamic> member) {
    final user = member['user'];
    if (user != null && user['name'] != null) return user['name'];
    return member['name'] ?? 'Team Member';
  }

  String _getStylistName(Map<String, dynamic> stylist) {
    // assigned stylist objects may have nested member or user
    final member = stylist['member'] ?? stylist;
    final user = member['user'] ?? stylist['user'];
    if (user != null && user['name'] != null) return user['name'];
    return member['name'] ?? stylist['name'] ?? 'Stylist';
  }

  String _getInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  num _effectivePrice(Map<String, dynamic> stylist) {
    final customPrice = stylist['custom_price'];
    if (customPrice != null) return customPrice is num ? customPrice : num.tryParse(customPrice.toString()) ?? widget.basePrice;
    return widget.basePrice;
  }

  int _effectiveDuration(Map<String, dynamic> stylist) {
    final customDuration = stylist['custom_duration_minutes'];
    if (customDuration != null) return customDuration is int ? customDuration : int.tryParse(customDuration.toString()) ?? widget.baseDuration;
    return widget.baseDuration;
  }

  String _formatPrice(num price) {
    if (price == price.truncateToDouble()) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _assignStylist(String memberId) async {
    try {
      await _api.put(
        '${ApiConfig.services}/${widget.serviceId}/stylists',
        body: {'stylist_ids': [memberId]},
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stylist assigned'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _assignAllStylists() async {
    final allStylistIds = _allMembers
        .where((m) => (m['role'] ?? '').toString() == 'stylist')
        .map((m) => m['id'].toString())
        .toList();

    if (allStylistIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stylists found in your salon'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isAssigningAll = true);
    try {
      await _api.put(
        '${ApiConfig.services}/${widget.serviceId}/stylists',
        body: {'stylist_ids': allStylistIds},
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All stylists assigned'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign all: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAssigningAll = false);
    }
  }

  Future<void> _toggleStylistActive(Map<String, dynamic> stylist, bool value) async {
    final memberId = (stylist['member_id'] ?? stylist['id']).toString();
    try {
      await _api.patch(
        '${ApiConfig.services}/${widget.serviceId}/stylists/$memberId',
        body: {'is_active': value},
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _removeStylist(Map<String, dynamic> stylist) async {
    final memberId = (stylist['member_id'] ?? stylist['id']).toString();
    final name = _getStylistName(stylist);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Stylist'),
        content: Text('Remove "$name" from this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('${ApiConfig.services}/${widget.serviceId}/stylists/$memberId');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stylist removed'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showEditOverrideSheet(Map<String, dynamic> stylist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditOverrideSheet(
        serviceId: widget.serviceId,
        memberId: (stylist['member_id'] ?? stylist['id']).toString(),
        stylistName: _getStylistName(stylist),
        basePrice: widget.basePrice,
        baseDuration: widget.baseDuration,
        currentPrice: stylist['custom_price'],
        currentDuration: stylist['custom_duration_minutes'],
        currentSkillLevel: stylist['skill_level'],
        onSaved: () => _loadData(),
      ),
    );
  }

  void _showCopySheet() {
    if (_assignedStylists.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 assigned stylists to copy settings'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopyToStylistsSheet(
        serviceId: widget.serviceId,
        assignedStylists: _assignedStylists,
        getStylistName: _getStylistName,
        effectivePrice: _effectivePrice,
        effectiveDuration: _effectiveDuration,
        onCopied: () => _loadData(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.serviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy settings',
            onPressed: _isLoading ? null : _showCopySheet,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading stylists...')
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Something went wrong', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Retry',
                        width: 120,
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info banner
                    _buildInfoBanner(),

                    // Stylists list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          children: [
                            if (_assignedStylists.isNotEmpty) ...[
                              _buildSectionHeader('Assigned Stylists', _assignedStylists.length),
                              const SizedBox(height: 8),
                              ..._assignedStylists.map(_buildAssignedStylistCard),
                            ],
                            if (_unassignedMembers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildSectionHeader('Unassigned Stylists', _unassignedMembers.length),
                              const SizedBox(height: 8),
                              ..._unassignedMembers.map(_buildUnassignedMemberCard),
                            ],
                            if (_assignedStylists.isEmpty && _unassignedMembers.isEmpty) ...[
                              const SizedBox(height: 48),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                                    const SizedBox(height: 12),
                                    const Text('No stylists in your salon', style: AppTextStyles.bodyMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add team members first',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Bottom button
                    if (_unassignedMembers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: AppButton(
                          text: 'Assign to All Stylists',
                          icon: Icons.group_add,
                          isLoading: _isAssigningAll,
                          onPressed: _isAssigningAll ? null : _assignAllStylists,
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            'Base: \u20B9${_formatPrice(widget.basePrice)} \u00B7 ${widget.baseDuration} min',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
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
        Text(
          title.toUpperCase(),
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Text('($count)', style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildAssignedStylistCard(Map<String, dynamic> stylist) {
    final name = _getStylistName(stylist);
    final price = _effectivePrice(stylist);
    final duration = _effectiveDuration(stylist);
    final skillLevel = stylist['skill_level']?.toString();
    final isActive = stylist['is_active'] != false;
    final hasCustomPrice = stylist['custom_price'] != null;
    final hasCustomDuration = stylist['custom_duration_minutes'] != null;

    return Container(
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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.softSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitial(name),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\u20B9${_formatPrice(price)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: hasCustomPrice ? AppColors.accent : AppColors.textSecondary,
                        fontWeight: hasCustomPrice ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text(
                      '${duration}m',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: hasCustomDuration ? AppColors.accent : AppColors.textSecondary,
                        fontWeight: hasCustomDuration ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (skillLevel != null && skillLevel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _SkillLevelBadge(level: skillLevel),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Active toggle
          SizedBox(
            height: 28,
            child: Switch(
              value: isActive,
              onChanged: (val) => _toggleStylistActive(stylist, val),
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          // Edit button
          InkWell(
            onTap: () => _showEditOverrideSheet(stylist),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
            ),
          ),

          // Remove button
          InkWell(
            onTap: () => _removeStylist(stylist),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 20, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedMemberCard(Map<String, dynamic> member) {
    final name = _getMemberName(member);
    final memberId = member['id'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitial(name),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: AppTextStyles.labelLarge),
          ),
          TextButton(
            onPressed: () => _assignStylist(memberId),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Skill Level Badge
// ====================================================================

class _SkillLevelBadge extends StatelessWidget {
  final String level;
  const _SkillLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (level.toLowerCase()) {
      case 'expert':
        color = AppColors.primary;
        break;
      case 'senior':
        color = AppColors.accent;
        break;
      case 'junior':
        color = AppColors.textSecondary;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ====================================================================
// Edit Override Bottom Sheet
// ====================================================================

class _EditOverrideSheet extends StatefulWidget {
  final String serviceId;
  final String memberId;
  final String stylistName;
  final num basePrice;
  final int baseDuration;
  final dynamic currentPrice;
  final dynamic currentDuration;
  final String? currentSkillLevel;
  final VoidCallback onSaved;

  const _EditOverrideSheet({
    required this.serviceId,
    required this.memberId,
    required this.stylistName,
    required this.basePrice,
    required this.baseDuration,
    required this.currentPrice,
    required this.currentDuration,
    required this.currentSkillLevel,
    required this.onSaved,
  });

  @override
  State<_EditOverrideSheet> createState() => _EditOverrideSheetState();
}

class _EditOverrideSheetState extends State<_EditOverrideSheet> {
  final ApiService _api = ApiService();
  late TextEditingController _priceController;
  late bool _useBasePrice;
  late bool _useBaseDuration;
  late int _selectedDuration;
  String? _skillLevel;
  bool _isSaving = false;

  static const List<int> _durationOptions = [15, 30, 45, 60, 90, 120];
  static const List<String?> _skillLevelOptions = [null, 'junior', 'senior', 'expert'];

  @override
  void initState() {
    super.initState();
    _useBasePrice = widget.currentPrice == null;
    _useBaseDuration = widget.currentDuration == null;
    _priceController = TextEditingController(
      text: widget.currentPrice != null
          ? _formatNum(widget.currentPrice)
          : _formatNum(widget.basePrice),
    );
    _selectedDuration = widget.currentDuration is int
        ? widget.currentDuration as int
        : int.tryParse(widget.currentDuration?.toString() ?? '') ?? widget.baseDuration;
    if (!_durationOptions.contains(_selectedDuration)) {
      _selectedDuration = widget.baseDuration;
    }
    _skillLevel = widget.currentSkillLevel;
  }

  String _formatNum(dynamic n) {
    if (n == null) return '';
    final num p = n is num ? n : num.tryParse(n.toString()) ?? 0;
    if (p == p.truncateToDouble()) return p.toInt().toString();
    return p.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'custom_price': _useBasePrice ? null : num.tryParse(_priceController.text.trim()),
        'custom_duration_minutes': _useBaseDuration ? null : _selectedDuration,
        'skill_level': _skillLevel,
      };
      await _api.patch(
        '${ApiConfig.services}/${widget.serviceId}/stylists/${widget.memberId}',
        body: body,
      );
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Override saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Edit Override - ${widget.stylistName}',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 20),

            // Price
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    enabled: !_useBasePrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Price (\u20B9)',
                      prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: _useBasePrice ? AppColors.softSurface : AppColors.cardBackground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Checkbox(
                      value: _useBasePrice,
                      onChanged: (val) {
                        setState(() {
                          _useBasePrice = val ?? false;
                          if (_useBasePrice) {
                            _priceController.text = _formatNum(widget.basePrice);
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const Text('Base', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _durationOptions.contains(_selectedDuration) ? _selectedDuration : _durationOptions.first,
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      prefixIcon: const Icon(Icons.schedule, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: _useBaseDuration ? AppColors.softSurface : AppColors.cardBackground,
                    ),
                    items: _durationOptions.map((min) {
                      final label = min >= 60
                          ? '${min ~/ 60} hr${min > 60 ? ' ${min % 60} min' : ''}'
                          : '$min min';
                      return DropdownMenuItem(value: min, child: Text(label));
                    }).toList(),
                    onChanged: _useBaseDuration
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedDuration = val);
                          },
                    dropdownColor: AppColors.cardBackground,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Checkbox(
                      value: _useBaseDuration,
                      onChanged: (val) {
                        setState(() {
                          _useBaseDuration = val ?? false;
                          if (_useBaseDuration) {
                            _selectedDuration = widget.baseDuration;
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const Text('Base', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Skill level
            DropdownButtonFormField<String?>(
              initialValue: _skillLevel,
              decoration: InputDecoration(
                labelText: 'Skill Level',
                prefixIcon: const Icon(Icons.star_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
              items: _skillLevelOptions.map((level) {
                final label = level == null
                    ? 'None'
                    : level[0].toUpperCase() + level.substring(1);
                return DropdownMenuItem(value: level, child: Text(label));
              }).toList(),
              onChanged: (val) => setState(() => _skillLevel = val),
              dropdownColor: AppColors.cardBackground,
            ),
            const SizedBox(height: 24),

            AppButton(
              text: 'Save',
              icon: Icons.check,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Copy to Stylists Bottom Sheet
// ====================================================================

class _CopyToStylistsSheet extends StatefulWidget {
  final String serviceId;
  final List<Map<String, dynamic>> assignedStylists;
  final String Function(Map<String, dynamic>) getStylistName;
  final num Function(Map<String, dynamic>) effectivePrice;
  final int Function(Map<String, dynamic>) effectiveDuration;
  final VoidCallback onCopied;

  const _CopyToStylistsSheet({
    required this.serviceId,
    required this.assignedStylists,
    required this.getStylistName,
    required this.effectivePrice,
    required this.effectiveDuration,
    required this.onCopied,
  });

  @override
  State<_CopyToStylistsSheet> createState() => _CopyToStylistsSheetState();
}

class _CopyToStylistsSheetState extends State<_CopyToStylistsSheet> {
  final ApiService _api = ApiService();
  String? _sourceMemberId;
  final Set<String> _targetMemberIds = {};
  bool _isCopying = false;

  Map<String, dynamic>? get _sourceStylist {
    if (_sourceMemberId == null) return null;
    try {
      return widget.assignedStylists.firstWhere(
        (s) => (s['member_id'] ?? s['id']).toString() == _sourceMemberId,
      );
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _availableTargets {
    return widget.assignedStylists
        .where((s) => (s['member_id'] ?? s['id']).toString() != _sourceMemberId)
        .toList();
  }

  String _formatPrice(num price) {
    if (price == price.truncateToDouble()) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  Future<void> _copy() async {
    if (_sourceMemberId == null || _targetMemberIds.isEmpty) return;

    setState(() => _isCopying = true);
    try {
      await _api.post(
        '${ApiConfig.services}/${widget.serviceId}/copy-to-stylists',
        body: {
          'source_member_id': _sourceMemberId,
          'target_member_ids': _targetMemberIds.toList(),
        },
      );
      widget.onCopied();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings copied successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isCopying = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _sourceStylist;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Copy Settings', style: AppTextStyles.h3),
            const SizedBox(height: 20),

            // Source dropdown
            DropdownButtonFormField<String>(
              initialValue: _sourceMemberId,
              decoration: InputDecoration(
                labelText: 'Copy from',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
              items: widget.assignedStylists.map((s) {
                final id = (s['member_id'] ?? s['id']).toString();
                return DropdownMenuItem(
                  value: id,
                  child: Text(widget.getStylistName(s)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _sourceMemberId = val;
                  _targetMemberIds.clear();
                });
              },
              dropdownColor: AppColors.cardBackground,
            ),

            // Show what will be copied
            if (source != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Will copy: \u20B9${_formatPrice(widget.effectivePrice(source))} \u00B7 ${widget.effectiveDuration(source)} min',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target checkboxes
              Text('Copy to:', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              ..._availableTargets.map((s) {
                final id = (s['member_id'] ?? s['id']).toString();
                return CheckboxListTile(
                  value: _targetMemberIds.contains(id),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _targetMemberIds.add(id);
                      } else {
                        _targetMemberIds.remove(id);
                      }
                    });
                  },
                  title: Text(widget.getStylistName(s), style: AppTextStyles.labelLarge),
                  subtitle: Text(
                    '\u20B9${_formatPrice(widget.effectivePrice(s))} \u00B7 ${widget.effectiveDuration(s)} min',
                    style: AppTextStyles.caption,
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              }),
            ],

            const SizedBox(height: 20),

            AppButton(
              text: 'Copy Settings',
              icon: Icons.copy,
              isLoading: _isCopying,
              onPressed: (_sourceMemberId == null || _targetMemberIds.isEmpty || _isCopying)
                  ? null
                  : _copy,
            ),
          ],
        ),
      ),
    );
  }
}
