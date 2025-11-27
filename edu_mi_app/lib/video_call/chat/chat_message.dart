class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? recipientId;
  final String? recipientName;
  final String? reactionType;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.type,
    this.recipientId,
    this.recipientName,
    this.reactionType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values.firstWhere((e) => e.toString() == 'MessageType.${json['type']}'),
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      reactionType: json['reactionType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'reactionType': reactionType,
    };
  }

  bool get isPrivate => recipientId != null;
  bool get isReaction => type == MessageType.reaction;
}

enum MessageType {
  text,
  image,
  file,
  system,
  reaction,
}