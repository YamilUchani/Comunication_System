import 'dart:ui';
import 'package:flutter/material.dart';

enum WhiteboardObjectType { stroke, line, arrow, rectangle, text, image }

abstract class WhiteboardObject {
  String id;
  WhiteboardObjectType type;
  Offset offset; // Desplazamiento global para mover el objeto entero

  WhiteboardObject({
    required this.id,
    required this.type,
    this.offset = Offset.zero,
  });

  Map<String, dynamic> toJson();
  
  static WhiteboardObject fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final id = json['id'] as String;
    final offset = Offset((json['offsetX'] as num).toDouble(), (json['offsetY'] as num).toDouble());

    switch (typeStr) {
      case 'stroke':
        return StrokeObject.fromJson(json, id, offset);
      case 'line':
        return LineObject.fromJson(json, id, offset);
      case 'arrow':
        return ArrowObject.fromJson(json, id, offset);
      case 'rectangle':
        return RectangleObject.fromJson(json, id, offset);
      case 'text':
        return TextObject.fromJson(json, id, offset);
      case 'image':
        return ImageObject.fromJson(json, id, offset);
      default:
        throw Exception('Tipo de objeto desconocido: $typeStr');
    }
  }

  // Comprueba si un punto toca el objeto (para seleccionarlo y moverlo)
  bool hitTest(Offset point);
}

class StrokeObject extends WhiteboardObject {
  List<Offset> points;
  Color color;
  double strokeWidth;

  StrokeObject({
    required String id,
    Offset offset = Offset.zero,
    required this.points,
    required this.color,
    required this.strokeWidth,
  }) : super(id: id, type: WhiteboardObjectType.stroke, offset: offset);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'stroke',
      'offsetX': offset.dx,
      'offsetY': offset.dy,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  static StrokeObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    var rawPoints = json['points'] as List;
    List<Offset> pts = rawPoints.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();
    return StrokeObject(
      id: id,
      offset: offset,
      points: pts,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
    );
  }

  @override
  bool hitTest(Offset point) {
    // Tolerancia para hacer clic en el trazo
    const tolerance = 10.0;
    final adjPoint = point - offset;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (_distanceToLineSegment(adjPoint, p1, p2) <= tolerance + (strokeWidth / 2)) {
        return true;
      }
    }
    return false;
  }
}

class LineObject extends WhiteboardObject {
  Offset start;
  Offset end;
  Color color;
  double strokeWidth;

  LineObject({
    required String id,
    Offset offset = Offset.zero,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  }) : super(id: id, type: WhiteboardObjectType.line, offset: offset);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'line',
      'offsetX': offset.dx,
      'offsetY': offset.dy,
      'startX': start.dx,
      'startY': start.dy,
      'endX': end.dx,
      'endY': end.dy,
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  static LineObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    return LineObject(
      id: id,
      offset: offset,
      start: Offset((json['startX'] as num).toDouble(), (json['startY'] as num).toDouble()),
      end: Offset((json['endX'] as num).toDouble(), (json['endY'] as num).toDouble()),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
    );
  }

  @override
  bool hitTest(Offset point) {
    final adjPoint = point - offset;
    return _distanceToLineSegment(adjPoint, start, end) <= 10.0 + (strokeWidth / 2);
  }
}

class ArrowObject extends WhiteboardObject {
  Offset start;
  Offset end;
  Color color;
  double strokeWidth;

  ArrowObject({
    required String id,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    Offset offset = Offset.zero,
  }) : super(id: id, type: WhiteboardObjectType.arrow, offset: offset);

  static ArrowObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    return ArrowObject(
      id: id,
      start: Offset((json['start']['x'] as num).toDouble(), (json['start']['y'] as num).toDouble()),
      end: Offset((json['end']['x'] as num).toDouble(), (json['end']['y'] as num).toDouble()),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      offset: offset,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'arrow',
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'color': color.value,
      'strokeWidth': strokeWidth,
      'offset': {'x': offset.dx, 'y': offset.dy},
    };
  }

  @override
  bool hitTest(Offset point) {
    // Calculo básico de distancia punto-línea
    final localPoint = point - offset;
    final dist = _distanceToLineSegment(localPoint, start, end);
    return dist <= (strokeWidth + 5); // Tensión de toque
  }
}

class RectangleObject extends WhiteboardObject {
  Rect rect;
  Color color;
  double strokeWidth;
  bool isFilled;

  RectangleObject({
    required String id,
    Offset offset = Offset.zero,
    required this.rect,
    required this.color,
    required this.strokeWidth,
    this.isFilled = false,
  }) : super(id: id, type: WhiteboardObjectType.rectangle, offset: offset);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'rectangle',
      'offsetX': offset.dx,
      'offsetY': offset.dy,
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'isFilled': isFilled,
    };
  }

  static RectangleObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    return RectangleObject(
      id: id,
      offset: offset,
      rect: Rect.fromLTRB(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      ),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      isFilled: json['isFilled'] as bool? ?? false,
    );
  }

  @override
  bool hitTest(Offset point) {
    final adjPoint = point - offset;
    if (isFilled) {
      return rect.contains(adjPoint);
    }
    // Solo golpear si está en los bordes
    const tolerance = 10.0;
    final outer = rect.inflate(tolerance);
    final inner = rect.deflate(tolerance);
    return outer.contains(adjPoint) && !inner.contains(adjPoint);
  }
}

class TextObject extends WhiteboardObject {
  String text;
  Offset position;
  Color color;
  double fontSize;

  TextObject({
    required String id,
    Offset offset = Offset.zero,
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  }) : super(id: id, type: WhiteboardObjectType.text, offset: offset);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'text',
      'offsetX': offset.dx,
      'offsetY': offset.dy,
      'text': text,
      'posX': position.dx,
      'posY': position.dy,
      'color': color.value,
      'fontSize': fontSize,
    };
  }

  static TextObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    return TextObject(
      id: id,
      offset: offset,
      text: json['text'] as String,
      position: Offset((json['posX'] as num).toDouble(), (json['posY'] as num).toDouble()),
      color: Color(json['color'] as int),
      fontSize: (json['fontSize'] as num).toDouble(),
    );
  }

  @override
  bool hitTest(Offset point) {
    final adjPoint = point - offset;
    // Estimación bruta del tamaño del texto
    final estWidth = text.length * fontSize * 0.6;
    final estHeight = fontSize * 1.2;
    final rect = Rect.fromLTWH(position.dx, position.dy - estHeight, estWidth, estHeight);
    return rect.inflate(10).contains(adjPoint);
  }
}

class ImageObject extends WhiteboardObject {
  String base64Image;
  Rect rect;

  ImageObject({
    required String id,
    Offset offset = Offset.zero,
    required this.base64Image,
    required this.rect,
  }) : super(id: id, type: WhiteboardObjectType.image, offset: offset);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'image',
      'offsetX': offset.dx,
      'offsetY': offset.dy,
      'base64Image': base64Image,
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
    };
  }

  static ImageObject fromJson(Map<String, dynamic> json, String id, Offset offset) {
    return ImageObject(
      id: id,
      offset: offset,
      base64Image: json['base64Image'] as String,
      rect: Rect.fromLTRB(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      ),
    );
  }

  @override
  bool hitTest(Offset point) {
    final adjPoint = point - offset;
    return rect.contains(adjPoint);
  }
}

// Utilidad matemática
double _distanceToLineSegment(Offset p, Offset v, Offset w) {
  final l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
  if (l2 == 0) return (p - v).distance;
  var t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
  return (p - proj).distance;
}
