# Meat Catalogue Architecture

## Purpose

This document defines the long-term meat product structure for the marketplace.

The structure must support:

- Species
- Primal sections
- Sub-primal sections
- Meat products / cuts
- Product variants and specifications
- Alternative/common product names
- Future industry product codes
- Supplier product listings
- Supplier-specific availability
- Public pricing
- Approved-customer pricing
- Private contract pricing
- Future purchasing
- Future sales/orders
- Future invoicing
- Future analytics
- Future visual animal browsers

Pork is not supported by this marketplace and must not be added to the catalogue.

---

# Core hierarchy

The canonical meat catalogue will follow:

Species
→ Primal Section
→ Sub-primal Section
→ Meat Product / Cut
→ Product Variant / Specification
→ Supplier Product

Example:

Beef
→ Chuck
→ Blade
→ Oyster Blade
→ Fresh / Boneless / Trim specification
→ Supplier listing

---

# 1. species

Represents the animal species/category.

Examples:

- Beef
- Lamb
- Chicken
- Goat

Pork must not be added.

Suggested fields:

- id
- name
- slug
- description
- active
- display_order
- created_at
- updated_at

Example:

name: Beef
slug: beef

---

# 2. primal_sections

Represents the major anatomical section of the animal.

Each primal section belongs to one species.

Example:

Beef
→ Chuck

Suggested fields:

- id
- species_id
- name
- slug
- description
- active
- display_order
- diagram_key
- created_at
- updated_at

diagram_key will later allow the interactive animal diagram to link a clickable region to the database.

Example:

species: Beef
name: Chuck
diagram_key: beef_chuck

---

# 3. subprimal_sections

Represents a subdivision underneath a primal section.

Example:

Beef
→ Chuck
→ Blade

Suggested fields:

- id
- primal_section_id
- name
- slug
- description
- active
- display_order
- created_at
- updated_at

---

# 4. meat_products

Represents the canonical meat cut/product.

This is not supplier-specific.

Example:

Beef
→ Chuck
→ Blade
→ Oyster Blade

Suggested fields:

- id
- subprimal_section_id
- name
- slug
- description
- active
- display_order
- created_at
- updated_at

This table represents what the product actually is.

It must not contain supplier-specific information such as:

- Supplier SKU
- Supplier price
- Supplier stock quantity
- Supplier brand
- Supplier availability

---

# 5. product_variants

Represents a specific variation or specification of a canonical meat product.

Example:

Oyster Blade
→ Fresh
→ Boneless
→ Trim specification
→ Pack specification

Suggested fields:

- id
- meat_product_id
- variant_name
- temperature_state
- bone_state
- trim_specification
- fat_specification
- weight_min
- weight_max
- weight_unit
- pack_size
- pack_unit
- grade
- breed
- halal_status
- country_of_origin
- specification_notes
- active
- created_at
- updated_at

Not every field must contain a value.

The purpose of this table is to allow multiple recognised specifications of the same canonical cut.

Example:

Meat product:
Oyster Blade

Variant:
Fresh Boneless Oyster Blade 2–4 kg

Another variant:
Frozen Boneless Oyster Blade 2–4 kg

---

# 6. product_aliases

Stores alternative or commonly used names for canonical meat products.

Suggested fields:

- id
- meat_product_id
- alias
- alias_type
- active
- created_at

Possible alias types:

- common
- regional
- trade
- historical
- supplier terminology

Example:

Canonical product:
Oyster Blade

Possible aliases:
- Oyster Blade
- Flat Iron source muscle
- Blade muscle

Aliases must point back to one canonical meat product.

---

# 7. product_codes

Stores industry or marketplace codes.

Suggested fields:

- id
- meat_product_id
- product_variant_id
- code_system
- code
- description
- active
- created_at

Possible future code systems:

- AUS-MEAT
- Marketplace
- Supplier
- Other recognised industry system

We will not populate AUS-MEAT codes until the catalogue structure is final and the codes are verified.

---

# 8. Existing products table

The existing products table currently represents a supplier's product listing.

We will keep this table.

It will eventually behave as the supplier_products table.

A new relationship will later be added:

product_variant_id

Conceptually:

products
- id
- supplier_business_id
- product_variant_id
- sku
- product_name
- brand
- temperature_state
- available_quantity
- quantity_unit
- availability_status
- active
- created_at
- updated_at

Existing product data must not be deleted during the migration.

The old animal_type_id and cut_id fields can remain temporarily while Flutter is migrated to the new structure.

They will only be retired after the new catalogue works correctly.

---

# Supplier product relationship

The relationship will be:

businesses
→ products
→ product_variants
→ meat_products
→ subprimal_sections
→ primal_sections
→ species

This means the supplier is linked to the actual product they sell rather than merely being linked to a generic animal section.

Example:

Supplier A
→ Supplier product SKU BEEF-001
→ Fresh Boneless Oyster Blade
→ Oyster Blade
→ Blade
→ Chuck
→ Beef

---

# Pricing relationship

The existing pricing architecture remains:

products
→ product_prices
→ price_lists

Price-list visibility remains:

1. Private contract
2. Approved customer
3. Public

The marketplace must select the most specific authorised price.

---

# Customer relationships

The existing supplier_customer_relationships table remains.

It controls whether a butcher has:

- Public access only
- Approved-customer access
- Supplier relationship status

Private pricing remains controlled separately through:

price_list_customers

---

# Future ordering relationship

Orders will later reference the supplier product.

Example:

order
→ order_item
→ products.id

The order item must also store a price snapshot so historical orders do not change when the supplier later changes their current price.

Potential future order item fields:

- product_id
- product_name_snapshot
- quantity
- quantity_unit
- unit_price
- price_basis
- line_total

This will be designed during the ordering phase.

---

# Future purchasing and sales

Purchasing and sales records will eventually reference supplier products and canonical meat products.

This will allow analytics such as:

- Purchase quantity
- Purchase cost
- Sale quantity
- Sale revenue
- Gross profit
- Gross margin
- Spend by supplier
- Sales by customer
- Product popularity
- Product profitability

These tables will not be created during the current catalogue phase.

---

# Future invoicing

Invoices will be built only after the order and sales structure is stable.

Invoice lines must preserve historical values rather than dynamically reading today's product price.

---

# Future animal browser

The interactive animal browser will use the primal_sections table.

Example:

Cow diagram
→ user clicks Chuck
→ primal_sections.diagram_key = beef_chuck
→ display Chuck sub-primals
→ display meat products
→ display supplier products
→ display authorised supplier price

The diagram will not contain the product database itself.

It will only act as a visual navigation layer over the catalogue.

---

# Security architecture

Suppliers never receive direct database administration access.

Supabase remains the backend database.

Suppliers and butchers access data through the marketplace application.

Supabase Row Level Security must continue enforcing:

- Suppliers can access their own supplier data
- Butchers can access authorised marketplace data
- Public prices remain visible to approved marketplace buyers
- Approved-customer pricing requires supplier approval
- Private pricing requires specific price-list assignment
- Admin-only actions require is_admin = true

CSV and Excel exports will later use the same authorisation rules.

---

# Migration strategy

We will not replace the current catalogue in one step.

Migration order:

1. Create the new catalogue tables.
2. Add Beef as the first full test species.
3. Add several Beef primal sections.
4. Add several sub-primal sections.
5. Add several canonical meat products.
6. Add product variants.
7. Add product_variant_id to the existing products table.
8. Link one existing supplier product to the new catalogue.
9. Update Flutter product creation/editing to use the new catalogue.
10. Update marketplace browsing.
11. Confirm pricing still works.
12. Migrate remaining products.
13. Retire the old flat animal_types/cuts relationship only after all dependencies have been removed.

No existing working product or pricing data should be deleted during this migration.

---

# Current Phase 2 objective

The immediate objective is to establish a stable canonical meat catalogue before building:

- Ordering
- Purchasing
- Sales
- Invoicing
- Interactive animal diagrams
- Analytics
- CSV/Excel exports