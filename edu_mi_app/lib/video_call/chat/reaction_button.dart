import 'package:flutter/material.dart';

class ReactionButton extends StatelessWidget {
  final IconData icon;
  final String reactionType;
  final String tooltip;
  final Function(String) onReaction;
  final Color color;

  const ReactionButton({
    super.key,
    required this.icon,
    required this.reactionType,
    required this.tooltip,
    required this.onReaction,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: () => onReaction(reactionType),
    );
  }
}