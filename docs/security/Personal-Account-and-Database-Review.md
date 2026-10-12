# CutLink personal-account fix and database-to-app review

## Completed change

Both supplier and butcher Settings now include **My account**. It loads the signed-in person's existing `profiles.first_name`, `profiles.last_name` and `profiles.phone` and saves those same fields on that same profile row. Sign-in email is displayed read-only. No new identity table or duplicate contact record was introduced.

Registration already collects these three fields in AccountDetailsPage. The existing account-creation process populates the profile; support ticket creation and message sending use that profile name. The missing piece was a settings screen for later edits. This fixes one missing settings section covering three existing fields.

Business identity, personal identity and billing contacts remain distinct:

| Identity | Where managed | Purpose |
| --- | --- | --- |
| Personal first/last name and phone | Settings → My account | The signed-in person; support sender identity |
| Trading/legal name, business email/phone/address | Settings → Business profile | The business identity |
| Butcher accounts contact name/email/phone | Settings → Billing & accounts | The person/team handling accounts |
| Supplier invoice and salesperson details | Settings → Invoice settings | Invoice contact, payment details and salesperson defaults |

Changing the personal name affects newly created support tickets and newly sent messages. Existing tickets and messages preserve the name recorded at the time. This avoids silently rewriting communication history. No existing customer name has been replaced automatically.

## Findings and limits

The live public schema scan covered **77 tables/views and 1,086 columns**, compared against the current Flutter source and **220 live public/cutlink_private function definitions**.

- One confirmed personal-settings gap: **three fields**, fixed in this update.
- Four identity/contact tables were reviewed in detail: profiles (8 columns), businesses (17), butcher_billing_profiles (14), supplier_invoice_profiles (22): **61 columns**. Business, billing and invoice contact controls exist; IDs, timestamps, business type and access/verification flags are internal or admin-managed. Blank billing contacts do not override personal names.
- **925 columns** have an exact quoted field-name mention somewhere in Flutter. A name appearing in code does not itself prove a working editable control, and shared column names can refer to another table.
- **161 columns** do not have that exact quoted mention. Of these, **143** have an explicit name mention in inspected database routines.
- **18 candidates** have neither an exact quoted Flutter field-name mention nor an explicit field-name mention in inspected routines. These are listed below. They are **not 18 proven unnecessary columns**.
- **Zero columns were approved for deletion or deleted.** A field may be used through select-star, to_jsonb(row), generated clients, views, defaults, foreign keys, triggers, historical data, service integrations or legacy compatibility. The scan does not prove the absence of these uses. Private-schema tables, Auth internals, Storage internals and integrations outside the supplied project are outside the public-column inventory.

The included Supabase-Field-Reference-Inventory.json lists every public column and its matching Flutter files and live routine names. It contains schema/source metadata only, with no customer records or credentials. Routine mentions are source evidence, not proof of an end-user screen or end-to-end reachability.

## Candidates requiring review before any removal

| Database field | Finding/action |
| --- | --- |
| `business_notification_dismissals.deleted_at` | Notification lifecycle metadata; verify retention and table consumers. |
| `business_notification_reads.read_at` | Read timestamp; can be consumed through select-star, row JSON or table defaults. |
| `invoices.customer_payment_claimed_at` | Potential legacy claim timestamp; current account-payment submission flow has separate records. |
| `invoices.customer_payment_claimed_by` | Potential legacy claim actor; inspect historical invoice compatibility before removal. |
| `meat_animals.image_asset_key` | Potential legacy asset mapping; Flutter currently uses its catalogue asset registry. |
| `meat_attribute_options.attribute_type_id` | Relational link; inspect constraints and joins, not a customer settings input. |
| `meat_grade_systems.authority_name` | Catalogue reference metadata; possible absent admin control. |
| `meat_grades.numeric_value` | Catalogue numeric metadata; inspect grade sorting and future catalogue needs. |
| `meat_specifications.unece_code` | Optional standards metadata; possible absent admin control. |
| `meat_specifications.canonical_specification_id` | Canonical catalogue linkage; inspect foreign keys and reconciliation needs. |
| `order_issue_items.quantity_affected` | Potential order-issue UI gap; inspect quantity-specific returns before editing/removal. |
| `supplier_delivery_drivers.linked_user_id` | Potential driver login feature linkage; not an ordinary contact name. |
| `supplier_delivery_runs.legacy_run_number` | Legacy compatibility field; preserve until historical dependencies are proved absent. |
| `supplier_delivery_vehicles.capacity_notes` | Optional vehicle notes; potential missing delivery settings input. |
| `supplier_inventory_stock_ledger.changed_at` | Audit timestamp; do not remove solely because it has no form field. |
| `supplier_offer_attributes.supplier_offer_id` | Relational link; inspect offer model and joins. |
| `supplier_offer_attributes.attribute_option_id` | Relational link; inspect offer model and joins. |
| `vip_trade_applications.withdrawn_at` | Application lifecycle timestamp; possible withdrawal feature gap. |

Some potential feature gaps are vehicle capacity notes, quantity-specific order issues, catalogue standards/authority metadata and withdrawal tracking. These require workflow decisions and dependency verification; they have not been labelled dead data or silently removed.

## Installation

Stop Flutter and extract this ZIP directly into `C:\Projects\meat-marketplace`, merging lib/, test/ and docs/ into the existing folders. Replace matching files. No enclosing folder is included.

Complete files:
- lib/features/authentication/presentation/personal_account_settings_page.dart — new shared personal-account editor.
- lib/features/orders/presentation/butcher_settings_page.dart — adds My account to butcher settings, preserves existing settings and branding.
- lib/features/orders/presentation/supplier_settings_page.dart — adds My account to supplier settings, preserves existing settings and branding.
- test/personal_account_settings_test.dart — four mocked UI tests.
- docs/Personal-Account-and-Database-Review.md — this report and installation/testing instructions.
- docs/Supabase-Field-Reference-Inventory.json — schema/source reference inventory.

No migrations, new dependencies, environment settings, file deletions or renames are required. Existing support and VIP request changes are retained; this ZIP does not replace those pages. No commit, push or deployment was performed.

## Verification

- Flutter analysis: clean in the prepared project here.
- Four Chrome widget tests: existing values, save payload limited to the three personal fields, required first name, repeat-click protection, failure retention and phone layout.
- Live Supabase rollback test under authenticated user privileges: own profile name update succeeded; attempts to update other profiles changed zero rows. The transaction was rolled back and the original name was verified unchanged afterward.
- Existing own-row RLS policies and administrative-flag protection were inspected. No access-policy changes were required. The client updates only first_name, last_name and phone; it does not submit business_type or is_admin.

These checks do not claim to test your local VS Code installation or an actual delivered admin support reply.

## Manual test

1. Run dart format on the four Dart files, then flutter analyze in the project root.
2. Start with flutter run -d chrome.
3. Sign in as a butcher, open Settings → My account, and confirm the currently stored personal name appears.
4. Enter the correct first/last name and optional personal phone. Save, leave the page and reopen it to confirm persistence.
5. Submit a new missing-item support request. Check that the new ticket and new messages use the saved personal name.
6. Check an older ticket: its original recorded name remains unchanged.
7. Repeat for a supplier account. Business and billing details must remain unchanged.

Registration also contains original signup Auth metadata. The profile row is the operational source used by support. This update does not copy billing contacts into personal profiles or edit original signup metadata.
