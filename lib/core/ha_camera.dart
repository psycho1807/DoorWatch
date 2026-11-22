import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'ha_client.dart';
import 'prefs.dart';

/// Accès au flux caméra via Home Assistant.
/// Sur Flutter web : utilise WebSocket camera/get_image (pas de CORS).
/// Sur mobile/desktop : utilise HTTP camera_proxy.
class HaCamera {
  HaCamera._();

  // ── Snapshot via WebSocket ───────────────────────────────────────────────

  /// Récupère une image JPEG via WebSocket HA (camera/get_image).
  /// Contourne le blocage CORS de Flutter web.
  static Future<Uint8List?> fetchSnapshot(String entityId) async {
    try {
      final result = await HaClient.instance.sendRequest({
        'type': 'camera/get_image',
        'entity_id': entityId,
      });

      dev.log('[HaCamera] camera/get_image result keys: ${result?.keys}',
          name: 'HaCamera');

      if (result == null) {
        dev.log('[HaCamera] result is null', name: 'HaCamera');
        return null;
      }

      // HA retourne {"content": "<base64>", "content_type": "image/jpeg"}
      final content = result['content'] as String?;
      if (content == null || content.isEmpty) {
        dev.log('[HaCamera] content vide. result=$result', name: 'HaCamera');
        return null;
      }

      dev.log('[HaCamera] content length=${content.length}', name: 'HaCamera');
      return base64Decode(content);
    } catch (e, st) {
      dev.log('[HaCamera] erreur: $e\n$st', name: 'HaCamera');
      return null;
    }
  }

  // ── URL du flux MJPEG ────────────────────────────────────────────────────

  /// URL MJPEG avec token en query param (pour WebView natif).
  static String mjpegUrl(String entityId) =>
      '${Prefs.haUrl.trimRight()}/api/camera_proxy_stream/$entityId'
      '?token=${Prefs.haToken}';

  /// URL snapshot standard.
  static String snapshotUrl(String entityId) =>
      Prefs.cameraProxyUrl(entityId);
}
