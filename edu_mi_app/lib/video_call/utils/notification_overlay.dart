import 'dart:async';
import 'package:flutter/material.dart';

class NotificationOverlay {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void showNotification(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void hideNotification() {
    _timer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}