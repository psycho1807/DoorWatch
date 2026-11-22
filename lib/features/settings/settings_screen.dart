import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/prefs.dart';

const String _gumroadUrl =
    'https://doorwatch.gumroad.com/l/doorwatch-pro';
const String _appVersion = '1.0.0';

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
  bool _activating = false;

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

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          // ── Connexion HA ──────────────────────────────────────────────
          _SectionHeader('Connexion Home Assistant'),
          _NavTile(
            icon: Icons.link,
            title: 'URL & Token',
            subtitle: Prefs.haUrl.isEmpty ? 'Non configuré' : Prefs.haUrl,
            onTap: () => context.push('/setup'),
          ),
          _NavTile(
            icon: Icons.sensors,
            title: 'Entités',
            subtitle: 'Sonnette · Caméra · Serrure · Lumière',
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
            leading: const Icon(Icons.history,
                size: 22, color: Colors.white54),
            title: const Text('Conserver les visites'),
            trailing: DropdownButton<int>(
              value: _keepDays,
              dropdownColor: const Color(0xFF1C2128),
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 14, color: Colors.white),
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
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.green),
              title: const Text('Licence Pro active',
                  style: TextStyle(color: Colors.green,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Reconnaissance faciale + intercom activés',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: TextButton(
                onPressed: _revokeLicense,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.red),
                child: const Text('Révoquer'),
              ),
            )
          else ...[
            // Description des fonctionnalités Pro
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Card(
                color: const Color(0xFF1C2128),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fonctionnalités Pro',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 10),
                      _ProFeature(
                          icon: Icons.face,
                          text: 'Reconnaissance faciale (MobileFaceNet)'),
                      _ProFeature(
                          icon: Icons.mic,
                          text: 'Intercom WebRTC bidirectionnel'),
                      _ProFeature(
                          icon: Icons.notifications_active,
                          text: 'Notifications push Firebase'),
                      _ProFeature(
                          icon: Icons.timeline,
                          text: 'Historique illimité + export CSV'),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Acheter DoorWatch Pro — 6,99 €'),
                          onPressed: _openGumroad,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Saisie licence
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _licenseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Clé de licence',
                        hintText: 'DW-XXXX-XXXX-XXXX',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      onSubmitted: (_) => _activateLicense(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _activating ? null : _activateLicense,
                    child: _activating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Text('Activer'),
                  ),
                ],
              ),
            ),
          ],

          // ── CORS info (uniquement si caméra configurée) ───────────────
          if (Prefs.cameraEntity.isNotEmpty) ...[
            _SectionHeader('Caméra web'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                color: const Color(0xFF1C2128),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF1E88E5), size: 18),
                          SizedBox(width: 8),
                          Text('Flux caméra sur navigateur',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pour afficher le flux Ring dans le navigateur, '
                        'ajoutez dans /config/configuration.yaml :',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'http:\n'
                          '  cors_allowed_origins:\n'
                          '    - http://localhost',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Puis redémarrez Home Assistant.',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── À propos ──────────────────────────────────────────────────
          _SectionHeader('À propos'),
          ListTile(
            leading: const Icon(Icons.doorbell_outlined,
                color: Color(0xFF1E88E5)),
            title: const Text('DoorWatch'),
            subtitle: Text('Version $_appVersion',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_outlined),
            title: const Text('Site officiel'),
            subtitle: const Text('doorwatch.gumroad.com',
                style: TextStyle(
                    color: Colors.white38, fontSize: 12)),
            onTap: _openGumroad,
          ),

          const SizedBox(height: 8),

          // ── Réinitialisation ──────────────────────────────────────────
          _SectionHeader('Général'),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.red),
            title: const Text('Réinitialiser DoorWatch',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text(
                'Efface toute la configuration et l\'historique',
                style: TextStyle(color: Colors.red, fontSize: 12)),
            onTap: _resetApp,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _openGumroad() async {
    final uri = Uri.parse(_gumroadUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _activateLicense() async {
    final key = _licenseCtrl.text.trim();
    if (key.isEmpty) return;

    setState(() => _activating = true);
    await Future.delayed(const Duration(milliseconds: 600)); // UX

    // TODO : vérifier la clé via Gumroad Ping API
    // Pour l'instant, accepter toute clé commençant par "DW-"
    final valid = key.startsWith('DW-') && key.length >= 14;

    setState(() => _activating = false);

    if (valid) {
      Prefs.proLicense = key;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Licence Pro activée ! 🎉'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clé de licence invalide'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _revokeLicense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Révoquer la licence ?'),
        content: const Text(
            'Les fonctionnalités Pro seront désactivées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Révoquer')),
        ],
      ),
    );
    if (confirm == true) {
      Prefs.proLicense = '';
      if (mounted) setState(() {});
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

// ── Widgets auxiliaires ──────────────────────────────────────────────────

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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      );
}

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: const Color(0xFF1E88E5).withOpacity(0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ),
          ],
        ),
      );
}
