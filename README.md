[FRONTEND_BACKEND_BLUEPRINT.md](https://github.com/user-attachments/files/34317172/FRONTEND_BACKEND_BLUEPRINT.md)
# ToolLedger: Flutter → Spring Boot + PostgreSQL Integration Blueprint

**Prepared from:** `Tool_Ledger.zip` (`Tool_Ledger/app/`)
**Date:** 2026-11-02
**Status:** Design / learning roadmap — no production backend yet

## 1. What exists in the uploaded frontend

- Flutter Web / Android with `flutter_riverpod`, `go_router`, `mobile_scanner`, `qr_flutter`, `excel`, `image_picker`, `http` and Material theming.
- `lib/features/auth/data/spring_boot_auth_repository.dart` already calls `/api/v1/auth/login`, `/logout`, `/password-reset`, and `/password` when built with `DATA_SOURCE=live`.
- **Only authentication switches to live mode.** `workspaceRepositoryProvider` in `lib/shared/data/workspace_controller.dart` always chooses `MockWorkspaceRepository`, even if `DATA_SOURCE=live`.
- `lib/shared/data/workspace_repository.dart` defines the complete write-contract for checkout, handover, approvals, returns, damage, asset registration, photo updates, settings, account administration.
- `lib/shared/models/workspace_data.dart` joins assets, loans, approvals, damage records, disposals, audit events, users and settings into one in-memory model.
- `lib/features/reports/data/excel_export_service.dart` creates client-side .xlsx files from the in-memory dataset. This is a demo feature, **not** sufficient server-controlled reporting for an enterprise deployment.
- QR payloads are normalized opaque IDs (see `QrAssetReference`).

## 2. Rules to settle before writing the database migrations

1. Confirm the threshold for expensive equipment. Demo defaults to PKR 250,000 (`AppSettings`), which must not silently become company policy.
2. Approvals must be based on a controlled metric (replacement value, with explicit restricted categories); NBV is not a suitable proxy for lending risk.
3. Does a high-value request reserve an asset while pending? Recommended: reservation with expiration to avoid multiple approvals.
4. Is the initial purchase row `Qty=2` split into two physical assets? **Yes**: unique physical asset ID for each; keep one purchase line for historical cost and quantity.
5. How are duplicate `Type` and `Dep. Till Date` columns interpreted? Preserve both as legacy fields pending finance sign-off.
6. Confirm depreciation policy, useful life and whether GST belongs in depreciable cost. The original register contains suspicious legacy figures; import without silently recalculating.
7. Confirm manager recovery protocol and deployment/network rules with company IT.

## 3. Recommended PostgreSQL model

| Table | Purpose | Important relationships / constraints |
|---|---|---|
| `departments` | Organization / borrowing departments | Unique code |
| `app_users` | Manager/lender identities | Unique username and employee ID; role MANAGER/LENDER; password hash only |
| `app_settings` | Approval thresholds, defaults, flags | Change audit |
| `purchase_lines` | Original register purchase rows | Source row ID, qty, unit/ext price, historical GST, total, vendor, PO, bill, foreign value |
| `tool_assets` | **One row per physical tool** | Unique asset ID/QR, link to purchase line, status, equipment metadata, location, current condition, optimistic version |
| `tool_photos` | Tool photos / damage evidence | Private object key + owner, purpose, MIME, size |
| `loans` | Tool issue/return history | Asset FK, borrower employee ID, issue/due/return times, lender user FK, approval FK |
| `approval_requests` | High-value and inventory-change decisions | Type, status, requester, manager, request payload, decision note, timestamps, expiry |
| `damage_events` | Damage, quarantine and repair history | FK to tool; costs and valuation snapshot, evidence references |
| `disposal_records` | Final retirement history | FK to tool, approved by, proceeds, asset valuation snapshot |
| `audit_events` | Append-only activity/security history | Actor identity, event kind, target, timestamp, before/after as permitted |
| `export_events` | Export audit | User, filters, dataset, count, timestamp |

**Database constraints:** forbid multiple active loans for a single tool (partial unique index or equivalent transaction-backed constraint). Recheck tool status and approval under a transaction before handover. Store financial amounts as PostgreSQL `numeric` / Java `BigDecimal`, never binary float.

**Archive approach:** keep `tool_assets` forever and use `damage_events` / `disposal_records` as historical records or separate views; never move tools out of the authoritative database by deleting them.

## 4. API mapping to current Flutter code

All endpoints below live under `/api/v1`. Only authentication endpoint paths are already assumed by the frontend; other paths are the proposed contract to implement.

| Flutter method/screen | HTTP | Endpoint | Access |
|---|---|---|---|
| `SpringBootAuthRepository.signIn` | POST | `/auth/login` | Public + CSRF protection |
| `SpringBootAuthRepository.signOut` | POST | `/auth/logout` | Authenticated |
| `requestPasswordReset` | POST | `/auth/password-reset` | Public, rate-limited, uniform response |
| `changePassword` | POST | `/auth/password` | Authenticated + reauthentication |
| Session restore (new) | GET | `/auth/me` | Authenticated |
| CSRF bootstrap (new) | GET | `/auth/csrf` | Public/authenticated depending on design |
| `WorkspaceRepository.load` | GET | `/dashboard/summary`, `/assets`, `/loans`, `/approvals`, etc. | **Role-filtered**; no full financial blob to lender |
| Inventory/QR | GET | `/assets/{assetId}` | Authenticated; role-specific DTO |
| `registerAsset` | POST | `/asset-registration-requests` | Lender or manager, subject to approval |
| `updatePhoto` | POST multipart | `/assets/{assetId}/photos` | Authorized |
| `requestCheckout` | POST | `/checkouts` | Lender/manager; server decides if approval needed |
| `completeHandover` | POST | `/approvals/{id}/handover` | Authorized lender; approved + available + unexpired |
| `decideApproval` | POST | `/approvals/{id}/decision` | MANAGER only |
| `returnAsset` | POST | `/assets/{assetId}/return` | Authorized lender/manager |
| `reportDamage` | POST | `/assets/{assetId}/damage-reports` | Authorized lender/manager |
| `updateSettings` | PUT | `/settings/business-rules` | MANAGER only |
| `updateNotificationPreferences` | PUT | `/users/me/preferences` | Authenticated |
| `createLender` | POST | `/users/lenders` | MANAGER only |
| `setUserActive` | PATCH | `/users/{id}/status` | MANAGER only |
| `initiatePasswordReset` | POST | `/users/{id}/password-reset` | MANAGER only |
| `revokeSessions` | POST | `/users/{id}/revoke-sessions` | MANAGER only |
| Reports/export | POST | `/reports/exports` | Server-authorized data scope |

### Proposed checkout example

`POST /api/v1/checkouts`

```json
{
  "assetId": "TL-1001",
  "borrowerName": "Sample Mechanic",
  "borrowerEmployeeId": "EMP-042",
  "department": "Maintenance",
  "workOrder": "GEN-2026-117",
  "purpose": "Generator inspection",
  "dueDate": "2026-11-05T12:00:00+05:00"
}
```

If eligible for direct issue: `201` with `{"result":"CHECKED_OUT","loanId":"..."}`.
If authorization required: `202` with `{"result":"APPROVAL_REQUIRED","approvalId":"..."}`.
If unavailable/invalid: `409` or `422` with a stable error code (e.g. `ASSET_NOT_AVAILABLE`).

The backend gets the actual lender identity from the authenticated session, **never** from an `actor` object supplied by Flutter.

### Login response expected by current Flutter

`POST /api/v1/auth/login` → on success:

```json
{
  "id": "uuid-string",
  "employeeId": "OES-MGR-01",
  "username": "manager@example.invalid",
  "displayName": "Example Manager",
  "role": "MANAGER",
  "department": "Product Support"
}
```

Response must also establish secure session state. Missing/invalid role is explicitly rejected by Flutter.

## 5. Required Flutter changes (small in number, important in effect)

1. Implement `SpringBootWorkspaceRepository` and select it when `AppConfig.useLiveBackend` is true in `workspaceRepositoryProvider`.
2. Add `fromJson` parsing (or separate API DTOs) for `ToolAsset`, `LoanRecord`, `ApprovalRecord`, `WorkspaceData`, etc. Models currently expose `toJson` for some types but lack corresponding parsers.
3. **Data minimization:** avoid sending the all-inclusive `WorkspaceData` (prices, depreciation, all users, audit) to lenders. Introduce operational vs managerial response DTOs and restrict every API server-side.
4. Add `/auth/me` and startup restoration so a valid server session survives a page refresh; currently `SessionController.build()` always starts unauthenticated.
5. Wire actual CSRF acquisition into `ApiClient.csrfToken` and POST/PUT/PATCH/DELETE. The current callback is declared but not supplied by `apiClientProvider`. Follow the Spring Security SPA CSRF integration guidance; refreshing the token after login/logout matters.
6. BrowserClient has `withCredentials=true`, which is a good start. Native `http.Client()` does not automatically provide an equivalent durable cookie jar; choose and implement Android session handling or an explicitly designed alternative.
7. Add multipart upload, authenticated file downloads, GET query/pagination support, and PATCH methods to the client.
8. Move *production* financial computations and downloadable sensitive Excel datasets to authorized backend endpoints; the existing client export remains suitable for mock demonstrations.
9. `ToolAsset` includes numeric `double` money; server uses `BigDecimal` and sends canonical decimal strings or clearly defined JSON amounts, carefully parsed/formatted on Flutter.
10. Add integration tests for `401`, `403`, `409`, duplicate checkout races, expired approvals, file limits and export authorization.

## 6. Security policy

- Roles: exactly MANAGER and LENDER; borrowers are recorded identities, not application accounts.
- No public registration. Manager provisions lender accounts; designated IT process recovers manager access.
- Password hashes with approved adaptive encoder (Argon2id or bcrypt); unique users, rate limits, account disable/revocation, MFA for manager-sensitive actions.
- Browser: HTTPS + secure HttpOnly session cookie + SameSite and CSRF defense. Configure approved origins (not wildcard with credentials). Restrict admin APIs server-side.
- Android: authenticate/session management deliberately, never assume `http.Client()` behaves like the browser cookie jar.
- Photos validated and stored privately; downloads authorized.
- Audit logs append-only, with retention policy; export logs and production database backups tested for restore.
- Never expose a full database dump as the lender's workspace response.

## 7. Training and construction sequence

| Lesson / Milestone | Topic | Measurable result |
|---|---|---|
| 1 | Java 21, Maven, Spring Boot API, HTTP | `GET /api/v1/health` returns JSON |
| 2 | PostgreSQL, Flyway migration, JPA | Persist individual tool assets |
| 3 | DTOs, validation, exceptions, pagination | Flutter inventory reads **real** data |
| 4 | Relationships and legacy import | Purchase lines + unique individual tools |
| 5 | Spring Security, sessions, CSRF, manager/lender roles | Flutter live login and `/auth/me` work |
| 6 | Loans and transaction locks | Safe direct checkout and return |
| 7 | Approval requests | High-value checkout requires authorized manager |
| 8 | Damage, repair and disposal | Historical archive linked to assets |
| 9 | `BigDecimal` depreciation | Validated valuations and finance views |
| 10 | Photos + Apache POI | Private photos, authorized XLSX exports |
| 11 | Integration, load and security tests | No double loan, no lender finance leak |
| 12 | End-to-end Flutter and workplace pilot | Role-separated live operation, backup restore test |

## 8. First hands-on tasks

1. Keep the original ZIP unchanged. Open `Tool_Ledger/app/` in Flutter IDE and verify `flutter analyze` / `flutter test` locally.
2. Initialize a **separate** Spring Boot Maven project `toolledger-api` alongside `app/` (not inside Flutter's `lib/`).
3. Use Java 21, Spring Web MVC, Validation, Data JPA, PostgreSQL Driver, Flyway, Spring Security, Actuator, and Test dependencies. Begin with a local-only development configuration.
4. Implement `GET /api/v1/health` and a minimal migration-backed asset table.
5. Write integration tests first for asset creation and retrieval, then wire the inventory frontend to a narrow asset DTO.
6. Add authentication **before exposing data to other devices or deploying**.

### Recommended folder layout

```text
ToolLedger/
  app/                 # Existing Flutter code
  api/                 # Spring Boot application
    pom.xml
    src/main/java/com/toolledger/
      auth/ inventory/ loans/ approvals/ finance/ reports/
      common/ security/ config/
    src/main/resources/db/migration/
  docs/
    FRONTEND_BACKEND_BLUEPRINT.md
```

**Note:** This blueprint was derived by static source inspection. No Flutter build, backend build, or full integration test was performed during this analysis.
