# Meat Catalogue Architecture

## Purpose

This document defines the long-term canonical meat catalogue architecture for the marketplace.

The catalogue must support:

- Species
- Flexible product and cut hierarchy
- Unlimited hierarchy depth
- Product variants and specifications
- Common and alternative terminology
- Verified industry codes
- Supplier product listings
- Supplier-specific naming
- Supplier-specific SKU
- Availability
- Public pricing
- Approved-customer pricing
- Private contract pricing
- Future ordering
- Future purchasing and sales
- Future invoicing
- Future analytics
- Future CSV and Excel exports
- Future interactive animal browsers

---

# Core principle

The marketplace must separate:

1. Canonical product identity
2. Product specification
3. Supplier listing
4. Supplier pricing
5. Visual animal anatomy

These are related concepts but must not be forced into one hierarchy.

---

# Canonical hierarchy

The catalogue uses a recursive product hierarchy.

Structure:

Species
→ Meat Product
→ Child Meat Product
→ Child Meat Product
→ any additional required levels
→ Product Variant
→ Supplier Product

Example:

Beef
→ Blade
→ Oyster Blade
→ Fresh Boneless Oyster Blade
→ Supplier listing

The number of meat product levels is not fixed.

A catalogue product may be:

- a top-level commercial family
- a recognised cut
- a child cut
- a structural catalogue grouping
- a recognised saleable product

The database must not assume every product has exactly one primal and one sub-primal parent.

---

# 1. species

Represents the top-level animal category.

Current species:

- Beef
- Lamb
- Chicken
- Goat

Suggested fields:

- id
- name
- slug
- description
- active
- display_order
- created_at
- updated_at

---

# 2. meat_products

Represents canonical meat products, cuts and catalogue families.

This table is recursive.

Important fields:

- id
- species_id
- parent_product_id
- name
- slug
- description
- product_level
- active
- display_order
- created_at
- updated_at

Relationship:

parent_product_id
→ meat_products.id

A root product has:

parent_product_id = null

Example:

Blade

Child product:

Blade
→ Oyster Blade

A deeper hierarchy is also valid where required.

The hierarchy must reflect product relationships rather than forcing every product through a predefined anatomical tree.

---

# 3. Recursive catalogue paths

The database view:

meat_product_catalogue_paths

resolves the complete ancestry of each canonical meat product.

Example output:

Blade

Blade → Oyster Blade

or deeper:

Product A
→ Product B
→ Product C
→ Product D

The view includes:

- species
- current product
- hierarchy depth
- path IDs
- path names
- printable catalogue path

Flutter should use this view instead of manually reconstructing parent relationships.

This prevents the application from depending on a fixed hierarchy depth.

---

# 4. Hierarchy validation

Database validation must protect the catalogue from invalid genealogy.

The hierarchy must reject:

- self-parenting
- circular parent relationships
- parents from another species

A Beef product cannot have a Lamb product as its parent.

A relationship such as:

Blade
→ Oyster Blade
→ Blade

must also be rejected.

These rules are enforced in PostgreSQL rather than relying only on Flutter validation.

---

# 5. product_variants

Represents specific recognised versions or specifications of a canonical product.

Example:

Canonical meat product:

Oyster Blade

Variant:

Fresh Boneless Oyster Blade

Possible specification fields:

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

Not every field must be populated.

Variants describe the product specification.

They must not contain supplier pricing or supplier stock.

---

# 6. product_aliases

Stores recognised alternative terminology for canonical meat products.

Possible alias types:

- common
- regional
- trade
- historical

Example:

Canonical product:

Oyster Blade

Possible recognised aliases can point back to that same canonical product.

Supplier-specific sales descriptions should normally not become global aliases automatically.

If Supplier A describes a product differently from Supplier B, each supplier can keep its own wording in products.product_name.

---

# 7. product_codes

Stores recognised canonical or industry codes.

Possible examples:

- AUS-MEAT HAM
- marketplace-defined code
- other recognised industry systems

Codes may reference:

- meat_product_id
- product_variant_id

Supplier-specific SKU values belong in:

products.sku

Supplier SKU values should not normally be inserted into the global product_codes table.

Industry codes must be verified before insertion.

---

# 8. Supplier products

The existing products table represents a supplier's actual marketplace listing.

Conceptually:

Canonical catalogue

Beef
→ Blade
→ Oyster Blade
→ Fresh Boneless Oyster Blade

Supplier listing

→ Supplier SKU
→ Supplier product name
→ Brand
→ Availability
→ Quantity
→ Supplier-specific description

The supplier listing links to the canonical catalogue through:

products.product_variant_id

This means multiple suppliers can sell the same canonical product while retaining their own:

- SKU
- wording
- brand
- available quantity
- stock status
- origin information
- commercial presentation

---

# Supplier variation

Different suppliers may present meat ranges differently.

A supplier sheet may contain:

- broad commercial headings
- supplier product names
- weight ranges
- brands
- grades
- chilled/frozen differences
- bone state
- trim specifications
- packaging descriptions
- supplier SKU/code
- supplier price

The marketplace should not copy one supplier's product structure and treat it as the universal catalogue.

Supplier data should be mapped to canonical marketplace products where appropriate.

---

# Pricing architecture

Pricing remains supplier-specific.

Relationship:

products
→ product_prices
→ price_lists

Price-list visibility:

1. Private
2. Approved customers
3. Public

The buyer should receive the highest-priority authorised price.

Canonical product hierarchy must not contain pricing.

---

# Supplier customer relationships

supplier_customer_relationships controls supplier/customer approval.

A butcher can:

- browse approved marketplace suppliers
- view authorised public prices
- request supplier access

A supplier can:

- approve a butcher
- decline a butcher
- suspend a relationship

Approved-customer pricing depends on an approved relationship.

Private pricing remains controlled through price_list_customers.

---

# Legacy structures

The following structures remain temporarily:

- animal_types
- cuts
- primal_sections
- subprimal_sections
- products.animal_type_id
- products.cut_id
- meat_products.subprimal_section_id

They are migration structures only.

They must not determine the long-term catalogue architecture.

They will be retired only after:

- all relevant products are migrated
- no Flutter feature depends on them
- future order and pricing dependencies are checked
- migration data has been validated

---

# Future visual animal browser

The animal diagram must be separate from canonical product genealogy.

A cow region such as a body section is a navigation concept.

It is not automatically the parent of every commercial product associated with that area.

Future structure:

species
→ animal_regions

and:

meat_products
↔ meat_product_regions
↔ animal_regions

Possible future animal_regions fields:

- id
- species_id
- name
- slug
- diagram_key
- description
- display_order
- active

Possible future meat_product_regions fields:

- meat_product_id
- animal_region_id
- relationship_type

This allows a product to appear when a butcher clicks a body region without corrupting the canonical product hierarchy.

---

# Supplier application flow

Supplier Add Product:

Species
→ Catalogue Product / Cut
→ Product Variant
→ Supplier Listing

The catalogue product dropdown displays the complete recursive path.

Example:

Blade
Blade → Oyster Blade

Supplier selects:

Blade → Oyster Blade

Then selects:

Fresh Boneless Oyster Blade

The supplier listing then stores product_variant_id.

---

# Supplier Edit Product

Edit Product uses the same recursive catalogue system.

Existing canonical products load:

Species
→ Catalogue Product / Cut
→ Variant

Legacy products can continue to be edited without being forced into the canonical catalogue immediately.

---

# Butcher marketplace

Browse Products displays:

Supplier product name

Supplier

Species
→ complete canonical product path
→ variant

Example:

Fresh Boneless Oyster Blade

Supplier A

Beef
→ Blade
→ Oyster Blade
→ Fresh Boneless Oyster Blade

Search must match:

- species
- every catalogue hierarchy level
- variant
- supplier product name
- SKU
- brand
- supplier name

---

# Product details

The butcher Product Details page displays:

- supplier product name
- supplier
- species
- complete catalogue path
- current canonical product
- variant
- availability
- supplier relationship status

The complete path must support unlimited hierarchy depth.

---

# Future ordering

Orders will reference supplier products.

Relationship:

orders
→ order_items
→ products.id

Each order item must store snapshots of important values at the time of purchase.

Potential snapshot fields:

- product_id
- supplier_product_name
- quantity
- quantity_unit
- unit_price
- price_basis
- line_total
- tax information
- catalogue description if required

A historical order must not change if the supplier later edits the live product or price.

---

# Future purchasing and sales

Purchasing and sales records will later reference supplier listings and canonical catalogue products.

This will support:

- purchase quantity
- purchase cost
- sale quantity
- sale revenue
- gross profit
- gross margin
- spend by supplier
- sales by customer
- product popularity
- product profitability

---

# Future invoicing

Invoices will be developed after ordering and sales structures are stable.

Invoice lines must preserve historical values.

---

# Security architecture

Suppliers and butchers interact only through the marketplace application.

They do not receive Supabase administration access.

Supabase Row Level Security must enforce:

- supplier ownership
- butcher marketplace access
- approved supplier/customer relationships
- private price-list assignment
- public price visibility
- admin-only functionality

Future CSV and Excel exports must obey the same permissions.

---

# Catalogue population strategy

The catalogue should not be populated from one supplier's list alone.

Sources can include:

- verified industry references
- recognised product codes
- real supplier catalogues
- butcher terminology
- commercial supplier sheets

Supplier material is useful for identifying:

- real-world naming
- common commercial groupings
- product variants
- weight specifications
- packaging terminology

But supplier-specific structure must be mapped into the canonical marketplace model rather than copied directly.

---

# Current Phase 2 objective

The remaining Phase 2 work is:

- validate the recursive model with more real-world cuts
- populate the initial canonical catalogue
- add verified aliases where appropriate
- add verified codes where appropriate
- review legacy dependencies
- document migration status
- perform final catalogue testing

Only after the canonical catalogue is stable should development move heavily into:

- Ordering
- Purchasing
- Sales
- Invoicing
- Animal diagrams
- Analytics
- CSV and Excel exports