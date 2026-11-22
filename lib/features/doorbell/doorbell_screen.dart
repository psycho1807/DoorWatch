import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ha_client.dart';
import '../../core/ha_camera.dart';
import '../../core/prefs.dart';
import '../../core/visit_history.dart';
import '../../widgets/camera_view.dart';
import '../../widgets/camera_web_view.dart';
import '../../widgets/action_button.dart';

/// Écran principal DoorWatch — flux caméra + boutons d'action.
class DoorbellScreen extends StatefulWidget {
  const DoorbellScreen({super.key});

  @override
  State<DoorbellScreen> createState() => _DoorbellScreenState();
}

class _DoorbellScreenState extends State<DoorbellScreen> {
  bool _ringing   = false;
  bool _doorOpen  = false;
  bool _lightOn   = false;
  bool _connected = false;

  Uint8List? _snapshot;

  @override
  void initState() {
    super.initState();
    _connectAndListen();
    _loadSnapshot();
  }

  Future<void> _connectAndListen() async {
    final client = HaClient.instance;
    final ok = await client.connect();
    if (mounted) setState(() => _connected = ok);
    if (!ok) return;

    // État initial des entités
    _syncInitialStates();

    // Abonnements
    if (Prefs.doorbellEntity.isNotEmpty) {
      client.subscribeState(Prefs.doorbellEntity, _onDoorbellState);
    }
    if (Prefs.lockEntity.isNotEmpty) {
      client.subscribeState(Prefs.lockEntity, _onLockState);
    }
    if (Prefs.lightEntity.isNotEmpty) {
      client.subscribeState(Prefs.lightEntity, _onLightState);
    }
  }

  /// Lit l'état initial des entités au démarrage.
  Future<void> _syncInitialStates() async {
    final client = HaClient.instance;

    if (Prefs.lockEntity.isNotEmpty) {
      final s = await client.getState(Prefs.lockEntity);
      final state = s?['state'] as String?;
      if (mounted && state != null) {
        setState(() => _doorOpen = state == 'unlocked');
      }
    }
    if (Prefs.lightEntity.isNotEmpty) {
      final s = await client.getState(Prefs.lightEntity);
      final state = s?['state'] as String?;
      if (mounted && state != null) {
        setState(() => _lightOn = state == 'on');
      }
    }
  }

  Future<void> _loadSnapshot() async {
    if (Prefs.cameraEntity.isEmpty) return;
    final bytes = await HaCamera.fetchSnapshot(Prefs.cameraEntity);
    if (mounted && bytes != null) setState(() => _snapshot = bytes);
  }

  void _onDoorbellState(Map<String, dynamic> event) {
    final data     = event['data'] as Map<String, dynamic>?;
    final newState = (data?['new_state'] as Map<String, dynamic>?)?['state'];
    if (!mounted) return;
    final wasRinging = _ringing;
    setState(() => _ringing = newState == 'on');
    if (_ringing && !wasRinging) {
      _loadSnapshot();
      _recordVisit();
    }
  }

  void _onLockState(Map<String, dynamic> event) {
    final data     = event['data'] as Map<String, dynamic>?;
    final newState = (data?['new_state'] as Map<String, dynamic>?)?['state'];
    if (mounted) setState(() => _doorOpen = newState == 'unlocked');
  }

  void _onLightState(Map<String, dynamic> event) {
    final data     = event['data'] as Map<String, dynamic>?;
    final newState = (data?['new_state'] as Map<String, dynamic>?)?['state'];
    if (mounted) setState(() => _lightOn = newState == 'on');
  }

  Future<void> _openDoor() async {
    if (Prefs.lockEntity.isEmpty) return;

    // Confirmation avant ouverture
    if (!_doorOpen) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: Color(0xFF1E88E5)),
              SizedBox(width: 10),
              Text('Ouvrir la porte ?'),
            ],
          ),
          content: const Text('La porte va être déverrouillée.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ouvrir'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final service = _doorOpen ? 'lock' : 'unlock';
    final ok = await HaClient.instance.callService(
      'lock', service,
      data: {'entity_id': Prefs.lockEntity},
    );

    if (ok && mounted) {
      setState(() => _doorOpen = !_doorOpen);
      _showSnack(
        _doorOpen ? 'Porte déverrouillée ✓' : 'Porte verrouillée ✓',
        _doorOpen ? Colors.green : Colors.orange,
      );
    } else if (mounted) {
      _showSnack('Erreur — vérifiez la connexion HA', Colors.red);
    }
  }

  Future<void> _toggleLight() async {
    if (Prefs.lightEntity.isEmpty) return;
    final ok = await HaClient.instance.callService(
      'light',
      _lightOn ? 'turn_off' : 'turn_on',
      data: {'entity_id': Prefs.lightEntity},
    );
    if (!ok && mounted) {
      _showSnack('Erreur lumière', Colors.red);
    }
  }

  Future<void> _recordVisit() async {
    await VisitHistory.addVisit(Visit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
    ));
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.doorbell_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('DoorWatch'),
            const Spacer(),
            // Indicateur connexion
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            // Badge sonnette
            if (_ringing)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active,
                        size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Sonnette',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'Historique',
          ),
          if (Prefs.isPro)
            IconButton(
              icon: const Icon(Icons.face),
              onPressed: () => context.push('/faces'),
              tooltip: 'Visages reconnus',
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Flux caméra ──────────────────────────────────────────────
          Expanded(
            child: Prefs.cameraEntity.isNotEmpty
                ? (kIsWeb
                    ? CameraWebView(
                        entityId: Prefs.cameraEntity,
                        ringing: _ringing,
                        onRefresh: _loadSnapshot,
                      )
                    : CameraView(
                        entityId: Prefs.cameraEntity,
                        snapshot: _snapshot,
                        ringing: _ringing,
                        onRefresh: _loadSnapshot,
                      ))
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off,
                            size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Aucune caméra configurée',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
          ),

          // ── Boutons d'action ─────────────────────────────────────────
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Ouvrir / Verrouiller la porte
                ActionButton(
                  icon: _doorOpen
                      ? Icons.lock_open
                      : Icons.lock_outlined,
                  label: _doorOpen ? 'Ouverte' : 'Ouvrir',
                  color: _doorOpen
                      ? Colors.green
                      : const Color(0xFF1E88E5),
                  enabled: Prefs.lockEntity.isNotEmpty,
                  onPressed: _openDoor,
                ),

                // Lumière
                ActionButton(
                  icon: _lightOn
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                  label: _lightOn ? 'Lumière ON' : 'Lumière',
                  color: _lightOn ? Colors.amber : Colors.white38,
                  enabled: Prefs.lightEntity.isNotEmpty,
                  onPressed: _toggleLight,
                ),

                // Intercom (Pro)
                ActionButton(
                  icon: Icons.mic_outlined,
                  label: 'Parler',
                  color: const Color(0xFF1E88E5),
                  enabled: Prefs.isPro,
                  proRequired: !Prefs.isPro,
                  onPressed: _startIntercom,
                ),

                // Snapshot manuel
                ActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Photo',
                  color: Colors.white54,
                  onPressed: _loadSnapshot,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startIntercom() async {
    // TODO (Pro) : lancer WebRTC intercom
    _showSnack('Intercom WebRTC — bientôt disponible', Colors.blue);
  }
}
