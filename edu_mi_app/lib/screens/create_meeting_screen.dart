import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/meeting_service.dart';
import '../video_call/video_call_screen.dart';

import '../services/api_service.dart';

/// Pantalla para crear una nueva reunión o programar un horario
class CreateMeetingScreen extends StatefulWidget {
  final bool isScheduleMode;
  
  const CreateMeetingScreen({super.key, this.isScheduleMode = false});

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

  // Variables para modo Horario (Schedule)
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

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
      if (widget.isScheduleMode) {
        // MODO HORARIO
        final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
        final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

        await ApiService.createSchedule(
          subject: _titleController.text.trim(),
          dayOfWeek: _selectedDay,
          startTime: startStr,
          endTime: endStr,
          scheduleType: _selectedMeetingType,
          allowedUsers: _selectedStudentIds.toList(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horario programado con éxito'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volver al dashboard y el loader de _loadSchedules tomará control
      } else {
        // MODO REUNIÓN INMEDIATA
        final meeting = await _meetingService.createMeeting(
          channelName: _channelController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          meetingType: _selectedMeetingType,
          allowedUsers: _selectedStudentIds.toList(),
        );

        if (!mounted) return;

        // Navegar a la pantalla de videollamada
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              channelName: meeting['channelName'],
              token: meeting['token'],
              userName: 'Usuario',
              meetingId: meeting['id'],
            ),
          ),
        );
      }
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
      appBar: AppBar(title: Text(widget.isScheduleMode ? 'Programar Horario' : 'Crear Reunión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!widget.isScheduleMode) ...[
                TextFormField(
                  controller: _channelController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Canal',
                    hintText: 'ejemplo: mi-reunion-123',
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa un nombre para el canal';
                    }
                    if (value.contains(' ')) {
                      return 'El nombre del canal no puede contener espacios';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: widget.isScheduleMode ? 'Materia/Título' : 'Título de la Reunión',
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) => 
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              
              if (!widget.isScheduleMode) ...[
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (Opcional)',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
              ],

              if (widget.isScheduleMode) ...[
                DropdownButtonFormField<int>(
                  value: _selectedDay,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Lunes')),
                    DropdownMenuItem(value: 2, child: Text('Martes')),
                    DropdownMenuItem(value: 3, child: Text('Miércoles')),
                    DropdownMenuItem(value: 4, child: Text('Jueves')),
                    DropdownMenuItem(value: 5, child: Text('Viernes')),
                    DropdownMenuItem(value: 6, child: Text('Sábado')),
                    DropdownMenuItem(value: 0, child: Text('Domingo')),
                  ],
                  onChanged: (val) => setState(() => _selectedDay = val!),
                  decoration: const InputDecoration(labelText: 'Día de la semana', prefixIcon: Icon(Icons.calendar_today)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Inicio'),
                        subtitle: Text(_startTime.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _startTime);
                          if (picked != null) setState(() => _startTime = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled),
                        title: const Text('Fin'),
                        subtitle: Text(_endTime.format(context)),
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _endTime);
                          if (picked != null) setState(() => _endTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMeeting,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.isScheduleMode ? 'Programar Horario' : 'Crear Reunión',
                          style: const TextStyle(fontSize: 16),
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
