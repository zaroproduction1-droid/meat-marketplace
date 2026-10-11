# CutLink image upload fix

## Install

Stop the running Flutter app. Extract `CutLink-Image-Upload-Fix.zip` directly into
`C:\Projects\meat-marketplace`, allowing the existing file to be replaced. The
ZIP begins with `lib/`, `test/` and `docs/`; do not put them inside another folder.
Apply this fix after any older replacement ZIPs.

No files need deleting or renaming. No new dependency, environment setting,
database migration or Supabase setting is required for this client-side fix.

## Files

| Path | Purpose |
| --- | --- |
| `lib/shared/security/upload_safety.dart` | Replaces the unsupported web dimension lookup with a cross-platform first-frame decode and disposes its image/codec resources. |
| `lib/shared/security/upload_image_dimensions.dart` | New PNG/JPEG/WebP header reader; rejects oversized images before decoding pixels. |
| `test/fixtures/upload_image_fixtures.dart` | Synthetic image fixtures only; no customer logos or personal information. |
| `test/upload_image_dimensions_check.dart` | Header, file-type, size and dimension regression checks. |
| `test/upload_safety_web_test.dart` | Browser decode tests for valid formats, corrupt data and oversized images. |
| `docs/security/image-upload-fix.md` | Installation, explanation and verification steps. |

## What caused the error

The previous helper used `ImageDescriptor.encoded(...).width` and `.height`.
Those getters are unsupported for encoded images in Flutter web. Its catch block
reported valid images as files that could not be decoded. This was a client-side
validation failure before the storage upload.

The shared helper is already used by supplier settings, butcher settings and the
product photo editor. Their call sites do not need changing.

## Limits and quality

- Logos remain PNG/JPG only. Product photos can additionally use WebP.
- Existing limits remain: 5 MiB, 8192 pixels per side, and 24 million pixels.
- Filename extensions must match the detected file type.
- A valid header alone is insufficient: a platform first-frame decode must also succeed.
- The 64-pixel decode is a validation preview only. The original uploaded bytes
  are unchanged, so the uploaded logo/photo is not resized or recompressed.
- The platform may decode the full image before scaling. Header limits bound
  accepted dimensions; this is not a guarantee of a fixed memory allocation.
- These checks are client-side defence in depth. Existing storage permissions
  and server-side controls remain necessary; this fix is not a malware scanner.

## Test in your project

Run the following in PowerShell from your existing project after copying the files:

```powershell
Set-Location "C:\Projects\meat-marketplace"
dart format lib/shared/security/upload_safety.dart lib/shared/security/upload_image_dimensions.dart test/fixtures/upload_image_fixtures.dart test/upload_image_dimensions_check.dart test/upload_safety_web_test.dart
flutter analyze
dart run test/upload_image_dimensions_check.dart
flutter test --platform chrome test/upload_safety_web_test.dart
flutter run -d chrome
```

In supplier or butcher settings, choose the original attached logo (`images.jpg`)
and save it. Confirm that the preview and saved logo appear. Also try a valid PNG
logo and a product photo. A renamed non-image file and an image over the limits
should still be rejected. Your attached logo is a valid JPEG; keep its `.jpg`
extension rather than renaming it to `.png`.

The automated tests do not log in, write customer data or upload to Supabase.
Live storage and your local VS Code environment are not tested by these tests.

## Verification performed for this delivery

- Formatted the changed Dart files.
- Full source `lib` and `test` analysis: no issues found.
- Standalone header/limit checks: 34 passed, including both supplied attachments
  (200 x 200 JPEG logo and 597 x 205 PNG screenshot).
- Flutter web tests in Chromium 153 with Flutter 3.44.9 / Dart 3.12.2:
  12 passed (the 10 included regression tests plus two local-only tests decoding
  the exact supplied attachments). Those attachment images are not included in
  this ZIP or the synthetic fixtures.
- Verified the ZIP contents and CRCs. The archive includes only the six paths
  listed above, with no extra enclosing folder.
