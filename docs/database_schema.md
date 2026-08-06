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