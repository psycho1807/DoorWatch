import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Widget qui affiche le flux caméra HA (snapshot + refresh automatique).
/// En version Pro, le flux MJPEG temps réel sera activé.
class CameraView extends StatelessWidget {
  final String entityId;
  final Uint8List? snapshot;
  final bool ringing;
  final VoidCallback? onRefresh;

  const CameraView({
    super.key,
    required this.entityId,
    this.snapshot,
    this.ringing = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image snapshot
        if (snapshot != null)
          Image.memory(
            snapshot!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          )
        else
          Container(
            color: const Color(0xFF0D1117),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Chargement de la caméra…',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),

        // Overlay rouge si sonnette active
        if (ringing)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
              ),
            ),
          ),

        // Badge sonnette
        if (ringing)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'QUELQU\'UN SONNE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Bouton refresh en bas à droite
        if (onRefresh != null)
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              onPressed: onRefresh,
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              child: const Icon(Icons.refresh, size: 18),
            ),
          ),

        // Timestamp en bas à gauche
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatNow(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }
}
