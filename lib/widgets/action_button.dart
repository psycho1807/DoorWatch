import 'package:flutter/material.dart';

/// Bouton d'action carré avec icône + label (barre du bas de DoorbellScreen).
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool proRequired;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.enabled = true,
    this.proRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : Colors.white24;

    return GestureDetector(
      onTap: enabled ? onPressed : (proRequired ? _showProNag(context) : null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: effectiveColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: effectiveColor.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(icon, color: effectiveColor, size: 28),
              ),
              if (proRequired)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _showProNag(BuildContext context) {
    return () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.star, color: Color(0xFFFFB300)),
                SizedBox(width: 8),
                Text('Fonctionnalité Pro'),
              ],
            ),
            content: const Text(
              'Cette fonctionnalité nécessite DoorWatch Pro.\n\n'
              'Débloquez la reconnaissance faciale, l\'intercom WebRTC '
              'et l\'historique illimité.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO : naviguer vers l'écran d'achat Pro
                },
                child: const Text('Passer à Pro'),
              ),
            ],
          ),
        );
  }
}
