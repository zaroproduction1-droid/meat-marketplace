# Database Schema

## Authentication and businesses

- profiles
- businesses
- business_memberships

## Supplier customer relationships

- supplier_customer_relationships

## Relationship rules

- A butcher can request access to a supplier.
- A supplier can approve, decline or suspend the relationship.
- Approved-customer pricing requires an approved supplier relationship.
- Private contract pricing requires direct assignment to the relevant price list.
- Public pricing is available to approved marketplace buyers.
- Suppliers and butchers never receive direct Supabase administration access.
- Admin-only actions require profiles.is_admin = true.

---

# Canonical Meat Catalogue

## species

Represents the top-level animal category.

Initial marketplace species:

- Beef
- Lamb
- Chicken
- Goat

Each species can contain any number of canonical meat products.

---

## meat_products

This is the main canonical meat catalogue table.

It represents recognised meat products, cuts, families and structural catalogue nodes.

Important relationships:

- species_id → species.id
- parent_product_id → meat_products.id

This creates a recursive hierarchy.

A meat product may:

- have no parent and act as a root catalogue product
- belong to another meat product
- have its own child products
- have children at any depth

Examples:

Beef
→ Blade
→ Oyster Blade

A deeper structure is also supported:

Species
→ Product
→ Child Product
→ Child Product
→ Child Product

There is no fixed maximum hierarchy depth.

Important fields include:

- id
- species_id
- parent_product_id
- subprimal_section_id
- name
- slug
- description
- product_level
- active
- display_order
- created_at
- updated_at

subprimal_section_id remains temporarily for backwards compatibility and migration only.

It is not the long-term source of truth for product hierarchy.

The canonical hierarchy is defined by:

species_id
+
parent_product_id

---

## meat_product_catalogue_paths

This is a recursive database view used to resolve the complete catalogue path for every meat product.

It exposes fields including:

- id
- species_id
- species_name
- parent_product_id
- name
- slug
- product_level
- display_order
- active
- depth
- path_ids
- path_names
- catalogue_path

Example:

Blade

or:

Blade → Oyster Blade

The Flutter application uses this view so it does not need to know how many hierarchy levels exist.

---

## Catalogue hierarchy validation

A database trigger validates meat product relationships.

It prevents:

- a meat product being its own parent
- parent/child relationships across different species
- recursive catalogue cycles

Example invalid relationships:

Beef product
→ Lamb product

or:

Blade
→ Oyster Blade
→ Blade

These relationships are rejected by PostgreSQL.

---

## product_variants

Represents a recognised variation or specification of a canonical meat product.

Relationship:

product_variants.meat_product_id
→ meat_products.id

Example:

Oyster Blade
→ Fresh Boneless Oyster Blade

Possible fields include:

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

Variants describe product specifications.

They do not contain supplier-specific SKU, pricing or stock.

---

## product_aliases

Stores recognised alternative or common terminology for a canonical meat product.

Relationship:

product_aliases.meat_product_id
→ meat_products.id

Possible alias types include:

- common
- regional
- trade
- historical

Supplier-specific product descriptions should normally remain in products.product_name rather than being automatically inserted as global aliases.

---

## product_codes

Stores recognised canonical or industry product codes.

A code can reference:

- meat_product_id
- product_variant_id

Examples of possible code systems:

- AUS-MEAT HAM
- Marketplace
- recognised industry systems

Supplier-specific SKUs should normally remain in products.sku instead of product_codes.

Only verified industry codes should be inserted.

---

# Supplier products

## products

The existing products table represents supplier-specific marketplace listings.

It is retained as the supplier product table.

Important relationships:

- supplier_business_id → businesses.id
- product_variant_id → product_variants.id

A supplier product may contain:

- supplier SKU
- supplier product name
- description
- brand
- country/state of origin
- temperature state
- price basis
- catch-weight status
- available quantity
- quantity unit
- availability status
- active status

Conceptually:

businesses
→ products
→ product_variants
→ meat_products
→ recursive parent meat_products
→ species

Example:

Supplier A
→ Supplier SKU BEEF-OB-001
→ Fresh Boneless Oyster Blade
→ Oyster Blade
→ Blade
→ Beef

The existing animal_type_id and cut_id fields remain temporarily for legacy product compatibility.

New canonical supplier products use product_variant_id.

---

# Legacy catalogue tables

The following tables predate the recursive canonical catalogue:

- animal_types
- cuts
- primal_sections
- subprimal_sections

These remain temporarily to avoid breaking legacy records and migration dependencies.

They are no longer the long-term canonical product hierarchy.

They must not be deleted until:

- all supplier products have been migrated
- Flutter no longer depends on them
- pricing and ordering dependencies have been checked
- legacy data has been reviewed

---

# Pricing

## price_lists

One supplier can have multiple price lists.

Visibility types:

- public
- approved_customers
- private

---

## product_prices

Links supplier products to prices on price lists.

Relationship:

products
→ product_prices
→ price_lists

One supplier product can have different prices on different price lists.

---

## price_list_customers

Assigns specific butcher businesses to private price lists.

---

## Pricing priority

When a buyer is authorised for more than one price, the marketplace uses:

1. Private contract price
2. Approved-customer price
3. Public price

Pricing continues to reference products.id.

The canonical catalogue migration does not change the pricing relationship.

---

# Current Flutter catalogue flow

Supplier Add Product:

Species
→ Catalogue Product / Cut
→ Product Variant
→ Supplier Listing

Supplier Edit Product:

Species
→ Catalogue Product / Cut
→ Product Variant
→ Supplier Listing

Supplier Products:

Displays the complete recursive catalogue path.

Butcher Browse Products:

Searches and displays the complete recursive catalogue path.

Butcher Product Details:

Displays the complete recursive catalogue path.

Example:

Beef
→ Blade
→ Oyster Blade
→ Fresh Boneless Oyster Blade

---

# Future animal browser

The visual animal browser must be separate from the canonical product genealogy.

Future tables may include:

- animal_regions
- meat_product_regions

Conceptually:

species
→ animal_regions

and:

meat_products
↔ meat_product_regions
↔ animal_regions

This allows a meat product to be associated with a visual anatomical region without forcing that region to become its database parent.

The animal diagram will be a navigation layer only.

---

# Future ordering

Orders will reference supplier products.

Conceptually:

orders
→ order_items
→ products.id

Order items must preserve historical snapshots such as:

- product name
- catalogue description where required
- quantity
- quantity unit
- unit price
- price basis
- line total

Historical orders must not depend on the supplier's current live price.

---

# Future purchasing and sales

Purchasing and sales records will later reference supplier products and canonical catalogue products.

This will support analytics including:

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

These tables are not part of the current catalogue phase.

---

# Future invoicing

Invoice functionality will be developed only after ordering and sales records are stable.

Invoice lines must preserve historical values.

---

# Security

Supabase remains the backend database.

Suppliers and butchers access data through the marketplace application.

Row Level Security must enforce:

- suppliers access only authorised supplier data
- butchers access authorised marketplace data
- public pricing is available to approved buyers
- approved-customer pricing requires supplier approval
- private pricing requires direct price-list assignment
- admin functions require is_admin = true

Future CSV and Excel exports must use the same authorisation rules.