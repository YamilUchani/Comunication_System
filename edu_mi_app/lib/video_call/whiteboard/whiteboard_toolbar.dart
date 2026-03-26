import 'package:flutter/material.dart';

enum WhiteboardTool { pencil, eraser, line, arrow, rectangle, text, move }

class WhiteboardToolbar extends StatelessWidget {
  final WhiteboardTool currentTool;
  final Function(WhiteboardTool) onToolChanged;
  final Color currentColor;
  final Function(Color) onColorChanged;
  final double strokeWidth;
  final Function(double) onStrokeWidthChanged;
  final VoidCallback onClear;
  final VoidCallback onPickImage;
  final bool isTransparent;
  final Function(bool) onModeChanged;
  final VoidCallback onClose;
  final bool isPassThrough;
  final VoidCallback onPassThroughToggled;

  const WhiteboardToolbar({
    Key? key,
    required this.currentTool,
    required this.onToolChanged,
    required this.currentColor,
    required this.onColorChanged,
    required this.strokeWidth,
    required this.onStrokeWidthChanged,
    required this.onClear,
    required this.onPickImage,
    required this.isTransparent,
    required this.onModeChanged,
    required this.onClose,
    required this.isPassThrough,
    required this.onPassThroughToggled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Mover / Seleccionar
            _ToolBtn(
              icon: Icons.pan_tool_alt,
              tooltip: 'Mover objeto',
              isSelected: currentTool == WhiteboardTool.move,
              onTap: () => onToolChanged(WhiteboardTool.move),
            ),
            // Lápiz
            _ToolBtn(
              icon: Icons.edit,
              tooltip: 'Lápiz libre',
              isSelected: currentTool == WhiteboardTool.pencil,
              onTap: () => onToolChanged(WhiteboardTool.pencil),
            ),
            // Línea
            _ToolBtn(
              icon: Icons.horizontal_rule,
              tooltip: 'Línea recta',
              isSelected: currentTool == WhiteboardTool.line,
              onTap: () => onToolChanged(WhiteboardTool.line),
            ),
            // Flecha
            _ToolBtn(
              icon: Icons.arrow_outward,
              tooltip: 'Flecha',
              isSelected: currentTool == WhiteboardTool.arrow,
              onTap: () => onToolChanged(WhiteboardTool.arrow),
            ),
            // Rectángulo
            _ToolBtn(
              icon: Icons.crop_din,
              tooltip: 'Rectángulo',
              isSelected: currentTool == WhiteboardTool.rectangle,
              onTap: () => onToolChanged(WhiteboardTool.rectangle),
            ),
            // Texto
            _ToolBtn(
              icon: Icons.text_fields,
              tooltip: 'Añadir texto',
              isSelected: currentTool == WhiteboardTool.text,
              onTap: () => onToolChanged(WhiteboardTool.text),
            ),
            // Imagen
            _ToolBtn(
              icon: Icons.image,
              tooltip: 'Cargar Imagen (Carpetas)',
              isSelected: false,
              onTap: onPickImage,
            ),
            // Borrador (Elimina objeto completo al tocar)
            _ToolBtn(
              icon: Icons.auto_fix_normal, // Icono similar a borrador
              tooltip: 'Borrador (Toca un objeto para borrar)',
              isSelected: currentTool == WhiteboardTool.eraser,
              onTap: () => onToolChanged(WhiteboardTool.eraser),
            ),
            
            const Divider(color: Colors.grey),

            // Selector de colores rústico
            _ColorBtn(color: Colors.white, isSelected: currentColor == Colors.white, onTap: () => onColorChanged(Colors.white)),
            _ColorBtn(color: Colors.red, isSelected: currentColor == Colors.red, onTap: () => onColorChanged(Colors.red)),
            _ColorBtn(color: Colors.green, isSelected: currentColor == Colors.green, onTap: () => onColorChanged(Colors.green)),
            _ColorBtn(color: Colors.blue, isSelected: currentColor == Colors.blue, onTap: () => onColorChanged(Colors.blue)),
            _ColorBtn(color: Colors.yellow, isSelected: currentColor == Colors.yellow, onTap: () => onColorChanged(Colors.yellow)),
            
            const Divider(color: Colors.grey),

            // Modo Transparente vs Blanco
            IconButton(
              tooltip: isTransparent ? 'Fondo Transparente' : 'Fondo Blanco',
              icon: Icon(
                isTransparent ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
              ),
              onPressed: () => onModeChanged(!isTransparent),
            ),

            const Divider(color: Colors.grey),

            // Botón limpiar
            IconButton(
              tooltip: 'Limpiar todo',
              icon: const Icon(Icons.delete_forever, color: Colors.orange),
              onPressed: onClear,
            ),

            // Cerrar pizarra
            IconButton(
              tooltip: 'Cerrar Pizarra',
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: onClose,
            ),
            const Divider(color: Colors.grey),
            // 🔓 Modo Paso: pasar clicks a la computadora sin dibujar
            Tooltip(
              message: isPassThrough ? 'Desactivar Modo Paso (Volver a dibujar)' : 'Modo Paso: Interactuar con apps',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isPassThrough ? Colors.orange.withOpacity(0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPassThrough ? Colors.orange : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    isPassThrough ? Icons.mouse : Icons.back_hand,
                    color: isPassThrough ? Colors.orange : Colors.white70,
                  ),
                  onPressed: onPassThroughToggled,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _ToolBtn({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: isSelected ? Colors.tealAccent : Colors.white70),
        onPressed: onTap,
      ),
    );
  }
}

class _ColorBtn extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorBtn({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.tealAccent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
