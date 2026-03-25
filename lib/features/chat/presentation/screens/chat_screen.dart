import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../services/api_service.dart';
import '../../../../services/supabase_chat_service.dart';
import '../../../../config/api_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String displayName;

  const ChatScreen({super.key, required this.roomId, required this.displayName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRoomActive = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 1;
  String? _error;

  SupabaseChatSubscription? _subscription;

  // Realtime connection state: null = connecting, true = connected, false = failed
  bool? _realtimeStatus;
  String? _realtimeError;

  // Typing indicator
  String? _typingUserName;
  Timer? _typingTimer;
  Timer? _typingClearTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _typingClearTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && _hasMore && !_isLoadingMore) {
      _loadOlderMessages();
    }
  }

  Future<void> _subscribeToRealtime() async {
    if (!mounted) return;
    setState(() {
      _realtimeStatus = null; // connecting
      _realtimeError = null;
    });

    final chatService = SupabaseChatService();

    if (!chatService.isReady) {
      await chatService.initFromBackend();
    }

    if (!mounted) return;

    if (!chatService.isReady) {
      setState(() {
        _realtimeStatus = false;
        _realtimeError = chatService.diagnosticInfo;
      });
      return;
    }

    final currentUserId = context.read<AuthProvider>().user?.id;

    _subscription = chatService.subscribeToRoom(
      roomId: widget.roomId,
      onNewMessage: (message) {
        if (message['sender_id'] != currentUserId) {
          if (mounted) {
            setState(() => _messages.add(message));
            _scrollToBottom();

            // Mark as read
            _api.post('${ApiConfig.chatRooms}/${widget.roomId}/mark-read')
                .then((_) {}).catchError((_) {});
          }
        }
      },
      onTyping: (userId, userName, isTyping) {
        if (userId != currentUserId && mounted) {
          setState(() => _typingUserName = isTyping ? userName : null);
          _typingClearTimer?.cancel();
          if (isTyping) {
            _typingClearTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _typingUserName = null);
            });
          }
        }
      },
      onMessagesRead: (readByUserId) {
        if (readByUserId != currentUserId && mounted) {
          setState(() {
            for (var msg in _messages) {
              if (msg['sender_id'] == currentUserId) {
                msg['is_read'] = true;
              }
            }
          });
        }
      },
      onRoomStatus: (isActive) {
        if (mounted) setState(() => _isRoomActive = isActive);
      },
      onSubscriptionStatus: (isSubscribed, error) {
        if (!mounted) return;
        setState(() {
          _realtimeStatus = isSubscribed;
          _realtimeError = error;
        });
        debugPrint('[ChatScreen] Subscription status: subscribed=$isSubscribed, error=$error');
      },
    );
  }

  Future<void> _loadMessages() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final response = await _api.get(
        '${ApiConfig.chatRooms}/${widget.roomId}/messages',
        queryParams: {'page': '1', 'limit': '50'},
      );
      if (!mounted) return;

      final data = response['data'] ?? [];
      final meta = response['meta'];
      final int totalPages = (meta?['totalPages'] as int?) ?? 1;

      setState(() {
        _messages = List<dynamic>.from(data);
        _currentPage = 1;
        _hasMore = _currentPage < totalPages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is ApiException ? e.message : 'Failed to load messages';
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await _api.get(
        '${ApiConfig.chatRooms}/${widget.roomId}/messages',
        queryParams: {'page': '$nextPage', 'limit': '50'},
      );
      if (!mounted) return;

      final data = response['data'] ?? [];
      final meta = response['meta'];
      final int totalPages = (meta?['totalPages'] as int?) ?? 1;

      final scrollOffset = _scrollController.offset;

      setState(() {
        _messages.insertAll(0, List<dynamic>.from(data));
        _currentPage = nextPage;
        _hasMore = _currentPage < totalPages;
        _isLoadingMore = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(scrollOffset + (_scrollController.position.maxScrollExtent - scrollOffset));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onTextChanged(String text) {
    if (_typingTimer?.isActive ?? false) return;
    _typingTimer = Timer(const Duration(seconds: 2), () {});

    _api.post(
      '${ApiConfig.chatRooms}/${widget.roomId}/typing',
      body: {'is_typing': text.isNotEmpty},
    ).then((_) {}).catchError((_) {});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUserId = context.read<AuthProvider>().user?.id;
    final currentUserName = context.read<AuthProvider>().user?.name;

    // Optimistic update
    final optimisticMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'chat_room_id': widget.roomId,
      'sender_id': currentUserId,
      'content': text,
      'message_type': 'text',
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
      'sender': {'id': currentUserId, 'name': currentUserName, 'profile_photo': null},
      '_optimistic': true,
    };

    setState(() {
      _isSending = true;
      _messages.add(optimisticMsg);
    });
    _messageController.clear();
    _scrollToBottom();

    // Stop typing indicator
    _api.post(
      '${ApiConfig.chatRooms}/${widget.roomId}/typing',
      body: {'is_typing': false},
    ).then((_) {}).catchError((_) {});

    try {
      final response = await _api.post(
        '${ApiConfig.chatRooms}/${widget.roomId}/messages',
        body: {'content': text, 'message_type': 'text'},
      );

      if (response['data'] != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == optimisticMsg['id']);
          if (idx >= 0) {
            _messages[idx] = response['data'];
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == optimisticMsg['id']);
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.displayName),
            if (_typingUserName != null)
              Text(
                '$_typingUserName is typing...',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              )
            else if (!_isRoomActive)
              const Text(
                'Chat closed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          // Connection status indicator — reflects actual subscription state
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                // Tapping shows diagnostic info
                final status = _realtimeStatus == true
                    ? 'Connected (live)'
                    : _realtimeStatus == false
                        ? 'Disconnected: ${_realtimeError ?? "unknown"}'
                        : 'Connecting...';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Realtime: $status'), duration: const Duration(seconds: 3)),
                );
              },
              child: Icon(
                _realtimeStatus == true
                    ? Icons.wifi
                    : _realtimeStatus == false
                        ? Icons.wifi_off
                        : Icons.sync,
                size: 16,
                color: _realtimeStatus == true
                    ? Colors.greenAccent
                    : _realtimeStatus == false
                        ? Colors.redAccent
                        : Colors.amber,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Realtime connection warning banner
          if (_realtimeStatus == false)
            GestureDetector(
              onTap: () {
                // Retry realtime connection
                _subscription?.unsubscribe();
                _subscribeToRealtime();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 14, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live updates unavailable. Tap to retry.',
                        style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                      ),
                    ),
                    Icon(Icons.refresh, size: 14, color: Colors.deepOrange.shade300),
                  ],
                ),
              ),
            ),

          // Messages area
          Expanded(child: _buildMessageArea(currentUserId)),

          // Typing indicator
          if (_typingUserName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 16,
                    child: _TypingDots(),
                  ),
                  const SizedBox(width: 8),
                  Text('$_typingUserName is typing...', style: AppTextStyles.caption),
                ],
              ),
            ),

          // Room closed banner
          if (!_isRoomActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.softSurface,
              child: const Text(
                'This chat room has been closed.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),

          // Message input
          if (_isRoomActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: _onTextChanged,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.softSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: IconButton(
                        icon: Icon(
                          _isSending ? Icons.hourglass_empty : Icons.send,
                          color: AppColors.white,
                          size: 20,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageArea(String? currentUserId) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading messages...', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No messages yet', style: AppTextStyles.bodySmall),
            SizedBox(height: 4),
            Text('Start the conversation!', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final msgIndex = _isLoadingMore ? index - 1 : index;
        final msg = _messages[msgIndex];
        final isMe = msg['sender_id'] == currentUserId;
        final sender = msg['sender'];
        final isOptimistic = msg['_optimistic'] == true;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? (isOptimistic ? AppColors.primaryLight : AppColors.primary)
                  : AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      sender['name'] ?? '',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                    ),
                  ),
                Text(
                  msg['content'] ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    color: isMe ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime((msg['created_at'] ?? msg['createdAt'])?.toString()),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? AppColors.white.withValues(alpha: 0.7)
                            : AppColors.textMuted,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg['is_read'] == true ? Icons.done_all : Icons.done,
                        size: 14,
                        color: msg['is_read'] == true
                            ? Colors.lightBlueAccent
                            : AppColors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated typing dots widget.
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.5 + (value < 0.5 ? value : 1.0 - value);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
