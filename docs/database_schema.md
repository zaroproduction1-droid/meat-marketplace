# Database Schema

## Authentication and businesses

- profiles
- businesses
- business_memberships

## Product catalogue

- animal_types
- cuts
- products

## Pricing

- price_lists
- price_list_customers
- product_prices

## Current pricing relationships

- One supplier can have multiple price lists.
- One price list can contain prices for multiple products.
- Public price lists are intended for all approved buyers.
- Approved-customer price lists are intended for approved supplier customers.
- Private price lists are assigned to specific butcher businesses.
- One product can have a different price on multiple price lists.

## Current product relationships

- One animal type has many cuts.
- One supplier business has many products.
- One product belongs to one animal type.
- One product belongs to one cut.

## Supplier customer relationships

- supplier_customer_relationships

## Relationship rules

- A butcher can request access to a supplier.
- A supplier can approve, decline or suspend the relationship.
- Approved-customer pricing requires an approved relationship.
- Private contract pricing requires the butcher to be assigned directly to the price list.
- Public pricing is available to approved butcher businesses.

## Canonical Meat Catalogue

### species

Top-level animal category.

Initial marketplace species:

- Beef
- Lamb
- Chicken
- Goat

Pork is not supported.

### primal_sections

Major anatomical sections belonging to a species.

Example:

Beef → Chuck

### subprimal_sections

Subdivisions belonging to a primal section.

Example:

Beef → Chuck → Blade

The old animal_types and cuts tables remain temporarily while the application is migrated to the canonical catalogue structure.

### meat_products

Canonical meat cuts/products belonging to a sub-primal section.

Example:

Beef
→ Chuck
→ Blade
→ Oyster Blade

This table describes what the cut/product actually is and contains no supplier-specific pricing, SKU or stock information.
### product_aliases

Alternative/common names that point back to one canonical meat product.

Example:

Oyster Blade
- Oyster Blade Steak
- Blade Muscle

### product_codes

Stores future verified product codes such as marketplace codes or recognised industry codes.

AUS-MEAT codes will only be added after verification.
### Supplier product catalogue link

The existing products table now contains:

- product_variant_id

This links a supplier's listing to the canonical meat catalogue.

Existing animal_type_id and cut_id relationships remain temporarily for backwards compatibility while Flutter is migrated.

Current relationship:

businesses
→ products
→ product_variants
→ meat_products
→ subprimal_sections
→ primal_sections
→ species

Existing pricing continues to reference products.id and is not changed by this migration.