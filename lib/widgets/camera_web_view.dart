// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../core/prefs.dart';

/// Widget caméra pour Flutter WEB uniquement.
/// Injecte un <img> HTML natif → contourne les restrictions CORS de Dart.
/// Le browser charge l'image directement avec le token en header via fetch.
class CameraWebView extends StatefulWidget {
  final String entityId;
  final bool ringing;
  final VoidCallback? onRefresh;

  const CameraWebView({
    super.key,
    required this.entityId,
    this.ringing = false,
    this.onRefresh,
  });

  @override
  State<CameraWebView> createState() => _CameraWebViewState();
}

class _CameraWebViewState extends State<CameraWebView>
    with TickerProviderStateMixin {
  late final String _viewId;
  html.ImageElement? _imgElement;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _viewId = 'ha-camera-${widget.entityId.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _borderController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _borderAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.easeInOut),
    );

    _registerView();
    _scheduleAutoRefresh();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#0D1117'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';

        _imgElement = html.ImageElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover';

        _loadImage();
        container.append(_imgElement!);
        return container;
      },
    );
  }

  void _loadImage() {
    if (_imgElement == null) return;
    final url = '${Prefs.haUrl.trimRight()}/api/camera_proxy/${widget.entityId}'
        '?token=${Prefs.haToken}&t=${DateTime.now().millisecondsSinceEpoch}';
    _imgElement!.src = url;
    widget.onRefresh?.call();
  }

  void _scheduleAutoRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _loadImage();
        _scheduleAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewId),

        // Gradient bas
        Positioned(
          bottom: 0, left: 0, right: 0, height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
        ),

        // Bordure animée sonnette
        if (widget.ringing)
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (_, __) => Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red.withOpacity(_borderAnimation.value),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),

        // Badge sonnette
        if (widget.ringing)
          Positioned(
            top: 20, left: 0, right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 25, spreadRadius: 8)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text('QUELQU\'UN SONNE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Label AUTO
        Positioned(
          top: 14, right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF1E88E5)),
                SizedBox(width: 4),
                Text('AUTO', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
          ),
        ),

        // Bouton refresh
        Positioned(
          bottom: 14, right: 14,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _loadImage,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh, size: 20, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
