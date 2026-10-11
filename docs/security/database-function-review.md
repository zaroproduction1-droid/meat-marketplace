# Database function review inventory

Read-only metadata review from the connected project. This inventory is not an authorization penetration test. Warnings are triage findings; callable SECURITY DEFINER functions remain required.

| Function | Signature | Privilege/access review |
|---|---|---|
| accept_marketplace_order_and_create_work_order | target_order_id uuid, confirmed_date date, confirmed_time time without time zone | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| accept_marketplace_order_and_create_work_order | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| acknowledge_marketplace_order_rejection | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| acknowledge_supplier_cancellation | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| add_supplier_work_order_items | target_order_id uuid, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| advance_supplier_invoiced_order | p_order_id uuid, p_action text, p_driver_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| align_invoice_number_to_work_order |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| allocate_account_credit | target_credit_id uuid, allocations_json jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| allocate_account_payment | target_payment_id uuid, allocations_json jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| apply_auto_allocate_payment | target_payment_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| approve_vip_trade_application | p_application_id uuid, p_internal_notes text, p_risk_rating text, p_approved_payment_method text, p_approved_payment_terms_days integer, p_approved_credit_limit numeric | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| assign_cutlink_delivery_run_number |  | Internal/trigger function; check public API grants |
| assign_cutlink_quote_number |  | Internal/trigger function; check public API grants |
| assign_order_delivery_driver | target_order_id uuid, p_driver_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| business_notification_unread_count | p_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| butcher_confirm_order_received | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| calculate_order_item_final_amount |  | Internal/trigger function; check public API grants |
| calculate_order_item_subtotal |  | Internal/trigger function; check public API grants |
| can_access_support_ticket | target_ticket_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cancel_butcher_order | p_order_id uuid, p_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| capture_document_product_details |  | Internal/trigger function; check public API grants |
| check_supplier_customer_credit_limit | target_supplier_customer_account_id uuid, proposed_amount numeric | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| complete_marketplace_order_delivery | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| complete_supplier_delivery_stop | p_stop_id uuid, p_recipient_name text, p_driver_notes text, p_proof_reference text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| complete_support_file_cleanup | p_token text, p_paths text[] | Internal/trigger function; check public API grants |
| complete_work_order_when_invoice_exists |  | Internal/trigger function; check public API grants |
| confirm_butcher_account_payment | target_submission_id uuid, review_note_value text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| convert_supplier_quote_to_sales_order | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| copy_work_order_private_note_to_invoice_item |  | Internal/trigger function; check public API grants |
| create_business_for_current_user | p_business_type text, p_legal_name text, p_trading_name text, p_abn text, p_business_email text, p_business_phone text, p_address_line_1 text, p_address_line_2 text, p_suburb text, p_state text, p_postcode text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_or_get_invoice_from_order | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_or_get_warehouse_work_order | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_replacement_order | target_issue_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_catalogue_product | p_details jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_chicken_product | p_supplier_business_id uuid, p_animal_id uuid, p_section_id uuid, p_specification_id uuid, p_sku text, p_product_name text, p_standard_price_inc_gst numeric, p_available_cartons numeric, p_minimum_cartons numeric, p_temperature_state text, p_availability_status text, p_description text, p_brand text, p_halal_status text, p_chicken_skin text, p_chicken_bone text, p_chicken_production_type text, p_chicken_preparation text, p_chicken_size_weight text, p_chicken_carton_size text, p_packaging_type text, p_pieces_per_carton integer, p_supplier_specification text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_credit_note | p_invoice_id uuid, p_reason text, p_lines jsonb, p_request_key uuid, p_issue_id uuid, p_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_custom_specification | p_supplier_business_id uuid, p_animal_id uuid, p_section_id uuid, p_name text, p_description text, p_specification_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_delivery_run | p_delivery_date date, p_driver_id uuid, p_vehicle_id uuid, p_order_ids uuid[], p_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_sales_desk_order | p_supplier_customer_account_id uuid, p_order_source text, p_source_reference text, p_customer_reference text, p_delivery_notes text, p_internal_notes text, p_payment_method text, p_payment_terms_days integer, p_fulfilment_method text, p_requested_fulfilment_date date, p_delivery_fee numeric, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_sales_desk_order | p_supplier_customer_account_id uuid, p_order_source text, p_source_reference text, p_customer_reference text, p_delivery_notes text, p_internal_notes text, p_payment_method text, p_payment_terms_days integer, p_fulfilment_method text, p_requested_fulfilment_date date, p_requested_fulfilment_time time without time zone, p_delivery_fee numeric, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_sales_desk_quote | p_supplier_customer_account_id uuid, p_order_source text, p_source_reference text, p_customer_reference text, p_delivery_notes text, p_internal_notes text, p_payment_method text, p_payment_terms_days integer, p_fulfilment_method text, p_requested_fulfilment_date date, p_requested_fulfilment_time time without time zone, p_delivery_fee numeric, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_sales_desk_quote | p_supplier_customer_account_id uuid, p_order_source text, p_source_reference text, p_customer_reference text, p_delivery_notes text, p_internal_notes text, p_payment_method text, p_payment_terms_days integer, p_fulfilment_method text, p_requested_fulfilment_date date, p_delivery_fee numeric, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_supplier_spec_grade_product | p_supplier_business_id uuid, p_animal_id uuid, p_section_id uuid, p_specification_id uuid, p_grade_id uuid, p_sku text, p_product_name text, p_standard_price_inc_gst numeric, p_available_cartons numeric, p_minimum_cartons numeric, p_temperature_state text, p_availability_status text, p_description text, p_brand text, p_origin_country text, p_origin_state text, p_marbling_score text, p_breed_program text, p_trim_specification text, p_fat_specification text, p_halal_status text, p_packaging_type text, p_pieces_per_carton integer, p_supplier_specification text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| create_support_ticket | p_business_id uuid, p_subject text, p_category text, p_priority text, p_message text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_supplier_business_id |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_user_can_edit_order_issue_items | target_issue_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_user_can_view_price_list | target_price_list_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_user_has_approved_business |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_user_is_admin |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| current_user_is_member_of_business | target_business_id uuid | Targeted authorization/path fix in unapplied migration |
| current_user_is_order_butcher | target_order_id uuid | Targeted authorization/path fix in unapplied migration |
| current_user_is_order_supplier | target_order_id uuid | Targeted authorization/path fix in unapplied migration |
| cutlink_admin_featured_list | p_search text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cutlink_admin_featured_set | p_type text, p_slot integer, p_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cutlink_public_businesses |  | Intentional public aggregate; only counts and approved featured names/logos |
| cutlink_setting_or_null | setting_name text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cutlink_stock_filter_values | p products | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cutlink_vip_reapply_cooldown |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| cutlink_vip_reapply_cooldown_seconds |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| decline_vip_trade_application | p_application_id uuid, p_internal_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| dismiss_business_notification | p_id uuid, p_deleted boolean | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| dismiss_today_business_notification | p_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| enforce_catch_weight_product_commercial_model |  | Internal/trigger function; check public API grants |
| enforce_catch_weight_product_price_basis |  | Internal/trigger function; check public API grants |
| enforce_catch_weight_product_price_model |  | Internal/trigger function; check public API grants |
| enforce_supplier_pickup_available |  | Internal/trigger function; check public API grants |
| ensure_supplier_delivery_defaults |  | Internal/trigger function; check public API grants |
| ensure_supplier_standard_price_list | p_supplier_business_id uuid | Targeted authorization/path fix in unapplied migration |
| fail_supplier_delivery_stop | p_stop_id uuid, p_failed_reason text, p_driver_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| finalise_supplier_delivered_order | p_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| generate_order_number |  | Internal/trigger function; check public API grants |
| get_business_analytics | p_business_id uuid, p_days integer, p_start_date date, p_end_date date | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| get_invoice_account_balance | target_invoice_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| get_my_cutlink_access |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| get_my_order_delivery_tracking | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| guard_order_sales_contact |  | Internal/trigger function; check public API grants |
| handle_new_user |  | Internal/trigger function; check public API grants |
| is_cutlink_admin |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| issue_invoice | target_invoice_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| kill_supplier_work_order | target_order_id uuid, p_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| kill_supplier_work_order | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_business_notifications | p_business_id uuid, p_offset integer, p_unread_only boolean, p_category text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_butcher_supplier_account_summaries | due_soon_days integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_cutlink_butchers_for_supplier |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_platform_banners | p_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_supplier_account_summaries | due_soon_days integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_supplier_product_brands | p_supplier_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_supplier_product_brands | p_supplier_business_id uuid, p_animal_code text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| list_suppliers_for_butcher_vip |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| mark_business_notifications_read | p_business_id uuid, p_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| mark_marketplace_order_ready_for_pickup | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| mark_support_ticket_read | p_ticket_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| marketplace_catalogue_index | p_animal_id uuid, p_section_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| marketplace_catalogue_index_v2 | p_animal_id uuid, p_section_id uuid, p_specification_id uuid, p_compact boolean | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| marketplace_stock_page | p_animal_id uuid, p_section_id uuid, p_variant_keys text[], p_search text, p_supplier_search text, p_sort text, p_offset integer, p_limit integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| marketplace_stock_page_v2 | p_animal_id uuid, p_section_id uuid, p_variant_keys text[], p_search text, p_supplier_search text, p_sort text, p_offset integer, p_limit integer, p_filters jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| marketplace_variant_data | p products | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| my_platform_billing_invoices | p_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| normalise_product_brand | p_brand text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| normalise_product_brand_on_write |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| order_delivery_fee_recalculate_total |  | Internal/trigger function; check public API grants |
| order_is_draft | target_order_id uuid | Targeted authorization/path fix in unapplied migration |
| order_item_recalculate_order |  | Internal/trigger function; check public API grants |
| platform_admin_action | p_action text, p_data jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| platform_admin_analytics | p_months integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| platform_admin_query | p_view text, p_business_id uuid, p_search text, p_offset integer, p_id uuid, p_filter text, p_access_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| platform_issue_invoice_notice | p_invoice_id uuid, p_stage integer, p_payment_deadline date | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| platform_restore_billing_hold | p_invoice_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| prefer_work_order_private_note_for_invoice |  | Internal/trigger function; check public API grants |
| prepare_invoice_receivable_linkage |  | Internal/trigger function; check public API grants |
| prepare_support_cleanup | p_token text | Internal/trigger function; check public API grants |
| prevent_supplier_delivery_postcode_overlap |  | Internal/trigger function; check public API grants |
| prevent_supplier_delivery_zone_activation_overlap |  | Internal/trigger function; check public API grants |
| preview_auto_allocate_payment | target_payment_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| protect_cutlink_admin_flag |  | Internal/trigger function; check public API grants |
| push_cutlink_notification | b uuid, c text, t text, d text, k text, r uuid, o uuid | Internal/trigger function; check public API grants |
| quick_complete_supplier_delivery_order | p_order_id uuid, p_recipient_name text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| quick_dispatch_supplier_delivery_order | p_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| recalculate_order_totals | target_order_id uuid | Targeted authorization/path fix in unapplied migration |
| record_account_credit | target_supplier_customer_account_id uuid, credit_amount numeric, credit_date_value date, credit_type_value text, credit_reference text, credit_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| record_account_payment | target_supplier_customer_account_id uuid, payment_amount numeric, payment_date_value date, payment_method_value text, payment_reference text, payment_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| record_cutlink_activity |  | Internal/trigger function; check public API grants |
| record_invoice_payment | target_invoice_id uuid, payment_amount numeric | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| record_supplier_product_stock_change |  | Internal/trigger function; check public API grants |
| refresh_draft_order_delivery_terms | target_order_id uuid | Targeted authorization/path fix in unapplied migration |
| refresh_invoice_after_credit_allocation |  | Internal/trigger function; check public API grants |
| refresh_invoice_after_payment_allocation |  | Internal/trigger function; check public API grants |
| refresh_invoice_receivable | target_invoice_id uuid | Targeted authorization/path fix in unapplied migration |
| refresh_invoices_after_credit_status |  | Internal/trigger function; check public API grants |
| refresh_invoices_after_payment_status |  | Internal/trigger function; check public API grants |
| refresh_order_pricing_status | target_order_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| refund_supplier_credit_note | p_credit_note_id uuid, p_amount numeric, p_method text, p_reference text, p_request_key uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| register_vip_application_document | p_application_id uuid, p_document_type text, p_file_name text, p_storage_path text, p_mime_type text, p_file_size_bytes bigint | Targeted authorization/path fix in unapplied migration |
| reject_butcher_account_payment | target_submission_id uuid, review_note_value text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| reject_marketplace_order | target_order_id uuid, rejection_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| reopen_support_ticket | p_ticket_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| request_support_ticket_reopen | p_ticket_id uuid, p_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| resolve_issue_when_replacement_completes |  | Internal/trigger function; check public API grants |
| reverse_account_credit | target_credit_id uuid, reversal_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| reverse_account_payment | target_payment_id uuid, reversal_reason text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| review_support_ticket_reopen | p_ticket_id uuid, p_approve boolean, p_note text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| save_supplier_customer_account_profile | p_supplier_business_id uuid, p_account_id uuid, p_values jsonb, p_expected_updated_at timestamp with time zone | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| send_invoice_to_butcher | target_invoice_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| send_support_ticket_attachment | p_ticket_id uuid, p_file_name text, p_storage_path text, p_mime_type text, p_file_size bigint | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| send_support_ticket_message | p_ticket_id uuid, p_message text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| send_support_ticket_message_with_attachments | p_ticket_id uuid, p_message text, p_attachments jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| set_account_ledger_updated_at |  | Internal/trigger function; check public API grants |
| set_business_app_settings_updated_at |  | Internal/trigger function; check public API grants |
| set_butcher_settings_updated_at |  | Internal/trigger function; check public API grants |
| set_customer_payment_submission_updated_at |  | Internal/trigger function; check public API grants |
| set_invoice_updated_at |  | Internal/trigger function; check public API grants |
| set_my_business_logo | p_business_id uuid, p_logo_path text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| set_order_issue_reporting_window |  | Internal/trigger function; check public API grants |
| set_order_issue_status_timestamp |  | Internal/trigger function; check public API grants |
| set_order_sales_contact | target_order_id uuid, contact_name text, contact_phone text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| set_order_status_timestamp |  | Internal/trigger function; check public API grants |
| set_supplier_invoice_profile_updated_at |  | Internal/trigger function; check public API grants |
| set_support_retention_deadline |  | Internal/trigger function; check public API grants |
| set_updated_at |  | Internal/trigger function; check public API grants |
| set_warehouse_work_order_updated_at |  | Internal/trigger function; check public API grants |
| snapshot_invoice_commercial_details |  | Internal/trigger function; check public API grants |
| snapshot_invoice_contact_name |  | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| snapshot_invoice_party_details | target_invoice_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| snapshot_invoice_supplier_logo |  | Internal/trigger function; check public API grants |
| snapshot_order_commercial_terms |  | Internal/trigger function; check public API grants |
| snapshot_order_delivery_address |  | Internal/trigger function; check public API grants |
| snapshot_order_delivery_terms |  | Internal/trigger function; check public API grants |
| submit_butcher_account_payment | target_supplier_business_id uuid, payment_amount numeric, payment_date_value date, payment_method_value text, payment_reference text, payment_notes text, allocations_json jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| submit_vip_trade_application | p_supplier_business_id uuid, p_application_type text, p_primary_contact_name text, p_primary_contact_position text, p_years_trading numeric, p_estimated_monthly_purchases numeric, p_requested_payment_terms_days integer, p_requested_credit_limit numeric, p_application_message text, p_trade_reference_contact_consent boolean, p_commercial_credit_assessment_consent boolean, p_consumer_credit_report_consent boolean, p_privacy_notice_accepted boolean, p_applicant_declaration_accepted boolean, p_trade_references jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_delivery_packing_list | p_order_id uuid, p_run_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_inventory_catalogue | p_supplier_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_inventory_facets | p_supplier_business_id uuid, p_specification_ids uuid[] | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_inventory_page | p_supplier_business_id uuid, p_variant_keys text[], p_search text, p_status text, p_sort text, p_offset integer, p_limit integer, p_sku text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_inventory_page_v2 | p_supplier_business_id uuid, p_filters jsonb, p_search text, p_status text, p_sort text, p_offset integer, p_limit integer, p_sku text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_product_size_options | p_supplier_business_id uuid, p_specification_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_sales_size_label | p_kind text, p_min numeric, p_max numeric, p_unit text, p_chicken text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_sales_stock_facets | p_supplier_business_id uuid, p_animal_id uuid, p_section_id uuid, p_specification_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_sales_stock_page | p_supplier_business_id uuid, p_filters jsonb, p_offset integer, p_limit integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_stock_options | p_supplier_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_stock_page | p_supplier_business_id uuid, p_variant_keys text[], p_search text, p_status text, p_sort text, p_offset integer, p_limit integer | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| supplier_stock_variant | p products | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| sync_legacy_invoice_claim_from_submission |  | Internal/trigger function; check public API grants |
| sync_offer_to_standard_product_price |  | Internal/trigger function; check public API grants |
| sync_standard_product_price_to_offer |  | Internal/trigger function; check public API grants |
| today_business_notifications | p_business_id uuid | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| touch_cutlink_updated_at |  | Internal/trigger function; check public API grants |
| transition_marketplace_issue | p_issue_id uuid, p_action text, p_note text, p_resolution text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_invoice_credit_totals |  | Internal/trigger function; check public API grants |
| update_my_business_profile | target_business_id uuid, p_trading_name text, p_legal_name text, p_business_email text, p_business_phone text, p_address_line_1 text, p_address_line_2 text, p_suburb text, p_state text, p_postcode text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_supplier_invoice_line | p_invoice_item_id uuid, p_discount_type text, p_discount_value numeric, p_public_comment text, p_private_comment text, p_delivery_fee numeric, p_remove boolean | Internal/trigger function; check public API grants |
| update_supplier_order_contact_name | target_order_id uuid, contact_name_value text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_supplier_product_stock | p_product_id uuid, p_quantity numeric, p_availability_status text, p_reason text, p_notes text | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_supplier_quote_line | p_order_item_id uuid, p_discount_type text, p_discount_value numeric, p_public_comment text, p_private_comment text, p_delivery_fee numeric, p_remove boolean | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_supplier_sales_desk_quote | target_order_id uuid, p_supplier_customer_account_id uuid, p_order_source text, p_source_reference text, p_customer_reference text, p_delivery_notes text, p_internal_notes text, p_payment_method text, p_payment_terms_days integer, p_fulfilment_method text, p_requested_fulfilment_date date, p_delivery_fee numeric, p_items jsonb | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_supplier_work_order_line | p_order_item_id uuid, p_discount_type text, p_discount_value numeric, p_public_comment text, p_private_comment text, p_delivery_fee numeric, p_remove boolean | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| update_support_ticket_admin | p_ticket_id uuid, p_status text, p_priority text, p_assign_to_me boolean, p_unassign boolean | Authorization predicate/delegation candidate from static triage; complete runtime multi-role coverage remains pending |
| validate_credit_allocation_account |  | Internal/trigger function; check public API grants |
| validate_order_issue_item |  | Internal/trigger function; check public API grants |
| validate_order_item_editable |  | Internal/trigger function; check public API grants |
| validate_order_item_supplier |  | Internal/trigger function; check public API grants |
| validate_order_status_transition |  | Internal/trigger function; check public API grants |
| validate_order_submission |  | Internal/trigger function; check public API grants |
| validate_payment_allocation_account |  | Internal/trigger function; check public API grants |
| validate_supplier_spec_grade_offer |  | Internal/trigger function; check public API grants |
