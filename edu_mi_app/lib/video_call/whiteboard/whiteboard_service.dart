import 'package:supabase_flutter/supabase_flutter.dart';
import 'whiteboard_model.dart';

class WhiteboardService {
  final String meetingId;
  late final RealtimeChannel _channel;
  
  final Function(WhiteboardObject) onObjectAdded;
  final Function(WhiteboardObject) onObjectUpdated;
  final Function(String) onObjectRemoved;
  final Function() onClear;
  final Function(bool) onModeChanged;
  final Function()? onSyncRequest;
  final Function(double, double)? onBoardInfoChanged;
  final Function()? onBoardClosed;  // 🚪 Nuevo: evento de cierre de pizarra

  WhiteboardService({
    required this.meetingId,
    required this.onObjectAdded,
    required this.onObjectUpdated,
    required this.onObjectRemoved,
    required this.onClear,
    required this.onModeChanged,
    this.onSyncRequest,
    this.onBoardInfoChanged,
    this.onBoardClosed,
  }) {
    _initChannel();
  }

  void _initChannel() {
    // Escuchar a un canal específico de la reunión para la pizarra
    _channel = Supabase.instance.client.channel('whiteboard_$meetingId');

    _channel.onBroadcast(event: 'add_object', callback: (payload) {
      if (payload['object'] != null) {
        try {
          final obj = WhiteboardObject.fromJson(payload['object']);
          onObjectAdded(obj);
        } catch (e, stack) {
          print('❌ ERROR PARSING ADD_OBJECT: $e\n$stack');
        }
      }
    }).onBroadcast(event: 'update_object', callback: (payload) {
      if (payload['object'] != null) {
        try {
          final obj = WhiteboardObject.fromJson(payload['object']);
          onObjectUpdated(obj);
        } catch (e, stack) {
          print('❌ ERROR PARSING UPDATE_OBJECT: $e\n$stack');
        }
      }
    }).onBroadcast(event: 'remove_object', callback: (payload) {
      if (payload['id'] != null) {
        onObjectRemoved(payload['id']);
      }
    }).onBroadcast(event: 'clear', callback: (payload) {
      onClear();
    }).onBroadcast(event: 'change_mode', callback: (payload) {
      if (payload['isTransparent'] != null) {
        onModeChanged(payload['isTransparent']);
      }
    }).onBroadcast(event: 'request_sync', callback: (payload) {
      if (onSyncRequest != null) onSyncRequest!();
    }).onBroadcast(event: 'board_info', callback: (payload) {
      if (onBoardInfoChanged != null && payload['width'] != null && payload['height'] != null) {
        onBoardInfoChanged!(payload['width'].toDouble(), payload['height'].toDouble());
      }
    }).onBroadcast(event: 'close_board', callback: (payload) {
      // 🚪 Evento de cierre en cascada: maestro cerró, todos cierren
      if (onBoardClosed != null) onBoardClosed!();
    }).subscribe();
  }

  void sendBoardInfo(double width, double height) {
    _channel.sendBroadcastMessage(
      event: 'board_info',
      payload: {'width': width, 'height': height},
    );
  }

  void requestSync() {
    _channel.sendBroadcastMessage(
      event: 'request_sync',
      payload: {},
    );
  }

  void sendObject(WhiteboardObject object) {
    _channel.sendBroadcastMessage(
      event: 'add_object',
      payload: {'object': object.toJson()},
    );
  }

  void updateObject(WhiteboardObject object) {
    _channel.sendBroadcastMessage(
      event: 'update_object',
      payload: {'object': object.toJson()},
    );
  }

  void removeObject(String id) {
    _channel.sendBroadcastMessage(
      event: 'remove_object',
      payload: {'id': id},
    );
  }

  void clearBoard() {
    _channel.sendBroadcastMessage(
      event: 'clear',
      payload: {},
    );
  }

  void changeMode(bool isTransparent) {
    _channel.sendBroadcastMessage(
      event: 'change_mode',
      payload: {'isTransparent': isTransparent},
    );
  }

  /// 🚪 Notifica a TODOS (incluyendo estudiantes) que la pizarra se cierra
  void notifyBoardClosed() {
    _channel.sendBroadcastMessage(
      event: 'close_board',
      payload: {},
    );
  }

  void dispose() {
    _channel.unsubscribe();
  }
}
