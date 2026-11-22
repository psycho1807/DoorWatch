import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/face_store.dart';
// Implémentation JS conditionnelle (web) ou no-op (mobile)
import 'face_recognizer_io.dart'
    if (dart.library.html) 'face_recognizer_web_impl.dart';

/// Résultat d'une détection de visage.
class FaceDetectionResult {
  final List<double> embedding; // vecteur 128D
  final Uint8List thumbnail;    // recadrage JPEG

  const FaceDetectionResult({
    required this.embedding,
    required this.thumbnail,
  });
}

/// Reconnaissance faciale locale.
///
/// Flutter Web : face-api.js (TensorFlow.js), 100 % dans le navigateur.
/// Mobile      : stub — TFLite dans une version Pro ultérieure.
class FaceRecognizer {
  static bool _initialized = false;
  static bool _initializing = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<bool> init() async {
    if (!kIsWeb) return false;
    if (_initialized) return true;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _initialized;
    }
    _initializing = true;
    final ok = await jsLoadModels();
    _initialized = ok;
    _initializing = false;
    return ok;
  }

  // ── Détection + embedding ─────────────────────────────────────────────────

  static Future<FaceDetectionResult?> detect(Uint8List imageBytes) async {
    if (!kIsWeb) return null;
    if (!_initialized && !await init()) return null;

    final b64 = base64Encode(imageBytes);
    final result = await jsDetectFace(b64);
    return result;
  }

  // ── Identification ────────────────────────────────────────────────────────

  static Future<String?> identify(Uint8List imageBytes) async {
    final detection = await detect(imageBytes);
    if (detection == null) return null;

    final faces = await FaceStore.loadAll();
    final match = FaceStore.findBest(detection.embedding, faces);
    return match?.name;
  }
}
