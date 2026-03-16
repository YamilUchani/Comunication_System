import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// Roles posibles: 'admin', 'teacher', 'student'
class MaterialsScreen extends StatefulWidget {
  final String role; // 'admin', 'teacher', 'student'

  const MaterialsScreen({super.key, required this.role});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _materials = [];
  bool _isLoading = true;

  bool get _isAdmin => widget.role == 'admin';
  bool get _isTeacher => widget.role == 'teacher';
  bool get _isStudent => widget.role == 'student';

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    try {
      var query = _supabase.from('materials').select().order('created_at', ascending: false);

      final data = await query;

      if (mounted) {
        setState(() {
          _materials = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error obteniendo materiales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Cicla el estado: disabled -> active -> achieved -> disabled
  Future<void> _cycleStatus(Map<String, dynamic> material) async {
    final current = material['status'] ?? 'disabled';
    String next;
    switch (current) {
      case 'disabled':
        next = 'active';
        break;
      case 'active':
        next = 'achieved';
        break;
      case 'achieved':
      default:
        next = 'disabled';
    }

    try {
      await _supabase
          .from('materials')
          .update({'status': next})
          .eq('id', material['id']);

      await _fetchMaterials();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateMaterialDialog(),
    ).then((value) {
      if (value == true) _fetchMaterials();
    });
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
                    child: Image.network(
                      material['image_url'],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
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
                    onPressed: () => _openPdf(material['pdf_url']),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Visor de PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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
    );
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el PDF')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar según rol
    final visibleMaterials = _isStudent
        ? _materials.where((m) {
            final s = m['status'] ?? 'disabled';
            return s == 'active' || s == 'achieved';
          }).toList()
        : _materials;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espacio de Material / Modelos'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🎓 Sección de gestión solo para maestro
                if (_isTeacher) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.teal.shade50,
                    child: const Text(
                      '🎛️ Gestión de Modelos — Toca el estado para cambiarlo',
                      style: TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: _buildTeacherManagementList()),
                  const Divider(height: 1, thickness: 1.5),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: const [
                        _StatusBadge(status: 'disabled'),
                        SizedBox(width: 8),
                        Text('Oculto al estudiante', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        SizedBox(width: 20),
                        _StatusBadge(status: 'active'),
                        SizedBox(width: 8),
                        Text('Visible al estudiante', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        SizedBox(width: 20),
                        _StatusBadge(status: 'achieved'),
                        SizedBox(width: 8),
                        Text('Logrado (borde naranja)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ]
                // Vista normal (admin o student) – Grid de tarjetas
                else if (visibleMaterials.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No hay modelos disponibles para ti.')),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: visibleMaterials.length,
                      itemBuilder: (context, index) {
                        final item = visibleMaterials[index];
                        final status = item['status'] ?? 'disabled';
                        final isAchieved = status == 'achieved';

                        return GestureDetector(
                          onTap: () => _showMaterialDetails(item),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isAchieved
                                  ? Border.all(color: Colors.orange, width: 3)
                                  : null,
                              boxShadow: isAchieved
                                  ? [BoxShadow(color: Colors.orange.withOpacity(0.35), blurRadius: 10, spreadRadius: 2)]
                                  : null,
                            ),
                            child: Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                        ? Image.network(item['image_url'], fit: BoxFit.cover)
                                        : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image, size: 50, color: Colors.grey),
                                          ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? 'Sin Título',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                    ),
                  ),
              ],
            ),
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

  Widget _buildTeacherManagementList() {
    if (_materials.isEmpty) {
      return const Center(child: Text('No hay modelos creados aún.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _materials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _materials[index];
        final status = item['status'] ?? 'disabled';

        return Card(
          elevation: 2,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                  ? Image.network(
                      item['image_url'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            title: Text(item['title'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: GestureDetector(
              onTap: () => _cycleStatus(item),
              child: _StatusBadge(status: status),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'active':
        bg = Colors.green;
        fg = Colors.white;
        icon = Icons.visibility;
        label = 'Activado';
        break;
      case 'achieved':
        bg = Colors.orange;
        fg = Colors.white;
        icon = Icons.emoji_events;
        label = 'Logrado';
        break;
      case 'disabled':
      default:
        bg = Colors.grey.shade400;
        fg = Colors.white;
        icon = Icons.visibility_off;
        label = 'Desactivado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =================== DIALOG DE CREACIÓN ===================

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _pdfFile = File(result.files.single.path!));
    }
  }

  Future<void> _saveModel() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      String? pdfUrl;

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
        'status': 'disabled', // Por defecto: desactivado al crear
        'created_by': _supabase.auth.currentUser!.id,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modelo creado. Está desactivado por defecto.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título del Modelo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Texto descriptivo'),
              maxLines: 4,
            ),
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
                if (_imageFile != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
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
                if (_pdfFile != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveModel,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Crear Modelo'),
        ),
      ],
    );
  }
}
