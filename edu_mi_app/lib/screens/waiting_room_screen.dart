import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/window_service.dart';
import '../video_call/video_call_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String channelName;
  final String userName;
  final String userRole;
  final String? meetingId;
  final String? authToken;

  const WaitingRoomScreen({
    super.key,
    required this.channelName,
    required this.userName,
    required this.userRole,
    this.meetingId,
    this.authToken,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _isLoading = false;

  Future<void> _enterVideoCall() async {
    setState(() => _isLoading = true);

    try {
      print('🎥 Obteniendo token para entrar a la videollamada...');
      
      final joinData = await ApiService.joinMeeting(widget.channelName);

      if (!mounted) return;

      print('✅ Token obtenido: ${joinData['token']}');
      print('🚀 Entrando a videollamada...');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            channelName: joinData['channelName'],
            token: joinData['token'],
            userName: widget.userName,
            meetingId: joinData['id'],
            authToken: widget.authToken,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error al entrar a la videollamada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o icono
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.teal[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_camera_front,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),

            // Título
            const Text(
              'Sala de Espera',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Descripción
            Text(
              'Bienvenido, ${widget.userName}',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),

            // Canal name
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Sala de videollamada',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Botón Entrar
            ElevatedButton(
              onPressed: _isLoading ? null : _enterVideoCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Entrar de Todos Modos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Texto de ayuda
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Asegúrate de que tu cámara y micrófono estén activados\nantes de entrar a la videollamada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
