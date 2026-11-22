import 'package:flutter/material.dart';

import '../../core/prefs.dart';

/// Écran de gestion des visages reconnus (Pro uniquement).
/// Affiche la liste des visages enregistrés et permet d'en ajouter.
class FacesScreen extends StatelessWidget {
  const FacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Prefs.isPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reconnaissance faciale')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.face, size: 80, color: Colors.white24),
                const SizedBox(height: 24),
                const Text(
                  'Reconnaissance faciale',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Identifiez automatiquement vos visiteurs habituels '
                  'grâce à l\'IA locale (TensorFlow Lite).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('Passer à DoorWatch Pro'),
                  onPressed: () {
                    // TODO : naviguer vers l'écran d'achat
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Version Pro : liste des visages
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visages reconnus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO : ajouter un visage
            },
            tooltip: 'Ajouter un visage',
          ),
        ],
      ),
      body: const _FacesList(),
    );
  }
}

class _FacesList extends StatelessWidget {
  const _FacesList();

  @override
  Widget build(BuildContext context) {
    // TODO : charger depuis SharedPreferences ou SQLite
    // Affiche un placeholder pour l'instant
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.face_retouching_natural,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Aucun visage enregistré',
              style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Ajouter un visage'),
            onPressed: () {
              // TODO : flux d'ajout de visage
            },
          ),
        ],
      ),
    );
  }
}
