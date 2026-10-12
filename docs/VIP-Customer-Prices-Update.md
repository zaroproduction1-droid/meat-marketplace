# VIP customer prices update

## Install

Stop the running Flutter app. Extract `CutLink-VIP-Customer-Prices-Update.zip`
directly into `C:\Projects\meat-marketplace`, accepting the replacement file.
The ZIP starts with `lib/`, `test/`, `supabase/` and `docs/`, with no extra folder.
Apply it after earlier CutLink replacement ZIPs.

No dependency installation, environment changes or file deletions are needed.
The Supabase migration has already been applied to the connected NSW Meat
Marketplace project (`wqdfimgaqqnhptxyarvm`). You do not need to run SQL or open
the Supabase dashboard. The migration file records the already-applied change
and uses the same version as the live migration history.

## Files

| File | Change |
| --- | --- |
| `lib/features/pricing/presentation/quick_price_management_page.dart` | Complete replacement: loads butcher logos, queues customer edits, and sends all pending prices through the transactional save function. |
| `lib/features/pricing/presentation/vip_customer_prices_dialog.dart` | New responsive inline editor: logos, price boxes, search, Undo, order options and a fixed Save all button. |
| `test/vip_customer_prices_dialog_test.dart` | Browser widget regression tests for editing, searching, validation, retry, closing, phone layout and repeated saves. |
| `supabase/migrations/20261012105725_supplier_bulk_price_changes.sql` | Already-applied atomic save function; retains existing row-level security and checks supplier/customer/product ownership. |
| `supabase/tests/supplier_bulk_price_changes_test.sql` | Admin-only backend verification using synthetic rows, with an explicit rollback. Already run for this delivery. |
| `docs/VIP-Customer-Prices-Update.md` | Installation and verification guide. |

## How it works

1. Open supplier **Inventory & Pricing**, then a product's **VIP customer prices**.
2. Click a butcher's price box and type the agreed GST-inclusive price.
3. Edit other butchers in the same window. Search keeps your hidden edits.
4. Click **Save all changes** once. The window stays open and shows confirmation.

Registered butcher logos use the existing business-branding bucket and logo
paths. A butcher without an uploaded logo gets an initials badge; an unavailable
image also falls back to the badge.

**Order options** expand within each row for price basis and optional minimum
quantity. Catch-weight prices stay per kg, with whole-carton minimums. Undo
restores that row's saved price and order options. Clearing an existing price
does not delete it; a valid amount or Undo is required before saving.

Closing the window keeps edits in the inventory page's existing queue. They can
be saved with the page's Save all button or continued by reopening the window.
This queue is held in memory: save before refreshing the browser or leaving the
inventory screen. Standard, trade and individual VIP prices share the save queue.

The server creates missing customer lists, assigns customers and saves all prices
in one transaction. Any rejected row rolls the whole transaction back. Failed or
timed-out requests keep edits so they can be retried; repeats reuse existing
price rows and customer lists. Inputs are limited to 1000 changes / 1 MiB per
request. Shared private lists remain managed through Price Lists; individual VIP
editing rejects a list assigned to more than one butcher.

## Run locally

```powershell
Set-Location "C:\Projects\meat-marketplace"
dart format lib/features/pricing/presentation/quick_price_management_page.dart lib/features/pricing/presentation/vip_customer_prices_dialog.dart test/vip_customer_prices_dialog_test.dart
flutter analyze
flutter test --platform chrome test/vip_customer_prices_dialog_test.dart
flutter run -d chrome
```

Try two different butcher prices, save once, then close and reopen the editor.
Confirm that both values persisted. Also try searching while you have unsaved
edits, Undo, and a negative price. A negative or invalid price should prevent
saving and leave the edits available to correct.

## Verification

- Full Dart source/test analysis: no issues found after cleanup.
- 24 isolated PostgreSQL pricing, retry, rollback and access checks passed.
- 14 live Supabase checks passed under the authenticated/anonymous database
  roles. Synthetic data was rolled back; no synthetic businesses remained.
- The function is SECURITY INVOKER, with a fixed search path, authenticated
  execute access and no anonymous execute access. Existing RLS remains enabled.
- Security and performance advisors were run. The new function is not listed in
  the security findings; existing wider-project advisories remain outside this UI
  update. Required existing SECURITY DEFINER functions were preserved.
- All 10 Chrome browser widget tests passed with Flutter 3.44.9 / Dart 3.12.2,
  including desktop editing, phone layout and keyboard, hidden invalid drafts,
  inline order options, search retention, retry, Undo and repeated-save protection.

The browser widget tests use synthetic customers and a mock save callback. The
backend tests separately execute the actual save function and RLS. Your local
VS Code environment and signed-in localhost session have not been tested here.
