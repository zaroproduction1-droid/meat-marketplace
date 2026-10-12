# CutLink missing item requests

Extract this ZIP directly into C:\Projects\meat-marketplace. The lib/, test/ and docs/ folders must merge with the existing folders; overwrite the three existing Dart pages. No extra parent folder is included.

## Behaviour

Inventory & Pricing, Supplier Sales and Butcher Browse Products have a Request missing item button. At narrower widths it uses a compact icon with the Request a missing item tooltip. On phones it joins the existing scrollable page controls.

The form asks for request type, item name and optional details. It includes the originating page, selected animal, cut/region, specification/grade identifiers where available and current search. It sends a Products & Pricing support ticket with the subject Missing item: [name], then opens that ticket's support conversation. Admin receives the request through the existing Support Centre. Existing chat supports follow-up messages and attachments.

Requests are suggestions for admin review; submitting one does not add products, alter inventory, promise availability or place orders. The supported animals remain unchanged.

Sending disables repeated clicks and closing while the response is pending. Failed submissions preserve typed details. If confirmation fails, check Support before resubmitting because a connection can fail after the server has accepted a request.

## Complete files included

- lib/features/pricing/presentation/quick_price_management_page.dart: button and context in Inventory & Pricing; preserves the previous VIP inline pricing changes.
- lib/features/orders/presentation/supplier_sales_page.dart: button and context in Supplier Sales.
- lib/features/marketplace/presentation/marketplace_products_page.dart: button and context in Butcher Browse Products.
- lib/features/support/presentation/missing_item_request_button.dart: shared responsive button and request form; uses the existing authenticated create_support_ticket function and opens the existing support chat.
- test/missing_item_request_test.dart: mocked widget tests for validation, request context, duplicate-click protection, error retention and phone layout. These tests do not write to Supabase.
- docs/Missing-Item-Requests.md: installation and testing instructions.

No new dependencies, environment settings, migrations, deletions or renames are required. Existing business access checks, support rate limiting and support row-level security remain in use. Database configuration was inspected read-only; no live data was changed for this update.

## Manual verification

1. Stop the running Flutter process, extract the files and run dart format followed by flutter analyze in the project root.
2. Run flutter run -d chrome and sign in as a supplier.
3. Open Inventory & Pricing, select an animal and request a missing specification. Confirm the support chat opens with your request and page context.
4. Return to Sales and try the same button there.
5. Sign in as a butcher and open Browse Products. Submit a missing item request.
6. Sign in as admin, open Support and locate each Missing item ticket. Reply and confirm the business can see the reply. These manual submissions create real support tickets in your connected development database.
7. Check at desktop and phone widths. Invalid empty names must not submit; a submission error must retain the draft.

Automated widget tests use a fake submit callback. They verify the client form without claiming to test a signed-in user's local browser or actual delivered admin replies.
