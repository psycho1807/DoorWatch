import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs.dart';

/// Écran des paramètres DoorWatch.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notifySound;
  late bool _notifyVibrate;
  late int  _keepDays;
  final _licenseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifySound   = Prefs.notifySound;
    _notifyVibrate = Prefs.notifyVibrate;
    _keepDays      = Prefs.keepHistoryDays;
    _licenseCtrl.text = Prefs.proLicense;
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          // ── Connexion HA ──────────────────────────────────────────────
          _SectionHeader('Connexion Home Assistant'),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('URL HA'),
            subtitle: Text(Prefs.haUrl.isEmpty ? 'Non configuré' : Prefs.haUrl,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup'),
          ),
          ListTile(
            leading: const Icon(Icons.sensors),
            title: const Text('Entités HA'),
            subtitle: const Text('Sonnette, caméra, serrure, lumière',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup/entities'),
          ),

          // ── Notifications ─────────────────────────────────────────────
          _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Son'),
            value: _notifySound,
            onChanged: (v) {
              setState(() => _notifySound = v);
              Prefs.notifySound = v;
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration'),
            value: _notifyVibrate,
            onChanged: (v) {
              setState(() => _notifyVibrate = v);
              Prefs.notifyVibrate = v;
            },
          ),

          // ── Historique ────────────────────────────────────────────────
          _SectionHeader('Historique'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Conserver les visites'),
            subtitle: Text(_keepDays == 0 ? 'Indéfiniment' : '$_keepDays jours',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: DropdownButton<int>(
              value: _keepDays,
              dropdownColor: const Color(0xFF1C2128),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 7,  child: Text('7 jours')),
                DropdownMenuItem(value: 14, child: Text('14 jours')),
                DropdownMenuItem(value: 30, child: Text('30 jours')),
                DropdownMenuItem(value: 90, child: Text('90 jours')),
                DropdownMenuItem(value: 0,  child: Text('Toujours')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _keepDays = v);
                Prefs.keepHistoryDays = v;
              },
            ),
          ),

          // ── Pro ───────────────────────────────────────────────────────
          _SectionHeader('DoorWatch Pro'),
          if (Prefs.isPro)
            const ListTile(
              leading: Icon(Icons.verified, color: Colors.green),
              title: Text('Licence Pro active'),
              subtitle: Text('Reconnaissance faciale + intercom activés',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _licenseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Clé de licence Pro',
                        hintText: 'DW-XXXX-XXXX-XXXX',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _activateLicense,
                    child: const Text('Activer'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Acheter DoorWatch Pro — 6,99 €'),
                onPressed: () {
                  // TODO : lancer l'URL Gumroad
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Réinitialisation ──────────────────────────────────────────
          _SectionHeader('Général'),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.red),
            title: const Text('Réinitialiser DoorWatch',
                style: TextStyle(color: Colors.red)),
            onTap: _resetApp,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _activateLicense() async {
    final key = _licenseCtrl.text.trim();
    if (key.isEmpty) return;
    // TODO : vérifier la clé via Gumroad API
    // Pour l'instant, accepter toute clé commençant par "DW-"
    if (key.startsWith('DW-') && key.length >= 14) {
      Prefs.proLicense = key;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Licence Pro activée ! 🎉'),
          backgroundColor: Colors.green,
        ));
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clé de licence invalide'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _resetApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réinitialiser ?'),
        content: const Text(
            'Toute la configuration et l\'historique seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (confirm == true) {
      await Prefs.clear();
      if (mounted) context.go('/setup');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF1E88E5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );
}
