import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

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
  bool _connecting = false;
  bool _reconnecting = false;

  final _eventListeners  = <String, List<HaEventCallback>>{};
  final _stateListeners  = <String, List<HaEventCallback>>{};
  final _pendingRequests = <int, void Function(dynamic)>{};

  // Completer résolu quand auth_ok est reçu
  Completer<bool>? _authCompleter;

  // ── Connexion ────────────────────────────────────────────────────────────

  /// Ouvre la connexion WebSocket et attend auth_ok.
  Future<bool> connect() async {
    if (_authenticated) return true;
    if (_connecting) {
      // Attendre que la connexion en cours se termine
      return await (_authCompleter?.future ?? Future.value(false));
    }

    _connecting = true;
    _authCompleter = Completer<bool>();

    try {
      final raw = Prefs.haUrl.trimRight();
      final uri = Uri.parse(
          raw.replaceFirst(RegExp(r'^http'), 'ws') + '/api/websocket');

      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          if (!(_authCompleter?.isCompleted ?? true)) {
            _authCompleter?.complete(false);
          }
          _scheduleReconnect();
        },
        onDone: () {
          if (!(_authCompleter?.isCompleted ?? true)) {
            _authCompleter?.complete(false);
          }
          _scheduleReconnect();
        },
      );

      final ok = await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      _connecting = false;
      return ok;
    } catch (_) {
      _connecting = false;
      _authCompleter?.complete(false);
      return false;
    }
  }

  void disconnect() {
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _authenticated = false;
    _connecting = false;
    _msgId = 1;
    _pendingRequests.clear();
  }

  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;
    _channel = null;
    _authenticated = false;
    _connecting = false;
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
        _connecting = false;
        if (!(_authCompleter?.isCompleted ?? true)) {
          _authCompleter?.complete(true);
        }
        _resubscribeAll();

      case 'auth_invalid':
        _authenticated = false;
        _connecting = false;
        if (!(_authCompleter?.isCompleted ?? true)) {
          _authCompleter?.complete(false);
        }
        disconnect();

      case 'event':
        _dispatchEvent(msg);

      case 'result':
        final id = msg['id'] as int?;
        if (id != null && _pendingRequests.containsKey(id)) {
          final cb = _pendingRequests.remove(id)!;
          if (msg['success'] == true) {
            cb(msg['result']);
          } else {
            // En cas d'erreur HA, on complète quand même avec null
            cb(null);
          }
        }
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  int _nextId() => _msgId++;

  // ── Événements ───────────────────────────────────────────────────────────

  /// S'abonne à un type d'événement HA.
  void subscribeEvent(String eventType, HaEventCallback cb) {
    _eventListeners.putIfAbsent(eventType, () => []).add(cb);
    if (_authenticated) {
      _send({'id': _nextId(), 'type': 'subscribe_events',
             'event_type': eventType});
    }
  }

  /// S'abonne aux changements d'état d'une entité spécifique.
  void subscribeState(String entityId, HaEventCallback cb) {
    final isFirstSub = _stateListeners.isEmpty;
    _stateListeners.putIfAbsent(entityId, () => []).add(cb);
    // N'envoyer la subscription qu'une seule fois pour state_changed
    if (_authenticated && isFirstSub) {
      _send({'id': _nextId(), 'type': 'subscribe_events',
             'event_type': 'state_changed'});
    }
  }

  void unsubscribeState(String entityId, HaEventCallback cb) {
    _stateListeners[entityId]?.remove(cb);
  }

  void _resubscribeAll() {
    for (final eventType in _eventListeners.keys) {
      _send({'id': _nextId(), 'type': 'subscribe_events',
             'event_type': eventType});
    }
    if (_stateListeners.isNotEmpty) {
      _send({'id': _nextId(), 'type': 'subscribe_events',
             'event_type': 'state_changed'});
    }
  }

  void _dispatchEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as Map<String, dynamic>?;
    if (event == null) return;

    final type = event['event_type'] as String?;
    if (type == null) return;

    for (final cb in (_eventListeners[type] ?? [])) {
      cb(event);
    }

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

  // ── WebSocket request/response ───────────────────────────────────────────

  /// Envoie une requête WS et attend la réponse `result`.
  Future<Map<String, dynamic>?> sendRequest(
      Map<String, dynamic> msg) async {
    if (!_authenticated) {
      final ok = await connect();
      if (!ok) return null;
    }
    try {
      final id = _nextId();
      final completer = Completer<Map<String, dynamic>?>();
      _pendingRequests[id] = (data) {
        if (data == null) {
          completer.complete(null);
        } else if (data is Map<String, dynamic>) {
          completer.complete(data);
        } else {
          // Cas inattendu — on wrappe pour ne pas casser le cast
          completer.complete({'_raw': data});
        }
      };
      _send({...msg, 'id': id});
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _pendingRequests.remove(id);
          return null;
        },
      );
    } catch (e) {
      return null;
    }
  }

  /// Appelle un service HA via WebSocket.
  Future<bool> callService(String domain, String service,
      {Map<String, dynamic>? data}) async {
    try {
      final result = await sendRequest({
        'type': 'call_service',
        'domain': domain,
        'service': service,
        'service_data': data ?? {},
      });
      return result != null;
    } catch (_) {
      return false;
    }
  }

  /// Liste les entités d'un domaine via WebSocket.
  Future<List<Map<String, dynamic>>> listStates({String? domain}) async {
    if (!_authenticated) {
      final ok = await connect();
      if (!ok) return [];
    }
    try {
      final id = _nextId();
      final completer = Completer<List<Map<String, dynamic>>>();
      _pendingRequests[id] = (data) {
        if (data == null) { completer.complete([]); return; }
        final result = data as List<dynamic>;
        final states = result
            .cast<Map<String, dynamic>>()
            .where((e) =>
                domain == null ||
                (e['entity_id'] as String).startsWith('$domain.'))
            .toList();
        completer.complete(states);
      };
      _send({'id': id, 'type': 'get_states'});
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _pendingRequests.remove(id);
          return [];
        },
      );
    } catch (_) {
      return [];
    }
  }

  /// Lit l'état courant d'une entité via WebSocket.
  Future<Map<String, dynamic>?> getState(String entityId) async {
    final states = await listStates();
    try {
      return states.firstWhere(
          (e) => e['entity_id'] == entityId);
    } catch (_) {
      return null;
    }
  }

  // ── Test de connexion (statique) ─────────────────────────────────────────

  /// Vérifie URL + token via WebSocket (pas soumis au CORS).
  static Future<bool> testConnection(String url, String token) async {
    final completer = Completer<bool>();
    WebSocketChannel? ch;

    try {
      final raw = url.trimRight();
      final wsUrl =
          raw.replaceFirst(RegExp(r'^http'), 'ws') + '/api/websocket';
      ch = WebSocketChannel.connect(Uri.parse(wsUrl));

      late StreamSubscription sub;
      sub = ch.stream.listen(
        (data) {
          try {
            final msg =
                jsonDecode(data as String) as Map<String, dynamic>;
            final type = msg['type'] as String?;
            if (type == 'auth_required') {
              ch!.sink.add(
                  jsonEncode({'type': 'auth', 'access_token': token}));
            } else if (type == 'auth_ok') {
              if (!completer.isCompleted) completer.complete(true);
              sub.cancel();
              ch?.sink.close();
            } else if (type == 'auth_invalid') {
              if (!completer.isCompleted) completer.complete(false);
              sub.cancel();
              ch?.sink.close();
            }
          } catch (_) {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          ch?.sink.close();
          return false;
        },
      );
    } catch (_) {
      ch?.sink.close();
      return false;
    }
  }
}
