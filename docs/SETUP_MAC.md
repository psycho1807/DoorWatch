# Installer Flutter sur Mac et créer le projet DoorWatch

## 1. Installer Flutter

```bash
# Via Homebrew (recommandé)
brew install flutter

# Vérifier l'installation
flutter doctor
```

Xcode n'est pas nécessaire (pas de build iOS).

## 2. Créer le projet

```bash
flutter create --org app.doorwatch --platforms android,ios doorwatch
cd doorwatch
```

## 3. Dépendances pubspec.yaml

Remplacer le contenu de `pubspec.yaml` par :

```yaml
name: doorwatch
description: Interphone intelligent pour Home Assistant
version: 0.1.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # HA connectivity
  web_socket_channel: ^2.4.0
  http: ^1.2.0

  # Notifications
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.0.0

  # Vidéo
  cached_network_image: ^3.3.0

  # Stockage local
  shared_preferences: ^2.2.0
  flutter_secure_storage: ^9.0.0

  # UI
  go_router: ^13.0.0

  # Pro : reconnaissance faciale
  tflite_flutter: ^0.10.4
  camera: ^0.10.5
  image: ^4.1.0

  # Pro : WebRTC interphone
  flutter_webrtc: ^0.10.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/models/         # Modèles TFLite
    - assets/images/
```

## 4. Lancer le projet

```bash
# Android (tablette/téléphone branché en USB)
flutter run

# iOS (simulateur)
flutter run -d iPhone

# Build release Android
flutter build apk --release

# Build release iOS
flutter build ipa --release
```

## 5. Structure à créer

```bash
mkdir -p lib/{app,core,features/{setup,doorbell,history,face_recognition,intercom},widgets}
mkdir -p assets/{models,images}
mkdir -p ha_integration
```
