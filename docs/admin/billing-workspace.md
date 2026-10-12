# CutLink simplified admin billing

Extract **CutLink-Simple-Admin-Billing.zip** into **C:\Projects\meat-marketplace** and replace the matching files. `lib/`, `supabase/` and `docs/` merge directly into your project. This package updates your existing restored app; it does not replace the entire project.

## The normal flow

1. **Admin → Billing → Accounts → Set up business billing.** Find the business and open it. If it needs approval, use Review business access.
2. **Start membership.** Confirm that it is a real business and choose founding, when available, or standard. Membership activation automatically creates the billing account, offer dates and next billing date. There is no separate account-creation step for a normal membership.
3. **Create invoice.** Review the exact billing period, amount, GST and due date before confirming. The default is the account's next monthly period. If an invoice already covers those dates, open it instead. Changed pricing requires a refreshed preview.
4. **Record received payment.** Open the invoice after funds arrive, record the payment, and download or print the PDF. Recording a payment does not charge a card or transfer funds. The PDF is sent externally through your existing workflow.

Each business has one **Billing** tab containing its account, current offer and invoice history. It shows the current monthly price, unpaid balance and next invoice date. Free membership now does not mean the next future period is free: the invoice preview calculates that period's actual price.

The main admin sidebar has one **Billing** entry. Inside it:

- **Accounts:** find a business's account, review billing or create its next invoice. Ready to invoice and overdue shortcuts use existing server filters and pagination.
- **Invoices:** all CutLink membership invoices, with unpaid/paid/overdue filters. Supplier trade invoices remain accessible through their business's Trade invoices tab.
- **Pricing:** supplier/butcher rates, founding places and open/pause controls. Individual offer changes happen on the business billing page.
- **Invoice details:** your CutLink legal identity, billing email, GST status and payment instructions. Set these once using your real information; no placeholder legal entity, ABN or bank account was invented.

Phones use a compact admin section selector. Billing controls scroll when screen space is limited, keeping the records visible.

Old account, invoice, membership and settings bookmarks still open the matching section. Analytics/overview shortcuts still work. The pending-approval shortcut now filters pending businesses directly.

## Existing and special accounts

Existing custom/legacy fees and GST settings are preserved. They are clearly labelled **Custom billing**. Use Edit billing details to deliberately change a custom fee; do not assume existing custom accounts were automatically converted to the published membership rates. Admin/test businesses must not consume founding places. Manual account creation remains under **Custom billing instead**.

Managed memberships hide fee/GST editing because the offer sets their price. Billing contact, payment terms, schedule and billing status remain editable. Pausing billing does not suspend business access. Starting a membership may require resolving invoices that already cover the current or a future period; the backend keeps this protection.

Founding offer changes and ending discounts stay behind membership actions and require a reason. Dates and places are not restarted or recycled. Existing approval, genuine-business checks, admin exclusion, authorization and audits remain.

Invoice pages show total, payments received, amount still unpaid and due date. Record received payment, Download invoice and Print are the main actions. Payment history, reminders, access restoration and voiding remain under More invoice actions, with the existing conditions and confirmations. Opening an invoice shows the original document; reminders are a separate selectable view. Newly created reminders open for download. Stored membership stage codes are translated into plain wording in PDFs; amounts and stored invoice snapshots are not rewritten.

## Supabase is already done

Migration **20261011022723_simplify_admin_billing** was applied to project **wqdfimgaqqnhptxyarvm** and verified. **Do not open Supabase or run SQL yourself.** The included complete migration is the project record of that applied change.

The new admin-only `platform_admin_invoice_preview` RPC reads prices/dates/GST without creating invoices or payments. Invoice creation remains in the existing guarded billing RPC, now with an optional expected-total check so a stale preview cannot silently issue a different amount. Existing exact-period retries continue to return the original invoice. Client-side buttons disable repeated submissions, while server locking and payment request keys remain authoritative.

Live checks confirmed the preview works for an existing administrator/account, rejects unrelated callers, and has no anonymous execution grant. Anonymous REST access returns HTTP 401. Public pricing remains HTTP 200, with $349.99 supplier and $199.99 butcher standard rates and 15/25 founding places unchanged. Account, invoice and payment fingerprints matched before/after. No real invoice, payment or membership was created during verification.

Security and performance advisors were reviewed. The new authenticated SECURITY DEFINER warning is intentional for a function with an explicit admin check; tested guards are retained. [Advisor details](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Existing unrelated advisory findings remain unchanged.

## Verification and local checks

- **182 isolated PostgreSQL checks passed on both setup paths**, using synthetic data. Coverage includes role/tier limits, exact free/discounted/regular amounts, GST, preview-to-issued totals/dates, existing invoice snapshots, overlap rejection, stale-preview prevention, legacy fees, repeat requests and authorization.
- The complete transaction installer was exercised before successful live installation. The included read-only admin billing checks passed live.
- **Dart analysis of all `lib` files passed with no issues** against real Flutter SDK dependencies in the verification environment. Complete replacement files were formatted; ZIP entries, CRC and byte matching were verified.
- A Flutter browser run, widget tests and rendered invoice PDF were not completed here. Your local VS Code environment was not tested. Isolated database tests are not a full staging clone or simultaneous multi-connection load test.

Run in VS Code PowerShell from **C:\Projects\meat-marketplace**:

```powershell
dart format lib/features/admin
flutter analyze
```

Then launch Chrome as usual. Check a normal approved business, pending approval, a custom/admin account, founding membership, a paused account and an unpaid invoice. Review an invoice preview first; create test invoices/payments only in an isolated test project. Confirm the PDF shows your correct logo, issuer details and payment instructions before issuing real bills.

No dependencies, environment files or real secrets are added. No files need deletion or renaming for this package. No Git commit, push or website deployment was performed.

## Complete replacement/new files

| Path | Change |
|---|---|
| `lib/features/admin/presentation/admin_console_page.dart` | One Billing entry; overview and old links route to the correct section. |
| `lib/features/admin/presentation/admin_business_page.dart` | One Billing tab per business; preserves profile/access and audited trade views. |
| `lib/features/admin/presentation/admin_billing_panel.dart` | New accounts/invoices/settings workspace, business picker and per-business billing view. |
| `lib/features/admin/presentation/admin_memberships_panel.dart` | Clear offer cards replacing the wide technical table. |
| `lib/features/admin/presentation/admin_membership_actions.dart` | Shared plain-language activation, offer and issuer-details forms. |
| `lib/features/admin/presentation/admin_widgets.dart` | Real confirmation checkboxes, friendly option labels and simpler billing editing. |
| `lib/features/admin/presentation/platform_invoice_page.dart` | Server-calculated review before creation and clearer document/payment actions. |
| `lib/features/admin/presentation/admin_theme.dart` | Billing icon and compact phone navigation. |
| `lib/features/admin/services/platform_admin_service.dart` | Invoice-preview call and reliable business-name fallback. |
| `lib/features/admin/services/admin_billing_labels.dart` | Bookmark compatibility and human-readable offer/PDF descriptions. |
| `lib/features/admin/services/platform_invoice_pdf.dart` | Plain membership wording in invoice PDFs. |
| `supabase/migrations/20261011022723_simplify_admin_billing.sql` | Complete record of the installed preview and stale-price protection. |
| `supabase/tests/admin_billing_workspace_checks.sql` | Read-only live verification; not required for you to run. |
| `docs/admin/billing-workspace.md` | Usage, installation and verification guide. |
