import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

/// Un visage enregistré : nom + embedding + photo miniature (JPEG base64).
class RegisteredFace {
  final String id;
  final String name;
  final List<double> embedding; // vecteur 128D (face-api.js)
  final String? thumbnailB64;  // miniature JPEG (base64)
  final DateTime registeredAt;

  const RegisteredFace({
    required this.id,
    required this.name,
    required this.embedding,
    this.thumbnailB64,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emb': embedding,
        'thumb': thumbnailB64,
        'at': registeredAt.millisecondsSinceEpoch,
      };

  factory RegisteredFace.fromJson(Map<String, dynamic> j) => RegisteredFace(
        id: j['id'] as String,
        name: j['name'] as String,
        embedding: (j['emb'] as List<dynamic>).cast<double>(),
        thumbnailB64: j['thumb'] as String?,
        registeredAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );

  /// Retourne les bytes JPEG de la miniature, ou null.
  Uint8List? get thumbnailBytes {
    if (thumbnailB64 == null || thumbnailB64!.isEmpty) return null;
    return base64Decode(thumbnailB64!);
  }
}

/// Stocke et lit les visages enregistrés dans SharedPreferences.
class FaceStore {
  FaceStore._();

  static const _key = 'face_store_v1';

  static Future<List<RegisteredFace>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RegisteredFace.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<RegisteredFace> faces) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(faces.map((f) => f.toJson()).toList()));
  }

  static Future<void> addFace(RegisteredFace face) async {
    final faces = await loadAll();
    faces.add(face);
    await save(faces);
  }

  static Future<void> removeFace(String id) async {
    final faces = await loadAll();
    faces.removeWhere((f) => f.id == id);
    await save(faces);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  // ── Distance cosinus ──────────────────────────────────────────────────────

  /// Distance euclidienne entre deux embeddings (face-api.js utilise L2).
  static double l2Distance(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sum; // distance² (évite sqrt pour la comparaison)
  }

  /// Trouve le visage le plus proche dans [faces] pour l'embedding donné.
  /// Retourne null si aucun visage n'est assez proche (distance > threshold).
  static RegisteredFace? findBest(
    List<double> embedding,
    List<RegisteredFace> faces, {
    double threshold = 0.6, // distance L2 max (face-api.js: 0.6 recommandé)
  }) {
    if (faces.isEmpty) return null;

    RegisteredFace? best;
    double bestDist = double.infinity;

    for (final face in faces) {
      final dist = l2Distance(embedding, face.embedding);
      if (dist < bestDist) {
        bestDist = dist;
        best = face;
      }
    }

    // threshold² car on compare la distance au carré
    return bestDist <= threshold * threshold ? best : null;
  }
}
