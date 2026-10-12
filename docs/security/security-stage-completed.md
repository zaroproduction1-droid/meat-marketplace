# CutLink security stage — installation and test guide

Completed 11 October 2026 against the existing development Supabase project. This package contains complete replacement/new files, with no extra enclosing directory, no real environment values, scheduler token, private file bytes or database rows.

## What is already done in Supabase

- Applied migration `20261011033543_finish_cutlink_security` to project `wqdfimgaqqnhptxyarvm`.
- Installed the keyed supplier/butcher payment RPCs required by the existing payment screens, selected write quotas, finite amount/input bounds, scoped helper authorization, active-business checks, private access-change journal, and VIP document ownership/path/metadata validation.
- Deployed the existing `support-retention-cleanup` service as version 2, with bounded request time/size, trusted-origin requests, unsafe/empty path rejection and retry-safe deletion acknowledgement. Preserved its existing custom token authentication and `15 * * * *` schedule. The token was not read, rotated or packaged.
- Verified all 77 public tables still have RLS. Before/after fingerprints match for eight business/order/invoice/payment datasets. Supplier $349.99 and butcher $199.99 prices remain GST inclusive; founding offers remain open.

You do not need to open Supabase or manually run this migration for these changes. The SQL and Edge source are supplied to keep your project files aligned with the installed version.

## Copy destination and obsolete file removal

Back up matching local files. Extract this ZIP directly into:

`C:\Projects\meat-marketplace`

Choose to replace matching files. The ZIP's `lib/`, `supabase/`, `test/` and `docs/` must merge into your existing folders; `pubspec.yaml` and `pubspec.lock` belong at the project root, beside the existing `lib/` folder. Do not place files under a new enclosing `CutLink/` folder and do not place another `main.dart` at the root.

If the earlier prepared security package left this file in your project, **delete it**:

`supabase/migrations/20261010034341_cutlink_security_hardening.sql`

Its replacement is:

`supabase/migrations/20261011033543_finish_cutlink_security.sql`

The old migration was not applied; the new file matches the hosted migration history. Keeping and later applying both can overwrite the reviewed functions with the older draft. No Dart file/route is deleted or renamed. Required legacy payment RPC signatures remain compatible, with the documented limitation that direct unkeyed calls do not provide replay protection.

**Do not run a blanket `supabase db push` or reapply the supplied SQL to this project.** The supplied ZIP does not contain the entire historical hosted migration set. The migration has original-version hash guards and is deliberately not a repeat-install script.

## Files changed and why

| Complete file | Purpose |
|---|---|
| `lib/shared/security/payment_retry_queue.dart` | New persistent retry queue: canonical payload hashes, per-user namespace, random keys, identical in-flight coalescing, fail-closed storage, bounds and timeout retention. |
| `lib/shared/security/retry_safe_payments.dart` | Connects the existing payment screens to preferences and the new queue without changing their RPC call sites. |
| `lib/features/legal/presentation/legal_info_page.dart` | Discloses retry storage and explains how clearing site data affects uncertain payments. |
| `pubspec.yaml` | Declares existing locked crypto/preferences packages directly; preserves earlier approved unused-icon removal. |
| `pubspec.lock` | Resolved lockfile; existing remaining versions preserved. |
| `supabase/migrations/20261011033543_finish_cutlink_security.sql` | Complete installed security migration, preserving current billing/trade logic and data. |
| `supabase/functions/support-retention-cleanup/index.ts` | Existing worker entry point delegates to the tested handler. |
| `supabase/functions/support-retention-cleanup/cleanup_handler.ts` | Hardened handler with injectable dependencies for isolated verification. |
| `test/payment_retry_queue_check.dart` | 20 meaningful standalone retry checks with synthetic storage/RPCs. |
| `test/security/cleanup_handler_check.mjs` | 21 isolated worker checks; uses synthetic tokens and no live deletion. |
| `docs/security/audit-50-checks.md` | Updated findings/action/verification for all 50 items; active controls distinguished from remaining setup. |
| `docs/security/operations-runbook.md` | Updated backup, monitoring, incident and manual ownership guidance with actual verification limits. |
| `docs/security/security-stage-completed.md` | This copy/test guide and exact file list. |

## Run locally

In your VS Code PowerShell terminal at `C:\Projects\meat-marketplace`:

```powershell
flutter pub get
dart format lib/shared/security/payment_retry_queue.dart lib/shared/security/retry_safe_payments.dart lib/features/legal/presentation/legal_info_page.dart test/payment_retry_queue_check.dart
flutter analyze
dart run test/payment_retry_queue_check.dart
flutter run -d chrome
```

No new production provider, server secret, environment variable or paid dependency is required for the local code. Crypto 3.0.7 and preferences 2.5.5 were already in the dependency graph; they are now direct dependencies. Existing `.env` stays unchanged and must only contain permitted public frontend configuration.

## What you can test

1. Record a small **test trade payment** using a test business/account; check its history and balance. Recording a payment does not move money. Supplier and butcher submissions should now resolve the keyed backend RPC instead of producing a missing-function/signature error.
2. The standalone Dart check safely exercises uncertain network responses, refresh/new queue instance, identical concurrent calls, timeout, user isolation and storage failure without touching your database. Prefer this over interrupting a real payment.
3. For a development UI check with test records only: submit a payment; if its response is uncertain, refresh and retry the **same details on the same browser/device**, then confirm there is only one corresponding record. Review history first if the outcome is unclear. Do not change amount/date/reference/allocation or clear site data to force a retry.
4. Sign in as an unrelated test business and check that the other business's order/invoice/private documents remain inaccessible. Test inactive/suspended members in an isolated test setup; support access to their own existing ticket should remain.
5. Open the privacy/storage notice and verify the new retry-storage explanation is displayed. Current logo/invoice, GST, pricing, founding membership and admin billing behavior should stay as before.

The replay guarantee uses the same signed-in user, random request key and exact payload. Browser storage clearing, a different device/tab, edited payment details or direct legacy unkeyed RPC calls can create a new key. It is not a global guarantee that two separate payment intents will be combined. Do not expire or manually purge unresolved request keys without checking account history. There is a 100-pending-key per-user/device cap; corruption/storage failure blocks sending rather than silently risking a duplicate.

The optional Node worker check requires Node 24 with TypeScript stripping; Node is not a production Flutter dependency. It has already passed here. No local Node install is required to use CutLink.

## Verified here

34 isolated PostgreSQL checks; 20 Dart payment retry checks; 21 cleanup checks; strict TypeScript checking; 14 upload checks; existing standalone customer-account and membership-date checks; full `lib`/`test` Dart analysis using genuine Flutter SDK dependencies with no issues. Seven hosted permission checks passed in a rolled-back transaction. Hosted cleanup returned GET 405 and invalid-token 401. Offline dependency resolution passed without upgrading remaining versions.

Your VS Code environment was not tested. No full Flutter widget suite, release build, end-to-end browser/accessibility test, real restore, broad concurrent load test or full production clearance is claimed.

## What still needs setup before public launch

- **Secure Supabase sign-in:** the dashboard currently shows its login screen. After you authenticate securely, provider-only settings can be reviewed/configured. Do not paste passwords, service-role keys or scheduler tokens into chat.
- **Account/Auth protection:** verify email confirmation, redirect URLs, rate limits and sessions; enrol MFA before enforcing it; leaked-password protection remains disabled. CAPTCHA needs a selected provider and working Flutter token integration before enforcement. No paid upgrade made.
- **Backup/recovery:** choose an encrypted restricted destination, accept retention/recovery targets, include database + uploaded file bytes + essential configuration, and perform an isolated real restoration. The synthetic SQL checks are not a backup restore.
- **Alerts/cost controls:** name primary/backup recipients, select existing provider or approved transport, set thresholds/retention/access and prove delivered alerts. The audit journal is active, but active alerts/monitoring are not claimed. No recurring task created.
- **Private uploads:** client checks and Storage caps are present; a server file-byte validation/quarantine/malware pipeline remains open for public uploads, particularly Office/PDF/ZIP. Private download, expiry and revoked-access runtime tests remain needed.
- **Launch ownership:** final operator/contact details, policies/licences, release hosting/headers, accessibility, full role tests and workload review remain open. See all 50 statuses and the runbook.

Stripe and the platform subscription payment method remain for a later decision. No payment-provider integration, subscription charging job, website publishing, Git commit or push was performed.
