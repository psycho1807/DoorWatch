import 'dart:typed_data';

import 'face_recognizer.dart';

/// Stub mobile/desktop — reconnaissance faciale non disponible sans face-api.js.
/// Une implémentation TFLite sera ajoutée dans le sprint Pro mobile.

// ignore: unused_element
Future<bool> jsLoadModels() async => false;

// ignore: unused_element
Future<FaceDetectionResult?> jsDetectFace(String b64) async => null;
