import 'package:flutter/material.dart';
import 'screen_sharing_windows.dart';

class ScreenSelectionScreen extends StatefulWidget {
  final ScreenShareController controller;

  const ScreenSelectionScreen({
    super.key,
    required this.controller,
  });

  @override
  _ScreenSelectionScreenState createState() => _ScreenSelectionScreenState();
}

class _ScreenSelectionScreenState extends State<ScreenSelectionScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      await widget.controller.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar fuentes: $e';
        });
      }
    }
  }

  Widget _buildSourceList() {
    final displays = widget.controller.availableDisplays;
    final windows = widget.controller.availableWindows;

    final allSources = [...displays, ...windows];

    if (allSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No se encontraron pantallas o ventanas para compartir.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSources,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: allSources.map((source) {
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 150,
              height: 100,
              child: widget.controller.buildThumbnail(source),
            ),
            title: Text(source.name),
            subtitle: Text(
              'Resolución: ${source.region.width!.toInt()}x${source.region.height!.toInt()}'
            ),
            onTap: () => _startSharing(source),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _startSharing(CaptureSource source) async {
    try {
      await widget.controller.startSharing(source);
      if (mounted) {
        Navigator.pop(context);
        print('[REMOTO] Watuki esta probanco el codigo para ver si el problema es agora o en general');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Pantalla o Ventana'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSources,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _buildSourceList(),
            ),
    );
  }
}