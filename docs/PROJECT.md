# DoorWatch — Interphone intelligent pour Home Assistant

**Tagline** : *Votre porte. Vos données. Aucun cloud.*

## Vision

Application mobile Android + iOS connectée à Home Assistant.
Notification push instantanée quand quelqu'un sonne, flux vidéo en direct,
reconnaissance faciale locale, et ouverture de la porte — le tout sans
passer par le cloud du fabricant.

---

## Positionnement

| | Ring App | Nest App | **DoorWatch** |
|---|---|---|---|
| Fonctionne sans abonnement | ❌ | ❌ | ✅ |
| Données locales (RGPD) | ❌ | ❌ | ✅ |
| Compatible toutes caméras HA | ❌ | ❌ | ✅ |
| Reconnaissance faciale locale | ❌ | ❌ | ✅ Pro |
| Open source | ❌ | ❌ | ✅ |

---

## Fonctionnalités

### Gratuit
- Connexion à Home Assistant (local + Nabu Casa + tunnel)
- Notification push quand sonnette déclenchée
- Flux vidéo en direct (caméra HA)
- Bouton ouverture de porte (switch/lock HA)
- Historique des visites (24h)

### Pro (~6,99€ achat unique)
- Reconnaissance faciale locale (moteur TensorFlow Lite)
- Notification personnalisée : "Juliette est à la porte"
- Ouverture automatique pour personnes de confiance
- Historique illimité avec photos et noms
- Interphone bidirectionnel (audio temps réel via WebRTC)
- Multi-portes / multi-caméras
- Alertes inconnus renforcées
- Synchronisation base de visages avec WallDock Pro

---

## Architecture technique

### Application mobile : Flutter
- Un seul code source pour Android et iOS
- Dart + Flutter 3.x
- Support Android 8+ / iOS 14+

### Connexion à Home Assistant
- **WebSocket API** HA (port 8123) pour événements temps réel
- **camera_proxy** API pour le flux vidéo (Bearer token)
- **REST API** HA pour états et services (ouvrir porte, etc.)
- Compatible Nabu Casa, Cloudflare Tunnel, accès local

### Notifications push
- **Firebase Cloud Messaging (FCM)** pour Android
- **Apple Push Notification Service (APNs)** pour iOS
- Déclenchées par une automation HA → webhook → serveur relais léger

### Reconnaissance faciale (Pro)
- Moteur : **TensorFlow Lite** embarqué dans l'appli (100% local)
- Modèle : MobileFaceNet (léger, précis, open source)
- Base de visages stockée localement sur le téléphone
- Synchronisation optionnelle avec WallDock Pro via HA

### Interphone audio (Pro)
- **WebRTC** peer-to-peer via HA comme signaling server
- Faible latence (<200ms)
- Chiffrement bout en bout

---

## Structure du repo

```
doorwatch/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                  # MaterialApp + thème
│   │   └── routes.dart
│   ├── core/
│   │   ├── ha_client.dart            # WebSocket + REST HA
│   │   ├── ha_camera.dart            # Flux vidéo camera_proxy
│   │   ├── notifications.dart        # FCM + APNs
│   │   └── prefs.dart                # SharedPreferences
│   ├── features/
│   │   ├── setup/                    # Écran de configuration HA
│   │   ├── doorbell/                 # Écran principal sonnette
│   │   ├── history/                  # Historique visites
│   │   ├── face_recognition/         # Pro : reconnaissance faciale
│   │   └── intercom/                 # Pro : audio WebRTC
│   └── widgets/
│       ├── camera_view.dart          # Widget flux vidéo
│       ├── door_button.dart          # Bouton ouverture porte
│       └── visitor_card.dart         # Carte visiteur identifié
├── android/
├── ios/
├── ha_integration/                   # Automation HA + blueprint
│   ├── blueprint.yaml
│   └── README.md
├── pubspec.yaml
├── README.md
└── LICENSE                           # GPL v3
```

---

## Modèle économique

- **Gratuit** : fonctions de base, open source sur GitHub
- **Pro** : achat unique ~6,99€ sur Gumroad (même plateforme que WallDock Pro)
- Clé de licence validée en local (même système que WallDock)
- Pas d'abonnement, pas de serveur payant à maintenir

---

## Roadmap

### v0.1 — MVP
- [ ] Connexion HA (URL + token)
- [ ] Réception événement sonnette (binary_sensor)
- [ ] Affichage flux caméra
- [ ] Bouton ouverture porte

### v0.2 — Notifications
- [ ] Push notification FCM/APNs
- [ ] Serveur webhook léger (ou automation HA native)

### v0.3 — Pro : reconnaissance faciale
- [ ] Intégration TensorFlow Lite
- [ ] Gestion base de visages
- [ ] Notifications personnalisées

### v0.4 — Pro : interphone
- [ ] WebRTC audio bidirectionnel
- [ ] Intégration HA comme signaling

### v1.0 — Release publique
- [ ] Page Gumroad Pro
- [ ] Blueprint HA publié sur HACS
