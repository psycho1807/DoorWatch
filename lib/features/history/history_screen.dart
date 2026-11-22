import 'package:flutter/material.dart';

import '../../core/prefs.dart';
import '../../core/visit_history.dart';

/// Écran d'historique des visites à la porte.
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

    // Nettoyage automatique selon la durée de rétention
    final keepDays = Prefs.keepHistoryDays;
    final filtered = keepDays == 0
        ? all
        : all.where((v) {
            final age = DateTime.now().difference(v.timestamp).inDays;
            return age <= keepDays;
          }).toList();

    if (filtered.length != all.length) await VisitHistory.save(filtered);

    if (mounted) setState(() { _visits = filtered; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des visites'),
        actions: [
          if (_visits.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAll,
              tooltip: 'Effacer',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Aucune visite enregistrée',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _VisitCard(visit: _visits[i]),
                ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Visit visit;
  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_outline,
              color: Color(0xFF1E88E5)),
        ),
        title: Text(
          visit.recognizedName ?? 'Visiteur inconnu',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatDate(visit.timestamp),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: visit.doorOpened
            ? const Icon(Icons.lock_open, color: Colors.green, size: 18)
            : null,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
