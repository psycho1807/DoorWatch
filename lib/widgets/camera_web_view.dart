// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';

import '../core/prefs.dart';

/// Widget caméra pour Flutter WEB.
/// Utilise une balise <img> native avec le token dans l'URL (?token=…)
/// → pas de header Authorization → pas de CORS preflight → ça marche.
/// L'image est rafraîchie toutes les 5 secondes via un timestamp dans l'URL.
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
  bool _loading = true;
  bool _error = false;
  int _loadCount = 0;
  Timer? _refreshTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _viewId = 'ha-cam-${widget.entityId.hashCode}';

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

    _registerHtmlView();
    // Le factory HTML s'exécute après le premier build — on attend le frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImage();
      _startAutoRefresh();
    });
  }

  /// Construit l'URL snapshot avec le token en query param (pas de CORS).
  String _buildUrl() {
    final base = Prefs.haUrl.trimRight();
    final token = Prefs.haToken;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$base/api/camera_proxy/${widget.entityId}'
        '?token=$token&_ts=$ts';
  }

  void _registerHtmlView() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#0D1117';

        _imgElement = html.ImageElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.display = 'none';

        _imgElement!.onLoad.listen((_) {
          _imgElement!.style.display = 'block';
          if (mounted) {
            setState(() { _loading = false; _error = false; });
            widget.onRefresh?.call();
          }
        });

        _imgElement!.onError.listen((_) {
          // ignore: avoid_print
          print('[CameraWebView] img onError, url=${_imgElement?.src}');
          if (mounted && _loadCount <= 1) {
            setState(() { _loading = false; _error = true; });
          }
        });

        container.append(_imgElement!);

        // La factory s'exécute au moment du build — on charge l'image ici
        // directement car c'est la garantie que _imgElement est non-null.
        _loadCount++;
        final url = _buildUrl();
        // ignore: avoid_print
        print('[CameraWebView] factory prête, loading url=$url');
        _imgElement!.src = url;

        return container;
      },
    );
  }

  void _loadImage() {
    if (_imgElement == null) {
      // ignore: avoid_print
      print('[CameraWebView] _loadImage: _imgElement est NULL (factory pas encore appelée)');
      return;
    }
    _loadCount++;
    final url = _buildUrl();
    // ignore: avoid_print
    print('[CameraWebView] loading url=$url');
    _imgElement!.src = url;
  }

  void _startAutoRefresh() {
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadImage();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Vue HTML native ───────────────────────────────────────────
        HtmlElementView(viewType: _viewId),

        // ── Loading ───────────────────────────────────────────────────
        if (_loading)
          Container(
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
                  Text('Connexion à la caméra…',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),

        // ── Erreur ────────────────────────────────────────────────────
        if (_error && !_loading)
          Container(
            color: const Color(0xFF0D1117),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 56, color: Colors.red),
                  SizedBox(height: 12),
                  Text('Flux caméra indisponible',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),

        // ── Gradient bas ──────────────────────────────────────────────
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

        // ── Bordure animée (sonnette) ─────────────────────────────────
        if (widget.ringing)
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (_, __) => Positioned.fill(
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

        // ── Badge sonnette animé ──────────────────────────────────────
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

        // ── Label AUTO ────────────────────────────────────────────────
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

        // ── Bouton refresh manuel ─────────────────────────────────────
        Positioned(
          bottom: 14,
          right: 14,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _loadImage,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.refresh, size: 20, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
