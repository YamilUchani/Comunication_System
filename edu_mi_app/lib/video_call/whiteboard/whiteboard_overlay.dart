import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:window_manager/window_manager.dart';import 'whiteboard_model.dart';
import 'whiteboard_service.dart';
import 'whiteboard_toolbar.dart';

class WhiteboardOverlay extends StatefulWidget {
  final bool isTeacher;
  final String meetingId;
  final VoidCallback onClose;

  const WhiteboardOverlay({
    Key? key,
    required this.isTeacher,
    required this.meetingId,
    required this.onClose,
  }) : super(key: key);

  @override
  _WhiteboardOverlayState createState() => _WhiteboardOverlayState();
}

class _WhiteboardOverlayState extends State<WhiteboardOverlay> {
  late WhiteboardService _service;
  final _uuid = const Uuid();

  // Estados
  List<WhiteboardObject> _objects = [];
  Map<String, ui.Image> _decodedImages = {};
  bool _isTransparent = true;
  bool _isPaused = false; // ⏸️ Evita dibujo si hay menús abiertos

  // Herramientas e interacciones
  WhiteboardTool _currentTool = WhiteboardTool.pencil;
  Color _currentColor = Colors.red;
  double _strokeWidth = 3.0;

  // Variables para gestos
  WhiteboardObject? _currentDrawingObject;
  WhiteboardObject? _selectedObject;
  Offset? _moveStartOffset;
  DateTime? _lastSyncTime; // ⏱️ Throttle envío de objetos (250ms)
  Size? _teacherSize; // 📏 Dimensiones pantalla del maestro
  bool _isPassThrough = false; // 🔓 Modo paso
  Timer? _mouseTimer;          // 🖱️ Revisa la posición del mouse
  bool _isMouseOverToolbar = false;
  @override
  void initState() {
    super.initState();

    // ⏮️ Listener de teclado: Escape desactiva el Modo Paso (el mouse no puede hacerlo)
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _service = WhiteboardService(
      meetingId: widget.meetingId,
      onObjectAdded: _handleRemoteAdd,
      onObjectUpdated: _handleRemoteUpdate,
      onObjectRemoved: _handleRemoteRemove,
      onClear: _handleRemoteClear,
      onModeChanged: _handleRemoteMode,
      onSyncRequest: _handleSyncRequest,
      onBoardInfoChanged: _handleBoardInfo,
      onBoardClosed: _handleBoardClosed, // 🚪 Nuevo: escuchar evento de cierre
    );

    // Si es estudiante, solicitar sincronización inicial después de un pequeo retraso para asegurar que el socket conectó
    if (!widget.isTeacher) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _service.requestSync();
      });
    }
  }

  @override
  void dispose() {
    _mouseTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _service.dispose();
    super.dispose();
  }

  /// 🌆 Handler de teclas LOCAL (cuando la pizarra tiene focus)
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isPassThrough && widget.isTeacher) {
        _togglePassThrough();
        return true;
      }
    }
    return false;
  }

  // ============== CALLBACKS REMOTOS ==============
  void _handleRemoteAdd(WhiteboardObject obj) {
    if (obj is ImageObject) _cacheImage(obj);
    setState(() {
      _objects.removeWhere((o) => o.id == obj.id);
      _objects.add(obj);
    });
  }

  void _handleRemoteUpdate(WhiteboardObject obj) {
    setState(() {
      final index = _objects.indexWhere((o) => o.id == obj.id);
      if (index != -1) {
        _objects[index] = obj;
      } else {
        _objects.add(obj); // 🔙 Si por si acaso llegó un Update antes del Add
      }
    });
  }

  void _handleRemoteRemove(String id) {
    setState(() {
      _objects.removeWhere((o) => o.id == id);
      _decodedImages.remove(id);
    });
  }

  void _handleRemoteClear() {
    setState(() {
      _objects.clear();
      _decodedImages.clear();
    });
  }

  void _handleRemoteMode(bool isTransparent) {
    setState(() {
      _isTransparent = isTransparent;
    });
  }

  void _handleBoardInfo(double w, double h) {
    setState(() {
      _teacherSize = Size(w, h);
    });
  }

  void _handleSyncRequest() {
    if (widget.isTeacher) {
      // Un estudiante acaba de conectarse y pide el estado actual del lienzo global
      _service.changeMode(_isTransparent);
      if (_teacherSize != null) {
        _service.sendBoardInfo(_teacherSize!.width, _teacherSize!.height);
      }
      for (var obj in _objects) {
        _service.sendObject(obj);
      }
    }
  }

  /// 🚪 Maneja el evento de cierre de pizarra en cascada (maestro cierra → estudiantes cierran)
  void _handleBoardClosed() {
    if (!widget.isTeacher) {
      print(
        '🚪 [Estudiante] Maestro cerró la pizarra. Cerrando automáticamente...',
      );
      // Solo cerrar si el widget aún está montado
      if (mounted) {
        widget.onClose();
      }
    }
  }

  // 🔓 MODO PASO: click-through via window_manager
  Future<void> _togglePassThrough() async {
    if (!Platform.isWindows) return;
    try {
      final next = !_isPassThrough;
      
      if (next) {
        // Al entrar en Modo Paso, comenzamos ignorando los eventos (click-through real)
        await windowManager.setIgnoreMouseEvents(true, forward: true);
        _startMouseTimer(); // 🔍 Empezamos a revisar si el mouse toca la barra
      } else {
        // Al salir del Modo Paso, detenemos el timer y restauramos el click normal
        _mouseTimer?.cancel();
        _isMouseOverToolbar = false;
        await windowManager.setIgnoreMouseEvents(false);
      }
      
      setState(() {
        _isPassThrough = next;
        _isPaused = next; 
      });
    } catch (e) {
      print('[WhiteboardOverlay] Error toggling pass-through: $e');
    }
  }

  // 🖱️ TIMER: Evita que la barra de herramientas quede inutilizable
  void _startMouseTimer() {
    _mouseTimer?.cancel();
    _mouseTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted || !_isPassThrough) {
        timer.cancel();
        return;
      }
      
      // Obtener posición global del mouse en Windows
      final point = calloc<win32.POINT>();
      win32.GetCursorPos(point);
      final mouseX = point.ref.x;
      // Obtenemos la posición de la ventana para calcular coordenadas relativas
      final winPos = await windowManager.getPosition();
      final relX = mouseX - winPos.dx;
      win32.free(point);
      
      // Si el mouse entra a la zona izquierda (0 a 100 px), devolvemos el interact al Flutter (Barra usable)
      final bool nowOverToolbar = relX >= 0 && relX <= 100;
      
      if (nowOverToolbar != _isMouseOverToolbar) {
        _isMouseOverToolbar = nowOverToolbar;
        // Si está sobre la barra: NO ignorar clicks -> El usuario puede hacer click en el menú!
        // Si sale de la barra: IGNORAR clicks -> El usuario puede hacer click en Chrome/juegos debajo
        await windowManager.setIgnoreMouseEvents(!nowOverToolbar, forward: !nowOverToolbar);
      }
    });
  }

  // ============== LÓGICA DE IMÁGENES ==============
  Future<void> _cacheImage(ImageObject obj) async {
    try {
      final bytes = base64Decode(obj.base64Image);
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      setState(() {
        _decodedImages[obj.id] = frameInfo.image;
      });
    } catch (e) {
      print('Error al decodificar imagen de pizarra: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!widget.isTeacher) return;

    setState(() => _isPaused = true);

    // 🔥 BAJAR la pizarra temporalmente para que el FilePicker de Windows no se quede atascado atrás
    if (Platform.isWindows) {
      await windowManager.setAlwaysOnTop(false);
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();

        // Chequear tamaño (para no reventar base64 websocket) - límite aprox 1MB
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Imagen demasiado grande. Máximo 2MB.'),
              ),
            );
          }
        } else {
          final base64String = base64Encode(bytes);
          final codec = await ui.instantiateImageCodec(bytes);
          final frameInfo = await codec.getNextFrame();
          final imgWidth = frameInfo.image.width.toDouble();
          final imgHeight = frameInfo.image.height.toDouble();

          // Escalar un poco si es gigante
          double scale = 1.0;
          if (imgWidth > 400) scale = 400 / imgWidth;

          final finalWidth = imgWidth * scale;
          final finalHeight = imgHeight * scale;

          final id = _uuid.v4();
          final imgObj = ImageObject(
            id: id,
            base64Image: base64String,
            rect: Rect.fromLTWH(0, 0, finalWidth, finalHeight),
            offset: const Offset(300, 300), // Aparece un poco más al centro
          );

          _decodedImages[id] = frameInfo.image;
          setState(() {
            _objects.add(imgObj);
          });
          _service.sendObject(imgObj);
        }
      }
    } finally {
      // ♻️ RESTAURAR la pizarra al frente y quitar pausa
      if (Platform.isWindows) {
        await windowManager.setAlwaysOnTop(true);
      }
      setState(() => _isPaused = false);
    }
  }

  // ============== TEXTO LÓGICA ==============
  Future<void> _addText(Offset position) async {
    setState(() => _isPaused = true);

    // Bajar temporalmente la pizarra para poder interactuar libremente con el pop-up de Flutter
    if (Platform.isWindows) await windowManager.setAlwaysOnTop(false);

    try {
      String? text = await showDialog<String>(
        context: context,
        builder: (context) {
          String inputText = "";
          return AlertDialog(
            title: const Text('Escribir texto'),
            content: TextField(
              autofocus: true,
              onChanged: (val) => inputText = val,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, inputText),
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );

      if (text != null && text.isNotEmpty) {
        final obj = TextObject(
          id: _uuid.v4(),
          text: text,
          position: const Offset(0, 0),
          offset: position,
          color: _currentColor,
          fontSize: 24.0,
        );
        setState(() {
          _objects.add(obj);
        });
        _service.sendObject(obj);
      }
    } finally {
      if (Platform.isWindows) await windowManager.setAlwaysOnTop(true);
      setState(() => _isPaused = false);
    }
  }

  // ============== GESTOS =================
  void _onPanStart(DragStartDetails details) {
    if (!widget.isTeacher || _isPaused) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final pos = renderBox.globalToLocal(details.globalPosition);

    if (_currentTool == WhiteboardTool.eraser) {
      // Buscar objeto presionado y borrar
      final tappedObj = _findHitObject(pos);
      if (tappedObj != null) {
        setState(() {
          _objects.remove(tappedObj);
        });
        _service.removeObject(tappedObj.id);
      }
      return;
    }

    if (_currentTool == WhiteboardTool.move) {
      _selectedObject = _findHitObject(pos);
      if (_selectedObject != null) {
        _moveStartOffset = pos - _selectedObject!.offset;
      }
      return;
    }

    if (_currentTool == WhiteboardTool.text) {
      _addText(pos);
      return;
    }

    // Dibujando nuevos objetos
    final id = _uuid.v4();
    if (_currentTool == WhiteboardTool.pencil) {
      _currentDrawingObject = StrokeObject(
        id: id,
        points: [pos],
        color: _currentColor,
        strokeWidth: _strokeWidth,
      );
      setState(() {
        _objects.add(_currentDrawingObject!);
      });
    } else if (_currentTool == WhiteboardTool.line) {
      _currentDrawingObject = LineObject(
        id: id,
        start: pos,
        end: pos,
        color: _currentColor,
        strokeWidth: _strokeWidth,
      );
      setState(() {
        _objects.add(_currentDrawingObject!);
      });
    } else if (_currentTool == WhiteboardTool.arrow) {
      _currentDrawingObject = ArrowObject(
        id: id,
        start: pos,
        end: pos,
        color: _currentColor,
        strokeWidth: _strokeWidth,
      );
      setState(() {
        _objects.add(_currentDrawingObject!);
      });
    } else if (_currentTool == WhiteboardTool.rectangle) {
      _currentDrawingObject = RectangleObject(
        id: id,
        rect: Rect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        color: _currentColor,
        strokeWidth: _strokeWidth,
      );
      setState(() {
        _objects.add(_currentDrawingObject!);
      });
    }

    // 🚀 Enviar el punto inicial inmediatamente
    if (_currentDrawingObject != null) {
      _service.sendObject(_currentDrawingObject!);
      _lastSyncTime = DateTime.now();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTeacher || _isPaused) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final pos = renderBox.globalToLocal(details.globalPosition);

    if (_currentTool == WhiteboardTool.move &&
        _selectedObject != null &&
        _moveStartOffset != null) {
      setState(() {
        _selectedObject!.offset = pos - _moveStartOffset!;
      });
      // 🚀 Sincronizar movimiento en tiempo real (limitado a 1 vez cada 250ms para no saturar Supabase)
      final now = DateTime.now();
      if (_lastSyncTime == null ||
          now.difference(_lastSyncTime!).inMilliseconds > 250) {
        _service.updateObject(_selectedObject!);
        _lastSyncTime = now;
      }
      return;
    }

    if (_currentDrawingObject == null) return;

    setState(() {
      if (_currentDrawingObject is StrokeObject) {
        (_currentDrawingObject as StrokeObject).points.add(pos);
      } else if (_currentDrawingObject is LineObject) {
        (_currentDrawingObject as LineObject).end = pos;
      } else if (_currentDrawingObject is ArrowObject) {
        (_currentDrawingObject as ArrowObject).end = pos;
      } else if (_currentDrawingObject is RectangleObject) {
        final rBox = _currentDrawingObject as RectangleObject;
        // Permite dibujar hacia atrás
        final startPos = Offset(
          rBox.rect.left,
          rBox.rect.top,
        ); // simplificación
        rBox.rect = Rect.fromPoints(startPos, pos);
      }
    });

    // 🚀 Sincronización en tiempo real (animar el dibujo a los estudiantes, máx 4 veces por segundo)
    final now = DateTime.now();
    if (_lastSyncTime == null ||
        now.difference(_lastSyncTime!).inMilliseconds > 250) {
      _service.updateObject(_currentDrawingObject!);
      _lastSyncTime = now;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTeacher || _isPaused) return;

    if (_currentTool == WhiteboardTool.move && _selectedObject != null) {
      // Enviar actualizacion final al maestro al soltar el drag
      _service.updateObject(_selectedObject!);
      _selectedObject = null;
      _moveStartOffset = null;
      return;
    }

    if (_currentDrawingObject != null) {
      _service.updateObject(
        _currentDrawingObject!,
      ); // ✨ Finalizar actualización
      _currentDrawingObject = null;
    }
  }

  WhiteboardObject? _findHitObject(Offset pos) {
    // Busca del final al principio (el de mas arriba primero)
    for (int i = _objects.length - 1; i >= 0; i--) {
      if (_objects[i].hitTest(pos)) {
        return _objects[i];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 📏 Informar el tamaño real del monitor del maestro a los alumnos
    if (widget.isTeacher) {
      final size = MediaQuery.of(context).size;
      if (_teacherSize != size) {
        _teacherSize = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _service.sendBoardInfo(size.width, size.height);
        });
      }
    }

    Widget canvasLayer = GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: ClipRect(
        child: CustomPaint(
          painter: _WhiteboardPainter(
            objects: _objects,
            images: _decodedImages,
          ),
        ),
      ),
    );

    // 🎓 Ajuste milimétrico de la pantalla para los Estudiantes
    if (!widget.isTeacher) {
      final safeTeacherSize = _teacherSize ?? const Size(1920, 1080);

      canvasLayer = FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment
            .center, // Garantiza el mismo comportamiento que renderModeFit
        child: SizedBox(
          width: safeTeacherSize.width,
          height: safeTeacherSize.height,
          child: canvasLayer,
        ),
      );
    }

    return Container(
      color: _isTransparent ? Colors.transparent : Colors.white,
      child: Stack(
        children: [
          // 🎨 LIENZO DE PINTURA - Usar AbsorbPointer para bloquear eventos completamente en modo PASO
          Positioned.fill(
            child: AbsorbPointer(
              absorbing:
                  _isPassThrough, // 🔓 Bloquear toques completamente cuando modo paso está activo
              child: IgnorePointer(
                ignoring: _isPassThrough,
                child: canvasLayer,
              ),
            ),
          ),

          // BARRA DE HERRAMIENTAS (Solo Maestro) - SIEMPRE TOCABLE ✨
          if (widget.isTeacher)
            Positioned(
              left: 20,
              top: 80,
              bottom: 80,
              child: Material(
                color: Colors.transparent,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: WhiteboardToolbar(
                    currentTool: _currentTool,
                    onToolChanged: (t) => setState(() => _currentTool = t),
                    currentColor: _currentColor,
                    onColorChanged: (c) => setState(() => _currentColor = c),
                    strokeWidth: _strokeWidth,
                    onStrokeWidthChanged: (w) =>
                        setState(() => _strokeWidth = w),
                    onClear: () {
                      setState(() {
                        _objects.clear();
                        _decodedImages.clear();
                      });
                      _service.clearBoard();
                    },
                    onPickImage: _pickImage,
                    isTransparent: _isTransparent,
                    onModeChanged: (val) {
                      setState(() => _isTransparent = val);
                      _service.changeMode(val);
                    },
                    onClose: () {
                      // 🧹 Limpiar y ocultar la pizarra para todos los estudiantes antes de cerrarla
                      setState(() {
                        _objects.clear();
                        _decodedImages.clear();
                        _isTransparent = true;
                      });
                      _service.clearBoard();
                      _service.changeMode(true);

                      // 🚪 IMPORTANTE: Notificar a estudiantes que cierren ANTES de cerrar el maestro
                      _service.notifyBoardClosed();

                      // Esperar un poco para que todos reciban el evento antes de cerrar localmente
                      Future.delayed(const Duration(milliseconds: 200), () {
                        widget.onClose();
                      });
                    },
                    isPassThrough: _isPassThrough,
                    onPassThroughToggled: _togglePassThrough,
                  ),
                ),
              ),
            ),

          // 🔓 Banner visual cuando Modo Paso está activo
          if (widget.isTeacher && _isPassThrough)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 8),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mouse, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Modo Paso: Activo — Haz Alt+Tab aquí y presiona ESC para dibujar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardObject> objects;
  final Map<String, ui.Image> images;

  _WhiteboardPainter({required this.objects, required this.images});

  @override
  void paint(Canvas canvas, Size size) {
    for (var obj in objects) {
      canvas.save();
      canvas.translate(obj.offset.dx, obj.offset.dy);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (obj is StrokeObject) {
        paint.color = obj.color;
        paint.strokeWidth = obj.strokeWidth;
        for (int i = 0; i < obj.points.length - 1; i++) {
          canvas.drawLine(obj.points[i], obj.points[i + 1], paint);
        }
      } else if (obj is LineObject) {
        paint.color = obj.color;
        paint.strokeWidth = obj.strokeWidth;
        canvas.drawLine(obj.start, obj.end, paint);
      } else if (obj is ArrowObject) {
        paint.color = obj.color;
        paint.strokeWidth = obj.strokeWidth;
        // Dibuja la línea principal
        canvas.drawLine(obj.start, obj.end, paint);

        // Dibuja la punta de flecha
        final double arrowLength = 15.0 + obj.strokeWidth;
        final double arrowAngle = pi / 6; // 30 grados

        // Ángulo de la línea
        final double angle = atan2(
          obj.end.dy - obj.start.dy,
          obj.end.dx - obj.start.dx,
        );

        // Puntos de la cabeza de flecha
        final Offset arrowPoint1 = Offset(
          obj.end.dx - arrowLength * cos(angle - arrowAngle),
          obj.end.dy - arrowLength * sin(angle - arrowAngle),
        );
        final Offset arrowPoint2 = Offset(
          obj.end.dx - arrowLength * cos(angle + arrowAngle),
          obj.end.dy - arrowLength * sin(angle + arrowAngle),
        );

        // Trazar el polígono de la flecha relleno
        final arrowHeadPaint = Paint()
          ..color = obj.color
          ..style = PaintingStyle.fill;

        final Path arrowPath = Path()
          ..moveTo(obj.end.dx, obj.end.dy)
          ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
          ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
          ..close();

        canvas.drawPath(arrowPath, arrowHeadPaint);
      } else if (obj is RectangleObject) {
        paint.color = obj.color;
        paint.strokeWidth = obj.strokeWidth;
        paint.style = obj.isFilled ? PaintingStyle.fill : PaintingStyle.stroke;
        canvas.drawRect(obj.rect, paint);
      } else if (obj is TextObject) {
        TextSpan span = TextSpan(
          style: TextStyle(
            color: obj.color,
            fontSize: obj.fontSize,
            fontWeight: FontWeight.bold,
          ),
          text: obj.text,
        );
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        // Alinear para que la posición sea el centro/abajo aproximado
        tp.paint(
          canvas,
          Offset(obj.position.dx, obj.position.dy - obj.fontSize),
        );
      } else if (obj is ImageObject) {
        final img = images[obj.id];
        if (img != null) {
          paint.style = PaintingStyle.fill;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            obj.rect,
            paint,
          );
        }
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter oldDelegate) => true; // Para fluidez constante
}
