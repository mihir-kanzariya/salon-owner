import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import 'package:provider/provider.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../providers/salon_provider.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _salonId;
  List<dynamic> _members = [];
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      setState(() => _isLoading = true);

      _salonId = context.read<SalonProvider>().salonId;

      if (_salonId != null) {
        final teamRes = await _api.get('${ApiConfig.salonDetail}/$_salonId/members');
        _members = teamRes['data'] ?? [];
      }

      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredMembers {
    if (_filterRole == 'all') return _members;
    return _members.where((m) => m['role'] == _filterRole).toList();
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'manager':
        return AppColors.accent;
      case 'receptionist':
        return AppColors.textSecondary;
      case 'stylist':
      default:
        return AppColors.primary;
    }
  }

  Color _roleBgColor(String? role) {
    switch (role) {
      case 'manager':
        return AppColors.accentLight;
      case 'receptionist':
        return AppColors.softSurface;
      case 'stylist':
      default:
        return AppColors.primary.withValues(alpha: 0.1);
    }
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return 'Stylist';
    return role[0].toUpperCase() + role.substring(1);
  }

  String _getInitial(Map<String, dynamic> member) {
    final user = member['user'];
    if (user != null && user['name'] != null && (user['name'] as String).isNotEmpty) {
      return user['name'][0].toUpperCase();
    }
    final name = member['name'];
    if (name != null && (name as String).isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'T';
  }

  String _getName(Map<String, dynamic> member) {
    final user = member['user'];
    if (user != null && user['name'] != null) return user['name'];
    return member['name'] ?? 'Team Member';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeam,
          ),
        ],
      ),
      body: _isLoading
          ? const SkeletonList(child: MemberCardSkeleton())
          : _members.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Team Members',
                  subtitle: 'Add stylists, managers, and receptionists to your salon team.',
                  actionText: 'Add Member',
                  onAction: () => _navigateToAddStylist(),
                )
              : Column(
                  children: [
                    // Role filter chips
                    _buildFilterChips(),

                    // Members list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadTeam,
                        child: _filteredMembers.isEmpty
                            ? Center(
                                child: Text(
                                  _filterRole == 'all' ? 'No team members found' : 'No ${_filterRole}s found',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _filteredMembers.length,
                                itemBuilder: (context, index) {
                                  return _buildMemberCard(_filteredMembers[index]);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddStylist(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: AppColors.white),
        label: const Text('Add Member', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilterChips() {
    final roles = ['all', 'stylist', 'manager', 'receptionist'];
    final labels = ['All', 'Stylists', 'Managers', 'Receptionists'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(roles.length, (index) {
            final isSelected = _filterRole == roles[index];
            return Padding(
              padding: EdgeInsets.only(right: index < roles.length - 1 ? 8 : 0),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  labels[index],
                  style: TextStyle(
                    color: isSelected ? AppColors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.cardBackground,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _filterRole = roles[index]);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final role = member['role'] as String?;
    final isActive = member['is_active'] ?? true;
    final specializations = member['specializations'] as List<dynamic>? ?? [];
    final commission = member['commission_percentage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToEditStylist(member),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _roleColor(role).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitial(member),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _roleColor(role),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Active status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getName(member),
                              style: AppTextStyles.labelLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.success : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isActive ? AppColors.success : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Role chip
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _roleBgColor(role),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatRole(role),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _roleColor(role),
                              ),
                            ),
                          ),
                          if (commission != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$commission% commission',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),

                      // Specializations
                      if (specializations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: specializations.map<Widget>((spec) {
                            final name = spec is Map ? (spec['name'] ?? spec.toString()) : spec.toString();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.softSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAddStylist() {
    Navigator.pushNamed(
      context,
      '/salon/add-stylist',
      arguments: {'salon_id': _salonId},
    ).then((result) {
      if (result == true) _loadTeam();
    });
  }

  void _navigateToEditStylist(Map<String, dynamic> member) {
    Navigator.pushNamed(
      context,
      '/salon/add-stylist',
      arguments: {
        'salon_id': _salonId,
        'stylist_id': member['id'],
        'stylist': member,
      },
    ).then((result) {
      if (result == true) _loadTeam();
    });
  }
}
