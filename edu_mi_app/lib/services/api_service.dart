import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static String get _baseUrl => dotenv.env['BACKEND_URL'] ?? '';

  static Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('No hay sesión activa');

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  // ==========================================
  // ADMIN
  // ==========================================

  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/stats'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['stats'];
    } else {
      throw Exception('Error cargando estadísticas: ${response.body}');
    }
  }

  static Future<List<dynamic>> getUsers({String? role, String? search}) async {
    String query = '';
    if (role != null) query += 'role=$role&';
    if (search != null) query += 'search=$search&';

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users?$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['users'];
    } else {
      throw Exception('Error cargando usuarios');
    }
  }

  static Future<void> updateUserRole(
    String userId,
    String role,
    String? groupName,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/users/$userId/role'),
      headers: await _getHeaders(),
      body: jsonEncode({'role': role, 'group_name': groupName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error actualizando rol: ${response.body}');
    }
  }

  static Future<List<dynamic>> getGroups() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/groups'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['groups'];
    } else {
      throw Exception('Error cargando grupos');
    }
  }

  static Future<Map<String, dynamic>> getGroupsWithMembers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/groups/with-members'),
      headers: await _getHeaders(),
    );

    print('🔍 getGroupsWithMembers - Status: ${response.statusCode}');
    print('🔍 getGroupsWithMembers - Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded;
    } else {
      throw Exception('Error cargando grupos con miembros: ${response.body}');
    }
  }

  static Future<void> deleteGroup(String groupName, String confirmName) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/groups/$groupName'),
      headers: await _getHeaders(),
      body: jsonEncode({'confirmName': confirmName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error eliminando grupo: ${response.body}');
    }
  }

  static Future<void> createGroup(
    String name,
    String displayName,
    String description,
    String color,
    String icon,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/groups'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'display_name': displayName,
        'description': description,
        'color': color,
        'icon': icon,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Error creando grupo: ${response.body}');
    }
  }

  // ==========================================
  // TEACHER
  // ==========================================

  static Future<Map<String, dynamic>> createMeeting(
    String title,
    String description, {
    List<String>? allowedGroups,
    List<String>? allowedUsers,
  }) async {
    // El backend genera channelName automáticamente o usa el título sanitizado
    final channelName = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();

    final response = await http.post(
      Uri.parse('$_baseUrl/meetings/create'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'channelName': channelName,
        'title': title,
        'description': description,
        'allowed_groups': allowedGroups,
        'allowed_users': allowedUsers,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body)['meeting'];
    } else {
      throw Exception('Error creando reunión: ${response.body}');
    }
  }

  // ==== FUNCIONES DE CONVERSIÓN DE ZONA HORARIA ====
  
  // Convierte un horario local a UTC para enviar al servidor
  static Map<String, dynamic> _localToUtcSchedule(int localDay, String startTime, String endTime) {
    int dartDay = localDay == 0 ? 7 : localDay;
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);
    
    // Sumamos días hasta llegar al primer 'dartDay' (usamos +7 para asegurar saltar posibles problemas de DST de dias pasados)
    DateTime localStart = baseDate.add(Duration(days: (dartDay - baseDate.weekday + 7) % 7 + 7));
    
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    localStart = DateTime(localStart.year, localStart.month, localStart.day, 
                          int.parse(startParts[0]), int.parse(startParts[1]));
                          
    DateTime localEnd = DateTime(localStart.year, localStart.month, localStart.day, 
                                 int.parse(endParts[0]), int.parse(endParts[1]));
                                 
    // Si la hora de fin es menor a la de inicio, significa que cruza la medianoche
    if (int.parse(endParts[0]) < int.parse(startParts[0])) {
      localEnd = localEnd.add(const Duration(days: 1));
    }
    
    DateTime utcStart = localStart.toUtc();
    DateTime utcEnd = localEnd.toUtc();
    
    int utcDay = utcStart.weekday == 7 ? 0 : utcStart.weekday;
    String outStart = '${utcStart.hour.toString().padLeft(2, '0')}:${utcStart.minute.toString().padLeft(2, '0')}:00';
    String outEnd = '${utcEnd.hour.toString().padLeft(2, '0')}:${utcEnd.minute.toString().padLeft(2, '0')}:00';
    
    return {
      'dayOfWeek': utcDay,
      'startTime': outStart,
      'endTime': outEnd,
    };
  }

  // Convierte un horario UTC del servidor a hora local para mostrar en la interfaz
  static Map<String, dynamic> _utcToLocalSchedule(Map<String, dynamic> schedule) {
    final utcDay = schedule['day_of_week'] as int;
    final dartDay = utcDay == 0 ? 7 : utcDay;
    
    final startParts = schedule['start_time'].toString().split(':');
    final endParts = schedule['end_time'].toString().split(':');
    
    final now = DateTime.now().toUtc();
    final baseDate = DateTime.utc(now.year, now.month, now.day);
    
    DateTime utcStart = baseDate.add(Duration(days: (dartDay - baseDate.weekday + 7) % 7 + 7));
    utcStart = DateTime.utc(utcStart.year, utcStart.month, utcStart.day, 
                            int.parse(startParts[0]), int.parse(startParts[1]));
                            
    DateTime utcEnd = DateTime.utc(utcStart.year, utcStart.month, utcStart.day, 
                                   int.parse(endParts[0]), int.parse(endParts[1]));
                                   
    if (int.parse(endParts[0]) < int.parse(startParts[0])) {
      utcEnd = utcEnd.add(const Duration(days: 1));
    }
    
    DateTime localStart = utcStart.toLocal();
    DateTime localEnd = utcEnd.toLocal();
    
    int localDay = localStart.weekday == 7 ? 0 : localStart.weekday;
    String outStart = '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}:00';
    String outEnd = '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}:00';
    
    return {
      ...schedule,
      'day_of_week': localDay,
      'start_time': outStart,
      'end_time': outEnd,
      'utc_original_day': utcDay, // guardamos el original por si acaso
    };
  }

  static Future<List<dynamic>> getSchedules() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/meetings/schedules'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> schedules = jsonDecode(response.body)['schedules'];
      return schedules.map((s) => _utcToLocalSchedule(s as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error cargando horarios: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> createSchedule({
    required String subject,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? groupName,
  }) async {
    final utcData = _localToUtcSchedule(dayOfWeek, startTime, endTime);
    
    final response = await http.post(
      Uri.parse('$_baseUrl/meetings/schedules'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'subject': subject,
        'day_of_week': utcData['dayOfWeek'],
        'start_time': utcData['startTime'],
        'end_time': utcData['endTime'],
        'group_name': groupName,
      }),
    );

    if (response.statusCode == 201) {
      final schedule = jsonDecode(response.body)['schedule'] as Map<String, dynamic>;
      return _utcToLocalSchedule(schedule);
    } else {
      throw Exception('Error programando clase: ${response.body}');
    }
  }

  static Future<void> deleteSchedule(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/meetings/schedules/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Error eliminando horario: ${response.body}');
    }
  }

  static Future<void> unlockAchievement(
    String studentId,
    String achievementId,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/achievements/unlock'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'student_id': studentId,
        'achievement_id': achievementId,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 409) {
      throw Exception('Error desbloqueando logro: ${response.body}');
    }
  }

  // ==========================================
  // SHARED / STUDENT
  // ==========================================

  static Future<List<dynamic>> getAchievements() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/achievements'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['achievements'];
    } else {
      throw Exception('Error cargando logros');
    }
  }

  static Future<List<dynamic>> getStudentAchievements(String studentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/achievements/student/$studentId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['achievements'];
    } else {
      throw Exception('Error cargando logros del estudiante');
    }
  }

  static Future<Map<String, dynamic>> joinMeeting(String channelName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/meetings/join'),
      headers: await _getHeaders(),
      body: jsonEncode({'channelName': channelName}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['meeting'];
    } else {
      throw Exception('Error uniéndose a la reunión: ${response.body}');
    }
  }

  static Future<List<dynamic>> getActiveMeetings() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/meetings/active'),
      headers: await _getHeaders(),
    );

    print('🔍 getActiveMeetings - Status: ${response.statusCode}');
    print('🔍 getActiveMeetings - Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print('🔍 getActiveMeetings - Decoded: $decoded');
      print('🔍 getActiveMeetings - Meetings: ${decoded['meetings']}');
      return decoded['meetings'];
    } else {
      throw Exception('Error cargando reuniones activas: ${response.body}');
    }
  }

  static Future<void> endMeeting(String meetingId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/meetings/$meetingId/end'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Error finalizando reunión: ${response.body}');
    }
  }

  // ==========================================
  // ATTENDANCE
  // ==========================================

  static Future<List<dynamic>> recordAttendance({
    required String meetingDate,
    required List<String> studentIds,
    String? meetingId,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/attendance/record'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'meeting_date': meetingDate,
        'student_ids': studentIds,
        'meeting_id': meetingId,
        'notes': notes,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body)['attendance'];
    } else {
      throw Exception('Error registrando asistencia: ${response.body}');
    }
  }

  static Future<List<dynamic>> getTeacherAttendance(
    String teacherId, {
    String? startDate,
    String? endDate,
  }) async {
    String query = '';
    if (startDate != null) query += 'start_date=$startDate&';
    if (endDate != null) query += 'end_date=$endDate&';

    final response = await http.get(
      Uri.parse('$_baseUrl/attendance/teacher/$teacherId?$query'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['attendance'];
    } else {
      throw Exception('Error obteniendo asistencias: ${response.body}');
    }
  }

  static Future<List<dynamic>> getStudentAttendance(String studentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/attendance/student/$studentId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['attendance'];
    } else {
      throw Exception('Error obteniendo asistencias: ${response.body}');
    }
  }

  static Future<List<dynamic>> getAttendanceByDate(String date) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/attendance/date/$date'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['attendance'];
    } else {
      throw Exception('Error obteniendo asistencias: ${response.body}');
    }
  }

  static Future<void> assignAchievementsToAttendance(
    String attendanceId,
    List<String> achievementIds,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/attendance/$attendanceId/achievements'),
      headers: await _getHeaders(),
      body: jsonEncode({'achievement_ids': achievementIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error asignando logros: ${response.body}');
    }
  }
}
