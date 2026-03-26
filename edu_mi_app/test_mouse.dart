import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
  final point = calloc<POINT>();
  GetCursorPos(point);
  print('X: ${point.ref.x}, Y: ${point.ref.y}');
  free(point);
}
