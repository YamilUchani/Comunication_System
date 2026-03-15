import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialsScreen extends StatefulWidget {
  final bool isAdmin;

  const MaterialsScreen({super.key, required this.isAdmin});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    try {
      final data = await _supabase
          .from('materials')
          .select()
          .order('created_at', ascending: false);

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

  void _showCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateMaterialDialog(),
    ).then((value) {
      if (value == true) {
        _fetchMaterials();
      }
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
                  child: Image.network(
                    material['image_url'],
                    height: 200,
                    fit: BoxFit.cover,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espacio de Material / Modelos'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? const Center(child: Text('Aún no hay modelos disponibles.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250, // Hace que las tarjetas sean más pequeñas
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                  ? Image.network(
                                      item['image_url'],
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: Text(
                                item['title'] ?? 'Sin Título',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Crear Modelo'),
              backgroundColor: Colors.teal,
            )
          : null,
    );
  }
}

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveModel() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl;
      String? pdfUrl;

      // Subir Imagen si hay
      if (_imageFile != null) {
        final imageExt = _imageFile!.path.split('.').last;
        final imagePath = 'images/${DateTime.now().millisecondsSinceEpoch}.$imageExt';
        
        await _supabase.storage.from('materials').upload(
          imagePath,
          _imageFile!,
        );
        imageUrl = _supabase.storage.from('materials').getPublicUrl(imagePath);
      }

      // Subir PDF si hay
      if (_pdfFile != null) {
        final pdfExt = _pdfFile!.path.split('.').last;
        final pdfPath = 'pdfs/${DateTime.now().millisecondsSinceEpoch}.$pdfExt';
        
        await _supabase.storage.from('materials').upload(
          pdfPath,
          _pdfFile!,
        );
        pdfUrl = _supabase.storage.from('materials').getPublicUrl(pdfPath);
      }

      // Insertar a base de datos
      await _supabase.from('materials').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'pdf_url': pdfUrl,
        'created_by': _supabase.auth.currentUser!.id,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modelo creado exitosamente')),
        );
      }
    } catch (e) {
      print('❌ Error guardando modelo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
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
                ]
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
                ]
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Crear Modelo'),
        ),
      ],
    );
  }
}
