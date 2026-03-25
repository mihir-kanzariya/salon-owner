import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../services/api_service.dart';
import '../../../../services/supabase_chat_service.dart';
import '../../../../config/api_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String? _error;
  SupabaseChatSubscription? _userSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToUnreadUpdates();
  }

  @override
  void dispose() {
    _userSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _subscribeToUnreadUpdates() async {
    final chatService = SupabaseChatService();
    if (!chatService.isReady) {
      await chatService.initFromBackend();
    }
    if (!chatService.isReady || !mounted) return;

    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return;

    _userSubscription = chatService.subscribeToUserChannel(
      userId: currentUserId,
      onUnreadUpdate: (roomId, unreadCount) {
        if (!mounted) return;
        setState(() {
          for (var room in _rooms) {
            if (room['id'] == roomId) {
              room['unread_count'] = unreadCount;
              break;
            }
          }
        });
      },
    );
  }

  Future<void> _load() async {
    try {
      if (mounted) setState(() { _isLoading = true; _error = null; });
      final response = await _api.get(ApiConfig.chatRooms);
      if (!mounted) return;
      _rooms = response['data'] ?? [];
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is ApiException ? e.message : 'Failed to load conversations';
      });
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final minute = date.minute.toString().padLeft(2, '0');
        final period = date.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[date.weekday - 1];
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList(child: ChatListItemSkeleton(), count: 5);
    }

    if (_error != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Could not load messages',
        subtitle: _error!,
        actionText: 'Retry',
        onAction: _load,
      );
    }

    if (_rooms.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations',
        subtitle: 'Chat will appear here after you make a booking',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _rooms.length,
        separatorBuilder: (_, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final room = _rooms[index];
          final salon = room['salon'];
          final customer = room['customer'];
          final booking = room['booking'];
          final unreadCount = int.tryParse(room['unread_count']?.toString() ?? '0') ?? 0;
          final isActive = room['is_active'] == true;
          final lastMessage = room['last_message']?.toString();

          final currentUserId = context.read<AuthProvider>().user?.id;
          final isCustomer = customer?['id'] == currentUserId;
          String displayName;
          String avatarInitial;
          if (isCustomer) {
            final stylistName = booking?['stylist']?['user']?['name'];
            displayName = salon?['name'] ?? 'Salon';
            if (stylistName != null && stylistName.toString().isNotEmpty) {
              displayName = '$displayName • $stylistName';
            }
            avatarInitial = (salon?['name'] ?? 'S')[0].toUpperCase();
          } else {
            displayName = customer?['name'] ?? 'Customer';
            avatarInitial = displayName[0].toUpperCase();
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                avatarInitial,
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: unreadCount > 0
                        ? AppTextStyles.labelLarge
                        : AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(room['updated_at']?.toString()),
                  style: TextStyle(
                    fontSize: 11,
                    color: unreadCount > 0 ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage != null && lastMessage.isNotEmpty
                        ? lastMessage
                        : 'Booking #${booking?['booking_number'] ?? ''}',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Closed', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  )
                else if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(fontSize: 11, color: AppColors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    roomId: room['id'],
                    displayName: displayName,
                  ),
                ),
              );
              _load();
            },
          );
        },
      ),
    );
  }
}
