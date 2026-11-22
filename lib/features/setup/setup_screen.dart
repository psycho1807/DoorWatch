import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ha_client.dart';
import '../../core/prefs.dart';

/// Écran de configuration initiale : URL HA + token long-lived.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _urlCtrl  = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final url   = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();

    final ok = await HaClient.testConnection(url, token);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'Impossible de se connecter. Vérifiez l\'URL et le token.';
      });
      return;
    }

    Prefs.haUrl   = url;
    Prefs.haToken = token;

    // Naviguer vers la config des entités
    if (mounted) context.go('/setup/entities');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // Logo + titre
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.doorbell_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DoorWatch',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Interphone Home Assistant',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const Text('Connexion à Home Assistant',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Entrez l\'URL de votre instance HA et un token d\'accès longue durée.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // URL
                    TextFormField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'URL Home Assistant',
                        hintText: 'http://192.168.1.100:8123',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'URL requise';
                        }
                        final uri = Uri.tryParse(v.trim());
                        if (uri == null || !uri.hasScheme) {
                          return 'URL invalide (ex: http://192.168.1.100:8123)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Token
                    TextFormField(
                      controller: _tokenCtrl,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Token longue durée',
                        hintText: 'eyJ0eXAiOiJKV...',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Token requis';
                        }
                        if (v.trim().length < 20) {
                          return 'Token trop court';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Aide token
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showTokenHelp(context),
                        icon: const Icon(Icons.help_outline, size: 16),
                        label: const Text('Comment créer un token ?'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Erreur
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bouton
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.arrow_forward),
                      label: Text(_loading ? 'Connexion…' : 'Se connecter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Créer un token longue durée',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _helpStep('1', 'Ouvrez Home Assistant dans un navigateur'),
            _helpStep('2', 'Cliquez sur votre profil (icône en bas à gauche)'),
            _helpStep('3', 'Faites défiler jusqu\'à "Tokens d\'accès longue durée"'),
            _helpStep('4', 'Cliquez sur "Créer un token" et nommez-le "DoorWatch"'),
            _helpStep('5', 'Copiez le token généré et collez-le ici'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _helpStep(String num, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(num,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
}
