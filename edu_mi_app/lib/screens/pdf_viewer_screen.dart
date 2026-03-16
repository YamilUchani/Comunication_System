import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:win32/win32.dart';

// Formato VERTICAL (portrait) — PDF se lee mejor en altura
const Size _kNormalSize = Size(520, 850);
const Size _kBubbleSize = Size(200, 280);

/// Obtiene el ancho real de la pantalla principal usando win32
double _realScreenWidth() {
  if (!Platform.isWindows) return 1920;
  return GetSystemMetrics(SYSTEM_METRICS_INDEX.SM_CXSCREEN).toDouble();
}

double _realScreenHeight() {
  if (!Platform.isWindows) return 1080;
  return GetSystemMetrics(SYSTEM_METRICS_INDEX.SM_CYSCREEN).toDouble();
}

/// Posición inicial: ventana pegada al borde derecho, centrada verticalmente
Offset initialWindowPosition() {
  final sw = _realScreenWidth();
  final sh = _realScreenHeight();
  const margin = 20.0;
  final x = sw - _kNormalSize.width - margin;
  final y = (sh - _kNormalSize.height) / 2;
  return Offset(x, y);
}

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

  /// Posición para la burbuja: esquina superior derecha con margen
  Offset _bubblePosition() {
    final sw = _realScreenWidth();
    const margin = 20.0;
    final x = sw - _kBubbleSize.width - margin;
    return Offset(x, margin);
  }

  Future<void> _toggleBubbleMode() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();

      if (!_isBubbleMode) {
        // 💾 Guardar posición actual
        _preBubblePosition = await windowManager.getPosition();

        // 📉 Encoger y mover a la derecha
        _isBubbleMode = true;
        final bubblePos = _bubblePosition();
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(_kBubbleSize);
        await windowManager.setPosition(bubblePos);
      } else {
        // 🔙 Restaurar tamaño y posición
        _isBubbleMode = false;
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSize(_kNormalSize);
        if (_preBubblePosition != null) {
          await windowManager.setPosition(_preBubblePosition!);
        } else {
          await windowManager.setPosition(initialWindowPosition());
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
              // Vista del PDF en miniatura (no interactiva)
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
              // Barra inferior con título y botón de restaurar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: Colors.black87,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Botón de restaurar ventana
                      InkWell(
                        onTap: _toggleBubbleMode,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.teal,
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

    // ─── MODO NORMAL (850×520, misma posición/tamaño que videollamada del estudiante) ───
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            onPressed: _toggleBubbleMode,
            tooltip: 'Modo Burbuja — minimiza a la esquina derecha',
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
