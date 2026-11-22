import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:http/http.dart' as http;

import 'prefs.dart';

typedef HaEventCallback = void Function(Map<String, dynamic> event);

/// Client WebSocket vers Home Assistant.
/// Gère l'authentification, les abonnements aux événements et le reconnect.
class HaClient {
  HaClient._();
  static final HaClient instance = HaClient._();

  WebSocketChannel? _channel;
  int _msgId = 1;
  bool _authenticated = false;
  bool _reconnecting = false;

  final _eventListeners = <String, List<HaEventCallback>>{};
  final _stateListeners = <String, List<HaEventCallback>>{};

  // ── Connexion ────────────────────────────────────────────────────────────

  /// Ouvre la connexion WebSocket et s'authentifie.
  Future<void> connect() async {
    if (_channel != null) return;

    final raw = Prefs.haUrl.trimRight();
    final uri = Uri.parse(raw.replaceFirst(RegExp(r'^http'), 'ws') + '/api/websocket');

    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onMessage,
      onError: (e) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void disconnect() {
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _authenticated = false;
    _msgId = 1;
  }

  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;
    _channel = null;
    _authenticated = false;
    Future.delayed(const Duration(seconds: 5), () async {
      _reconnecting = false;
      await connect();
    });
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = msg['type'] as String?;

    switch (type) {
      case 'auth_required':
        _send({'type': 'auth', 'access_token': Prefs.haToken});

      case 'auth_ok':
        _authenticated = true;
        _resubscribeAll();

      case 'auth_invalid':
        // Token invalide — ne pas reconnecter en boucle
        disconnect();

      case 'event':
        _dispatchEvent(msg);
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  int _nextId() => _msgId++;

  // ── Événements ───────────────────────────────────────────────────────────

  /// S'abonne à un type d'événement HA (`state_changed`, `call_service`, …).
  void subscribeEvent(String eventType, HaEventCallback cb) {
    _eventListeners.putIfAbsent(eventType, () => []).add(cb);
    if (_authenticated) {
      _send({'id': _nextId(), 'type': 'subscribe_events', 'event_type': eventType});
    }
  }

  /// S'abonne aux changements d'état d'une entité spécifique.
  void subscribeState(String entityId, HaEventCallback cb) {
    _stateListeners.putIfAbsent(entityId, () => []).add(cb);
    if (_authenticated) {
      _send({'id': _nextId(), 'type': 'subscribe_events', 'event_type': 'state_changed'});
    }
  }

  void unsubscribeState(String entityId, HaEventCallback cb) {
    _stateListeners[entityId]?.remove(cb);
  }

  void _resubscribeAll() {
    for (final eventType in _eventListeners.keys) {
      _send({'id': _nextId(), 'type': 'subscribe_events', 'event_type': eventType});
    }
    if (_stateListeners.isNotEmpty) {
      _send({'id': _nextId(), 'type': 'subscribe_events', 'event_type': 'state_changed'});
    }
  }

  void _dispatchEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as Map<String, dynamic>?;
    if (event == null) return;

    final type = event['event_type'] as String?;
    if (type == null) return;

    // Listeners génériques sur le type
    for (final cb in (_eventListeners[type] ?? [])) {
      cb(event);
    }

    // Listeners par entité sur state_changed
    if (type == 'state_changed') {
      final data = event['data'] as Map<String, dynamic>?;
      final entityId = data?['entity_id'] as String?;
      if (entityId != null) {
        for (final cb in (_stateListeners[entityId] ?? [])) {
          cb(event);
        }
      }
    }
  }

  // ── API REST ─────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${Prefs.haToken}',
        'Content-Type': 'application/json',
      };

  /// Lit l'état d'une entité.
  Future<Map<String, dynamic>?> getState(String entityId) async {
    try {
      final r = await http.get(
        Uri.parse(Prefs.apiUrl('/states/$entityId')),
        headers: _headers,
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  /// Appelle un service HA (`domain.service`).
  Future<bool> callService(String domain, String service,
      {Map<String, dynamic>? data}) async {
    try {
      final r = await http.post(
        Uri.parse(Prefs.apiUrl('/services/$domain/$service')),
        headers: _headers,
        body: jsonEncode(data ?? {}),
      );
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Liste toutes les entités d'un domaine.
  Future<List<Map<String, dynamic>>> listStates({String? domain}) async {
    try {
      final r = await http.get(
        Uri.parse(Prefs.apiUrl('/states')),
        headers: _headers,
      );
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .where((e) => domain == null ||
              (e['entity_id'] as String).startsWith('$domain.'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Vérifie que l'URL et le token sont valides.
  static Future<bool> testConnection(String url, String token) async {
    try {
      final r = await http.get(
        Uri.parse('${url.trimRight()}/api/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
