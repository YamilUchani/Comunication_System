import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../video_call/video_call_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String channelName;
  final String meetingTitle;
  final String creatorName;
  final String meetingId;

  const WaitingRoomScreen({
    super.key,
    required this.channelName,
    required this.meetingTitle,
    required this.creatorName,
    required this.meetingId,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _isLoading = false;
  bool _inVideoCall = false;
  late String _token;
  late String _channelName;
  late String _userName;
  late String _videoMeetingId;

  Future<void> _enterVideoCall() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Obtener token y datos de la reunión
      final joinData = await ApiService.joinMeeting(widget.channelName);

      if (context.mounted) {
        // Obtener nombre del usuario
        final user = Supabase.instance.client.auth.currentUser;
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('user_id', user!.id)
            .single();

        final userName = profile['full_name'] ?? 'Estudiante';

        // TODO: Cambiar estado a "Presente" en la base de datos cuando la columna 'status' exista
        // await Supabase.instance.client
        //     .from('attendance')
        //     .update({
        //       'status': 'in_call', // Estado: En Llamada (en videollamada)
        //       'updated_at': DateTime.now().toIso8601String(),
        //     })
        //     .eq('user_id', user.id)
        //     .eq('meeting_id', widget.meetingId);

        if (context.mounted && mounted) {
          setState(() {
            _token = joinData['token'];
            _channelName = joinData['channelName'];
            _userName = userName;
            _videoMeetingId = joinData['id'];
            _inVideoCall = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al entrar a la videollamada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveVideoCall() async {
    if (mounted) {
      setState(() {
        _inVideoCall = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está en videollamada, mostrar VideoCallScreen dentro
    if (_inVideoCall) {
      return WillPopScope(
        onWillPop: () async {
          // Al presionar atrás, volver a la sala de espera
          await _leaveVideoCall();
          return false;
        },
        child: VideoCallScreen(
          channelName: _channelName,
          token: _token,
          userName: _userName,
          meetingId: _videoMeetingId,
        ),
      );
    }

    // Si no está en videollamada, mostrar la sala de espera
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Sala de Espera'),
        backgroundColor: Colors.orange,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono de espera
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.hourglass_empty,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 30),

              // Título
              Text(
                widget.meetingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Profesor
              Text(
                'Profesor: ${widget.creatorName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Estado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Estado: Esperando entrada...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Botón para entrar
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _enterVideoCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.videocam),
                label: Text(
                  _isLoading ? 'Conectando...' : 'Entrar a Videollamada',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Información adicional
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    '💡 Asegúrate de tener tu cámara y micrófono listos antes de entrar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
