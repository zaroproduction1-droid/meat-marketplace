# CutLink operational security runbook — pre-launch

This is a proposed manual operating plan, not evidence that backups, monitoring, alerts or ownership are active. No recurring task or paid service was created. The project owner must accept owners, contacts, retention and budget before launch.

## Ownership and launch record

| Control | Proposed responsible person | Action and evidence to retain |
|---|---|---|
| Project/security owner | Amro, subject to confirmation | Name a technical responder and backup contact; keep private phone/email contacts in a restricted vault, not source code. |
| Supabase administration | Project owner + approved technical responder | MFA on dashboard; least-privilege organisation members; review departing-user access and keys. |
| Backups/recovery | Assigned technical responder | Confirm fresh DB + stored-file + config coverage, access controls and an isolated restore test. Record result/date. |
| Alerts/incidents | Named primary and backup recipient | Test each alert end to end. Confirm who can pause a public route, revoke credentials and contact providers. |
| Privacy/commercial terms | Operator + qualified adviser as needed | Final identity/contact, retention, deletion handling, licensing and legal coverage decisions. |
| Dependencies/releases | Technical responder | Review lockfile and advisories before each release and at a manually agreed cadence; regression-test relevant flows. |

Do not store server keys, scheduler token, private contact details or incident evidence in this public project bundle.

## Backup coverage and recovery

Read-only inspection found the free plan, 75 public tables, and 22 stored objects: 7 support attachments (~3.58 MB), 4 branding files (~0.06 MB), 11 VIP files (~5.46 MB). Product-photo bucket exists but had no objects in the aggregate inspection. Object names and bytes were not exported. These counts do not verify that every linked object exists or has a backup.

Recoverable from the supplied ZIP: app source, assets, tests and dependency lockfile. Read-only definitions and deployed cleanup function were inspected; they are not a complete recoverable database backup. No full data/auth dump, stored-file backup, provider configuration export or genuine isolated restoration was completed. Database-only backup does not restore stored file bytes.

Proposed pre-launch coverage:

1. Take a consistent database export including roles/schema/data and required Auth records through a provider-supported backup workflow. Keep privileged export credentials in a vault and reset any unsupported custom-role credentials during restoration. Do not include a dump in public source or this ZIP.
2. Separately export all bucket file bytes and a manifest with bucket/path/size/checksum/access classification. Reconcile each manifest against the DB references. Protect private support/VIP files; never convert them to public buckets to make backup easier.
3. Export non-secret configuration: Auth redirect/site URLs, provider names, Storage limits/policies, Realtime/publication settings, Edge source, scheduler settings without token, hosting rules, key names and alert routes. Preserve secret values only in an encrypted vault with recovery access.
4. Store encrypted backups off-site, restricted to named owner/responder with MFA, separate credentials and audit history. Use encryption at rest and authenticated TLS transfer. Do not claim these controls exist until verified on the chosen destination.
5. Suggested starting retention: 7 daily + 4 weekly + 3 monthly snapshots, adjusted to actual legal/privacy needs and budget. This is backup retention, not a statutory financial-record retention decision. Do not purge any live data based on this proposal. Review backup deletion implications for privacy requests and maintain a replayable deletion log.
6. Restore into an isolated, non-public environment with outbound email/webhooks, cron and payment integrations disabled. Never use a live project URL as a restore destination. Use local resources or a separately approved test project; do not create a paid branch automatically.
7. Compare table/record counts, foreign keys, functions/RLS/grants and file checksums. Test fresh Auth sign-in, two unrelated businesses, private downloads, invoice/stock/account consistency and application boot. Record restoration duration and gaps. Delete temporary test copies securely after evidence is retained and retention approved.

Proposed targets to agree: recover within 4 hours and lose no more than 24 hours of transactions. These targets are untested; real trading may require tighter recovery and separately approved PITR. Before launch, complete and record a genuine restore. The synthetic migration test in this package is not that test.

## Monitoring, alerting and retention

Existing platform-admin audit data and an hourly resolved-support cleanup job were found. The cleanup schedule was preserved, not verified end to end. The new migration adds a private access-change journal containing timestamps, actor/target IDs, event type and changed field names only; it excludes names, emails, financial values, comments and credentials. It adds write-window and request-key ledgers. None of these new controls is active until the migration is applied.

Recommended alert rules, requiring configured transport and confirmed recipients:

- More than 10 failed logins from a source in 5 minutes, repeated recovery/sign-up abuse, and unexpected admin sign-ins. Correlate provider Auth logs; don't record passwords, raw JWTs or OTPs.
- Any admin-flag change; membership-role/status or business verification changes outside an approved change; repeated permission denials or access to unrelated-business objects.
- Repeated 5xx errors, timeout/quota rejections, cleanup failures and growing deletion queues. Aggregate route names and error codes; omit request bodies, token-bearing URLs and customer content.
- Storage/egress/invocation/database usage at 80% and 90% of an owner-approved quota; unusual daily growth and cost forecasts. A spend cap may not cover every chargeable feature; verify applicable provider controls.

Use existing provider logs or an approved provider before adding an SDK. Name both a primary and backup recipient. Trigger a benign synthetic event and prove receipt, acknowledgement and access restrictions. This was not done; no active alerts are claimed.

Suggested retention pending owner approval: 30 days operational logs/window counters, 90 days access-change audit events, and payment replay records while clients may still retry (initially 30 days). Request ledgers include payment response/payload data and therefore require restricted access and retention review; purge only after an approved plan. Do not expire replay keys while an outstanding retry can be accepted as new. No automatic retention job was created for new tables. Do not log or export raw ledger content into monitoring. Existing support retention may be shorter or longer; review the actual policy and lawful record obligations before changing it.

## Incident response

The owner appoints an incident lead; technical responder contains/repairs; privacy/legal responder assesses coverage and notifications. Add private contact and escalation details to a restricted contact sheet before launch. Public references below are provider/regulator channels, not pre-approved recipients for messages.

1. Record detection time, affected service and observed symptoms. Preserve limited relevant logs/snapshots before changes. Store evidence encrypted with access history and hashes. Avoid copying unrelated personal data.
2. Contain the specific route/key/account causing harm. Restrict offending access, stop optional integrations, isolate public endpoints where necessary and retain the investigation trail. Do not destroy the whole project or overwrite the live database as a reflex.
3. Revoke compromised credentials at the issuer, rotate affected keys/tokens and update legitimate applications/worker configuration in a coordinated order. Invalidate sessions as needed. Removing a user alone does not immediately invalidate already issued JWT access tokens; check session/JWT behaviour and sensitive operation checks. Do not publish credentials or force unrelated rotations without cause.
4. Identify scope: affected businesses/users, information categories, unauthorised access vs availability loss, duration, downstream disclosures and remedial actions. Reassess access flags, private document paths and backend invariants.
5. Recover from a verified clean backup into isolation, reconcile financial/stock/file data and replay authorised changes. Test business isolation, invoice/credit/payment integrity, fulfilment and privacy before reopening. Communicate service status through the operator's approved channel.
6. Assess Australian notification duties with a qualified responder. If the Privacy Act covers the operator and an eligible breach is established, OAIC guidance requires prompt notice to at-risk individuals and OAIC. Assess likely serious harm and remedial prevention; do not assume every incident is notifiable or small-business exemption always applies. Review the current assessment-time and notification guidance when the event occurs. Notifications identify the organisation/contact, describe the incident and affected data categories and advise protective steps. No notifications were sent and this is not legal sign-off.
7. Document root cause, controls changed, evidence kept, recovery gaps and follow-up owners. Re-test alerts and backup restoration; review retained evidence for minimisation and lawful retention.

Provider contacts: [Supabase support](https://supabase.com/dashboard/support/new); the eventual hosting/domain/email providers must be recorded once chosen. Regulator guidance and reporting: [OAIC report a data breach](https://www.oaic.gov.au/privacy/notifiable-data-breaches/report-a-data-breach), [when to report](https://www.oaic.gov.au/privacy/notifiable-data-breaches/when-to-report-a-data-breach), and [ACMA marketing rules](https://www.acma.gov.au/avoid-sending-spam). User-facing support/privacy contact remains to be established. Do not automatically send messages based on this plan.

## Upload and outbound-request launch gates

Client signatures/dimensions prevent accidental disguised files; they do not protect against a caller bypassing the app. Storage MIME/size limits and RLS remain necessary, but a filename/MIME header does not prove file content. Add an owner-approved server validation/quarantine workflow before accepting public uploads, check real bytes/containers, reject active HTML/SVG/executables, scan supported documents, and release only clean files. Configure downloadable document Content-Disposition and nosniff; test stored PDF/Office/ZIP behaviour. Avoid server unpacking of untrusted ZIP archives, which this app does not implement.

Private downloads must remain business-scoped and short-lived; test signed links across different businesses, revoked membership and expiry. Existing support links use a 300-second signature; already issued signed links remain bearer URLs until expiry.

The worker only calls a configured Supabase origin and rejects redirects; it does not fetch arbitrary user-provided URLs. If such fetching is introduced, enforce an origin allowlist, HTTPS, DNS/IP checks against loopback/private/link-local/metadata destinations, redirect checks, response-size/time limits and concurrency limits. Do not treat a browser CSP as server SSRF prevention.

## Release acceptance record

Fill actual owner, date and evidence for: local Flutter analysis/tests/release build; browser headers and accessibility; all business-role isolation; keyed buyer/supplier replay and concurrent invoice/order operations; dependency/licence clearance; provider CAPTCHA/Auth settings; malware pipeline; backup freshness + isolated restore; delivered security/cost alerts; legal entity/contact/policies and privacy request handling. Do not publish until open blockers have an explicit disposition.
