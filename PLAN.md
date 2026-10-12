# Coolify Mobile — Implementation Plan

A native mobile client for managing a self-hosted Coolify v4 instance. The user enters the **instance URL + API token** once. After that, the only gate is **device security** (biometrics / device PIN) every time the app is opened, resumed from background, or woken from sleep. No browser needed.

## 1. Decisions

| Question | Recommendation | Why |
|---|---|---|
| Flutter/Dart or Go? | **Flutter + Dart** | Go has no mature mobile UI toolkit (Fyne/Gio are weak for a large CRUD/log/terminal-style app, poor biometric/secure-storage plugins). Go would only make sense as a backend proxy, which we don't want: the token must stay on-device and talk straight to Coolify. |
| State mgmt | Riverpod (+ `riverpod_generator`) | Testable, good for async/polling/caching |
| HTTP | `dio` + interceptors | Auth header, retry, timeouts, cert handling |
| API client | Generated from Coolify's `openapi.json` (`openapi-generator` dart-dio or `swagger_parser`) + thin hand-written repository layer | Coolify ships an OpenAPI spec (in its repo / `/docs/api`); avoids hand-typing ~150 endpoints and tracks version changes |
| Models | `freezed` + `json_serializable` | |
| Navigation | `go_router` | |
| Token storage | `flutter_secure_storage` (Android Keystore / iOS Keychain) | Never SharedPreferences, never logged |
| Device lock | `local_auth` (biometric + device credential fallback) | See §3 |
| Local cache | `drift` (SQLite) or `hive` — read-only cache of lists for fast cold start/offline view | Optional, phase 2 |
| Push/alerts | Phase 3: optional polling via WorkManager/BGTaskScheduler; real push needs a server component (out of scope) | |

## 2. Coolify API facts to build against

- Base: `https://<site>/api/v1`, header `Authorization: Bearer <token>`. API must be enabled in Coolify *Settings → Advanced → API Access*.
- Token abilities: `read`, `read:sensitive`, `write`, `deploy`, `root`. App must **detect abilities** and hide/disable actions the token can't do (and explain why). `read:sensitive` gates secret values (env values, DB passwords); without it Coolify masks them.
- Team-scoped: a token only sees its team's resources.
- Main resource groups (verify exact paths against the instance's own openapi + `/version` — they vary by Coolify version):
  - **System**: `/version`, `/healthcheck` (+ `/enable`, `/disable` API), `/teams`, `/teams/current`, `/teams/{id}/members`
  - **Servers**: list/get/create/update/delete, `/servers/{uuid}/resources`, `/domains`, `/validate`
  - **Projects & environments**: `/projects`, `/projects/{uuid}/{env}`, create/delete environments
  - **Applications**: list/get/update/delete; create from public repo, GitHub App, deploy key, Dockerfile, Docker image, Docker Compose; `start|stop|restart`; `logs`; `envs` (CRUD, bulk); `storages`; `scheduled-tasks`; previews
  - **Deployments**: `/deploy?uuid=|tag=&force=`, `/deployments`, `/deployments/{uuid}` (incl. logs), cancel, per-app deployment list
  - **Databases**: list/get/create per engine (postgres, mysql, mariadb, mongodb, redis, keydb, dragonfly, clickhouse), start/stop/restart, **backups** (schedules, executions, restore info), envs, storages
  - **Services** (one-click/compose): CRUD, start/stop/restart, envs, storages, scheduled tasks
  - **Resources**: `/resources` (unified list)
  - **Security**: private keys CRUD (`/security/keys`), cloud provider tokens (Hetzner etc.), GitHub Apps
  - **Misc**: tags, destinations/networks, teams
- Gaps to expect: no live-streaming websocket on the public API → logs are **polled** (`?lines=N`); terminal/exec is not in the API (explicitly out of scope, can note as "open in web" later if ever wanted). Rate limiting exists — use backoff.

## 3. Security model (the core requirement)

Threat model: lost/unlocked-by-someone-else phone, shoulder-surfing, screenshots, backups. Not in scope: rooted-device attacker.

1. **Token + URL** saved only in secure storage, encrypted by Keystore/Keychain with `accessibleWhenUnlockedThisDeviceOnly` (iOS) / `setUserAuthenticationRequired` key (Android) so the secret itself is bound to device auth, not just the app gate.
2. **App lock gate**: a `LockController` listens to `WidgetsBindingObserver`:
   - cold start → locked
   - `paused/inactive/hidden` → record timestamp, show a **privacy cover** immediately (hides app-switcher snapshot)
   - `resumed` → if elapsed ≥ configured grace period (default **0s / immediate**, options: immediately, 30s, 1m, 5m) → locked
   - Also lock on device sleep / screen-off (Android `ACTION_SCREEN_OFF` via a small platform channel; iOS covered by lifecycle).
3. **Unlock** = `local_auth.authenticate(biometricOnly: false)` → biometrics with automatic fallback to device PIN/pattern/passcode. Because device security is the only gate, if the device has **no lock screen set**, the app refuses to store a token and shows setup instructions.
4. While locked: no API calls, no providers hydrated with secrets, token not held in memory (load from secure storage only after successful auth; drop on lock).
5. Failure handling: lockout/too many attempts → show "use device credential"; cancel → remain locked, retry button. Optional "wipe credentials after N consecutive failures" setting.
6. Hardening: `FLAG_SECURE` (Android) to block screenshots/recents thumbnails; iOS blur overlay; disable Android auto-backup of app data; no analytics/crash reports containing URLs/tokens; log redaction in dio interceptor; obscure sensitive values (env vars, DB passwords) behind tap-to-reveal **plus a fresh auth prompt** for reveal/copy and for destructive actions.
7. Network: HTTPS required by default; plain HTTP only after explicit warning toggle. Support self-signed/custom CA via **certificate pinning on first use** (store fingerprint, warn on change) — common for self-hosted setups.
8. Token hygiene: on connect, call `/teams/current` + `/version` to validate and show abilities; recommend least-privilege token in onboarding; "Disconnect / forget instance" wipes everything.

## 4. Feature scope (everything the web UI does, via API)

Mapped to bottom-nav tabs: **Dashboard · Resources · Deployments · Servers · More**

- **Dashboard**: instance health, server status, unhealthy resources, running/failed deploys, quick actions.
- **Resources**: unified list with search/filter (type, project, env, status, tag); detail screens for Application / Database / Service with start·stop·restart·redeploy, status chips, env var editor (bulk, secret masking), storages, domains/FQDN, build settings (build pack, ports, health check, resource limits), scheduled tasks + executions, previews, webhooks info, logs viewer (tail/refresh/search/share).
- **Create flows**: wizard per source type (public repo, GitHub App with repo/branch pickers, deploy key, Dockerfile, image, compose, database engine, one-click service) → choose server → project/environment.
- **Deployments**: global + per-app history, detail with log (auto-poll while in progress), cancel, redeploy, force rebuild.
- **Databases**: backups schedules, executions, trigger/restore info, connection strings (gated by `read:sensitive` + re-auth).
- **Servers**: add/edit/delete, validate, resources on server, domains, proxy status, private key selection.
- **More**: projects/environments, private keys, GitHub Apps, cloud tokens, tags, destinations, team + members, instance version/updates, settings (lock timeout, theme, cert pins), multi-instance switcher.
- **Safety**: confirm dialogs (type-name-to-confirm for delete/stop prod), optimistic UI with rollback, all destructive actions re-auth.

## 5. Architecture

```
lib/
  core/        # http (dio), errors, result types, redaction logger, theme, router
  security/    # lock controller, auth service (local_auth), secure store, cert pinning
  data/
    api/       # generated openapi client
    repos/     # ApplicationRepo, DatabaseRepo, ServerRepo, ... (map errors, ability checks)
    models/    # freezed domain models
  features/    # onboarding, dashboard, resources, deployments, servers, settings, ...
  shared/      # widgets (status chip, log viewer, env editor, confirm dialog)
platform: android/ (screen-off receiver, FLAG_SECURE), ios/ (privacy cover)
test/ integration_test/
```

- Repository layer normalizes API quirks (version differences, nullable fields, 4xx messages) and exposes capability checks (`canWrite`, `canDeploy`, `canReadSensitive`).
- Polling manager: foreground-only, adaptive interval (2s for active deploy logs, 15–30s for lists), paused when app locked/backgrounded.
- Version compatibility: read `/version` → feature flags; unknown endpoints degrade gracefully (404 → hide feature).

## 6. Phases

| Phase | Deliverable | Notes |
|---|---|---|
| **0 – Setup (1–2d)** | Flutter project, lints, CI (analyze/test/build APK), fetch & pin `openapi.json`, generate client | Android first, iOS compiled in CI |
| **1 – Secure shell (3–4d)** | Onboarding (URL+token, validate), secure storage, **lock controller + device auth + privacy cover**, settings for grace period | Security is built first, not bolted on |
| **2 – Read-only core (4–5d)** | Dashboard, resource list/detail, servers, deployments, logs viewer | Works with a `read` token |
| **3 – Operations (4–5d)** | start/stop/restart/deploy/cancel, env var editor, re-auth for sensitive actions | `write`/`deploy` tokens |
| **4 – Create & configure (6–8d)** | Creation wizards, app settings, databases + backups, services, storages, scheduled tasks | Largest chunk |
| **5 – Admin (3–4d)** | Servers CRUD/validate, keys, GitHub Apps, cloud tokens, teams, projects/envs | |
| **6 – Polish (3–4d)** | Multi-instance, cert pinning UX, offline cache, dark mode, tablet layout, accessibility, background failure notifications (polling) | |
| **7 – Release** | Store listings, privacy policy, signed builds, Play/TestFlight | |

Total ≈ 5–6 weeks for one developer.

## 7. Testing & quality

- Unit: repositories with mocked dio; lock controller state machine (lifecycle × grace period × auth result) — this is the highest-value test.
- Contract: run against a disposable Coolify (Docker) in CI using a seeded token; snapshot-compare `openapi.json` between versions.
- Widget/golden tests for env editor, log viewer, confirm dialogs.
- Manual security checklist: app-switcher snapshot blank, screenshots blocked, token absent from logs/backups, unlock required after sleep, no-lockscreen device blocked.

## 8. Risks / open questions

1. **API coverage gaps** – some web-UI features (terminal, some settings, proxy config, instance settings updates) may have no endpoint. Mitigation: audit openapi in Phase 0 and publish a coverage matrix.
2. **Version drift** – Coolify v4 is beta-moving; generated client + feature flags needed.
3. **Self-signed certs / LAN-only instances** – VPN/Tailscale users; pinning UX required.
4. **Token power** – a `root` token on a phone is high impact; we encourage scoped tokens and re-auth on destructive actions.
5. **iOS/Android parity** for screen-off detection and secure flags.
6. **Store review** – app that stores user-supplied credentials; needs clear privacy policy (all data stays on-device).

## 9. Questions for you before coding

1. Android only first, or iOS as well?
2. Single Coolify instance or multi-instance from day one?
3. Default lock grace period: always immediate, or user-configurable (proposed)?
4. Must create/delete operations ship in v1, or read + deploy/restart first (Phases 1–3) as MVP?
5. Is your Coolify instance on a public domain with valid TLS, or LAN/self-signed?
