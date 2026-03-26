import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para comunicarse con el backend de reuniones
class MeetingService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Cambiar en producción

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene el token JWT del usuario actual
  Future<String?> _getAuthToken() async {
    final session = _supabase.auth.currentSession;
    return session?.accessToken;
  }

  /// Crea una nueva reunión
  /// Returns: Map con información de la reunión y el token de Agora
  Future<Map<String, dynamic>> createMeeting({
    required String channelName,
    required String title,
    String? description,
    String meetingType = 'master',
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Usuario no autenticado');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/meetings/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'channelName': channelName,
        'title': title,
        'description': description,
        'meeting_type': meetingType,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['meeting'];
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para crear reuniones');
    } else if (response.statusCode == 409) {
      throw Exception('Ya existe una reunión activa con ese nombre');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error']['message'] ?? 'Error al crear reunión');
    }
  }

  /// Une al usuario a una reunión existente
  /// Returns: Map con información de la reunión y el token de Agora
  Future<Map<String, dynamic>> joinMeeting(String channelName) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Usuario no autenticado');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/meetings/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'channelName': channelName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['meeting'];
    } else if (response.statusCode == 404) {
      throw Exception('Reunión no encontrada');
    } else if (response.statusCode == 410) {
      throw Exception('La reunión ha expirado');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error']['message'] ?? 'Error al unirse a la reunión',
      );
    }
  }

  /// Obtiene la lista de reuniones activas
  /// Returns: Lista de reuniones activas
  Future<List<dynamic>> getActiveMeetings() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Usuario no autenticado');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/meetings/active'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['meetings'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error']['message'] ?? 'Error al obtener reuniones',
      );
    }
  }

  /// Finaliza una reunión
  Future<void> endMeeting(String meetingId) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Usuario no autenticado');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/meetings/$meetingId/end'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 403) {
      throw Exception('Solo el creador puede finalizar la reunión');
    } else if (response.statusCode == 404) {
      throw Exception('Reunión no encontrada');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error']['message'] ?? 'Error al finalizar reunión',
      );
    }
  }
}
