import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../video_call/video_call_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic>? _myStudents;
  List<dynamic>? _activeMeetings;
  bool _isLoading = false;

  // Calendar State
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _attendanceEvents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMyStudents(),
      _loadActiveMeetings(),
      _loadAttendanceHistory(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMyStudents() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('group_name')
            .eq('user_id', session.user.id)
            .single();

        final groupName = profile['group_name'];
        if (groupName != null) {
          final students = await Supabase.instance.client
              .from('profiles')
              .select('*')
              .eq('role', 'student')
              .eq('group_name', groupName);

          if (mounted) {
            setState(() {
              _myStudents = students;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  Future<void> _loadActiveMeetings() async {
    try {
      final meetings = await ApiService.getActiveMeetings();
      if (mounted) {
        setState(() {
          _activeMeetings = meetings;
        });
      }
    } catch (e) {
      print('Error loading meetings: $e');
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Cargar asistencia de los últimos 2 meses
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - 1, 1);
      final endDate = DateTime(now.year, now.month + 1, 0);

      final attendance = await ApiService.getTeacherAttendance(
        user.id,
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
      );

      // Agrupar por fecha para el calendario
      final events = <DateTime, List<dynamic>>{};
      for (var record in attendance) {
        final date = DateTime.parse(record['meeting_date']);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        if (events[normalizedDate] == null) events[normalizedDate] = [];
        events[normalizedDate]!.add(record);
      }

      if (mounted) {
        setState(() {
          _attendanceEvents = events;
        });
      }
    } catch (e) {
      print('Error loading attendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Maestro'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Acciones Rápidas'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Iniciar Clase',
                          Icons.video_call,
                          Colors.teal,
                          () => _showCreateClassDialog(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          'Asistencia',
                          Icons.calendar_today,
                          Colors.orange,
                          () => _showAttendanceCalendar(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Reuniones Activas'),
                  const SizedBox(height: 10),
                  if (_activeMeetings == null || _activeMeetings!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay reuniones activas en este momento.',
                        ),
                      ),
                    )
                  else
                    ..._activeMeetings!.map(
                      (meeting) => _buildMeetingCard(meeting),
                    ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Mis Estudiantes'),
                  const SizedBox(height: 10),
                  if (_myStudents == null || _myStudents!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No tienes estudiantes asignados en tu grupo.',
                        ),
                      ),
                    )
                  else
                    ..._myStudents!.map(
                      (student) => _buildStudentCard(student),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.teal.shade50,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.video_camera_front, color: Colors.white),
        ),
        title: Text(meeting['title'] ?? 'Reunión'),
        subtitle: Text(meeting['description'] ?? ''),
        trailing: ElevatedButton(
          onPressed: () => _joinMeeting(meeting),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('Unirse'),
        ),
      ),
    );
  }

  Widget _buildStudentCard(dynamic student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Text(student['full_name']?[0] ?? 'S')),
        title: Text(student['full_name'] ?? 'Estudiante'),
        subtitle: Text('Email: ${student['email']}'),
      ),
    );
  }

  // --- Dialogs & Actions ---

  void _showAttendanceCalendar(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Calendario de Asistencia'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showAttendanceDialog(selectedDay);
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  eventLoader: (day) {
                    final normalizedDay = DateTime(
                      day.year,
                      day.month,
                      day.day,
                    );
                    return _attendanceEvents[normalizedDay] ?? [];
                  },
                  calendarStyle: const CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceDialog(DateTime date) async {
    if (_myStudents == null || _myStudents!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes estudiantes para registrar asistencia'),
        ),
      );
      return;
    }

    // Verificar si ya hay asistencia para esta fecha
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingAttendance = _attendanceEvents[normalizedDate];

    // Mapa para guardar attendance_id por estudiante si ya existe
    final studentAttendanceIds = <String, String>{};
    // Mapa para guardar los logros de cada estudiante
    final studentAchievements = <String, List<dynamic>>{};

    if (existingAttendance != null) {
      for (var record in existingAttendance) {
        studentAttendanceIds[record['user_id']] = record['id'];
      }

      // Cargar logros existentes para cada estudiante
      for (var studentId in studentAttendanceIds.keys) {
        final attendanceId = studentAttendanceIds[studentId];
        try {
          final achievements = await _getAchievementsForAttendance(
            attendanceId!,
          );
          studentAchievements[studentId] = achievements;
        } catch (e) {
          studentAchievements[studentId] = [];
        }
      }
    }

    // Preparar estado inicial de checkboxes
    final selectedStudents = <String>{};
    if (existingAttendance != null) {
      for (var record in existingAttendance) {
        if (record['was_present'] == true || record['user_id'] != null) {
          selectedStudents.add(record['user_id']);
        }
      }
    } else {
      // Por defecto todos seleccionados si es nuevo registro
      for (var s in _myStudents!) {
        selectedStudents.add(s['user_id']);
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Asistencia: ${DateFormat('dd/MM/yyyy').format(date)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _myStudents!.length,
              itemBuilder: (context, index) {
                final student = _myStudents![index];
                final studentId = student['user_id'];
                final isSelected = selectedStudents.contains(studentId);
                final attendanceId = studentAttendanceIds[studentId];
                final achievements = studentAchievements[studentId] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedStudents.add(studentId);
                          } else {
                            selectedStudents.remove(studentId);
                          }
                        });
                      },
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(student['full_name'])),
                        if (achievements.isNotEmpty)
                          ...achievements.map((ach) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                ach['achievements']['icon'] ?? '🏆',
                                style: const TextStyle(fontSize: 18),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            // Botón de trofeo para asignar logros
            IconButton(
              icon: const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 28,
              ),
              tooltip: 'Asignar Logros',
              onPressed: () async {
                await _showBulkAchievementsDialog(
                  date,
                  selectedStudents.toList(),
                  studentAttendanceIds,
                );
                // Recargar logros después de asignar
                final updatedAchievements = <String, List<dynamic>>{};
                for (var studentId in studentAttendanceIds.keys) {
                  final attendanceId = studentAttendanceIds[studentId];
                  try {
                    final achievements = await _getAchievementsForAttendance(
                      attendanceId!,
                    );
                    updatedAchievements[studentId] = achievements;
                  } catch (e) {
                    updatedAchievements[studentId] = [];
                  }
                }
                setDialogState(() {
                  studentAchievements.clear();
                  studentAchievements.addAll(updatedAchievements);
                });
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.recordAttendance(
                    meetingDate: DateFormat('yyyy-MM-dd').format(date),
                    studentIds: selectedStudents.toList(),
                    notes: 'Registro manual desde calendario',
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Asistencia guardada')),
                    );
                    _loadAttendanceHistory();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Guardar Asistencia'),
            ),
          ],
        ),
      ),
    );
  }

  // Método auxiliar para obtener logros de una asistencia
  Future<List<dynamic>> _getAchievementsForAttendance(
    String attendanceId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('student_achievements')
          .select('*, achievements(*)')
          .eq('attendance_id', attendanceId);
      return response as List<dynamic>;
    } catch (e) {
      print('Error loading achievements for attendance: $e');
      return [];
    }
  }

  // Nuevo método para asignar logros a múltiples estudiantes
  Future<void> _showBulkAchievementsDialog(
    DateTime date,
    List<String> studentIds,
    Map<String, String> studentAttendanceIds,
  ) async {
    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un estudiante')),
      );
      return;
    }

    try {
      final allAchievements = await ApiService.getAchievements();

      // Cargar logros actuales de cada estudiante
      final currentAchievements = <String, Set<String>>{};
      for (var studentId in studentIds) {
        final attendanceId = studentAttendanceIds[studentId];
        if (attendanceId != null) {
          final achievements = await _getAchievementsForAttendance(
            attendanceId,
          );
          currentAchievements[studentId] = achievements
              .map((a) => a['achievement_id'] as String)
              .toSet();
        } else {
          currentAchievements[studentId] = {};
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              'Asignar Logros - ${DateFormat('dd/MM/yyyy').format(date)}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona logros para ${studentIds.length} estudiante(s):',
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allAchievements.length,
                      itemBuilder: (context, index) {
                        final achievement = allAchievements[index];
                        final achievementId = achievement['id'];

                        // Verificar cuántos estudiantes tienen este logro
                        int count = 0;
                        for (var studentId in studentIds) {
                          if (currentAchievements[studentId]?.contains(
                                achievementId,
                              ) ??
                              false) {
                            count++;
                          }
                        }

                        final isFullySelected = count == studentIds.length;
                        final isPartiallySelected =
                            count > 0 && count < studentIds.length;

                        return CheckboxListTile(
                          secondary: Text(
                            achievement['icon'] ?? '🏆',
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(achievement['name']),
                          subtitle: isPartiallySelected
                              ? Text(
                                  '$count de ${studentIds.length} estudiantes',
                                )
                              : null,
                          value: isFullySelected,
                          tristate: true,
                          onChanged: (val) async {
                            // Alternar: si está seleccionado, deseleccionar todos; si no, seleccionar todos
                            final shouldSelect = !isFullySelected;

                            for (var studentId in studentIds) {
                              final attendanceId =
                                  studentAttendanceIds[studentId];
                              if (attendanceId == null) continue;

                              if (shouldSelect) {
                                // Agregar logro
                                currentAchievements[studentId]!.add(
                                  achievementId,
                                );
                                try {
                                  await ApiService.assignAchievementsToAttendance(
                                    attendanceId,
                                    [achievementId],
                                  );
                                } catch (e) {
                                  print('Error assigning achievement: $e');
                                }
                              } else {
                                // Quitar logro
                                currentAchievements[studentId]!.remove(
                                  achievementId,
                                );
                                try {
                                  await _removeAchievementFromAttendance(
                                    studentId,
                                    achievementId,
                                  );
                                } catch (e) {
                                  print('Error removing achievement: $e');
                                }
                              }
                            }

                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando logros: $e')));
    }
  }

  // Método para eliminar un logro
  Future<void> _removeAchievementFromAttendance(
    String studentId,
    String achievementId,
  ) async {
    try {
      await Supabase.instance.client
          .from('student_achievements')
          .delete()
          .eq('student_id', studentId)
          .eq('achievement_id', achievementId);
    } catch (e) {
      print('Error removing achievement: $e');
      rethrow;
    }
  }

  void _showCreateClassDialog(BuildContext context) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Nueva Clase'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Título de la clase',
            hintText: 'Ej: Matemáticas Avanzadas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final meeting = await ApiService.createMeeting(
                  titleController.text,
                  'Clase creada por maestro',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  _joinMeeting(meeting);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinMeeting(dynamic meeting) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', user!.id)
          .single();

      final userName = profile['full_name'] ?? 'Maestro';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              channelName: meeting['channelName'],
              token: meeting['token'],
              userName: userName,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error joining meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al unirse: $e')));
      }
    }
  }


