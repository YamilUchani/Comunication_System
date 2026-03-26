import 'package:flutter/material.dart';
import '../services/meeting_service.dart';
import '../video_call/video_call_screen.dart';

/// Pantalla para crear una nueva reunión usando el backend
class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _channelController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingService = MeetingService();
  bool _isLoading = false;
  String _selectedMeetingType = 'master'; // 🔥 Selección del tipo de clase

  @override
  void dispose() {
    _channelController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final meeting = await _meetingService.createMeeting(
        channelName: _channelController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        meetingType: _selectedMeetingType,
      );

      if (!mounted) return;

      // Navegar a la pantalla de videollamada con el token del backend
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            channelName: meeting['channelName'],
            token: meeting['token'],
            userName: 'Usuario', // Puedes pasar el nombre real del usuario
            meetingId: meeting['id'], // 🆔 Pasar ID de la reunión
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Reunión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _channelController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Canal',
                  hintText: 'ejemplo: mi-reunion-123',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre de canal';
                  }
                  final regex = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');
                  if (!regex.hasMatch(value)) {
                    return 'Solo letras, números, - y _ (1-64 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Reunión',
                  hintText: 'ejemplo: Clase de Matemáticas',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Detalles de la reunión',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Tipo de Clase:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'master',
                    label: Text('Magistral'),
                    icon: Icon(Icons.school),
                  ),
                  ButtonSegment(
                    value: 'private',
                    label: Text('Privada/Grupal'),
                    icon: Icon(Icons.group),
                  ),
                ],
                selected: {_selectedMeetingType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedMeetingType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createMeeting,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear Reunión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
