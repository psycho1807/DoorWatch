# Intégration Home Assistant — DoorWatch

## Blueprint notifications push

### Installation

1. Dans Home Assistant, allez dans **Paramètres → Automatisations → Blueprints**
2. Cliquez sur **Importer un blueprint**
3. Collez l'URL de ce fichier ou importez `blueprint.yaml` directement

### Configuration manuelle

Ajoutez dans votre `configuration.yaml` :

```yaml
# Optionnel : script pour ouvrir la porte depuis la notification
script:
  doorwatch_open_door:
    alias: "DoorWatch — Ouvrir la porte"
    sequence:
      - service: lock.unlock
        target:
          entity_id: lock.votre_serrure
```

### Répondre aux actions de notification

Ajoutez une automation pour gérer les boutons de notification :

```yaml
automation:
  - alias: "DoorWatch — Action notification"
    trigger:
      - platform: event
        event_type: mobile_app_notification_action
        event_data:
          action: OPEN_DOOR
    action:
      - service: lock.unlock
        target:
          entity_id: lock.votre_serrure
```

## Entités recommandées

| Rôle | Domaine HA | Exemple |
|------|-----------|---------|
| Sonnette | `binary_sensor` | `binary_sensor.sonnette_entree` |
| Caméra | `camera` | `camera.entree` |
| Serrure | `lock` | `lock.porte_entree` |
| Lumière | `light` | `light.entree` |

## Token longue durée

1. Profil HA → **Tokens d'accès longue durée**
2. **Créer un token** → nommez-le `DoorWatch`
3. Copiez le token dans l'app DoorWatch
