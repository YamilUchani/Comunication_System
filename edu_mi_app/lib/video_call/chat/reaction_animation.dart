import 'package:flutter/material.dart';

class ReactionAnimation extends StatefulWidget {
  final String reactionType;
  final Duration duration;

  const ReactionAnimation({
    super.key,
    required this.reactionType,
    this.duration = const Duration(seconds: 2),
  });

  @override
  _ReactionAnimationState createState() => _ReactionAnimationState();
}

class _ReactionAnimationState extends State<ReactionAnimation> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 2),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  IconData _getReactionIcon() {
    switch (widget.reactionType) {
      case 'like':
        return Icons.thumb_up;
      case 'hand':
        return Icons.waving_hand;
      case 'clap':
        return Icons.celebration;
      case 'heart':
        return Icons.favorite;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.emoji_emotions;
    }
  }

  Color _getReactionColor() {
    switch (widget.reactionType) {
      case 'like':
        return Colors.blue;
      case 'hand':
        return Colors.orange;
      case 'clap':
        return Colors.yellow[700]!;
      case 'heart':
        return Colors.red;
      case 'fire':
        return Colors.orangeAccent;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getReactionColor().withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getReactionColor().withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _getReactionIcon(),
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}