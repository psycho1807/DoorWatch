import 'package:shared_preferences/shared_preferences.dart';

/// Clés de stockage des préférences DoorWatch.
class Prefs {
  Prefs._();

  static late SharedPreferences _p;

  static const _keyHaUrl      = 'ha_url';
  static const _keyHaToken    = 'ha_token';
  static const _keyDoorbellEntity = 'doorbell_entity';
  static const _keyCameraEntity  = 'camera_entity';
  static const _keyLockEntity    = 'lock_entity';
  static const _keyLightEntity   = 'light_entity';
  static const _keyProLicense    = 'pro_license';
  static const _keyNotifySound   = 'notify_sound';
  static const _keyNotifyVibrate = 'notify_vibrate';
  static const _keyKeepHistory   = 'keep_history_days';
  static const _keyFcmToken      = 'fcm_token';

  /// Initialiser en début d'app.
  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ── Connexion HA ─────────────────────────────────────────────────────────

  static String get haUrl      => _p.getString(_keyHaUrl) ?? '';
  static String get haToken    => _p.getString(_keyHaToken) ?? '';
  static set haUrl(String v)   => _p.setString(_keyHaUrl, v);
  static set haToken(String v) => _p.setString(_keyHaToken, v);

  static bool get isConfigured => haUrl.isNotEmpty && haToken.isNotEmpty;

  // ── Entités HA ───────────────────────────────────────────────────────────

  static String get doorbellEntity => _p.getString(_keyDoorbellEntity) ?? '';
  static String get cameraEntity   => _p.getString(_keyCameraEntity) ?? '';
  static String get lockEntity     => _p.getString(_keyLockEntity) ?? '';
  static String get lightEntity    => _p.getString(_keyLightEntity) ?? '';

  static set doorbellEntity(String v) => _p.setString(_keyDoorbellEntity, v);
  static set cameraEntity(String v)   => _p.setString(_keyCameraEntity, v);
  static set lockEntity(String v)     => _p.setString(_keyLockEntity, v);
  static set lightEntity(String v)    => _p.setString(_keyLightEntity, v);

  // ── Pro ──────────────────────────────────────────────────────────────────

  /// Clé de licence Pro achetée via Gumroad.
  static String get proLicense => _p.getString(_keyProLicense) ?? '';
  static set proLicense(String v) => _p.setString(_keyProLicense, v);

  static bool get isPro => proLicense.isNotEmpty;

  // ── Notifications ────────────────────────────────────────────────────────

  static bool get notifySound   => _p.getBool(_keyNotifySound) ?? true;
  static bool get notifyVibrate => _p.getBool(_keyNotifyVibrate) ?? true;
  static set notifySound(bool v)   => _p.setBool(_keyNotifySound, v);
  static set notifyVibrate(bool v) => _p.setBool(_keyNotifyVibrate, v);

  /// Durée en jours de conservation des visites (0 = infini).
  static int get keepHistoryDays => _p.getInt(_keyKeepHistory) ?? 30;
  static set keepHistoryDays(int v) => _p.setInt(_keyKeepHistory, v);

  // ── FCM ──────────────────────────────────────────────────────────────────

  static String get fcmToken => _p.getString(_keyFcmToken) ?? '';
  static set fcmToken(String v) => _p.setString(_keyFcmToken, v);

  // ── Utilitaires ─────────────────────────────────────────────────────────

  /// Réinitialise toute la configuration (logout / reset).
  static Future<void> clear() => _p.clear();

  /// Construit l'URL complète vers un endpoint de l'API HA.
  static String apiUrl(String path) =>
      '${haUrl.trimRight()}/api$path';

  /// Construit l'URL de la caméra proxy HA.
  static String cameraProxyUrl(String entityId) =>
      '${haUrl.trimRight()}/api/camera_proxy/$entityId';
}
