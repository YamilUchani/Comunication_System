import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'chat_message.dart';
import 'user_selection_dialog.dart';
import 'reaction_button.dart';
import 'reaction_animation.dart';

class ChatScreen extends StatefulWidget {
  final ChatController chatController;
  final Map<String, String> users;

  const ChatScreen({
    super.key,
    required this.chatController,
    required this.users,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedRecipientId;
  String? _selectedRecipientName;

  @override
  void initState() {
    super.initState();
    widget.chatController.markMessagesAsRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    widget.chatController.sendTextMessage(
      text,
      recipientId: _selectedRecipientId,
      recipientName: _selectedRecipientName,
    ).then((_) {
      _messageController.clear();
      _scrollToBottom();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando mensaje: $error')),
      );
    });
  }

  void _sendReaction(String reactionType) {
    widget.chatController.sendReaction(reactionType);
    _showReactionAnimation(reactionType);
  }

  void _showReactionAnimation(String reactionType) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Center(
          child: ReactionAnimation(reactionType: reactionType),
        ),
      ),
    );
  }

  Future<void> _selectRecipient() async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => UserSelectionDialog(users: widget.users),
    );

    if (result != null) {
      setState(() {
        _selectedRecipientId = result['id'];
        _selectedRecipientName = result['name'];
      });
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == widget.chatController.localUserId;
    final isPrivate = message.isPrivate;
    final isReaction = message.isReaction;

    if (isReaction) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  message.senderName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _getReactionIcon(message.reactionType),
                    color: _getReactionColor(message.reactionType),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${message.senderName} ${_getReactionText(message.reactionType)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.green,
                child: Text(
                  'Tú',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) 
                  Text(
                    message.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe 
                      ? (isPrivate ? Colors.purple[300] : Colors.blue[300])
                      : (isPrivate ? Colors.purple[100] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (isPrivate)
                  Text(
                    isMe 
                      ? 'Para: ${message.recipientName ?? 'Usuario'}'
                      : 'Mensaje privado',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                'Tú',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getReactionIcon(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return Icons.thumb_up;
      case 'hand':
        return Icons.waving_hand;
      case 'clap':
        return Icons.celebration;
      case 'heart':
        return Icons.favorite;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.emoji_emotions;
    }
  }

  Color _getReactionColor(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return Colors.blue;
      case 'hand':
        return Colors.orange;
      case 'clap':
        return Colors.yellow[700]!;
      case 'heart':
        return Colors.red;
      case 'fire':
        return Colors.orangeAccent;
      default:
        return Colors.purple;
    }
  }

  String _getReactionText(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return 'dio me gusta';
      case 'hand':
        return 'levantó la mano';
      case 'clap':
        return 'aplaudió';
      case 'heart':
        return 'envió un corazón';
      case 'fire':
        return 'está en llamas';
      default:
        return 'reaccionó';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _selectRecipient,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedRecipientId != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.purple.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.purple),
                  const SizedBox(width: 4),
                  Text(
                    'Enviando a: $_selectedRecipientName',
                    style: const TextStyle(color: Colors.purple),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedRecipientId = null;
                        _selectedRecipientName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: widget.chatController.messages,
              builder: (context, messages, child) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              children: [
                ReactionButton(
                  icon: Icons.thumb_up,
                  reactionType: 'like',
                  tooltip: 'Me gusta',
                  onReaction: _sendReaction,
                  color: Colors.blue,
                ),
                ReactionButton(
                  icon: Icons.waving_hand,
                  reactionType: 'hand',
                  tooltip: 'Levantar mano',
                  onReaction: _sendReaction,
                  color: Colors.orange,
                ),
                ReactionButton(
                  icon: Icons.celebration,
                  reactionType: 'clap',
                  tooltip: 'Aplaudir',
                  onReaction: _sendReaction,
                  color: Colors.yellow[700]!, // ← CORREGIDO: quitar la línea duplicada
                ),
                ReactionButton(
                  icon: Icons.favorite,
                  reactionType: 'heart',
                  tooltip: 'Corazón',
                  onReaction: _sendReaction,
                  color: Colors.red,
                ),
                ReactionButton(
                  icon: Icons.local_fire_department,
                  reactionType: 'fire',
                  tooltip: 'Fuego',
                  onReaction: _sendReaction,
                  color: Colors.orangeAccent,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}