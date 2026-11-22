// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../core/prefs.dart';

/// Widget caméra pour Flutter WEB uniquement.
/// Utilise XMLHttpRequest avec header Authorization pour Ring cameras.
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
  String? _currentBlobUrl;
  bool _loading = true;
  bool _error = false;
  Timer? _refreshTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _viewId = 'ha-camera-${widget.entityId.hashCode}';

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
    _loadImage();
    _startAutoRefresh();
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

        container.append(_imgElement!);
        return container;
      },
    );
  }

  Future<void> _loadImage() async {
    final url =
        '${Prefs.haUrl.trimRight()}/api/camera_proxy/${widget.entityId}';
    final token = Prefs.haToken;

    try {
      final blobUrl = await _xhrFetch(url, token);
      if (blobUrl == null) {
        if (mounted) setState(() { _loading = false; _error = true; });
        return;
      }

      if (_imgElement != null) {
        _imgElement!.src = blobUrl;
        _imgElement!.style.display = 'block';
      }

      // Libère l'ancien blob URL
      if (_currentBlobUrl != null) {
        html.Url.revokeObjectUrl(_currentBlobUrl!);
      }
      _currentBlobUrl = blobUrl;

      if (mounted) setState(() { _loading = false; _error = false; });
      widget.onRefresh?.call();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  /// Fait une requête XHR avec header Authorization et retourne une blob URL.
  Future<String?> _xhrFetch(String url, String token) {
    final completer = Completer<String?>();

    final xhr = html.HttpRequest();
    xhr.open('GET', url);
    xhr.setRequestHeader('Authorization', 'Bearer $token');
    xhr.responseType = 'blob';

    xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        final blob = xhr.response as html.Blob;
        completer.complete(html.Url.createObjectUrlFromBlob(blob));
      } else {
        completer.complete(null);
      }
    });

    xhr.onError.listen((_) => completer.complete(null));
    xhr.send();

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadImage();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _refreshTimer?.cancel();
    if (_currentBlobUrl != null) {
      html.Url.revokeObjectUrl(_currentBlobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Vue HTML native (l'<img> avec blob URL)
        HtmlElementView(viewType: _viewId),

        // Loading overlay
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
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),

        // Erreur overlay
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
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),

        // Gradient bas
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
                  Colors.black.withOpacity(0.7)
                ],
              ),
            ),
          ),
        ),

        // Bordure animée quand sonnette
        if (widget.ringing)
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (_, __) => Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        Colors.red.withOpacity(_borderAnimation.value),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),

        // Badge sonnette animé
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
                      )
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

        // Label AUTO
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

        // Bouton refresh manuel
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
                child: Icon(Icons.refresh, size: 20, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
