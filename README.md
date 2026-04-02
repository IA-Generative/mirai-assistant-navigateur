# MirAI Browser v1.2.1

Extension Chrome/Firefox pour capturer et transcrire automatiquement les reunions en ligne.

## Fonctionnalites

- **Enregistrement de reunions** — Webconf, Visio, COMU, Webinaire, Webex, Google Meet, Teams
- **Detection automatique** — detecte la plateforme et l'identifiant de reunion depuis l'URL
- **Overlay flottant** — bouton REC superpose sur les pages de visio, draggable, auto-minimize
- **Authentification SSO** — PKCE Keycloak avec login dans un onglet normal (gestionnaire de mots de passe compatible)
- **Reconnexion automatique** — refresh token silencieux, lien "Se reconnecter" en cas d'expiration
- **Sync avec le serveur** — detecte les enregistrements en cours au chargement de la page
- **Badge REC** — indicateur rouge sur l'icone de l'extension quand un enregistrement est actif
- **Raccourcis MirAI** — acces rapide a Chat, Resume, Compte rendu, Comu, Aide
- **Multi-profils** — configuration dev / int / prod centralisee dans `src/dm/config.json`
- **Device Management** — enrollment, relay, telemetrie OTLP, auto-update

## Structure

```
manifest.json                 # Chrome MV3 + Firefox ESR
package.json / jest.config.js
src/
  popup.html / popup.js / popup.css   # Interface popup
  options.html / options.js           # Page options
  overlay.js                          # Bouton REC flottant (content script)
  callback.html / callback.js        # Page retour SSO
  auth.js                            # PKCE + enrollment DM
  background.js                      # Service worker
  recording.js                       # API meetings (start/stop/sync)
  compat.js                          # Bridge Chrome/Firefox
  crypto.js                          # Chiffrement AES-GCM
  dm/
    config.json                      # Config multi-profils
    manifest.json                    # Metadata DM
    bootstrap.js                     # Client config DM
    telemetry.js                     # Telemetrie OTLP
icons/                               # Icones extension
tests/                               # 103 tests Jest
scripts/
  build.sh                           # Build + packaging CRX/XPI
  deploy-release.sh                  # Deploy vers le DM
  register-dm.sh                     # Enregistrement du plugin dans le DM
```

## Installation dev

```bash
# Installer les dependances (tests)
npm install

# Charger dans Chrome
# chrome://extensions → Mode developpeur → Charger l'extension non empaquetee → dossier racine

# Charger dans Firefox ESR
# about:debugging#/runtime/this-firefox → Charger un module temporaire → manifest.json
```

## Tests

```bash
npm test              # 103 tests
npm run test:watch    # mode watch
npm run test:coverage # couverture
```

## Build

```bash
scripts/build.sh              # dist/extension/ (non empaquete)
scripts/build.sh --crx        # + dist/mirai-browser-1.2.1.crx (Chrome signe)
scripts/build.sh --xpi        # + dist/mirai-browser-1.2.1.xpi (Firefox)
scripts/build.sh --crx --xpi  # les deux
```

Le `.crx` est signe avec `private/mirai-browser-key.pem` (non versionne).

## Configuration

Modifier `src/dm/config.json` :

```json
{
  "activeProfile": "prod",   // dev | int | prod
  "slug": "mirai-browser"
}
```

| Profil | bootstrap_url | Keycloak |
|--------|--------------|----------|
| dev | `http://localhost:3001` | `localhost:8082/realms/openwebui` |
| int | `https://bootstrap.fake-domain.name` | placeholders DM |
| prod | `https://bootstrap.fake-domain.name` | `sso.mirai.interieur.gouv.fr/realms/mirai` |

## Plateformes supportees

| Plateforme | URL | Mot de passe |
|-----------|-----|-------------|
| Webconf | `webconf.numerique.gouv.fr` | Non |
| Visio | `visio.numerique.gouv.fr` | Non |
| COMU | `webconf.comu.gouv.fr` | Oui (6 chiffres) |
| Webinaire | `webinaire.numerique.gouv.fr` | Non |
| Webex | `*.webex.com` | Oui |
| Google Meet | `meet.google.com` | Non |
| Teams | `teams.microsoft.com` | Oui |

## Licence

MPL-2.0
