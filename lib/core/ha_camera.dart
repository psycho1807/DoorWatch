import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'prefs.dart';

/// Accès au flux caméra via camera_proxy de Home Assistant.
/// Le proxy HA renvoie un flux MJPEG (multipart/x-mixed-replace).
class HaCamera {
  HaCamera._();

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${Prefs.haToken}',
      };

  // ── Snapshot unique ──────────────────────────────────────────────────────

  /// Télécharge une image JPEG instantanée de la caméra.
  static Future<Uint8List?> fetchSnapshot(String entityId) async {
    try {
      final r = await http.get(
        Uri.parse(Prefs.cameraProxyUrl(entityId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── URL du flux MJPEG ────────────────────────────────────────────────────

  /// Retourne l'URL MJPEG (stream) pour un widget natif ou WebView.
  static String mjpegUrl(String entityId) =>
      '${Prefs.haUrl.trimRight()}/api/camera_proxy_stream/$entityId'
      '?token=${Prefs.haToken}';

  /// Retourne l'URL snapshot standard.
  static String snapshotUrl(String entityId) =>
      Prefs.cameraProxyUrl(entityId);
}
