import 'package:flutter/material.dart';
import '../video_call/video_call_screen.dart';

class ChannelInputScreen extends StatefulWidget {
  final String userName;

  const ChannelInputScreen({
    super.key,
    required this.userName,
  });

  @override
  _ChannelInputScreenState createState() => _ChannelInputScreenState();
}

class _ChannelInputScreenState extends State<ChannelInputScreen> {
  final TextEditingController _channelController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  void _joinCall() {
    final channelName = _channelController.text.trim();
    final token = _tokenController.text.trim();

    if (channelName.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el nombre del canal y el token')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelName: channelName, 
          token: token,
          userName: widget.userName, // Pasar el nombre de usuario
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a videollamada')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Usuario: ${widget.userName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _channelController,
              decoration: const InputDecoration(
                labelText: 'Nombre del canal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token de Agora',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _joinCall,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Unirse a la llamada'),
            ),
          ],
        ),
      ),
    );
  }
}