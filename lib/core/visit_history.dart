import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Enregistrement d'une visite à la porte.
class Visit {
  final String id;
  final DateTime timestamp;
  final String? snapshotPath; // chemin local de la capture
  final String? recognizedName; // Pro : nom reconnu via TFLite
  final bool   doorOpened;

  const Visit({
    required this.id,
    required this.timestamp,
    this.snapshotPath,
    this.recognizedName,
    this.doorOpened = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': timestamp.millisecondsSinceEpoch,
        'snap': snapshotPath,
        'name': recognizedName,
        'opened': doorOpened,
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        snapshotPath: j['snap'] as String?,
        recognizedName: j['name'] as String?,
        doorOpened: (j['opened'] as bool?) ?? false,
      );
}

/// Stocke et lit l'historique des visites dans SharedPreferences.
class VisitHistory {
  VisitHistory._();

  static const _key = 'visit_history';

  static Future<List<Visit>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<Visit> visits) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(visits.map((v) => v.toJson()).toList()));
  }

  static Future<void> addVisit(Visit visit) async {
    final visits = await load();
    visits.insert(0, visit); // plus récent en premier
    // Nettoyage automatique selon la durée de rétention
    // (géré dans HistoryScreen au chargement)
    await save(visits);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
