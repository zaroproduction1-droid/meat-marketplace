$ErrorActionPreference = "Stop"

$root = (Get-Location).Path

$customer = Join-Path $root "lib\features\customers\presentation\supplier_customer_requests_page.dart"
$market = Join-Path $root "lib\features\marketplace\presentation\marketplace_product_details_page.dart"
$edit = Join-Path $root "lib\features\products\presentation\edit_product_page.dart"

foreach ($file in @($customer, $market, $edit)) {
    if (-not (Test-Path $file)) {
        throw "File not found: $file"
    }
    Copy-Item $file "$file.bak" -Force
}

# 1) supplier_customer_requests_page.dart
# Change only the DropdownButtonFormField's selected value property.
$text = Get-Content $customer -Raw
$old = "value: paymentMethod,"
$new = "initialValue: paymentMethod,"
if ($text -notmatch [regex]::Escape($old)) {
    Write-Host "Customer page: target was already fixed or not found."
} else {
    $text = $text.Replace($old, $new)
    Set-Content $customer $text -NoNewline
    Write-Host "Fixed deprecated DropdownButtonFormField value."
}

# 2) marketplace_product_details_page.dart
# Remove only the unused declarations immediately after visiblePrice?.
$text = Get-Content $market -Raw

$patternAmount = "(?m)^\s*final amount = visiblePrice\?\['amount'\];\r?\n"
$patternBasis  = "(?m)^\s*final priceBasis = visiblePrice\?\['price_basis'\]\?\.toString\(\);\r?\n"

$before = $text
$text = [regex]::Replace($text, $patternAmount, "", 1)
$text = [regex]::Replace($text, $patternBasis, "", 1)

if ($text -eq $before) {
    Write-Host "Marketplace page: unused target declarations were already fixed or not found."
} else {
    Set-Content $market $text -NoNewline
    Write-Host "Removed unused marketplace amount/priceBasis declarations."
}

# 3) edit_product_page.dart
$text = Get-Content $edit -Raw

# Remove the unnecessary null assertion if still present.
$text = $text.Replace("savingText!", "savingText")

# Remove the obsolete _PrivatePriceListCard class from its declaration to EOF.
$marker = "class _PrivatePriceListCard extends StatelessWidget {"
$index = $text.IndexOf($marker)

if ($index -ge 0) {
    $text = $text.Substring(0, $index).TrimEnd() + [Environment]::NewLine
    Write-Host "Removed unused _PrivatePriceListCard class."
} else {
    Write-Host "Edit Product page: _PrivatePriceListCard was already removed."
}

Set-Content $edit $text -NoNewline

Write-Host ""
Write-Host "All targeted analyzer cleanup is complete."
Write-Host "Backup files were created beside each Dart file with .bak extension."
Write-Host ""
Write-Host "Now run:"
Write-Host "  dart format lib\features\customers\presentation\supplier_customer_requests_page.dart lib\features\marketplace\presentation\marketplace_product_details_page.dart lib\features\products\presentation\edit_product_page.dart"
Write-Host "  flutter analyze"
