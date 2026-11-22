import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ha_client.dart';
import '../../core/prefs.dart';

/// Écran de sélection des entités HA (sonnette, caméra, serrure, lumière).
class EntitiesScreen extends StatefulWidget {
  const EntitiesScreen({super.key});

  @override
  State<EntitiesScreen> createState() => _EntitiesScreenState();
}

class _EntitiesScreenState extends State<EntitiesScreen> {
  bool _loading = true;

  List<String> _binarySensors = [];
  List<String> _cameras       = [];
  List<String> _locks         = [];
  List<String> _lights        = [];

  String? _doorbell;
  String? _camera;
  String? _lock;
  String? _light;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    await HaClient.instance.connect();

    final sensors = await HaClient.instance.listStates(domain: 'binary_sensor');
    final cameras = await HaClient.instance.listStates(domain: 'camera');
    final locks   = await HaClient.instance.listStates(domain: 'lock');
    final lights  = await HaClient.instance.listStates(domain: 'light');

    setState(() {
      _binarySensors = sensors.map((e) => e['entity_id'] as String).toList();
      _cameras       = cameras.map((e) => e['entity_id'] as String).toList();
      _locks         = locks.map((e) => e['entity_id'] as String).toList();
      _lights        = lights.map((e) => e['entity_id'] as String).toList();
      _loading = false;

      // Pré-remplir si déjà configuré, sinon auto-détecter les entités Ring
      _doorbell = Prefs.doorbellEntity.isNotEmpty
          ? Prefs.doorbellEntity
          : _autoDetect(_binarySensors, [
              'porte_d_entree_ding', 'doorbell', 'sonnette', 'ding',
            ]);
      _camera   = Prefs.cameraEntity.isNotEmpty
          ? Prefs.cameraEntity
          : _autoDetect(_cameras, [
              'porte_d_entree_live_view', 'doorbell', 'entree',
            ]);
      _lock     = Prefs.lockEntity.isNotEmpty
          ? Prefs.lockEntity
          : _autoDetect(_locks, ['entree', 'porte', 'door']);
      _light    = Prefs.lightEntity.isNotEmpty
          ? Prefs.lightEntity
          : _autoDetect(_lights, [
              'entree_vehicule_light', 'entree_vehicule_lumiere', 'entree',
            ]);
    });
  }

  /// Cherche dans [list] le premier entity_id contenant un des [keywords].
  String? _autoDetect(List<String> list, List<String> keywords) {
    for (final kw in keywords) {
      final match = list.firstWhere(
        (id) => id.contains(kw),
        orElse: () => '',
      );
      if (match.isNotEmpty) return match;
    }
    return null;
  }

  void _save() {
    if (_doorbell == null || _camera == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sonnette et caméra sont obligatoires'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    Prefs.doorbellEntity = _doorbell!;
    Prefs.cameraEntity   = _camera!;
    Prefs.lockEntity     = _lock ?? '';
    Prefs.lightEntity    = _light ?? '';

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurer les entités')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Associez vos entités Home Assistant à DoorWatch.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 24),

                _EntityPicker(
                  label: 'Sonnette (binary_sensor) *',
                  icon: Icons.doorbell_outlined,
                  items: _binarySensors,
                  value: _doorbell,
                  onChanged: (v) => setState(() => _doorbell = v),
                ),
                const SizedBox(height: 16),

                _EntityPicker(
                  label: 'Caméra *',
                  icon: Icons.videocam_outlined,
                  items: _cameras,
                  value: _camera,
                  onChanged: (v) => setState(() => _camera = v),
                ),
                const SizedBox(height: 16),

                _EntityPicker(
                  label: 'Serrure connectée (optionnel)',
                  icon: Icons.lock_outlined,
                  items: _locks,
                  value: _lock,
                  onChanged: (v) => setState(() => _lock = v),
                  optional: true,
                ),
                const SizedBox(height: 16),

                _EntityPicker(
                  label: 'Lumière entrée (optionnel)',
                  icon: Icons.lightbulb_outlined,
                  items: _lights,
                  value: _light,
                  onChanged: (v) => setState(() => _light = v),
                  optional: true,
                ),
                const SizedBox(height: 40),

                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Terminer la configuration'),
                ),
              ],
            ),
    );
  }
}

class _EntityPicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;

  const _EntityPicker({
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = optional ? [null, ...items] : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white54),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: const Color(0xFF1C2128),
          items: allItems.map((id) {
            return DropdownMenuItem<String?>(
              value: id,
              child: Text(
                id ?? '— Aucune —',
                style: TextStyle(
                  color: id == null ? Colors.white38 : Colors.white,
                  fontSize: 13,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
