import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../video_call/video_call_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<dynamic>? _achievements;
  List<dynamic>? _activeMeetings;
  List<dynamic>? _attendanceHistory;
  bool _isLoading = true;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<dynamic>> _attendanceEvents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Cargar datos en paralelo
      final results = await Future.wait([
        ApiService.getStudentAchievements(userId),
        ApiService.getActiveMeetings(),
        ApiService.getStudentAttendance(userId),
      ]);

      if (mounted) {
        setState(() {
          _achievements = results[0];
          _activeMeetings = results[1];
          _attendanceHistory = results[2];

          // Procesar eventos del calendario
          _attendanceEvents.clear();
          if (_attendanceHistory != null) {
            for (var record in _attendanceHistory!) {
              final date = DateTime.parse(record['attendance_date']);
              final normalizedDate = DateTime(date.year, date.month, date.day);

              if (_attendanceEvents[normalizedDate] == null) {
                _attendanceEvents[normalizedDate] = [];
              }
              _attendanceEvents[normalizedDate]!.add(record);
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Error loading student data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Aula'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _showAttendanceCalendar(context),
            tooltip: 'Ver Calendario',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _showStudentProfile(context),
            tooltip: 'Mi Perfil',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
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
                  _buildSectionTitle('Clases Activas'),
                  if (_activeMeetings == null || _activeMeetings!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay clases activas para tu grupo.'),
                      ),
                    )
                  else
                    ..._activeMeetings!.map(
                      (meeting) => _buildMeetingCard(meeting),
                    ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Mis Logros Recientes'),
                  if (_achievements == null || _achievements!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Aún no tienes logros. ¡Sigue esforzándote!',
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: _achievements!.length,
                      itemBuilder: (context, index) {
                        final achievementData = _achievements![index];
                        final achievement = achievementData['achievements'];
                        final date = DateTime.parse(
                          achievementData['unlocked_at'],
                        );

                        return Card(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                achievement['icon'] ?? '🏆',
                                style: const TextStyle(fontSize: 30),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                achievement['name'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM').format(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.videocam, color: Colors.white),
        ),
        title: Text(meeting['title']),
        subtitle: Text('Profesor: ${meeting['creatorName'] ?? 'Maestro'}'),
        trailing: ElevatedButton(
          onPressed: () async {
            try {
              final joinData = await ApiService.joinMeeting(
                meeting['channelName'],
              );

              if (context.mounted) {
                final user = Supabase.instance.client.auth.currentUser;
                final profile = await Supabase.instance.client
                    .from('profiles')
                    .select('full_name')
                    .eq('user_id', user!.id)
                    .single();

                final userName = profile['full_name'] ?? 'Estudiante';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoCallScreen(
                      channelName: joinData['channelName'],
                      token: joinData['token'],
                      userName: userName,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error al unirse: $e')));
              }
            }
          },
          child: const Text('Unirse'),
        ),
      ),
    );
  }

  void _showStudentProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Mi Perfil'),
            backgroundColor: Colors.orange,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Historial de Asistencia'),
              if (_attendanceHistory == null || _attendanceHistory!.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay registros de asistencia.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attendanceHistory!.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceHistory![index];
                    final date = DateTime.parse(record['meeting_date']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        title: Text('Asistió a clase'),
                        subtitle: Text(
                          DateFormat('EEEE d MMMM yyyy', 'es').format(date),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              _buildSectionTitle('Todos mis Logros'),
              if (_achievements == null || _achievements!.isEmpty)
                const Text('Sin logros aún.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _achievements!.length,
                  itemBuilder: (context, index) {
                    final achievementData = _achievements![index];
                    final achievement = achievementData['achievements'];
                    final date = DateTime.parse(achievementData['unlocked_at']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Text(
                          achievement['icon'] ?? '🏆',
                          style: const TextStyle(fontSize: 30),
                        ),
                        title: Text(achievement['name']),
                        subtitle: Text(achievement['description'] ?? ''),
                        trailing: Text(
                          DateFormat('dd/MM/yyyy').format(date),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Mostrar calendario de asistencia
  void _showAttendanceCalendar(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mi Calendario de Asistencia'),
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
                    _showAttendanceDetail(selectedDay);
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
                      color: Colors.orange,
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

  // Mostrar detalle de asistencia de un día
  void _showAttendanceDetail(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final attendanceRecord = _attendanceEvents[normalizedDate];

    if (attendanceRecord == null || attendanceRecord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registro de asistencia para este día'),
        ),
      );
      return;
    }

    // Obtener logros para este registro de asistencia
    final attendanceId = attendanceRecord[0]['id'];
    List<dynamic> achievements = [];

    try {
      final response = await Supabase.instance.client
          .from('student_achievements')
          .select('*, achievements(*)')
          .eq('attendance_id', attendanceId);
      achievements = response as List<dynamic>;
    } catch (e) {
      print('Error loading achievements: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Asistencia - ${DateFormat('dd/MM/yyyy').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ Presente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            if (achievements.isNotEmpty) ...[
              const Text(
                'Logros obtenidos:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: achievements.map((ach) {
                  final achievement = ach['achievements'];
                  return Chip(
                    avatar: Text(
                      achievement['icon'] ?? '🏆',
                      style: const TextStyle(fontSize: 20),
                    ),
                    label: Text(achievement['name']),
                    backgroundColor: Colors.orange.shade100,
                  );
                }).toList(),
              ),
            ] else
              const Text(
                'No obtuviste logros en esta clase.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
