import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/window_service.dart';
import '../services/meeting_cleanup_service.dart';
import '../utils/dialog_utils.dart';
import '../video_call/video_call_screen.dart';
import 'materials_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _activeMeetings;
  List<dynamic>? _groupsWithMembers;
  List<dynamic>? _unassignedUsers;
  List<dynamic>? _parents;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await ApiService.getAdminStats();
      final meetings = await ApiService.getActiveMeetings();
      final groupsData = await ApiService.getGroupsWithMembers();

      print('📊 Admin Dashboard - Stats: $stats');
      print('📊 Admin Dashboard - Meetings count: ${meetings.length}');
      print('📊 Admin Dashboard - Groups: ${groupsData['groups']}');

      List<dynamic> parents = [];
      try {
        parents = await ApiService.getParents();
      } catch (e) {
        print('⚠️ Error cargando padres (tabla parent_students puede no existir): $e');
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _activeMeetings = meetings;
          _groupsWithMembers = groupsData['groups'];
          _unassignedUsers = groupsData['unassigned'];
          _parents = parents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
        backgroundColor: Colors.indigo,
        actions: [
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
              // 🔐 Pedir confirmación antes de cerrar sesión
              final confirmed = await DialogUtils.showLogoutDialog(context);
              if (!confirmed) return;

              // 🧹 Limpieza al cerrar sesión
              await MeetingCleanupService.cleanupActiveMeeting();
              await WindowService().terminateSecondaryWindows();

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
                  _buildCard(
                    context,
                    'Espacio de Material',
                    'Gestiona los modelos y recursos para estudiantes',
                    Icons.dashboard_customize,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MaterialsScreen(role: 'admin')),
                    ),
                  ),
                  const Divider(height: 30),

                  // Sección de Reuniones Activas (Expandible)
                  _buildActiveMeetingsSection(),

                  const Divider(height: 30),

                  // Sección de Grupos (Expandible)
                  _buildGroupsSection(),

                  const Divider(height: 30),

                  // Sección de Padres (Expandible)
                  _buildParentsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      onPressed: onTap,
    );
  }

  Widget _buildActiveMeetingsSection() {
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Reuniones Activas (${_activeMeetings?.length ?? 0})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.purple),
            tooltip: 'Nueva Reunión',
            onPressed: () => _showCreateMeetingDialog(context),
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        if (_activeMeetings == null || _activeMeetings!.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No hay reuniones activas'),
          )
        else
          ..._activeMeetings!.map((m) => _buildMeetingCard(m)),
      ],
    );
  }

  Widget _buildGroupsSection() {
    if (_groupsWithMembers == null)
      return const Center(child: CircularProgressIndicator());

    return ExpansionTile(
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Gestión de Grupos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.orange),
            tooltip: 'Crear Grupo',
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        ..._groupsWithMembers!.map((group) => _buildGroupTile(group)),
        _buildUnassignedTile(),
      ],
    );
  }

  Widget _buildGroupTile(dynamic group) {
    final members = group['members'] as List<dynamic>? ?? [];
    final color = _parseColor(group['color']);

    return DragTarget<Object>(
      onWillAccept: (data) {
        if (data is Map<String, dynamic>) {
          return data['group_name'] != group['name'];
        }
        return false;
      },
      onAccept: (data) {
        if (data is Map<String, dynamic>) {
          _moveUserToGroup(data, group['name']);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: candidateData.isNotEmpty ? Colors.blue.withOpacity(0.1) : null,
          shape: candidateData.isNotEmpty
              ? RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text(
                group['display_name']?[0] ?? 'G',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              group['display_name'] ?? group['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${members.length} miembros'),
            children: [
              ...members.map((member) => _buildMemberTile(member)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Eliminar Grupo'),
                      onPressed: () => _confirmDeleteGroup(group),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnassignedTile() {
    final users = _unassignedUsers ?? [];
    return DragTarget<Object>(
      onWillAccept: (data) {
        if (data is Map<String, dynamic>) {
          return data['group_name'] != null;
        }
        return false;
      },
      onAccept: (data) {
        if (data is Map<String, dynamic>) {
          _moveUserToGroup(data, null);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Card(
          color: candidateData.isNotEmpty
              ? Colors.grey.withOpacity(0.3)
              : Colors.grey[100],
          margin: const EdgeInsets.only(bottom: 8),
          shape: candidateData.isNotEmpty
              ? RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ExpansionTile(
            leading: const Icon(Icons.person_outline, color: Colors.grey),
            title: const Text('No Asignados'),
            subtitle: Text('${users.length} usuarios sin grupo'),
            children: users.map((u) => _buildMemberTile(u)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(dynamic user) {
    final isTeacher = user['role'] == 'teacher';
    final tile = ListTile(
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: isTeacher ? Colors.red : Colors.blue,
        child: Icon(
          isTeacher ? Icons.school : Icons.person,
          size: 16,
          color: Colors.white,
        ),
      ),
      title: Text(user['full_name'] ?? 'Sin nombre'),
      subtitle: Text(isTeacher ? 'Profesor' : 'Estudiante'),
      dense: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTeacher)
            const Chip(
              label: Text(
                'Teacher',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showEditUserDialog(user),
            tooltip: 'Editar usuario',
          ),
        ],
      ),
    );

    return Draggable<Object>(
      data: user,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: tile,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: tile),
      child: tile,
    );
  }

  Future<void> _moveUserToGroup(dynamic user, String? newGroupName) async {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moviendo a ${user['full_name']} a ${newGroupName ?? "No Asignados"}...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      await ApiService.updateUserRole(
        user['user_id'],
        user['role'], // Mantener el mismo rol
        newGroupName,
      );

      if (mounted) {
        _loadData(); // Recargar datos para reflejar el cambio
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moviendo usuario: $e')));
      }
    }
  }

  void _showEditUserDialog(dynamic user) async {
    String selectedRole = user['role'] ?? 'student';
    String? selectedGroup = user['group_name'];

    // Obtener lista de grupos disponibles
    List<dynamic> groups = [];
    try {
      groups = await ApiService.getGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando grupos: $e')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Editar: ${user['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rol:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'student',
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Estudiante'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'teacher',
                        child: Row(
                          children: [
                            Icon(Icons.school, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Profesor'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'parent',
                        child: Row(
                          children: [
                            Icon(Icons.family_restroom, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Padre'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'administrator',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Administrador'),
                          ],
                        ),
                      ),
                    ],
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Grupo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<String?>(
                value: selectedGroup,
                isExpanded: true,
                hint: const Text('Sin grupo'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin grupo')),
                  ...groups.map(
                    (g) => DropdownMenuItem(
                      value: g['name'],
                      child: Text(g['display_name']),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedGroup = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateUserRole(
                    user['user_id'],
                    selectedRole,
                    selectedGroup,
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Usuario actualizado exitosamente'),
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xff')));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _confirmDeleteGroup(dynamic group) async {
    final confirmController = TextEditingController();
    final groupName = group['name'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar el grupo "$groupName"?'),
            const SizedBox(height: 10),
            const Text(
              'Esta acción moverá a todos los miembros a "No Asignados".',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Text('Escribe el nombre del grupo para confirmar:'),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(hintText: groupName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmController.text == groupName) {
                Navigator.pop(context);
                try {
                  await ApiService.deleteGroup(
                    groupName,
                    confirmController.text,
                  );
                  _loadData(); // Recargar silenciosamente
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grupo eliminado')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El nombre no coincide')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PARENTS SECTION
  // ═══════════════════════════════════════════

  Widget _buildParentsSection() {
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Vinculación Padres-Hijos (${_parents?.length ?? 0})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            tooltip: 'Recargar',
            onPressed: () async {
              try {
                final parents = await ApiService.getParents();
                if (mounted) setState(() => _parents = parents);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        if (_parents == null || _parents!.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No hay padres registrados. Los padres se registran desde la app EduCoParent.'),
          )
        else
          ..._parents!.map((p) => _buildParentTile(p)),
      ],
    );
  }

  Widget _buildParentTile(dynamic parent) {
    final children = parent['children'] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.family_restroom, color: Colors.white),
        ),
        title: Text(
          parent['name'] ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${parent['email'] ?? ''}  •  ${children.length} hijo(s)'),
        children: [
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sin hijos vinculados aún', style: TextStyle(color: Colors.grey)),
            )
          else
            ...children.map((c) => ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              title: Text(c['name'] ?? 'Desconocido'),
              subtitle: Text('${c['email'] ?? ''}  •  ${c['group'] ?? 'Sin grupo'}'),
              trailing: IconButton(
                icon: const Icon(Icons.link_off, color: Colors.red, size: 20),
                tooltip: 'Desvincular',
                onPressed: () => _showUnlinkConfirm(parent, c),
              ),
            )),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.teal),
              label: const Text('Vincular Estudiante'),
              onPressed: () => _showLinkStudentDialog(parent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkStudentDialog(dynamic parent) async {
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    bool searching = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Vincular estudiante a ${parent['name']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar estudiante',
                    hintText: 'Nombre o correo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) async {
                    if (val.trim().isEmpty) return;
                    setDialogState(() => searching = true);
                    try {
                      final results = await ApiService.searchStudents(val);
                      setDialogState(() {
                        searchResults = results;
                        searching = false;
                      });
                    } catch (e) {
                      setDialogState(() => searching = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (searching)
                  const CircularProgressIndicator()
                else if (searchResults.isEmpty && searchController.text.isNotEmpty)
                  const Text('Sin resultados', style: TextStyle(color: Colors.grey))
                else
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final student = searchResults[index];
                        final alreadyLinked = (parent['children'] as List).any((c) => c['id'] == student['user_id']);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: alreadyLinked ? Colors.green : Colors.blue,
                            child: Text(
                              (student['full_name'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(student['full_name'] ?? 'Sin nombre'),
                          subtitle: Text('${student['email'] ?? ''}  •  ${student['group_name'] ?? 'Sin grupo'}'),
                          trailing: alreadyLinked
                              ? const Chip(label: Text('Vinculado', style: TextStyle(fontSize: 10)), backgroundColor: Colors.green)
                              : ElevatedButton(
                                  child: const Text('Vincular'),
                                  onPressed: () async {
                                    try {
                                      await ApiService.linkStudentToParent(parent['id'], student['user_id']);
                                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text('${student['full_name']} vinculado correctamente'),
                                        ));
                                        final parents = await ApiService.getParents();
                                        if (mounted) setState(() => _parents = parents);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    }
                                  },
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnlinkConfirm(dynamic parent, dynamic child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular estudiante'),
        content: Text('¿Desvincular a ${child['name']} de ${parent['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.unlinkStudentFromParent(parent['id'], child['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${child['name']} desvinculado de ${parent['name']}'),
          ));
          final parents = await ApiService.getParents();
          if (mounted) setState(() => _parents = parents);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildMeetingCard(dynamic meeting) {
    final createdAt = DateTime.parse(meeting['createdAt']);
    final formattedTime =
        '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.video_camera_front, color: Colors.white),
        ),
        title: Text(
          meeting['title'] ?? 'Reunión',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Creada a las $formattedTime\nCanal: ${meeting['channelName']}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.login, color: Colors.green),
              tooltip: 'Unirse',
              onPressed: () => _joinMeeting(meeting),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Finalizar',
              onPressed: () => _endMeeting(meeting['id']),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endMeeting(String meetingId) async {
    try {
      await ApiService.endMeeting(meetingId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reunión finalizada')));
        _loadData(); // Recargar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _joinMeeting(dynamic meeting) async {
    try {
      print('🎥 Intentando unirse a reunión: ${meeting['channelName']}');

      // Obtener token de Agora desde el backend
      final meetingData = await ApiService.joinMeeting(meeting['channelName']);
      print('✅ Token obtenido: ${meetingData['token']}');

      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', user!.id)
          .single();

      final userName = profile['full_name'] ?? 'Admin';

      if (mounted) {
        print('🚀 Lanzando ventana de videollamada independiente...');
        
        await WindowService().openVideoCallWindow(
          channelName: meetingData['channelName'],
          token: meetingData['token'],
          userName: userName,
          userRole: 'admin', // 🔐 Identificar como admin
          meetingId: meetingData['id'], // 🆔 Pasar ID de la reunión
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
      print('❌ Error uniéndose a reunión: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al unirse: $e')));
      }
    }
  }

  Widget _buildStatsOverview() {
    if (_stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen del Sistema',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Usuarios',
                _stats!['users'].length.toString(),
                Icons.person,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Reuniones Activas',
                _stats!['active_meetings'].toString(),
                Icons.video_camera_front,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildStatCard(
          'Asistencia (Último mes)',
          _stats!['attendance_last_month'].toString(),
          Icons.calendar_today,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showUserManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const UserManagementSheet(),
    );
  }

  void _showCreateGroupDialog(BuildContext parentContext) {
    final displayController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear Nuevo Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: displayController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Grupo (ej: Matemáticas 101)',
                hintText: 'El ID se generará automáticamente',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (displayController.text.isEmpty) return;

              try {
                // Generar ID automático
                final generatedId = displayController.text
                    .toLowerCase()
                    .trim()
                    .replaceAll(RegExp(r'\s+'), '_')
                    .replaceAll(RegExp(r'[^a-z0-9_]'), '');

                // Esperar a que termine la creación
                await ApiService.createGroup(
                  generatedId,
                  displayController.text,
                  'Grupo creado por admin',
                  '#3B82F6',
                  '📚',
                );

                if (parentContext.mounted) {
                  Navigator.pop(dialogContext); // Cerrar diálogo
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Grupo creado exitosamente')),
                  );

                  // Recargar datos silenciosamente
                  _loadData();
                }
              } catch (e) {
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(
                    parentContext,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showCreateMeetingDialog(BuildContext parentContext) async {
    final titleController = TextEditingController();
    List<dynamic> groups = [];
    List<String> selectedGroups = [];

    try {
      groups = await ApiService.getGroups();
    } catch (e) {
      // Ignorar error de carga de grupos
    }

    if (!parentContext.mounted) return;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Iniciar Reunión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la reunión',
                    hintText: 'Ej: Reunión General',
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Seleccionar Grupos Permitidos:'),
                Wrap(
                  spacing: 8,
                  children: groups.map((g) {
                    final isSelected = selectedGroups.contains(g['name']);
                    return FilterChip(
                      label: Text(g['display_name']),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedGroups.add(g['name']);
                          } else {
                            selectedGroups.remove(g['name']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final meeting = await ApiService.createMeeting(
                    titleController.text,
                    'Reunión creada por admin',
                    allowedGroups: selectedGroups.isEmpty
                        ? null
                        : selectedGroups,
                  );

                  if (parentContext.mounted) {
                    Navigator.pop(dialogContext);
                    _loadData(); // Recargar lista de reuniones

                    final user = Supabase.instance.client.auth.currentUser;
                    final profile = await Supabase.instance.client
                        .from('profiles')
                        .select('full_name')
                        .eq('user_id', user!.id)
                        .single();

                    final userName = profile['full_name'] ?? 'Admin';

                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          channelName: meeting['channelName'],
                          token: meeting['token'],
                          userName: userName,
                          meetingId: meeting['id'], // 🆔 Pasar ID de la reunión
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(
                      parentContext,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Iniciar'),
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementSheet extends StatefulWidget {
  const UserManagementSheet({super.key});

  @override
  State<UserManagementSheet> createState() => _UserManagementSheetState();
}

class _UserManagementSheetState extends State<UserManagementSheet> {
  List<dynamic>? _users;
  List<dynamic>? _groups;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final users = await ApiService.getUsers();
      final groups = await ApiService.getGroups();
      if (mounted) {
        setState(() {
          _users = users;
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Gestión de Usuarios',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_users == null || _users!.isEmpty)
            const Text('No hay usuarios registrados')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users!.length,
                itemBuilder: (context, index) {
                  final user = _users![index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(user['full_name']?[0] ?? '?'),
                      ),
                      title: Text(user['full_name'] ?? 'Sin nombre'),
                      subtitle: Text(
                        user['email'] != null &&
                                user['email'].toString().isNotEmpty
                            ? '${user['email']}\nRol: ${user['role']} | Grupo: ${user['group_name'] ?? "Ninguno"}'
                            : 'Rol: ${user['role']} | Grupo: ${user['group_name'] ?? "Ninguno"}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editUser(user),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _editUser(dynamic user) {
    String selectedRole = user['role'] ?? 'student';
    String? selectedGroup = user['group_name'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Editar ${user['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: ['student', 'teacher', 'parent', 'administrator']
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedRole = val!),
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _groups?.any((g) => g['name'] == selectedGroup) == true
                    ? selectedGroup
                    : null,
                items:
                    _groups
                        ?.map<DropdownMenuItem<String>>(
                          (g) => DropdownMenuItem(
                            value: g['name'],
                            child: Text(g['display_name']),
                          ),
                        )
                        .toList() ??
                    [],
                onChanged: (val) => setState(() => selectedGroup = val),
                decoration: const InputDecoration(labelText: 'Grupo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateUserRole(
                    user['user_id'],
                    selectedRole,
                    selectedGroup,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData(); // Recargar lista
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
