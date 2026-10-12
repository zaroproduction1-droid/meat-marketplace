# CutLink clear pricing and founding availability

Extract **CutLink-Clear-Pricing-Fix.zip** into **C:\Projects\meat-marketplace**, your existing project root. Replace the matching files. The ZIP contains `lib/`, `supabase/` and `docs/` directly, with no extra enclosing folder. It updates the existing restored project; it is not a replacement for the whole project.

## What changes

White pricing page with a supplier/butcher switch, a clear regular monthly price and two burgundy-and-gold founding cards. Large **FREE** and **for your first 6 months** labels replace compact price notation. Subsequent prices are shown on each card. Smooth entry, role-switch and hover effects respect reduced motion. Narrow screens and larger text stack the cards.

Refresh makes a new request, shows loading and reports success or failure. Unknown availability never invents counts; paused and filled offers are explicit. Registration does not reserve a place. The public page, member summary, new-account defaults and managed invoice calculations use matching prices and cent rounding.

All amounts are **AUD and GST inclusive**:

| Membership | First 6 months | Next 12 months | After that |
|---|---|---|---|
| First 10 suppliers | Free | $175.00/month | $349.99/month |
| Next 5 suppliers | Free | $349.99/month | $349.99/month |
| Standard supplier | $349.99/month | $349.99/month | $349.99/month |
| First 10 butchers | Free | $100.00/month | $199.99/month |
| Next 15 butchers | Free | $199.99/month | $199.99/month |
| Standard butcher | $199.99/month | $199.99/month | $199.99/month |

The half-price year rounds to the nearest cent, consistently in the app and database. Free months start when CutLink confirms membership, not at signup. Founding places follow genuine membership confirmation order separately for suppliers and butchers.

## Required Supabase setup

The inspected project was missing the founding pricing tables and public pricing function. Refresh could not resolve that missing setup. **Copying files alone does not install database changes.** No live migration was applied in this session.

1. Open Supabase Dashboard → SQL Editor for project **wqdfimgaqqnhptxyarvm**. Confirm the project reference. If available, test in an isolated copy first; do not consume live places with test businesses.
2. Open **supabase/migrations/20261011013438_cutlink_clear_pricing.sql** in VS Code. Copy the **entire file**, paste into SQL Editor and run once. This complete installer installs the missing module and corrects prices, or upgrades an installed module. Do not run the older founding migration separately afterward. Do not use a blanket `supabase db push`: the local project lacks some historical migrations.
3. The file runs in one transaction. Before installing a missing module it checks the inspected billing functions. Changed functions or partial installation cause rollback rather than overwriting unknown changes. If it reports a mismatch, retain the exact error and request a backend review; do not remove the checks.
4. Run **supabase/tests/founding_memberships_checks.sql** in SQL Editor. It is read-only, checks prices, grants, RLS and counts, and rolls back. Review Database Advisors afterward. Public pricing intentionally exposes aggregate prices/counts without business identities.
5. Newly installed offers start **paused**. Use **Admin → Pricing & Memberships** to open the supplier and/or butcher offer when ready. An upgrade preserves existing offer-open settings. Opening requires a reason and does not allocate places automatically.
6. Restart the app and refresh pricing. Verify a real count or accurate paused/full label. If the request still fails, check the SQL Editor result and the app's Supabase project configuration. The installer requests a PostgREST schema-cache refresh.

No new dependencies, credentials or environment variables are required. No files need deletion or renaming. Existing configuration and assets remain in your project.

## Local checks

Run in VS Code PowerShell at **C:\Projects\meat-marketplace**:

```powershell
dart format lib/features/landing/presentation/cutlink_pricing_page.dart lib/features/memberships/services/membership_service.dart lib/features/memberships/presentation/membership_summary.dart lib/features/admin/presentation/admin_widgets.dart
flutter analyze
```

Then use your existing Chrome launch workflow. Check both roles at narrow/wide widths, larger text, reduced motion, registration role selection and refresh feedback. In an isolated database, test open/paused/full states and free/discounted/regular invoices. Review a rendered invoice before issuing real bills. Verify the issuer's legal name, ABN and GST settings.

## Billing and data preservation

Managed accounts retain the regular fee in `monthly_fee`; the backend calculates each period's applicable amount. Supplier standard total: **$349.99 = $318.17 + $31.82 GST**. Butcher standard: **$199.99 = $181.81 + $18.18 GST**. Discounted totals remain **$175.00** and **$100.00**. If the issuer is not GST registered, the agreed total remains unchanged and GST is zero.

Existing legacy/custom fees, issued invoices and recorded payments are preserved. Only accounts enrolled in the managed module receive the new regular fee. Membership dates, allocations, revocations and offer-open settings are preserved. Existing businesses are not automatically enrolled.

Existing admin review, authorization and audit controls remain. Enrolment requires an active approved business, active member, genuine-business confirmation and a reason; administrator-owned businesses are excluded. Do not use genuine enrolment for test/development accounts. Repeat activation never restarts an offer. Cancelled/revoked positions are retained. Tier changes/revocations need a reason and resolution of invoices covering affected periods. Billing periods stay anchored to the original activation date, including month-end handling.

Invoices and verified payments use the existing internal admin workflow. This package adds no automatic charges, recurring invoice jobs or automatic email delivery.

## Verification and limits

- **147 isolated PostgreSQL checks passed on each path:** missing module and existing module. Coverage includes allocation, eligibility, authorization, RLS/grants, free/discounted/regular totals, GST, invoice retries, cancellation/revocation, legacy fees and repeat installation.
- The included read-only SQL smoke checks passed in the isolated database.
- **65 pure Dart checks passed**, with no standalone analyzer issues. They exercise the page's actual pricing-state model and shared price calculations, including availability, cohort boundaries, malformed responses and cent rounding.
- Changed Dart files were parsed/formatted; ZIP contents, CRC and byte matching were verified.

Full Flutter analysis, widget/browser rendering and your local VS Code environment were not tested here. PostgreSQL checks used synthetic data and relevant schema fixtures, not a complete Supabase staging clone or simultaneous multi-connection approvals. Live installation and post-install advisors remain manual steps. No commit, push or deployment was performed.

## Complete replacement/new files

| Project-relative path | Reason |
|---|---|
| `lib/features/landing/presentation/cutlink_pricing_page.dart` | Clear royal offer cards, responsive layout and refresh feedback. |
| `lib/features/memberships/services/membership_service.dart` | Shared regular prices, cent rounding and plain stage labels. |
| `lib/features/memberships/presentation/membership_summary.dart` | Plain member offer wording and matching discounted amounts. |
| `lib/features/admin/presentation/admin_widgets.dart` | Correct defaults for new billing accounts. |
| `supabase/migrations/20261011013438_cutlink_clear_pricing.sql` | Complete guarded installer and managed billing price correction. |
| `supabase/tests/founding_memberships_checks.sql` | Read-only setup, price, rounding and access checks. |
| `docs/memberships/founding-memberships-setup.md` | Installation, data preservation and verification instructions. |
