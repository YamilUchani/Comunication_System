import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/window_service.dart';

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
      print(
        '🔍 Found ${existingAttendance.length} attendance records for $normalizedDate',
      );
      for (var record in existingAttendance) {
        print(
          '   - Student: ${record['user_id']}, Attendance ID: ${record['id']}',
        );
        studentAttendanceIds[record['user_id']] = record['id'];
      }

      // Cargar logros existentes para cada estudiante
      for (var studentId in studentAttendanceIds.keys) {
        final attendanceId = studentAttendanceIds[studentId];
        print(
          '🎯 Loading achievements for student $studentId, attendance $attendanceId',
        );
        try {
          final achievements = await _getAchievementsForAttendance(
            attendanceId!,
          );
          print('   ✅ Found ${achievements.length} achievements');
          for (var ach in achievements) {
            print(
              '      - ${ach['achievements']['name']} (ID: ${ach['achievement_id']})',
            );
          }
          studentAchievements[studentId] = achievements;
        } catch (e) {
          print('   ❌ Error loading achievements: $e');
          studentAchievements[studentId] = [];
        }
      }
    } else {
      print('⚠️ No existing attendance found for $normalizedDate');
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

                // Obtener IDs de logros actuales del estudiante
                final currentAchievementIds = achievements
                    .map((a) => a['achievement_id'] as String)
                    .toSet();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
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
                            Expanded(
                              child: Text(
                                student['full_name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (attendanceId != null && isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 48, top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildAchievementCheckbox(
                                  '✅ Modelo Terminado',
                                  'Modelo Terminado',
                                  attendanceId,
                                  studentId,
                                  currentAchievementIds,
                                  setDialogState,
                                  studentAchievements,
                                ),
                                _buildAchievementCheckbox(
                                  '⏰ Puntualidad',
                                  'Puntualidad',
                                  attendanceId,
                                  studentId,
                                  currentAchievementIds,
                                  setDialogState,
                                  studentAchievements,
                                ),
                                _buildAchievementCheckbox(
                                  '🙋 Participación',
                                  'Participación',
                                  attendanceId,
                                  studentId,
                                  currentAchievementIds,
                                  setDialogState,
                                  studentAchievements,
                                ),
                                _buildAchievementCheckbox(
                                  '🎨 Creatividad',
                                  'Creatividad',
                                  attendanceId,
                                  studentId,
                                  currentAchievementIds,
                                  setDialogState,
                                  studentAchievements,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
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

  // Método para eliminar un logro
  Future<void> _removeAchievementFromAttendance(
    String studentId,
    String achievementId,
    String attendanceId,
  ) async {
    try {
      await Supabase.instance.client
          .from('student_achievements')
          .delete()
          .eq('student_id', studentId)
          .eq('achievement_id', achievementId)
          .eq('attendance_id', attendanceId);
    } catch (e) {
      print('Error removing achievement: $e');
      rethrow;
    }
  }

  // Método para construir un checkbox de logro inline
  Widget _buildAchievementCheckbox(
    String label,
    String achievementName,
    String attendanceId,
    String studentId,
    Set<String> currentAchievementIds,
    StateSetter setState,
    Map<String, List<dynamic>> studentAchievements,
  ) {
    // Buscar el ID del logro por nombre
    final isSelected = currentAchievementIds.any((id) {
      try {
        final achievement = studentAchievements[studentId]?.firstWhere(
          (a) => a['achievement_id'] == id,
        );
        return achievement != null &&
            achievement['achievements']['name'] == achievementName;
      } catch (e) {
        return false;
      }
    });

    return InkWell(
      onTap: () async {
        // Obtener todos los logros para encontrar el ID correcto
        try {
          final allAchievements = await ApiService.getAchievements();
          final targetAchievement = allAchievements
              .where((a) => a['name'] == achievementName)
              .firstOrNull;

          if (targetAchievement == null) return;

          final achievementId = targetAchievement['id'];

          // OPTIMISTIC UPDATE: Actualizar UI inmediatamente
          final tempAchievement = {
            'achievement_id': achievementId,
            'achievements': targetAchievement,
          };

          if (isSelected) {
            // Quitar logro de la UI inmediatamente
            studentAchievements[studentId]?.removeWhere(
              (a) => a['achievement_id'] == achievementId,
            );
          } else {
            // Agregar logro a la UI inmediatamente
            if (studentAchievements[studentId] == null) {
              studentAchievements[studentId] = [];
            }
            studentAchievements[studentId]!.add(tempAchievement);
          }

          // Actualizar UI
          setState(() {});

          // Actualizar en servidor en segundo plano
          if (isSelected) {
            _removeAchievementFromAttendance(
              studentId,
              achievementId,
              attendanceId,
            ).catchError((e) {
              print('Error removing achievement: $e');
              // Revertir cambio si falla
              if (studentAchievements[studentId] != null) {
                studentAchievements[studentId]!.add(tempAchievement);
                setState(() {});
              }
            });
          } else {
            ApiService.assignAchievementsToAttendance(attendanceId, [
              achievementId,
            ]).catchError((e) {
              print('Error assigning achievement: $e');
              // Revertir cambio si falla
              studentAchievements[studentId]?.removeWhere(
                (a) => a['achievement_id'] == achievementId,
              );
              setState(() {});
            });
          }
        } catch (e) {
          print('Error toggling achievement: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isSelected ? Colors.teal : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.teal.shade900 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
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
      // ✅ OBTENER EL TOKEN antes de entrar (el objeto de la lista no lo tiene)
      final joinData = await ApiService.joinMeeting(meeting['channelName']);

      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', user!.id)
          .single();

      final userName = profile['full_name'] ?? 'Maestro';

      if (mounted) {
        print('🚀 Lanzando ventana de videollamada independiente...');
        
        await WindowService().openVideoCallWindow(
          channelName: joinData['channelName'],
          token: joinData['token'],
          userName: userName,
          meetingId: joinData['id'], // 🆔 Pasar ID de la reunión
          authToken: session?.accessToken, // 🔑 Pasar token de autenticación
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ventana de videollamada abierta'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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
}
