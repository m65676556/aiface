import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/dating_api_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String myId;
  final String theirId;
  final String theirSummary;
  final String? theirPhotoBase64;

  const ChatRoomScreen({
    super.key,
    required this.myId,
    required this.theirId,
    required this.theirSummary,
    this.theirPhotoBase64,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  String _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
  Timer? _pollTimer;
  Uint8List? _theirPhoto;

  @override
  void initState() {
    super.initState();
    if (widget.theirPhotoBase64 != null &&
        widget.theirPhotoBase64!.isNotEmpty) {
      try {
        _theirPhoto = base64Decode(widget.theirPhotoBase64!);
      } catch (_) {}
    }
    _loadHistory();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await DatingApiService.fetchMessages(
          widget.myId, widget.theirId, _lastFetchTime);
      if (msgs.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(msgs);
          _lastFetchTime = msgs.last['created_at'] as String;
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _poll() async {
    try {
      final msgs = await DatingApiService.fetchMessages(
          widget.myId, widget.theirId, _lastFetchTime);
      if (msgs.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(msgs);
          _lastFetchTime = msgs.last['created_at'] as String;
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await DatingApiService.sendMessage(widget.myId, widget.theirId, text);
      // Optimistically add message to UI
      final now = DateTime.now().toIso8601String();
      setState(() {
        _messages.add({
          'from_id': widget.myId,
          'to_id': widget.theirId,
          'content': text,
          'created_at': now,
        });
        _lastFetchTime = now;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
        _messageController.text = text;
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.pink.withOpacity(0.2),
              backgroundImage:
                  _theirPhoto != null ? MemoryImage(_theirPhoto!) : null,
              child: _theirPhoto == null
                  ? const Icon(Icons.person, color: Colors.pink, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.theirId.length > 8
                        ? widget.theirId.substring(0, 8)
                        : widget.theirId,
                    style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  if (widget.theirSummary.isNotEmpty)
                    Text(
                      widget.theirSummary,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      '还没有消息，先打个招呼吧 👋',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isMe = msg['from_id'] == widget.myId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.pink.withOpacity(0.2),
              backgroundImage:
                  _theirPhoto != null ? MemoryImage(_theirPhoto!) : null,
              child: _theirPhoto == null
                  ? const Icon(Icons.person, color: Colors.pink, size: 14)
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.pink
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                msg['content'] as String,
                style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.textColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
            top: BorderSide(color: Colors.pink.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: AppTheme.textColor),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '说点什么...',
                hintStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isSending
                    ? Colors.pink.withOpacity(0.4)
                    : Colors.pink,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
