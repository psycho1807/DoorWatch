import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bouton d'action carré avec icône + label (barre du bas de DoorbellScreen).
/// Supporte les états loading, disabled et pro-required.
class ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function()? onPressed;
  final bool enabled;
  final bool proRequired;
  final bool loading;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.enabled = true,
    this.proRequired = false,
    this.loading = false,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.enabled || _busy || widget.loading) return;

    if (widget.proRequired) {
      _showProNag(context);
      return;
    }

    HapticFeedback.lightImpact();
    await _pressCtrl.forward();
    await _pressCtrl.reverse();

    if (widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        (widget.enabled && !widget.proRequired) ? widget.color : Colors.white24;
    final isActive = widget.enabled && !widget.proRequired;
    final showSpinner = _busy || widget.loading;

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) {
        if (isActive && !_busy) _pressCtrl.forward();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: effectiveColor.withOpacity(isActive ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: effectiveColor.withOpacity(isActive ? 0.4 : 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: showSpinner
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: effectiveColor,
                            ),
                          ),
                        )
                      : Icon(widget.icon,
                          color: effectiveColor, size: 28),
                ),
                if (widget.proRequired)
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
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProNag(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(
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
          'Débloquez la reconnaissance faciale, l\'intercom '
          'et l\'historique illimité pour 6,99 €.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Naviguer vers les paramètres pour activer la licence
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/settings');
            },
            child: const Text('Passer à Pro →'),
          ),
        ],
      ),
    );
  }
}
