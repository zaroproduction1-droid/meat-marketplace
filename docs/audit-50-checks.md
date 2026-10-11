# CutLink security audit and replacement package — 10 October 2026

## Outcome and scope

This is a prepared hardening package for the supplied meat-marketplace.zip, plus read-only inspection of NSW Meat Marketplace (wqdfimgaqqnhptxyarvm, PostgreSQL 17.6, Sydney). It is **not a completed production security clearance**. The Flutter framework, names, supported animals, workflow, hosted records and configuration are preserved. CutLink is the displayed product name; CutlinkTrade is the intended web identity. The operator is not yet official.

No remote migration, deployment, commit, user deletion, bucket change, credential rotation, notification, paid service or new scheduled task was performed. The migration and Edge Function are complete prepared files, not active controls. Copying the ZIP does not update Supabase.

## Findings that matter most

- Required SECURITY DEFINER functions stay usable; missing helper authorization is targeted. A profile-admin guard already exists and was retained.
- All 75 public tables currently have RLS. This does not prove every policy prevents every cross-business operation.
- Uploaded file types were trusted by filename in several paths. Client defence is added, and VIP metadata/path registration is hardened, but server malware/type scanning is still absent.
- Supplier/butcher payment recording now sends a request key, supported by backward-compatible overloads in the migration. Pending keys are held in memory and do not survive restart. Legacy signatures are retained for compatibility, and therefore are not protected by keyed replay logic.
- Supabase security advisor still reports leaked-password protection disabled. Current free plan may constrain available features; do not purchase an upgrade without approval.
- Catalogue image-source URLs include third-party retailer/stock assets. No redistribution licence was supplied.
- Backups, restoration, alert delivery, CAPTCHA and full provider settings remain unverified. These are launch blockers, not hidden completed items.

## Verification performed

Dart 3.13.5: formatted changed Dart files; pure-Dart upload validator analyzed with no issues; 14 upload checks passed. Isolated PostgreSQL via PGlite: 17 synthetic checks passed, covering cross-business denials, authorized recalculation, inactive-business denial, access journal insertion, successful-write quota, supplier payment retry and changed-payload rejection. SQL outer syntax parsed. Retention worker passed strict TypeScript checking with a minimal Deno type declaration.

Full Flutter analyze, Flutter tests, release build, browser/screen-reader checks, UI image decoding, complete role matrix and load/concurrency tests were **not run**. Automatic approval review blocked Flutter tooling because it contacted a cloud metadata endpoint. Dart dependency resolution cannot substitute for Flutter SDK resolution. No claim is made about your VS Code environment. Synthetic schema/function tests do not reproduce all live constraints, triggers, privileges, provider services or network behaviour.

Security and performance advisors were read again. Since no remote fixes were applied, the original warnings remain: 107 authenticated callable SECURITY DEFINER warnings, 1 intentionally public business aggregate warning, 1 RLS/no-policy informational notice, and leaked-password protection disabled. Performance advisor identifies 47 unindexed foreign keys, 23 unused indexes and 21 multiple permissive policies. Index removal/addition requires workload evidence; no speculative bulk changes made.

## All 50 checklist entries

Status “Changed” means prepared replacement code. “Prepared migration” is not a hosted fix. “Partial” is not clearance. Not-applicable entries apply only to the inspected feature set.

| # | Check | Status | Finding and action | Verification / remaining work |
|---|---|---|---|---|
| 1 | Privacy policy | Prepared / owner setup | New pre-launch privacy notice states actual data categories, trading disclosure and unresolved operator/contact/retention details. | Source and links checked; final published operator policy remains open. |
| 2 | Terms of service | Prepared / owner setup | Adult business-use development terms distinguish marketplace approval from quality guarantees and payment records from money movement. | No legal entity or final subscription terms invented; legal review needed before launch. |
| 3 | Refund policy | Prepared / owner setup | Order disputes, credit notes and recorded refunds separated from future platform fee refunds; non-excludable rights preserved. | No blanket no-refunds claim; commercial terms must be finalised. |
| 4 | Cookie policy | Prepared | Essential sign-in/browser-storage notice added; no optional advertising/analytics SDK found in app dependencies. | Release-build network/storage inventory still required. |
| 5 | Cookie consent banner | Not applicable currently | No optional tracker identified in supplied app. No misleading banner added for essential session storage. | Reassess and gate optional tracking if an SDK/embed is introduced. |
| 6 | Form consents | Partial | Unchecked adult/business-authority and notice acknowledgement added to registration. Notice version saved in signup metadata; no marketing consent bundled. | Client acknowledgement is not tamper-proof consent evidence; durable server consent record/final notice required at launch. |
| 7 | Unnecessary data | Partial | No DOB/identity-document fields added. Privacy notice asks users to supply only necessary trade/support data. | Trade/credit application fields and duplicate request-ledger retention need operator review. |
| 8 | Third-party SDKs | Reviewed / incomplete runtime | Direct packages inventoried: Flutter, Supabase, PDF/printing, picker, launcher, SVG/path, dotenv and web. | No analytics/ads SDK found; transitive vulnerability and browser/network verification pending. |
| 9 | Dark patterns | Reviewed | Registration acknowledgement is explicit and unchecked; request dialogs allow cancellation; video remains user initiated. | No identified dark pattern removed; full role/device usability review pending. |
| 10 | Hidden fees | Partial | Notices require disclosure of tax, delivery, catch weight and future subscription fees before purchase. | Existing order totals retained; fee/cancellation disclosure must be checked against final charging model. |
| 11 | Fake reviews | Reviewed | No fabricated landing testimonials/reviews identified. Community uses database aggregate and selected registered businesses. | Do not market platform approval as independent quality certification. |
| 12 | Unsupported claims | Changed / partial | Removed stale 80-second film claim; notices qualify platform approval and payment recording. | Claims in narrated footage and all future ads still need substantiation. |
| 13 | Accessibility alt text | Changed / partial | Business logo semantics and password-toggle labels improved; existing preview/product semantic labels retained. | Screen-reader and complete image inventory verification pending. |
| 14 | Colour contrast | Reviewed / partial | Public palette inspected; dark red/white and muted text/white have usable contrast. | Whole-app contrast, disabled states and video text not exhaustively measured. |
| 15 | Keyboard navigation | Partial | Notices use standard focusable Flutter controls and selectable text. Existing native video controls retained. | End-to-end keyboard navigation, focus order/dialog return and screen-reader tests pending. |
| 16 | Business details | Owner setup | CutLink display name, CutlinkTrade web identity, NSW/Australia used. Explicit pre-launch notice. | Legal entity, ABN where applicable, public contact, complaint channel and final domain ownership still unconfirmed. |
| 17 | Children/age consent | Changed / partial | 18+ adult business-authority acknowledgement added without collecting DOB. | This is self-attestation, not age verification. No child-oriented service identified. |
| 18 | Email unsubscribe | Not applicable to inspected marketing flow | No marketing-email sender found; authentication emails are service messages. | Before marketing: lawful consent records, sender/contact details and working no-login unsubscribe required; SMTP settings/template audit pending. |
| 19 | Font/image licensing | Open launch blocker | DejaVu font licence present. Catalogue image-source manifest contains third-party retailer/stock-image URLs. | Attribution is not permission. Obtain licences/permission or replace images before public launch; video/brand permissions also need evidence. |
| 20 | Data deletion requests | Changed / partial | Access/correction/deletion requests submit through existing business-scoped support tickets with confirmation. No live data automatically erased. | Sign-in/no-membership fallback needs published privacy contact. Operator must verify and action requests with lawful retention review. |
| 21 | Remove unused packages | Changed / dependency resolution pending | Unused cupertino_icons direct dependency removed; remaining direct packages are imported. | Run flutter pub get locally to regenerate lockfile; no wholesale dependency changes. |
| 22 | Git secrets | Partial | Extracted source scanned for secret-key/private-key/AWS-key patterns and service-role JWTs; no matching secret found. | ZIP has no .git history; historical commits, provider secrets and broader credential formats were not audited. |
| 23 | Rate limiting | Prepared migration / partial | Transactional shared quota of 120 successful write calls per user/minute added to selected expensive/mutation RPCs. | Isolated quota test passed; failed transactions, reads, Auth and Storage are outside this limiter. |
| 24 | User access | Prepared migration | Membership helpers additionally require active, pending/approved business; suspended/rejected businesses excluded. | Isolated inactive-business check passed; complete owner/manager/staff/butcher/supplier/admin runtime matrix still pending. |
| 25 | Password hashing | Provider control | Passwords go to Supabase Auth; no custom password database/hash introduced. | Provider hash strength/config not changed; leaked-password protection advisor warning remains. |
| 26 | Hide API keys | Changed | Startup rejects sb_secret and non-anon legacy JWT keys. Current client environment only has URL/publishable key names. | Frontend .env is a public asset by design; no server secret may be placed there. Signatures checked, not key validity. |
| 27 | Authentication | Partial | Duplicate in-flight sign-in/signup guard and safer unexpected sign-in errors; existing backend access RPC retained. | Email verification/MFA/session revocation/provider limits require configuration and role/session testing. |
| 28 | Update dependencies | Open verification | Existing pubspec.lock retained; no speculative major upgrades. | Full flutter pub outdated/transitive advisory review and regression tests required; Flutter tool blocked in this environment. |
| 29 | Sanitise forms | Changed / partial | Upload bytes/signatures/size/dimensions validated; support strings and order/allocation arrays bounded in migration. | No claim all field validators reviewed; server byte scanning/format parsing still missing. |
| 30 | XSS | Reviewed / partial | No dynamic innerHTML/eval found in Dart app; labels render as text. Active HTML/SVG text uploads rejected client-side. | Client checks are bypassable. Stored PDF/Office/ZIP malware handling and deployed nosniff headers pending. |
| 31 | Debug mode | Owner release step | App hides debug banner already; raw unexpected sign-in exception and debug logging removed. | Hiding banner does not make a release build. Use flutter build web --release and inspect deployed artefacts before launch. |
| 32 | Full security audit | Recorded / not clearance | All 50 items have findings/action/verification status. 204 function definitions, 75 public tables, policies, constraints, triggers and buckets inventoried. | Static triage plus selected isolated tests; no complete penetration test or security/legal sign-off. |
| 33 | Environment variables | Changed / partial | Publishable-key/HTTPS validation; existing .gitignore and .env.example retained. No real env values packaged. | No environment file deletion/replacement. Review server/CI secret stores separately. |
| 34 | Exposed files | Partial | Private buckets retained; no build outputs, .env, secrets or database rows exported in replacement ZIP. | Local localhost hosting has not been deployed/scanned; check maps, backup files, directory listing and artefact rules at launch. |
| 35 | Admin routes | Verified control / partial | Admin profile flag is already protected by database trigger; ordinary profiles cannot promote themselves through that flag. | Existing is_cutlink_admin checks retained; full route/RPC role matrix remains open. |
| 36 | API endpoints | Prepared migration | Scoped standard price-list creation, order totals, delivery terms, invoice receivable and draft-status helpers without removing required SECURITY DEFINER grants. | Isolated cross-business denials and allowed calculations passed; migration unapplied. |
| 37 | CORS | Open provider/release check | Existing retention worker has no browser CORS grant and uses a separate database-validated scheduler token. | Auth redirect/site URL/CORS actual responses not accessible through current settings tools; configure localhost now and exact origins at launch. CORS is not authorization. |
| 38 | Security headers | Prepared hosting template | web/_headers adds CSP, nosniff, frame denial, referrer and permissions controls; index language/referrer metadata added. | localhost does not load _headers. Hosting integration and Flutter/PDF/video CSP compatibility tests required; HSTS only after HTTPS verified. |
| 39 | Database access | Verified baseline / targeted fixes pending | All 75 public tables have RLS enabled; private documents/notes policies scoped; no public views found. | Advisor callable-function warnings are not blanket vulnerabilities. 1 no-policy table is intentionally managed through RPC; full policy execution tests pending. |
| 40 | Rate limiting everywhere | Open launch blocker | Selected write quota plus existing 3s anon/8s authenticated statement timeouts. | Not every endpoint is covered. Auth limits, REST/Storage quotas, failed-request/IP limits and gateway controls must be configured/tested. |
| 41 | Usage quotas | Prepared / partial | Existing bucket caps 5/10/15 MB; client VIP document cap 5; selected write quota and 500-line/allocation bounds. | Aggregate per-business storage/egress/read quotas and cleanup of orphan objects remain open. |
| 42 | Request throttling | Prepared / partial | UI in-flight guards, DB transactional quota, capped cleanup batches and outbound worker timeouts. | No cross-service concurrency gateway configured; load/concurrent-order testing pending. |
| 43 | CAPTCHA | Provider setup required | No CAPTCHA provider/site key is configured in the supplied app. | Configure Supabase-supported provider and Flutter token integration together, then test valid/missing/expired tokens. Do not enable server enforcement before client support works. |
| 44 | Cost controls | Owner setup required | Free plan verified; no paid resources created. Limits reduce some work. | Provider quotas, billing recipient, egress/storage alarms and any paid-plan spend cap unverified; no active cost alert claimed. |
| 45 | Backups/recovery | Plan prepared / recovery unverified | Source ZIP recoverable; 22 stored objects across 3 populated buckets identified. Free-plan daily DB backup coverage not established. | No database/upload backup exported and no real restore performed. See recovery runbook; synthetic SQL tests are not a restoration test. |
| 46 | Security monitoring | Prepared / delivery unverified | 38 existing platform-admin audit events counted; new private redacted access-change journal and restricted quota ledger prepared. | No monitoring provider, recipients, alert transport or delivered alert verified. Existing hourly cleanup job retained; no recurring task created. |
| 47 | Incident response | Runbook prepared | Containment, evidence, revocation, recovery and NSW/Australian notification review assigned to owner/technical/privacy responders. | Current OAIC official guidance consulted; jurisdiction/Privacy Act coverage and notification decisions need owner/legal review. No notification sent. |
| 48 | Uploads/outbound requests | Changed / partial | Signature checks and bounded raster decode; VIP registered objects must match owning application/path/size/MIME; cleanup fetches only configured Supabase with redirect rejection/timeouts. | No arbitrary user URL server-fetch feature found. Client MIME checks are not server malware scanning; Office containers only signature-checked. Release blocker remains. |
| 49 | Reliability under abuse | Prepared / partial | DB/helper quotas, server input bounds, timeouts and keyed payment retries added. Invoice order_id is unique; credit/refund request keys already constrained. | 17 isolated PG checks incl supplier and buyer payment replay passed. Legacy payment signatures retained; pending keys lost on restart. Concurrent invoice/order/load tests remain pending. |
| 50 | Operational ownership | Runbook prepared / owner assignment required | Manual controls list specifies dependency, backup, alert, incident, privacy and licence responsibilities. | No recurring monitoring or ownership acceptance implied; fill contacts and record actual test dates before launch. |

## Apply files and verify locally

Extract **into the existing project root**, for example `C:\Projects\meat-marketplace`, so `lib/`, `web/`, `supabase/`, `test/` and `docs/` merge with the same folders. There is no extra enclosing folder. Keep a backup of matching existing files first. No source file must be deleted or renamed; old database signatures are intentionally retained and their replay limitation is explicitly reported.

The new payment request parameter requires the included SQL migration **before using the changed payment screens**. In an isolated test project copied from your current database, apply the entire migration file through Supabase SQL Editor and run the role/flow tests below. Review the results before applying to the connected project. Do not run an unreviewed `supabase db push`: the source ZIP lacks the full historical migrations. The included migration was generated with the CLI and contains no live row replacement/deletion. It does modify functions, add private tables and replace only the named audit triggers.

The worker source remains a prepared replacement. Before deploying it, preserve the existing verify_jwt=false scheduler setup and 72-character database-validated token authentication. Do not change/reveal the token or cron command. A deployment is a separate action; none was performed. Test invalid token, valid no-work run, bounded queued-file batch, network timeout and deletion-acknowledgement retry in isolation.

Run in the VS Code PowerShell terminal at the project root:

```powershell
flutter pub get
dart format lib/main.dart lib/features/authentication/presentation/account_details_page.dart lib/features/authentication/presentation/sign_in_page.dart lib/features/legal lib/features/landing/presentation/cutlink_landing_content.dart lib/features/landing/presentation/cutlink_explainer_video_web.dart lib/features/landing/presentation/featured_businesses_section.dart lib/features/marketplace/presentation/butcher_vip_suppliers_page.dart lib/features/orders/presentation/supplier_settings_page.dart lib/features/orders/presentation/butcher_settings_page.dart lib/features/orders/presentation/butcher_accounts_page.dart lib/features/customers/presentation/supplier_customer_account_page.dart lib/features/support/presentation/support_center_page.dart lib/shared/security lib/shared/widgets/product_photo_editor.dart lib/shared/widgets/public_auth_frame.dart test/upload_file_type_check.dart
flutter analyze
dart run test/upload_file_type_check.dart
flutter test
```

`flutter pub get` regenerates the local lockfile after removing unused cupertino_icons. No new production dependency was added. Existing .env and .env.example are untouched; the download contains neither real environment values nor server credentials. Publishable frontend keys are public, not authentication bypasses.

Before public launch: test a release build and the hosting headers, MFA/admin access, CAPTCHA and Auth limits, private document downloads across two unrelated businesses, suppliers/buyers/staff/suspended members, invoice/credit/payment retries and concurrency, preserved public/private comments, stock reservation/cancellation, and invoice creation without automatic dispatch. Verify no Pork is introduced; taxonomy and ordering architecture were not changed.

## Official references consulted

- [Supabase backups](https://supabase.com/docs/guides/platform/backups): database backups exclude stored file bytes; free projects need their own exports.
- [Supabase password security](https://supabase.com/docs/guides/auth/password-security): provider password protections and availability must be checked.
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits), [sessions](https://supabase.com/docs/guides/auth/sessions), [cost controls](https://supabase.com/docs/guides/platform/cost-control).
- [Database function warning guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Required authenticated definer RPCs are not blindly revoked.
- [ACCC rights and guarantees](https://www.accc.gov.au/consumers/buying-products-and-services/consumer-rights-and-guarantees): preserve non-excludable rights; applicability to wholesale resale needs legal assessment.
- [OAIC small business guidance](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/organisations/small-business): do not assume NSW location or small size settles Privacy Act coverage.
- [OAIC reporting](https://www.oaic.gov.au/privacy/notifiable-data-breaches/report-a-data-breach), [when to report](https://www.oaic.gov.au/privacy/notifiable-data-breaches/when-to-report-a-data-breach).
- [ACMA spam guidance](https://www.acma.gov.au/avoid-sending-spam): marketing consent, identification and unsubscribe obligations need an actual working process.

These sources were consulted on 10 October 2026. Policy drafts and the incident runbook are not legal sign-off.
