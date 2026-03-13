import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'chat_message.dart';
import '../utils/notification_overlay.dart'; // Import añadido

class ChatController {
  final RtcEngine _engine;
  final String localUserId;
  final String localUserName;
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> hasUnreadMessages = ValueNotifier(false);
  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();
  int _dataStreamId = 0;
  bool _isDataStreamInitialized = false;
  BuildContext? _context;

  /// Si se establece, solo se muestran mensajes cuyo senderId esté en este set.
  /// Útil para el chat estudiante-maestro: ignorar mensajes de otros estudiantes.
  Set<String>? allowedSenderIds;

  void setContext(BuildContext context) {
    _context = context;
  }

  bool get mounted => _context != null;

  ChatController({
    required RtcEngine engine,
    required this.localUserId,
    required this.localUserName,
    this.allowedSenderIds,
  }) : _engine = engine {
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      _dataStreamId = await _engine.createDataStream(
        DataStreamConfig(syncWithAudio: false, ordered: true),
      );

      print('✅ Stream de chat creado con ID: $_dataStreamId');
      _isDataStreamInitialized = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onStreamMessage:
              (connection, remoteUid, streamId, data, length, sentTs) {
                if (streamId == _dataStreamId) {
                  _handleIncomingMessage(data, remoteUid);
                }
              },
          onStreamMessageError:
              (connection, remoteUid, streamId, error, missed, cached) {
                if (streamId == _dataStreamId) {
                  print('Error en mensaje de chat: $error');
                }
              },
        ),
      );
    } catch (e) {
      print('❌ Error creando stream de datos: $e');
      _isDataStreamInitialized = false;
    }
  }

  void _handleIncomingMessage(Uint8List data, int remoteUid) {
    try {
      final messageStr = String.fromCharCodes(data);
      final messageJson = jsonDecode(messageStr);
      final message = ChatMessage.fromJson(messageJson);

      // 🔒 Filtro de remitentes: ignorar mensajes de usuarios no permitidos
      if (allowedSenderIds != null && !allowedSenderIds!.contains(message.senderId)) {
        return; // Ignorar mensajes de otros estudiantes
      }

      if (message.recipientId == null || message.recipientId == localUserId) {
        messages.value = [...messages.value, message];
        _messageStream.add(message);
        hasUnreadMessages.value = true;

        _showNotification(message);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error procesando mensaje: $e');
      }
    }
  }

  void _showNotification(ChatMessage message) {
    if (_context == null) return;

    String notificationText;

    if (message.isReaction) {
      notificationText =
          '${message.senderName} ${_getReactionText(message.reactionType)}';
    } else {
      notificationText = '${message.senderName}: ${message.content}';

      if (notificationText.length > 50) {
        notificationText = '${notificationText.substring(0, 47)}...';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_context != null && mounted) {
        try {
          NotificationOverlay.showNotification(
            _context!,
            notificationText,
            duration: const Duration(seconds: 3),
          );
        } catch (e) {
          print('Error mostrando notificación: $e');
        }
      }
    });
  }

  String _getReactionText(String? reactionType) {
    switch (reactionType) {
      case 'like':
        return 'dio me gusta 👍';
      case 'hand':
        return 'levantó la mano ✋';
      case 'clap':
        return 'aplaudió 👏';
      case 'heart':
        return 'envió un corazón ❤️';
      case 'fire':
        return 'está en llamas 🔥';
      default:
        return 'reaccionó';
    }
  }

  Future<void> sendMessage({
    required String content,
    required MessageType type,
    String? recipientId,
    String? recipientName,
    String? reactionType,
  }) async {
    try {
      if (!_isDataStreamInitialized) {
        throw Exception(
          'Stream de chat no inicializado. Espera unos segundos.',
        );
      }

      final message = ChatMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: localUserId,
        senderName: localUserName,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        recipientId: recipientId,
        recipientName: recipientName,
        reactionType: reactionType,
      );

      final messageJson = jsonEncode(message.toJson());
      final data = Uint8List.fromList(messageJson.codeUnits);

      await _engine.sendStreamMessage(
        streamId: _dataStreamId,
        data: data,
        length: data.length,
      );

      messages.value = [...messages.value, message];
      _messageStream.add(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error enviando mensaje: $e');
      }

      final errorMessage = ChatMessage(
        messageId: 'error-${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'system',
        senderName: 'Sistema',
        content: 'Error al enviar mensaje: ${e.toString()}',
        timestamp: DateTime.now(),
        type: MessageType.system,
      );

      messages.value = [...messages.value, errorMessage];
      _messageStream.add(errorMessage);
      rethrow;
    }
  }

  Future<void> sendTextMessage(
    String text, {
    String? recipientId,
    String? recipientName,
  }) {
    return sendMessage(
      content: text,
      type: MessageType.text,
      recipientId: recipientId,
      recipientName: recipientName,
    );
  }

  Future<void> sendReaction(String reactionType) {
    return sendMessage(
      content: 'Reacción: $reactionType',
      type: MessageType.reaction,
      recipientId: null,
      reactionType: reactionType,
    );
  }

  void markMessagesAsRead() {
    hasUnreadMessages.value = false;
  }

  List<ChatMessage> getMessagesForUser(String? userId) {
    if (userId == null) {
      return messages.value.where((msg) => msg.recipientId == null).toList();
    }
    return messages.value
        .where(
          (msg) =>
              msg.recipientId == null ||
              msg.recipientId == userId ||
              msg.senderId == userId,
        )
        .toList();
  }

  Stream<ChatMessage> get messageStream => _messageStream.stream;

  void dispose() {
    messages.dispose();
    hasUnreadMessages.dispose();
    _messageStream.close();
  }
}
