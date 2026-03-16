import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  Size? _preBubbleSize;
  Offset? _preBubblePosition;

  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    if (Platform.isWindows) {
      windowManager.setPreventClose(false); 
      // PDF viewer no previene cierre
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _toggleBubbleMode() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      
      if (!_isBubbleMode) {
        // 💾 GUARDAR estado actual antes de encoger
        _preBubbleSize = await windowManager.getSize();
        _preBubblePosition = await windowManager.getPosition();
        
        // 📉 ENCOGER a modo burbuja
        _isBubbleMode = true;
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(const Size(280, 200));
        await windowManager.setPosition(const Offset(40, 40));
      } else {
        // 🔙 RESTAURAR estado anterior
        _isBubbleMode = false;
        await windowManager.setAlwaysOnTop(false);
        if (_preBubbleSize != null) {
          await windowManager.setSize(_preBubbleSize!);
        } else {
          await windowManager.setSize(const Size(800, 600));
        }

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
              // Vista del PDF pequeñito o solo miniatura
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
              // Botón de restaurar
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.open_in_full, color: Colors.white, size: 20),
                    onPressed: _toggleBubbleMode,
                    tooltip: 'Restaurar ventana',
                  ),
                ),
              ),
              // Título burbuja superior
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- MODO NORMAL ---
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            onPressed: _toggleBubbleMode,
            tooltip: 'Modo Burbuja (Minimizar)',
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
