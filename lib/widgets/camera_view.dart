import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Widget qui affiche le flux caméra HA (snapshot + refresh automatique).
/// En version Pro, le flux MJPEG temps réel sera activé.
class CameraView extends StatefulWidget {
  final String entityId;
  final Uint8List? snapshot;
  final bool ringing;
  final VoidCallback? onRefresh;
  final int autoRefreshSeconds;

  const CameraView({
    super.key,
    required this.entityId,
    this.snapshot,
    this.ringing = false,
    this.onRefresh,
    this.autoRefreshSeconds = 5,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;
  Timer? _autoRefreshTimer;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Animation de pulsation pour le badge sonnette
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation de la bordure rouge
    _borderController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _borderAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.easeInOut),
    );

    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ringing && !oldWidget.ringing) {
      _pulseController.repeat(reverse: true);
      _borderController.repeat(reverse: true);
    } else if (!widget.ringing && oldWidget.ringing) {
      _pulseController.stop();
      _borderController.stop();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (widget.autoRefreshSeconds > 0 && widget.onRefresh != null) {
      _autoRefreshTimer = Timer.periodic(
        Duration(seconds: widget.autoRefreshSeconds),
        (_) {
          if (mounted) {
            setState(() => _lastRefresh = DateTime.now());
            widget.onRefresh!();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Image snapshot ───────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.snapshot != null
              ? Image.memory(
                  widget.snapshot!,
                  key: ValueKey(widget.snapshot.hashCode),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Container(
                  key: const ValueKey('loading'),
                  color: const Color(0xFF0D1117),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_outlined,
                            size: 56, color: Color(0xFF1E88E5)),
                        SizedBox(height: 16),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            backgroundColor: Color(0xFF1E3A5F),
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Connexion à la caméra…',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Gradient bas (lisibilité des boutons overlay)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),

        // ── Bordure animée quand sonnette active ─────────────────────────
        if (widget.ringing)
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (context, _) => Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red
                        .withOpacity(_borderAnimation.value),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),

        // ── Badge sonnette pulsant ───────────────────────────────────────
        if (widget.ringing)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6),
                        blurRadius: 25,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'QUELQU\'UN SONNE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Bouton refresh manuel ────────────────────────────────────────
        if (widget.onRefresh != null)
          Positioned(
            bottom: 14,
            right: 14,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _lastRefresh = DateTime.now());
                  widget.onRefresh!();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.refresh, size: 20, color: Colors.white70),
                ),
              ),
            ),
          ),

        // ── Timestamp ───────────────────────────────────────────────────
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatTime(_lastRefresh),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),

        // ── Label LIVE/AUTO ─────────────────────────────────────────────
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record,
                    size: 8, color: Color(0xFF1E88E5)),
                SizedBox(width: 4),
                Text(
                  'AUTO',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }
}
