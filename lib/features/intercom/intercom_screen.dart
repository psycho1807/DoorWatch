import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Écran d'intercom WebRTC (Pro) — communication bidirectionnelle audio.
///
/// Architecture :
///   - Signaling via HA WebSocket (custom events)
///   - Audio peer-to-peer WebRTC (flutter_webrtc)
///   - Compression Opus, STUN Google, TURN optionnel
class IntercomScreen extends StatefulWidget {
  const IntercomScreen({super.key});

  @override
  State<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends State<IntercomScreen> {
  bool _connected = false;
  bool _muted     = false;
  bool _speaking  = false;

  // RTCPeerConnection? _pc;
  // MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    // TODO (Pro) :
    // 1. Capturer le micro local
    //    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    // 2. Créer RTCPeerConnection avec STUN
    // 3. Envoyer l'offre SDP via HA WebSocket (event custom `doorwatch_offer`)
    // 4. Recevoir la réponse SDP depuis HA/ESP32-cam
    // 5. Échanger les candidats ICE
    // 6. setState(() => _connected = true)

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _connected = true);
  }

  Future<void> _endCall() async {
    // _pc?.close();
    // _localStream?.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // Avatar sonnette
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF1E88E5).withOpacity(0.3),
                    width: 2),
              ),
              child: const Icon(Icons.doorbell_outlined,
                  size: 56, color: Color(0xFF1E88E5)),
            ),
            const SizedBox(height: 24),

            const Text('Sonnette',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _connected ? 'En communication' : 'Connexion…',
              style: TextStyle(
                color: _connected ? Colors.green : Colors.white38,
              ),
            ),

            // Indicateur niveau audio (placeholder)
            if (_connected) ...[
              const SizedBox(height: 32),
              _AudioLevelIndicator(active: _speaking),
            ],

            const Spacer(),

            // Boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute
                _CallButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Son coupé' : 'Micro',
                  color: _muted ? Colors.red : Colors.white24,
                  onPressed: () => setState(() => _muted = !_muted),
                ),

                // Raccrocher
                _CallButton(
                  icon: Icons.call_end,
                  label: 'Terminer',
                  color: Colors.red,
                  size: 72,
                  onPressed: _endCall,
                ),

                // Haut-parleur
                _CallButton(
                  icon: Icons.volume_up,
                  label: 'HP',
                  color: Colors.white24,
                  onPressed: () {
                    // TODO : basculer haut-parleur
                  },
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback? onPressed;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 56,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
}

class _AudioLevelIndicator extends StatelessWidget {
  final bool active;
  const _AudioLevelIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        12,
        (i) => AnimatedContainer(
          duration: Duration(milliseconds: 100 + i * 20),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: active ? (8.0 + (i % 4) * 10) : 8,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF1E88E5)
                : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
