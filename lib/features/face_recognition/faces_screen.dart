import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/face_store.dart';
import '../../core/ha_camera.dart';
import '../../core/prefs.dart';
import 'face_recognizer.dart';

/// Écran de gestion des visages reconnus (Pro uniquement).
class FacesScreen extends StatefulWidget {
  const FacesScreen({super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends State<FacesScreen> {
  List<RegisteredFace> _faces = [];
  bool _loading = true;
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    if (Prefs.isPro) {
      _loadFaces();
      _initModel();
    }
  }

  Future<void> _loadFaces() async {
    final faces = await FaceStore.loadAll();
    if (mounted) setState(() { _faces = faces; _loading = false; });
  }

  Future<void> _initModel() async {
    final ok = await FaceRecognizer.init();
    if (mounted) setState(() => _modelReady = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!Prefs.isPro) return _buildUpsell(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visages reconnus'),
        actions: [
          if (_faces.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Tout effacer',
              onPressed: _confirmClearAll,
            ),
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Ajouter un visage',
            onPressed: _modelReady ? _addFaceDialog : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _faces.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Column(
      children: [
        if (!_modelReady)
          Container(
            color: Colors.orange.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text('Chargement du modèle IA…',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _faces.length,
            itemBuilder: (_, i) => _FaceTile(
              face: _faces[i],
              onDelete: () => _deleteFace(_faces[i].id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.face_retouching_natural,
              size: 72, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('Aucun visage enregistré',
              style: TextStyle(fontSize: 18, color: Colors.white60)),
          const SizedBox(height: 10),
          const Text(
            'Ajoutez des visages pour identifier\nautomatiquement vos visiteurs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _modelReady ? _addFaceDialog : null,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_modelReady
                ? 'Ajouter un visage'
                : 'Chargement du modèle…'),
          ),
        ],
      ),
    );
  }

  // ── Ajout de visage ────────────────────────────────────────────────────────

  Future<void> _addFaceDialog() async {
    // Étape 1 : prendre un snapshot de la caméra
    final snapshot = await _captureSnapshot();
    if (snapshot == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de capturer une image de la caméra'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;

    // Étape 2 : détecter le visage
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DetectingDialog(),
    );

    final detection = await FaceRecognizer.detect(snapshot);

    if (!mounted) return;
    Navigator.of(context).pop(); // ferme _DetectingDialog

    if (detection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun visage détecté dans l\'image'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Étape 3 : demander le nom
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(thumbnail: detection.thumbnail),
    );

    if (name == null || name.isEmpty) return;

    // Enregistrer
    final face = RegisteredFace(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      embedding: detection.embedding,
      thumbnailB64: base64Encode(detection.thumbnail),
      registeredAt: DateTime.now(),
    );

    await FaceStore.addFace(face);
    await _loadFaces();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name enregistré ✓'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<Uint8List?> _captureSnapshot() async {
    if (Prefs.cameraEntity.isEmpty) return null;
    return HaCamera.fetchSnapshot(Prefs.cameraEntity);
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> _deleteFace(String id) async {
    final face = _faces.firstWhere((f) => f.id == id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce visage ?'),
        content: Text('${face.name} sera retiré de la reconnaissance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FaceStore.removeFace(id);
    await _loadFaces();
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text(
            'Tous les visages enregistrés seront supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FaceStore.clear();
    await _loadFaces();
  }

  // ── Upsell ─────────────────────────────────────────────────────────────────

  Widget _buildUpsell(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reconnaissance faciale')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face_retouching_natural,
                  size: 80, color: Color(0xFF1E88E5)),
              const SizedBox(height: 24),
              const Text(
                'Reconnaissance faciale',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeatureRow(
                      icon: Icons.psychology,
                      text: 'IA locale — aucune donnée envoyée en dehors',
                    ),
                    SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.speed,
                      text: 'Identification en temps réel (<500 ms)',
                    ),
                    SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.people_outline,
                      text: 'Jusqu\'à 50 visages enregistrés',
                    ),
                    SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.history_edu,
                      text: 'Nom affiché dans l\'historique des visites',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.star),
                label: const Text('Passer à DoorWatch Pro'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  // TODO : naviguer vers l'écran d'achat Gumroad
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Pro — disponible prochainement'),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliaires ────────────────────────────────────────────────────────

class _FaceTile extends StatelessWidget {
  final RegisteredFace face;
  final VoidCallback onDelete;

  const _FaceTile({required this.face, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final thumb = face.thumbnailBytes;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: thumb != null
            ? Image.memory(
                thumb,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              )
            : Container(
                width: 52,
                height: 52,
                color: const Color(0xFF161B22),
                child: const Icon(Icons.face, color: Colors.white38),
              ),
      ),
      title: Text(
        face.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Enregistré le ${_fmt(face.registeredAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.white38),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white38),
        onPressed: onDelete,
        tooltip: 'Supprimer',
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }
}

class _DetectingDialog extends StatelessWidget {
  const _DetectingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Détection du visage…'),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final Uint8List thumbnail;
  const _NameDialog({required this.thumbnail});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nommer ce visage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              widget.thumbnail,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex : Jean, Marie, Livreur…',
              labelText: 'Prénom ou étiquette',
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) {
              if (v.isNotEmpty) Navigator.pop(context, v.trim());
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E88E5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
