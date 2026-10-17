# CutLink security status — 16 October 2026

This records targeted changes and explicit gaps. It is not a claim that all 50 controls passed, a penetration-test certificate, a legal opinion or a promise of no lawsuits, hacking or provider suspension. Earlier audit descriptions are not evidence of fresh runtime testing in this update.

## Implemented in this update

Five migrations are active in the existing development project `wqdfimgaqqnhptxyarvm`:

| Applied version | Change |
|---|---|
| 20261016131325 | Private supplier stock; guarded buyer catalogue; cart/detail/favourite compatibility; revoke browser table-altering privileges |
| 20261016131818 | Recorded product-photo rights confirmations; path/owner checks; authorisation quotas; immutable upload paths; product-photo reporting/moderation backend |
| 20261016132138 | Index new restriction actor reference |
| 20261016132224 | Evaluate original price-list permission rules once per statement |
| 20261016132457 | Serialize stored-photo cap checks across concurrent managers |

The 14 complete Dart replacements activate the client changes after local installation. The app now displays supplier photos or placeholders; a separate explicit-filename cleanup script deletes 45 retired bundled reference photographs. Copying a ZIP alone does not delete files already in your Windows project. Existing deployed builds/assets must also be replaced through a new deployment.

Exact `available_quantity` and `available_weight_kg` balances are unavailable to ordinary butchers through the product table/stock ledger. Catalogue rows mask them and marketplace JSON omits the keys. Availability labels remain. Supplier inventory remains available to the supplier's authorised members. Orders preserve the buyer's own quantities and specifications. Database administrators still possess privileged access: app RLS does not conceal data from the database owner.

Supplier photo confirmation records are private. They record an assertion of rights, not proof of ownership. Limits are 10 successful authorisations per minute and 100 per rolling 24 hours per account, plus a stored-photo limit of 10 per product. Existing bucket type/size restrictions remain. These are not universal API, bandwidth or business-storage limits.

Content reports use the existing business-scoped Support workflow. Administrators review evidence, can block/remove a product photo and later allow a new upload. Moderation reasons are audited. Existing business suspension supports serious or repeated abuse. A blocked catalogue photo and a deleted storage file are different outcomes: the UI reports failed physical deletion and supports retry. Old browser/CDN copies may persist temporarily. There is no automatic content classifier, legal determination or guaranteed immediate purge.

## Verification and limits

- Live rollback suites passed: stock isolation; supplier inventory; catalogue/availability/legacy RPCs; unknown-account denial; consent/version/path/ownership checks; used-consent rejection; upload-authorisation quota; admin permission/restriction/unrestriction/audit; buyer cart add/update; frozen product details; favourite creation. Tests did not persist their data. A rolled-back test order can consume an order-number sequence value.
- Price visibility matched the original access guard for every existing business-member account. Expected IDs were computed before switching to the RLS-restricted role, avoiding a false test caused by hidden customer assignments.
- The sampled default marketplace query returned 40 of 47,251 catalogue products in 1,885 ms under the existing 8-second statement timeout. Before the optimisation, that equivalent request timed out. This single measurement is not a throughput or concurrency guarantee.
- 159 Dart files parsed without syntax errors; exact-stock references were removed from buyer catalogue/detail/favourite screens. This is not Flutter type analysis.
- Current security advisor: 6 RLS/no-policy informational notices, 2 anonymous definer-function notices, 117 authenticated definer-function notices and 1 leaked-password-protection warning. The private ledgers intentionally have RLS and no client grants/policies. The two public aggregate/pricing routines are intentional. Callable-function inventory still needs complete endpoint/role review; warning counts are not clearance.
- Current performance advisor: 47 unindexed foreign keys, 25 unused-index notices and 20 multiple-permissive-policy notices. The new restriction reference was indexed. No speculative mass index removal or policy merging was done.
- All inspected public and private application tables retain RLS.

Not run here: Flutter analyzer, widget/browser tests, release build, actual authenticated Storage byte upload/deletion, delivered email/alerts, live cleanup deletion, a restore, independent penetration testing, complete route/role/device checks or genuine multi-connection upload/load testing. Flutter/Dart SDKs are unavailable in this environment. The checked-in Storage trigger's concurrency design is not a claim that a real parallel upload test passed.

## Outstanding launch blockers and needed inputs

| Work still open | What is needed |
|---|---|
| Real operator and final policies | Actual legal operator name, ABN if applicable, public privacy/support/copyright contact, intended live domain, charging/cancellation model and legal review. No identity or contact was invented. |
| MFA | Secure owner enrolment for the Supabase dashboard and app administrators; recovery arrangements; tested enforcement after enrolment. Last inspected app MFA factor count was zero. Dashboard MFA is distinct and unverified. |
| Auth settings | Enable supported leaked-password protection; inspect session/redirect/rate/SMTP settings and test sign-in, recovery and delivery. Email confirmation is enabled in the inspected public Auth configuration; delivery was not tested. Current connector tools do not change provider Auth configuration. No plan upgrade was purchased. |
| CAPTCHA / bot protection | A supported provider, real site/secret configuration and live domains; token integration and valid/missing/expired-token tests. Server enforcement was not enabled against a client with no token integration. TLS fingerprinting is optional supplementary telemetry, not a mandatory control or replacement for authentication, quotas and monitoring. |
| Backup and restore | Approved encrypted destination, database/Auth + uploaded file bytes + configuration coverage, retention, recovery owner/targets and a genuine isolated restoration. Source ZIPs and rollback tests are not backups or restoration evidence. |
| Alerts and incidents | Confirm primary/backup recipients and transport; cost/security/error thresholds, retention and actual delivery/acknowledgement tests. Audit events exist; active alerts are not claimed. |
| File validation and malware | Server file-byte validation, safe decode/re-encode or quarantine as appropriate, malware scanning and controlled downloads. Client checks and declared MIME/size restrictions can be bypassed; new photo consent does not scan bytes. Office/PDF/ZIP support uploads remain a particular review item. |
| Complete abuse/cost controls | Read/Auth/failed-request/IP/egress controls; aggregate storage and per-business limits for all buckets; orphan cleanup and provider billing alerts. Photo quotas and the existing selected-write limiter cover only part of this. |
| Deployment | Confirm hosting and live domain; release build, HTTPS/HSTS decision, effective CSP/frame/nosniff/referrer headers, Flutter/PDF/video compatibility, exposed-artifact checks and runtime network/storage inventory. No production site was deployed or inspected. |
| Remaining media permissions | The 45 reference meat photos are retired; uploaded supplier images need real permission. Video, other branding, diagrams and other media rights were not newly licensed or certified. |
| Complete independent verification | Full endpoint/function and business-role matrix, revoked/suspended access, private download expiry, all devices, accessibility, race/replay/fulfilment cases, dependency CVEs, repository history and an independent penetration test. |
| Operational ownership and legal coverage | Assign security/backup/moderation/privacy responders, lawful retention, food-trade responsibilities and incident/notification processes; assess insurance and applicable legal duties with the actual business model. |

No passwords, MFA codes, private keys, service-role keys or scheduler tokens should be pasted into chat. Provider enrolment needs secure account interaction. Paid resources, backup destinations and alert recipients were not invented or created.

## Status against all 50 audit categories

“Present” below is limited to inspected code/configuration; it does not mean a full runtime pass. “Open” and “partial” remain unfinished.

| # | Category | Current status / remaining work |
|---|---|---|
| 1 | Privacy policy | Development notice updated for stock confidentiality, privileged support access and photo consent. Final operator/contact, retention and publication open. |
| 2 | Terms of service | Development terms plus supplier-photo terms. Qualified responsibility wording; final commercial terms/legal review open. |
| 3 | Refund policy | Existing development notice distinguishes meat transactions and platform fees. Final subscription refunds/cancellation and legal applicability open. |
| 4 | Cookie/storage policy | Existing session/retry-storage notice retained. Release network/storage inventory open. |
| 5 | Cookie consent banner | No optional tracker found in supplied dependencies. Reassess if optional analytics/ads/embeds are introduced. |
| 6 | Form consent | Photo rights confirmation is now stored server-side with a policy version. General registration acknowledgement remains client/Auth metadata, not final durable contractual consent. |
| 7 | Unnecessary data | No new identity-document requirement. Photo audit metadata has a defined security purpose. Final field minimisation and retention review open. |
| 8 | Third-party SDKs | Supplied dependency inventory reviewed previously. Current browser/network and full transitive CVE review not run. |
| 9 | Dark patterns | New report/review dialogs allow cancellation. Whole-app usability review not repeated. |
| 10 | Hidden fees | Transaction pricing retained. Final platform charging/cancellation disclosures and end-to-end totals review open. |
| 11 | Fake reviews | No new reviews/testimonials introduced. Existing marketing/approval claims still require factual substantiation. |
| 12 | Unsupported claims | No claim that supplier photos are independently verified or that CutLink is immune from liability. Remaining advertising/video claims open. |
| 13 | Image semantics | Supplier-photo and placeholder semantics retained. Full screen-reader/image audit open. |
| 14 | Contrast | Existing palette retained. Complete measurement of all states/devices open. |
| 15 | Keyboard navigation | Standard Flutter dialog/form controls used. Focus return, keyboard and screen-reader runtime checks open. |
| 16 | Business details | Actual legal operator, applicable ABN, public contact and final domain still required. |
| 17 | Adult/business authority | Existing adult/business registration acknowledgement retained. No independent age/authority verification claim. |
| 18 | Unsubscribe | No marketing sender introduced. SMTP/service delivery review and future marketing compliance open. |
| 19 | Image/font licensing | 45 reference meat photos retired and cleanup provided. Supplier rights attestation recorded. Other media and actual supplier licences still need evidence. |
| 20 | Privacy/deletion requests | Existing support-based requests retained; new content-report route added. Public no-login contact and actual case handling/retention decisions open. |
| 21 | Unused packages | No new dependencies added. No package removal or dependency refresh in this update. |
| 22 | Git secrets | No secrets or .env included in this package. Full Git history, CI/provider secret stores and comprehensive credential audit remain unavailable/open. |
| 23 | Rate limiting | Existing selected-write limiter plus new product-photo authorisation quotas. Reads, failed/rolled-back requests, all Auth and other Storage routes not universally covered. |
| 24 | User access | Exact inventory restricted; buyer cart/favourites and sampled supplier/unknown roles tested. Full active/pending/suspended/revoked role matrix still open. |
| 25 | Password security | Supabase Auth retains hashing responsibility. Leaked-password protection remains disabled and must be addressed through supported provider configuration. |
| 26 | Public/private keys | Frontend publishable key is intentionally public; no server secret added. Required protection is server authorisation/RLS, not concealing public configuration. |
| 27 | Authentication | Email confirmation enabled in inspected configuration; MFA, CAPTCHA, redirects/sessions/rates and delivery testing open. |
| 28 | Dependency updates | No versions changed. Current CVE/SDK review and regression build open. |
| 29 | Input validation | Server photo consent/version/path/ownership and quota checks added. Real image-byte validation/scanning still open. |
| 30 | XSS/content | New report text renders as text. No HTML/SVG product upload type added. Server scanning and deployed content-type/nosniff validation open. |
| 31 | Release/debug | No release build or deployment here. Debug-banner setting is not evidence of a release build. |
| 32 | Security audit | Targeted live DB regression and source checks completed. This is not a full independent security audit or certification. |
| 33 | Environment configuration | No .env changes or new secrets required. Hosting/CI/server stores need separate review. |
| 34 | Exposed files | No confidential records exported in this ZIP. Old reference assets need local cleanup and redeployment. Live source maps/backups/directory listing checks open. |
| 35 | Admin routes | Existing trusted profile flag guard retained. Photo moderation requires it and logs reasons; ordinary supplier denial tested. MFA and complete admin route review open. |
| 36 | API endpoints | Direct inventory access closed for buyers; safe catalogue, frozen details and price authorisation checked. Full callable-function review remains open. |
| 37 | CORS/origins | No CORS changes. Actual Auth redirect allowlist/hosting origins need provider review. CORS is not an access-control substitute. |
| 38 | Headers | Earlier hosting template was not a verified deployment. Effective production CSP/HTTPS/frame/nosniff/referrer/permissions headers remain untested. |
| 39 | Database access | RLS retained; browser TRUNCATE/TRIGGER/REFERENCES removed; private consent/moderation records deny client access. Privileged owner access remains possible and requires purpose limits/MFA. |
| 40 | Universal rate limiting | Open. Photo quota and selected-write quota are partial coverage, not a gateway/anti-DDoS system. |
| 41 | Usage quotas | Photo count/authorisation and existing per-file caps active. Business-wide bytes, all buckets, egress and orphan controls open. |
| 42 | Throttling | Photo authorisations serialize per account; stored-photo count serializes per product. Actual multi-connection/provider abuse tests remain open. |
| 43 | CAPTCHA | Not configured or integrated. Needs real provider/domain setup and tested tokens before enforcement. |
| 44 | Cost controls | No paid upgrade/resources created. Provider billing limits, recipients and delivered usage/cost alerts open. |
| 45 | Backups/recovery | Not completed. No verified database + file-byte + configuration backup or isolated restore. |
| 46 | Monitoring | Existing access journal/admin read audit retained; photo moderation audited. Raw dashboard/SQL access is not logged by the app's admin-view audit. Active delivered alerts open. |
| 47 | Incident response | Existing runbook remains a plan; actual responder contacts, drills, privacy coverage and notification decisions open. |
| 48 | Uploads/outbound requests | New rights/path/owner/immutable-photo controls active. Actual byte scanning/quarantine, no-login claims channel and complete runtime download/upload checks open. |
| 49 | Reliability under abuse | Default price query improved; buyer cart/favourite DB checks passed. Full stock/payment/replacement/concurrent order/load/browser tests not rerun or completed. |
| 50 | Operational ownership | Concrete owners, provider settings, legal details, recovery, alert delivery and moderation response targets remain to be accepted and exercised. |

## Screenshot claims and legal responsibility

Some screenshot claims identify real risks, but they overstate automatic liability and automatic shutdown. A platform needs appropriate terms, privacy handling and provider-compliant operation; the exact legal obligations and remedies depend on the jurisdiction, content, business model and circumstances. A password rule does not moderate user content. TLS fingerprints are a probabilistic bot-risk signal, not proof of identity. An American DMCA page is not an automatic Australian commercial-platform safe harbour.

For supplier photos, obtaining permission/licences and keeping evidence matters. Supplier warranties and a service-specific display licence help allocate responsibility, but no wording guarantees that CutLink can never be liable or excludes rights/duties that cannot lawfully be excluded. Do not use “online photos are entirely up to the supplier” as an unrestricted permission to copy others' work.

Your ability to administer supplier data in Supabase is a technical privilege, not a blanket right to use it for any purpose. Restrict staff access to legitimate operation, support, security and compliance; disclose actual handling, maintain confidentiality and access records, and do not use supplier-confidential information for unrelated competitive purposes. Whether particular privacy laws apply requires the actual operator and business activities; a small-business exemption should not be assumed to eliminate every obligation.

Official references:

- [Australian Attorney-General: copyright users and permission](https://www.ag.gov.au/rights-and-protections/copyright/copyright-users)
- [ACCC: contracts and unfair terms](https://www.accc.gov.au/business/selling-products-and-services/contracts)
- [OAIC: small business and privacy](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/organisations/small-business)
- [OAIC: APP 6, use and disclosure](https://www.oaic.gov.au/privacy/australian-privacy-principles-guidelines/chapter-6-app-6-use-or-disclosure-of-personal-information)
- [Supabase: password security](https://supabase.com/docs/guides/auth/password-security)
- [Supabase: production checklist](https://supabase.com/docs/guides/platform/going-into-prod)
- [Supabase: backup coverage](https://supabase.com/docs/guides/platform/backups)
- [Supabase: intentionally deny-client RLS tables](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Supabase: authenticated definer-function inventory](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Supabase: unindexed foreign-key findings](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
