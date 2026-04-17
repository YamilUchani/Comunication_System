import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Variables para selección de estudiantes
  List<dynamic> _studentsList = [];
  final Set<String> _selectedStudentIds = {};
  bool _isLoadingStudents = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingStudents = false);
        return;
      }
      
      final profileResponse = await supabase
          .from('profiles')
          .select('role, group_name')
          .eq('user_id', user.id)
          .single();
      
      final userRole = profileResponse['role'] ?? 'student';
      final groupName = profileResponse['group_name'];
      
      if ((userRole == 'teacher' || userRole == 'administrator') && groupName != null) {
        final studentsResponse = await supabase
            .from('profiles')
            .select('user_id, full_name')
            .eq('role', 'student')
            .eq('group_name', groupName)
            .order('full_name');
            
        if (mounted) {
          setState(() {
            _studentsList = studentsResponse as List<dynamic>;
            _isLoadingStudents = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStudents = false);
      }
    } catch (e) {
      print('Error loading students: $e');
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

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
        allowedUsers: _selectedStudentIds.toList(), // 🔥 Enviar estudiantes seleccionados
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
              const SizedBox(height: 20),
              
              if (_isLoadingStudents)
                const Center(child: CircularProgressIndicator())
              else if (_studentsList.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Seleccionar Estudiantes Permitidos:', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedStudentIds.length == _studentsList.length) {
                             _selectedStudentIds.clear();
                          } else {
                             _selectedStudentIds.addAll(_studentsList.map((s) => s['user_id'] as String));
                          }
                        });
                      },
                      child: Text(_selectedStudentIds.length == _studentsList.length ? 'Deseleccionar Todos' : 'Seleccionar Todos'),
                    )
                  ]
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _studentsList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = _studentsList[index];
                      final studentId = student['user_id'] as String;
                      final isSelected = _selectedStudentIds.contains(studentId);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(student['full_name'] ?? 'Sin nombre'),
                        value: isSelected,
                        activeColor: Colors.indigo,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedStudentIds.add(studentId);
                            } else {
                              _selectedStudentIds.remove(studentId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    'Si no seleccionas ninguno, todos los alumnos de tu grupo podrán unirse por defecto (Clase abierta al grupo). Si seleccionas alumnos específicos, SOLO esos alumnos podrán ver y entrar a la clase.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              ] else ...[
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.amber.shade50,
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.amber.shade200),
                   ),
                   child: const Row(
                     children: [
                       Icon(Icons.warning_amber_rounded, color: Colors.orange),
                       SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           'No se encontraron estudiantes en tu grupo. Asegúrate de tener alumnos registrados en tu mismo grupo.',
                           style: TextStyle(color: Colors.deepOrange),
                         ),
                       ),
                     ],
                   ),
                 )
              ],
              
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
