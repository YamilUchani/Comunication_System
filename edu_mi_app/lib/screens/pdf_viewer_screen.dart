import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Mismo tamaño que la videollamada del estudiante
const Size _kNormalSize = Size(850, 520);
const Size _kBubbleSize = Size(280, 200);

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> with WindowListener {
  bool _isBubbleMode = false;
  Offset? _preBubblePosition;

  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Calcula la posición para la burbuja: margen derecho de la pantalla
  Future<Offset> _bubblePosition() async {
    if (!Platform.isWindows) return const Offset(40, 40);

    double screenW = 1920; // default common
    try {
      final currentPos = await windowManager.getPosition();
      final currentSize = await windowManager.getSize();
      // Estimar ancho de pantalla: el centro de la ventana está a la mitad de la pantalla
      screenW = (currentPos.dx + currentSize.width / 2) * 2;
    } catch (_) {}

    const margin = 20.0;
    final x = screenW - _kBubbleSize.width - margin;
    return Offset(x, margin);
  }

  Future<void> _toggleBubbleMode() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();

      if (!_isBubbleMode) {
        // 💾 Guardar posición antes de encoger
        _preBubblePosition = await windowManager.getPosition();

        // Calcular posición derecha
        final bubblePos = await _bubblePosition();

        _isBubbleMode = true;
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(_kBubbleSize);
        await windowManager.setPosition(bubblePos);
      } else {
        // 🔙 Restaurar tamaño original (= videollamada estudiante) y posición
        _isBubbleMode = false;
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSize(_kNormalSize);
        if (_preBubblePosition != null) {
          await windowManager.setPosition(_preBubblePosition!);
        } else {
          await windowManager.center();
        }
      }
      setState(() {});
    } catch (e) {
      print('❌ Error Bubble Mode PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBubbleMode) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: GestureDetector(
          onPanUpdate: (details) async {
            if (Platform.isWindows) {
              await windowManager.startDragging();
            }
          },
          child: Stack(
            children: [
              // Vista del PDF pequeñita (no interactiva)
              Positioned.fill(
                child: AbsorbPointer(
                  child: SfPdfViewer.network(
                    widget.pdfUrl,
                    canShowScrollHead: false,
                    canShowPaginationDialog: false,
                    canShowScrollStatus: false,
                  ),
                ),
              ),
              // Título en la parte inferior
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black87,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Botón de restaurar
                      GestureDetector(
                        onTap: _toggleBubbleMode,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.open_in_full, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- MODO NORMAL (850×520, igual que la videollamada del estudiante) ---
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            onPressed: _toggleBubbleMode,
            tooltip: 'Modo Burbuja — minimiza a la derecha',
          ),
        ],
      ),
      body: SfPdfViewer.network(
        widget.pdfUrl,
        key: _pdfViewerKey,
      ),
    );
  }
}
