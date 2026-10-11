# CutLink replacement files

Extract into `C:\Projects\meat-marketplace` (your existing project root). No enclosing folder. No source deletion or rename required. Do not overwrite your .env.

Read `docs/security/audit-50-checks.md` for all 50 findings and exact PowerShell commands. Read `operations-runbook.md` for remaining manual controls.

**Before using the changed payment screens:** the complete included SQL migration must be reviewed/tested and applied to Supabase. Copying files alone does not apply it. New keyed payment RPC signatures are not yet hosted. The Edge Function is also a prepared replacement, not a deployed worker.

No new production dependency; run flutter pub get to refresh pubspec.lock after removing unused cupertino_icons.

| Complete file | Why changed/new |
|---|---|
| pubspec.yaml | Remove unused Cupertino icon dependency |
| test/upload_file_type_check.dart | Validate uploaded bytes/types/sizes; bound image decoding |
| lib/main.dart | Prevent privileged keys/non-HTTPS endpoint at startup |
| web/_headers | Hosting security-header template; requires actual host activation/testing |
| web/index.html | Document language and referrer metadata |
| docs/security/audit-50-checks.md | 50-item audit, database inventory or operational runbook |
| docs/security/operations-runbook.md | 50-item audit, database inventory or operational runbook |
| docs/security/database-function-review.md | 50-item audit, database inventory or operational runbook |
| supabase/migrations/20261010034341_cutlink_security_hardening.sql | Targeted authorization, quotas, VIP upload verification, redacted access journal and keyed payment replay |
| supabase/functions/support-retention-cleanup/index.ts | Bounded cleanup requests and outbound timeouts; preserve existing token authentication |
| lib/features/authentication/presentation/sign_in_page.dart | Safer unexpected errors, remove raw debug logs, in-flight guard and control labels |
| lib/features/authentication/presentation/account_details_page.dart | Explicit unchecked development notice/adult-business acknowledgement and in-flight guard |
| lib/features/customers/presentation/supplier_customer_account_page.dart | Retain request keys after uncertain payment-recording responses |
| lib/features/support/presentation/support_center_page.dart | Validate uploaded bytes/types/sizes; bound image decoding |
| lib/features/landing/presentation/featured_businesses_section.dart | Logo accessibility label |
| lib/features/landing/presentation/cutlink_explainer_video_web.dart | Remove unsupported hard-coded duration claim |
| lib/features/landing/presentation/cutlink_landing_content.dart | Link pre-launch policies without rebuilding layout |
| lib/features/orders/presentation/butcher_settings_page.dart | Logo validation and access to privacy notices |
| lib/features/orders/presentation/butcher_accounts_page.dart | Retain request keys after uncertain payment-recording responses |
| lib/features/orders/presentation/supplier_settings_page.dart | Logo validation and access to privacy notices |
| lib/features/marketplace/presentation/butcher_vip_suppliers_page.dart | Validate uploaded bytes/types/sizes; bound image decoding |
| lib/features/legal/presentation/legal_info_page.dart | Pre-launch notices and privacy requests via existing support |
| lib/shared/widgets/public_auth_frame.dart | Link pre-launch policies without rebuilding layout |
| lib/shared/widgets/product_photo_editor.dart | Validate uploaded bytes/types/sizes; bound image decoding |
| lib/shared/security/retry_safe_payments.dart | Retain request keys after uncertain payment-recording responses |
| lib/shared/security/upload_file_type.dart | Validate uploaded bytes/types/sizes; bound image decoding |
| lib/shared/security/upload_safety.dart | Validate uploaded bytes/types/sizes; bound image decoding |
