import 'dart:typed_data';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:image/image.dart' as img;

/// Reconnaissance faciale locale via TensorFlow Lite (MobileFaceNet).
///
/// Modèle : MobileFaceNet — léger, optimisé mobile, précis.
/// Taille : ~2 MB. Produit un vecteur embedding 192D pour chaque visage.
///
/// Usage :
///   final recognizer = FaceRecognizer();
///   await recognizer.init();
///   final name = await recognizer.identify(imageBytes);
class FaceRecognizer {
  // Interpreter? _interpreter;
  static const _modelPath  = 'assets/models/mobile_face_net.tflite';
  static const _inputSize  = 112; // pixels (entrée modèle)
  static const _embeddingSize = 192;
  static const _threshold  = 0.6; // distance cosinus max pour match

  bool _initialized = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    // TODO (Pro) :
    //   _interpreter = await Interpreter.fromAsset(_modelPath);
    _initialized = true;
  }

  // ── Identification ────────────────────────────────────────────────────────

  /// Identifie le visage dans [imageBytes] (JPEG/PNG).
  /// Retourne le nom enregistré, ou null si inconnu.
  Future<String?> identify(Uint8List imageBytes) async {
    if (!_initialized) await init();

    // 1. Détecter + recadrer le visage (MTCNN ou simple crop centré)
    // 2. Redimensionner à 112×112
    // 3. Normaliser [-1, 1]
    // 4. Inférence TFLite → embedding 192D
    // 5. Comparer avec les embeddings enregistrés (cosinus)
    // 6. Si distance < _threshold → retourner le nom

    // Placeholder — implémentation complète dans le sprint Pro
    return null;
  }

  // ── Enregistrement d'un visage ───────────────────────────────────────────

  /// Extrait l'embedding d'un visage et le stocke avec le [name] associé.
  Future<bool> registerFace(String name, Uint8List imageBytes) async {
    if (!_initialized) await init();
    // TODO : extraire embedding, sauvegarder dans SharedPreferences/SQLite
    return false;
  }

  // ── Utilitaires ─────────────────────────────────────────────────────────

  /// Distance cosinus entre deux vecteurs embedding.
  static double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (normA * normB == 0 ? 1 : (normA * normB));
  }

  void dispose() {
    // _interpreter?.close();
    _initialized = false;
  }
}
