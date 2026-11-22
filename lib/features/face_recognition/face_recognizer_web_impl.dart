/// Implémentation web — face-api.js via dart:js_util
import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'face_recognizer.dart';

const _cdnBase =
    'https://justadudewhohacks.github.io/face-api.js/models';

/// Charge les modèles face-api.js (SSD MobileNet + FaceNet).
Future<bool> jsLoadModels() async {
  try {
    final faceapi = js.context['faceapi'];
    if (faceapi == null) return false;

    final nets = js_util.getProperty(faceapi, 'nets');

    // Détection SSD MobileNet
    await js_util.promiseToFuture<void>(
      js_util.callMethod(
        js_util.getProperty(nets, 'ssdMobilenetv1'),
        'loadFromUri',
        [_cdnBase],
      ),
    );

    // Embeddings FaceNet 128D
    await js_util.promiseToFuture<void>(
      js_util.callMethod(
        js_util.getProperty(nets, 'faceRecognitionNet'),
        'loadFromUri',
        [_cdnBase],
      ),
    );

    return true;
  } catch (_) {
    return false;
  }
}

/// Détecte un visage dans l'image base64, retourne embedding + thumbnail.
Future<FaceDetectionResult?> jsDetectFace(String b64) async {
  try {
    final result = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(js.context, '_doorwatchDetectFace', [b64]),
    );

    if (result == null) return null;

    final embJs   = js_util.getProperty(result, 'embedding') as dynamic;
    final thumbData = js_util.getProperty(result, 'thumbnail') as String?;
    if (thumbData == null || thumbData.isEmpty) return null;

    // Float32Array JS → List<double>
    final len = js_util.getProperty(embJs, 'length') as int;
    final embedding = List<double>.generate(
      len,
      (i) => (js_util.callMethod(embJs, 'at', [i]) as num).toDouble(),
    );

    // Extraire les bytes JPEG du data URL (data:image/jpeg;base64,XXX)
    final b64Thumb = thumbData.contains(',')
        ? thumbData.split(',').last
        : thumbData;
    final thumbnail = base64Decode(b64Thumb);

    return FaceDetectionResult(embedding: embedding, thumbnail: thumbnail);
  } catch (_) {
    return null;
  }
}
