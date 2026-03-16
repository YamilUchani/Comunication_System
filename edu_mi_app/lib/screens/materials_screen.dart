import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/window_service.dart';

class MaterialsScreen extends StatefulWidget {
  final String role; // 'admin', 'teacher', 'student'

  const MaterialsScreen({super.key, required this.role});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _supabase = Supabase.instance.client;

  List<dynamic> _materials = [];
  List<dynamic> _students = [];

  // Mapa: material_id -> { student_id -> status }
  Map<String, Map<String, String>> _progressMap = {};

  bool _isLoading = true;

  String? get _myUserId => _supabase.auth.currentUser?.id;

  bool get _isAdmin => widget.role == 'admin';
  bool get _isTeacher => widget.role == 'teacher';
  bool get _isStudent => widget.role == 'student';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await _fetchMaterials();
      if (_isTeacher) {
        await _fetchMyGroupStudents();
        await _fetchAllProgress();
      } else if (_isStudent) {
        await _fetchMyProgress();
      }
    } catch (e) {
      print('❌ Error cargando materiales: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMaterials() async {
    final data = await _supabase
        .from('materials')
        .select()
        .order('created_at', ascending: false);
    if (mounted) setState(() => _materials = data);
  }

  Future<void> _fetchMyGroupStudents() async {
    // Obtener grupo del maestro logueado
    final profile = await _supabase
        .from('profiles')
        .select('group_name')
        .eq('user_id', _myUserId!)
        .single();

    final groupName = profile['group_name'];
    if (groupName == null) return;

    final students = await _supabase
        .from('profiles')
        .select('user_id, full_name')
        .eq('role', 'student')
        .eq('group_name', groupName)
        .order('full_name');

    if (mounted) setState(() => _students = students);
  }

  Future<void> _fetchAllProgress() async {
    if (_materials.isEmpty || _students.isEmpty) return;

    final studentIds = _students.map((s) => s['user_id'] as String).toList();
    final materialIds = _materials.map((m) => m['id'] as String).toList();

    final rows = await _supabase
        .from('student_material_progress')
        .select()
        .inFilter('student_id', studentIds)
        .inFilter('material_id', materialIds);

    final map = <String, Map<String, String>>{};
    for (final r in rows) {
      final mid = r['material_id'] as String;
      final sid = r['student_id'] as String;
      final status = r['status'] as String? ?? 'disabled';
      map.putIfAbsent(mid, () => {});
      map[mid]![sid] = status;
    }
    if (mounted) setState(() => _progressMap = map);
  }

  Future<void> _fetchMyProgress() async {
    if (_myUserId == null) return;
    final rows = await _supabase
        .from('student_material_progress')
        .select('material_id, status')
        .eq('student_id', _myUserId!);

    final map = <String, Map<String, String>>{};
    for (final r in rows) {
      final mid = r['material_id'] as String;
      final status = r['status'] as String? ?? 'disabled';
      map[mid] = {_myUserId!: status};
    }
    if (mounted) setState(() => _progressMap = map);
  }

  // Devuelve el status de un estudiante para un material dado
  String _getStatus(String materialId, String studentId) {
    return _progressMap[materialId]?[studentId] ?? 'disabled';
  }

  // Guarda/actualiza el status en Supabase
  Future<void> _setStatus(String materialId, String studentId, String newStatus) async {
    await _supabase.from('student_material_progress').upsert({
      'material_id': materialId,
      'student_id': studentId,
      'status': newStatus,
      'updated_by': _myUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'material_id,student_id');

    // Actualizar local
    _progressMap.putIfAbsent(materialId, () => {});
    _progressMap[materialId]![studentId] = newStatus;
    if (mounted) setState(() {});
  }

  // ════════════════════════════════════════════
  //  MAESTRO: Dialog per-estudiante de un modelo
  // ════════════════════════════════════════════
  void _showStudentProgressDialog(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.manage_accounts, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['title'] ?? 'Modelo',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text('Estado por estudiante', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: _students.isEmpty
                ? const Text('No tienes estudiantes asignados.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final student = _students[i];
                      final sid = student['user_id'] as String;
                      final mid = material['id'] as String;
                      final status = _getStatus(mid, sid);

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.teal.withOpacity(0.15),
                          child: Text(
                            (student['full_name'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(student['full_name'] ?? 'Estudiante'),
                        trailing: _StatusDropdown(
                          status: status,
                          onChanged: (newStatus) async {
                            await _setStatus(mid, sid, newStatus);
                            setDlgState(() {}); // refrescar el dialog
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialDetails(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material['title'] ?? 'Sin título'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (material['image_url'] != null && material['image_url'].toString().isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(material['image_url'], height: 200, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(material['description'] ?? 'Sin descripción'),
              const SizedBox(height: 16),
              if (material['pdf_url'] != null && material['pdf_url'].toString().isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _openPdf(material['pdf_url'], material['title'] ?? 'Visor de PDF'),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Visor de PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _openPdf(String url, String title) async {
    if (Platform.isWindows) {
      try {
        await WindowService().openPdfViewerWindow(
          pdfUrl: url,
          title: title,
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir PDF: $e')));
      }
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el PDF')));
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateMaterialDialog(),
    ).then((value) {
      if (value == true) _loadAll();
    });
  }

  // ════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espacio de Material / Modelos'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'Actualizar'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Crear Modelo'),
              backgroundColor: Colors.teal,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isTeacher) return _buildTeacherView();
    if (_isStudent) return _buildStudentView();
    return _buildAdminView(); // admin: ve todos en grid
  }

  // ─── VISTA MAESTRO ───────────────────────────────────────────
  Widget _buildTeacherView() {
    if (_materials.isEmpty) {
      return const Center(child: Text('No hay modelos creados aún.'));
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.teal.shade50,
          child: Text(
            '👥 ${_students.length} estudiante(s) en tu grupo  •  Toca la tarjeta para ver el modelo  •  "Gestionar" para asignar estados',
            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _materials.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _materials[index];
              final mid = item['id'] as String;

              // Contar cuántos estudiantes tienen cada estado
              final counts = <String, int>{'disabled': 0, 'active': 0, 'achieved': 0};
              for (final student in _students) {
                final sid = student['user_id'] as String;
                final s = _getStatus(mid, sid);
                counts[s] = (counts[s] ?? 0) + 1;
              }

              return Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onTap: () => _showMaterialDetails(item), // ← el maestro también puede ver el modelo
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                        ? Image.network(item['image_url'], width: 56, height: 56, fit: BoxFit.cover)
                        : Container(
                            width: 56, height: 56,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                  ),
                  title: Text(item['title'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        _MiniCount(count: counts['disabled']!, color: Colors.grey, icon: Icons.visibility_off),
                        const SizedBox(width: 8),
                        _MiniCount(count: counts['active']!, color: Colors.green, icon: Icons.visibility),
                        const SizedBox(width: 8),
                        _MiniCount(count: counts['achieved']!, color: Colors.orange, icon: Icons.emoji_events),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blueGrey),
                        tooltip: 'Ver modelo',
                        onPressed: () => _showMaterialDetails(item),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showStudentProgressDialog(item),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Gestionar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Leyenda
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniCount(count: 0, color: Colors.grey, icon: Icons.visibility_off),
                const SizedBox(width: 4),
                const Text('Desactivado  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _MiniCount(count: 0, color: Colors.green, icon: Icons.visibility),
                const SizedBox(width: 4),
                const Text('Activado  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _MiniCount(count: 0, color: Colors.orange, icon: Icons.emoji_events),
                const SizedBox(width: 4),
                const Text('Logrado', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── VISTA ESTUDIANTE ────────────────────────────────────────
  Widget _buildStudentView() {
    final uid = _myUserId;
    final visible = _materials.where((m) {
      if (uid == null) return false;
      final s = _progressMap[m['id'] as String]?[uid] ?? 'disabled';
      return s == 'active' || s == 'achieved';
    }).toList();

    if (visible.isEmpty) {
      return const Center(child: Text('Tu maestro aún no ha activado ningún modelo para ti.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        final status = _progressMap[item['id'] as String]?[uid!] ?? 'active';
        final isAchieved = status == 'achieved';

        return GestureDetector(
          onTap: () => _showMaterialDetails(item),
          child: Container(
            decoration: isAchieved
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 3),
                    boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.35), blurRadius: 10, spreadRadius: 2)],
                  )
                : null,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                        ? Image.network(item['image_url'], fit: BoxFit.cover)
                        : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (isAchieved)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.emoji_events, color: Colors.orange, size: 14),
                                SizedBox(width: 4),
                                Text('Logrado', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── VISTA ADMIN ─────────────────────────────────────────────
  Widget _buildAdminView() {
    if (_materials.isEmpty) {
      return const Center(child: Text('No hay modelos creados aún.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final item = _materials[index];
        return GestureDetector(
          onTap: () => _showMaterialDetails(item),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                      ? Image.network(item['image_url'], fit: BoxFit.cover)
                      : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.white,
                  child: Text(item['title'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════ WIDGETS CHICOS ════════

class _MiniCount extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;
  const _MiniCount({required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 2),
        Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;
  const _StatusDropdown({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      {'value': 'disabled', 'label': 'Desactivado', 'color': 0xFF9E9E9E},
      {'value': 'active', 'label': 'Activado', 'color': 0xFF4CAF50},
      {'value': 'achieved', 'label': 'Logrado', 'color': 0xFFFF9800},
    ];

    final selected = items.firstWhere((i) => i['value'] == status, orElse: () => items[0]);
    final color = Color(selected['color'] as int);

    return PopupMenuButton<String>(
      initialValue: status,
      onSelected: onChanged,
      tooltip: 'Cambiar estado',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected['label'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
      itemBuilder: (ctx) => items.map((i) {
        final c = Color(i['color'] as int);
        return PopupMenuItem<String>(
          value: i['value'] as String,
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(i['label'] as String, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════
//  DIALOG DE CREACIÓN (ADMIN)
// ════════════════════════════════════════════
class CreateMaterialDialog extends StatefulWidget {
  const CreateMaterialDialog({super.key});

  @override
  State<CreateMaterialDialog> createState() => _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends State<CreateMaterialDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  File? _pdfFile;
  bool _isUploading = false;
  final _supabase = Supabase.instance.client;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _imageFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      setState(() => _pdfFile = File(result.files.single.path!));
    }
  }

  Future<void> _saveModel() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El título es obligatorio.')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      String? imageUrl, pdfUrl;

      if (_imageFile != null) {
        final ext = _imageFile!.path.split('.').last;
        final path = 'images/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('materials').upload(path, _imageFile!);
        imageUrl = _supabase.storage.from('materials').getPublicUrl(path);
      }

      if (_pdfFile != null) {
        final ext = _pdfFile!.path.split('.').last;
        final path = 'pdfs/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('materials').upload(path, _pdfFile!);
        pdfUrl = _supabase.storage.from('materials').getPublicUrl(path);
      }

      await _supabase.from('materials').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'pdf_url': pdfUrl,
        'created_by': _supabase.auth.currentUser!.id,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modelo creado.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nuevo Modelo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título del Modelo')),
            const SizedBox(height: 10),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Texto descriptivo'), maxLines: 4),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(_imageFile == null ? 'Imagen' : 'Cambiar Imagen'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100]),
                  ),
                ),
                if (_imageFile != null) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.green)],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(_pdfFile == null ? 'PDF de Instrucciones' : 'Cambiar PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                  ),
                ),
                if (_pdfFile != null) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.green)],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isUploading ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveModel,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Crear Modelo'),
        ),
      ],
    );
  }
}
