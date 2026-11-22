import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/prefs.dart';
import '../../core/visit_history.dart';

/// Écran d'historique des visites à la porte, groupées par jour.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Visit> _visits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await VisitHistory.load();

    final keepDays = Prefs.keepHistoryDays;
    final filtered = keepDays == 0
        ? all
        : all.where((v) {
            final age = DateTime.now().difference(v.timestamp).inDays;
            return age <= keepDays;
          }).toList();

    if (filtered.length != all.length) await VisitHistory.save(filtered);

    if (mounted) setState(() {
      _visits = filtered
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: const Text('Toutes les visites seront supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Effacer')),
        ],
      ),
    );
    if (confirm == true) {
      await VisitHistory.clear();
      if (mounted) setState(() => _visits = []);
    }
  }

  /// Regroupe les visites par jour (clé = "YYYY-MM-DD").
  Map<String, List<Visit>> get _byDay {
    final map = <String, List<Visit>>{};
    for (final v in _visits) {
      final key = DateFormat('yyyy-MM-dd').format(v.timestamp);
      (map[key] ??= []).add(v);
    }
    return map;
  }

  String _dayLabel(String key) {
    final dt = DateTime.parse(key);
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day      = DateTime(dt.year, dt.month, dt.day);

    if (day == today) return 'Aujourd\'hui';
    if (day == yesterday) return 'Hier';
    return DateFormat('EEEE d MMMM', 'fr_FR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byDay;
    final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Historique'),
            if (!_loading && _visits.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_visits.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_visits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
              tooltip: 'Effacer tout',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 72,
                          color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 20),
                      const Text(
                        'Aucune visite enregistrée',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Les visites apparaîtront ici\nlorsque la sonnette sonnera.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white24, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: dayKeys.length,
                  itemBuilder: (_, di) {
                    final key    = dayKeys[di];
                    final visits = grouped[key]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Séparateur jour ───────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              16, 20, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                _dayLabel(key),
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF1E88E5)
                                      .withOpacity(0.2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${visits.length} visite'
                                '${visits.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // ── Cartes du jour ────────────────────────
                        ...visits.map(
                          (v) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: _VisitCard(visit: v),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Visit visit;
  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(visit.timestamp);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icône visiteur
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (visit.recognizedName != null
                        ? Colors.green
                        : const Color(0xFF1E88E5))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                visit.recognizedName != null
                    ? Icons.face
                    : Icons.person_outline,
                color: visit.recognizedName != null
                    ? Colors.green
                    : const Color(0xFF1E88E5),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Nom + heure
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.recognizedName ?? 'Visiteur inconnu',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Badge porte ouverte
            if (visit.doorOpened)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open,
                        color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text('Ouvert',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
