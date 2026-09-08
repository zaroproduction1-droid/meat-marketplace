-- ============================================================================
-- CutLink Supplier-Custom Specification Moderation Hardening v2
-- ============================================================================

begin;

alter table public.meat_specifications enable row level security;

drop policy if exists meat_specifications_authenticated_select
on public.meat_specifications;

drop policy if exists meat_specifications_catalogue_select
on public.meat_specifications;

create policy meat_specifications_catalogue_select
on public.meat_specifications
for select
to authenticated
using (
    is_active = true
    and (
        specification_type = 'canonical'
        or approval_status = 'approved'
        or public.current_user_is_admin()
        or (
            created_by_supplier_business_id is not null
            and public.current_user_is_member_of_business(
                created_by_supplier_business_id
            )
        )
    )
);

create or replace function public.review_supplier_custom_specification(
    p_specification_id uuid,
    p_decision text
)
returns public.meat_specifications
language plpgsql
security definer
set search_path = public
as $$
declare
    v_spec public.meat_specifications%rowtype;
    v_decision text;
begin
    if auth.uid() is null then
        raise exception 'Authentication required.';
    end if;

    if not public.current_user_is_admin() then
        raise exception 'CutLink administrator access is required.';
    end if;

    v_decision := lower(trim(coalesce(p_decision, '')));

    if v_decision not in ('approved', 'rejected') then
        raise exception 'Decision must be approved or rejected.';
    end if;

    select *
    into v_spec
    from public.meat_specifications
    where id = p_specification_id
      and specification_type = 'supplier_custom';

    if not found then
        raise exception 'Supplier-created specification not found.';
    end if;

    update public.meat_specifications
    set approval_status = v_decision
    where id = p_specification_id
    returning * into v_spec;

    return v_spec;
end;
$$;

revoke all on function public.review_supplier_custom_specification(uuid, text)
from public;

grant execute on function public.review_supplier_custom_specification(uuid, text)
to authenticated;

commit;

select
    policyname,
    cmd,
    qual
from pg_policies
where schemaname = 'public'
  and tablename = 'meat_specifications'
order by policyname;

select
    ms.id,
    a.code as animal_code,
    s.code as section_code,
    ms.name,
    ms.specification_type,
    ms.approval_status,
    ms.created_by_supplier_business_id,
    ms.is_active
from public.meat_specifications ms
join public.meat_animals a on a.id = ms.animal_id
join public.meat_sections s on s.id = ms.section_id
where ms.specification_type = 'supplier_custom'
order by ms.created_at desc nulls last, ms.name;
