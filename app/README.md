# ToolLedger

Industrial asset inventory, QR lending, approvals, finance and audit workspace.
Flutter (Web / Desktop / Android) · Riverpod · GoRouter · Spring Boot-ready.

## First run (verify everything)

```bash
flutter pub get
dart format .          # normalises formatting of the hardening changes
flutter analyze
flutter test           # existing suites + test/hardening_test.dart
flutter run -d chrome  # demo mode: mock data, demo logins on the sign-in screen
```

## Build modes

| Flag | Meaning |
|---|---|
| *(none)* / `DATA_SOURCE=mock` | Demo data and demo authenticator; demo credentials and "simulate expiry" are shown. |
| `DATA_SOURCE=live` | Authentication goes to the Spring Boot API; all demo affordances are hidden. |
| `API_BASE_URL=https://…` | Backend origin. HTTPS is enforced (HTTP only for localhost). |

> **Live status:** the live switch currently covers **authentication**
> (`SpringBootAuthRepository`). Inventory, loans, approvals, finance and admin
> still use `MockWorkspaceRepository`. Implement `WorkspaceRepository`
> (`lib/shared/data/workspace_repository.dart`) against your API and select it in
> `workspaceRepositoryProvider` before going to production.

## Backend contract (auth)

`POST /api/v1/auth/login` → `200 {id, employeeId, username, displayName, role: MANAGER|LENDER, department}`;
`401` bad credentials, `403` disabled, `429` rate limited. Also `/logout`, `/password-reset`, `/password`.
Session = HttpOnly/Secure/SameSite cookie; CORS must allow the web origin with credentials;
send CSRF via `X-XSRF-TOKEN` (wire `ApiClient.csrfToken`). Unknown roles are rejected client-side.

## Session behaviour

* Router re-evaluates on every session change (sign-in/out, expiry).
* 15-minute client idle timeout (`sessionIdleTimeoutProvider`), reset by pointer activity.
* Any HTTP 401 from `ApiClient` expires the session and routes to `/session-expired`.
* The backend must still enforce authorization and session lifetime.

## Release

**Web (Docker + hardened nginx, CSP, SPA fallback):**
```bash
docker build --build-arg API_BASE_URL=https://api.example.com -t toolledger-web .
docker run -p 8080:8080 toolledger-web
```
Edit `connect-src` in `deploy/nginx.conf` to your API origin. Serve behind TLS.

**Android (signed AAB):**
1. `keytool -genkey -v -keystore toolledger-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias toolledger`
2. Copy `android/key.properties.example` → `android/key.properties`, fill in (git-ignored).
3. Set your own `applicationId` / package in `android/app/build.gradle.kts` and `MainActivity.kt`.
4. `flutter build appbundle --release --dart-define=DATA_SOURCE=live --dart-define=API_BASE_URL=https://api.example.com`

Without `key.properties` the release build falls back to the debug key and prints a warning — never publish that build.
Release builds enable R8 minification; smoke-test the QR scanner on a physical device.

**CI:** `.github/workflows/ci.yml` runs analyze, test, web build and (optionally signed) AAB.

## Pre-production checklist

- [ ] `flutter analyze` and `flutter test` green on your machine
- [ ] Live `WorkspaceRepository` implemented and contract-tested
- [ ] Backend: RBAC on every endpoint, CSRF, rate limiting, MFA for managers, server-side approval rules
- [ ] Own application ID, release keystore, store listing assets
- [ ] CSP `connect-src` set to the real API origin
