import 'dart:io';
import 'package:flutter/material.dart';
import '../services/simulator_service.dart';

/// Botón inteligente que detecta los .exe en la carpeta simuladores/
/// y los lanza. Si hay varios, muestra un menú.
class SimuladorButton extends StatelessWidget {
  final bool compact; // true = solo ícono + texto corto (para el detalle del modelo)

  const SimuladorButton({super.key, this.compact = false});

  Future<void> _handlePress(BuildContext context) async {
    final sims = SimulatorService.listarSimuladores();

    if (sims.isEmpty) {
      _showNoSimuladorDialog(context);
      return;
    }

    if (sims.length == 1) {
      // Solo uno: lanzar directamente
      await _launch(context, sims.first);
    } else {
      // Varios: mostrar menú de selección
      _showPickerDialog(context, sims);
    }
  }

  Future<void> _launch(BuildContext context, File exe) async {
    try {
      await SimulatorService.lanzar(exe.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Simulador "${exe.uri.pathSegments.last}" iniciado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al abrir simulador: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoSimuladorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: Colors.teal),
            SizedBox(width: 8),
            Text('Sin Simulador'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No se encontró el simulador (STEM_FOR_ALL.exe) en la carpeta:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                SimulatorService.simuladoresDir.path,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Coloca el archivo STEM_FOR_ALL.exe en esa carpeta e inténtalo de nuevo.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await SimulatorService.abrirCarpetaEnExplorador();
            },
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Abrir Carpeta'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showPickerDialog(BuildContext context, List<File> sims) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: Colors.teal),
            SizedBox(width: 8),
            Text('Seleccionar Simulador'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sims.map((exe) {
            final name = exe.uri.pathSegments.last.replaceAll('.exe', '');
            return ListTile(
              leading: const Icon(Icons.play_circle, color: Colors.teal),
              title: Text(name),
              onTap: () {
                Navigator.pop(ctx);
                _launch(context, exe);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ElevatedButton.icon(
        onPressed: () => _handlePress(context),
        icon: const Icon(Icons.sports_esports, size: 18),
        label: const Text('Abrir Simulador'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Versión de tarjeta grande (para el dashboard del maestro)
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handlePress(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.teal.withOpacity(0.12),
                child: const Icon(Icons.sports_esports, color: Colors.teal, size: 26),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Abrir Simulador',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Lanza el simulador 3D desde la carpeta local',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
