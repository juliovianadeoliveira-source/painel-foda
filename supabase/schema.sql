-- Painel FODA — esquema inicial seguro para Supabase
-- Execute no SQL Editor do projeto zpatgxfwrlllrrkxwuxt.
-- Antes de usar em produção, revise os papéis e políticas conforme o fluxo real.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'client' check (role in ('admin','reseller','client')),
  reseller_id uuid references public.profiles(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_not_self_reseller check (reseller_id is null or reseller_id <> id)
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  price numeric(12,2) not null default 0 check (price >= 0),
  duration_days integer not null default 30 check (duration_days > 0),
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text not null default '',
  notes text not null default '',
  plan_id uuid references public.plans(id) on delete set null,
  reseller_id uuid references public.profiles(id) on delete set null,
  status text not null default 'active' check (status in ('active','pending','expired','suspended','cancelled')),
  starts_at timestamptz,
  expires_at timestamptz,
  connection_limit integer not null default 1 check (connection_limit > 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete set null,
  reseller_id uuid references public.profiles(id) on delete set null,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'BRL',
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','refunded')),
  method text not null default 'manual',
  reference text,
  description text not null default '',
  paid_at timestamptz,
  confirmed_by uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.renewals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  plan_id uuid references public.plans(id) on delete set null,
  payment_id uuid references public.payments(id) on delete set null,
  previous_expiry timestamptz,
  new_expiry timestamptz not null,
  status text not null default 'pending' check (status in ('pending','completed','cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists clients_reseller_id_idx on public.clients(reseller_id);
create index if not exists clients_status_idx on public.clients(status);
create index if not exists clients_expires_at_idx on public.clients(expires_at);
create index if not exists payments_client_id_idx on public.payments(client_id);
create index if not exists payments_status_idx on public.payments(status);
create index if not exists payments_created_at_idx on public.payments(created_at desc);
create index if not exists renewals_client_id_idx on public.renewals(client_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists plans_set_updated_at on public.plans;
create trigger plans_set_updated_at before update on public.plans
for each row execute function public.set_updated_at();
drop trigger if exists clients_set_updated_at on public.clients;
create trigger clients_set_updated_at before update on public.clients
for each row execute function public.set_updated_at();
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments
for each row execute function public.set_updated_at();

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin' and p.active = true
  );
$$;
revoke all on function private.is_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.plans enable row level security;
alter table public.clients enable row level security;
alter table public.payments enable row level security;
alter table public.renewals enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
create policy "profiles_select_self_or_admin" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select private.is_admin()));

drop policy if exists "profiles_insert_self_client" on public.profiles;
create policy "profiles_insert_self_client" on public.profiles
for insert to authenticated
with check (id = (select auth.uid()) and role = 'client' and reseller_id is null);

drop policy if exists "profiles_update_self_name_or_admin" on public.profiles;
create policy "profiles_update_self_name_or_admin" on public.profiles
for update to authenticated
using (id = (select auth.uid()) or (select private.is_admin()))
with check (
  (id = (select auth.uid()) and role = 'client' and reseller_id is null)
  or (select private.is_admin())
);

drop policy if exists "plans_read_authenticated" on public.plans;
create policy "plans_read_authenticated" on public.plans
for select to authenticated
using (active = true or (select private.is_admin()));

drop policy if exists "plans_admin_manage" on public.plans;
create policy "plans_admin_manage" on public.plans
for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

drop policy if exists "clients_read_owner_or_admin" on public.clients;
create policy "clients_read_owner_or_admin" on public.clients
for select to authenticated
using (
  (select private.is_admin())
  or reseller_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'reseller'
      and p.active = true and p.id = clients.reseller_id
  )
);

drop policy if exists "clients_admin_or_reseller_insert" on public.clients;
create policy "clients_admin_or_reseller_insert" on public.clients
for insert to authenticated
with check (
  (select private.is_admin())
  or (
    reseller_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'reseller' and p.active = true)
  )
);

drop policy if exists "clients_admin_or_reseller_update" on public.clients;
create policy "clients_admin_or_reseller_update" on public.clients
for update to authenticated
using ((select private.is_admin()) or reseller_id = (select auth.uid()))
with check ((select private.is_admin()) or reseller_id = (select auth.uid()));

drop policy if exists "clients_admin_delete" on public.clients;
create policy "clients_admin_delete" on public.clients
for delete to authenticated
using ((select private.is_admin()));

drop policy if exists "payments_read_admin_or_reseller" on public.payments;
create policy "payments_read_admin_or_reseller" on public.payments
for select to authenticated
using (
  (select private.is_admin())
  or reseller_id = (select auth.uid())
  or exists (select 1 from public.clients c where c.id = payments.client_id and c.reseller_id = (select auth.uid()))
);

drop policy if exists "payments_insert_admin_or_reseller" on public.payments;
create policy "payments_insert_admin_or_reseller" on public.payments
for insert to authenticated
with check (
  (select private.is_admin())
  or (reseller_id = (select auth.uid()) and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'reseller' and p.active = true))
);

drop policy if exists "payments_update_admin_only" on public.payments;
create policy "payments_update_admin_only" on public.payments
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

drop policy if exists "payments_delete_admin_only" on public.payments;
create policy "payments_delete_admin_only" on public.payments
for delete to authenticated
using ((select private.is_admin()));

drop policy if exists "renewals_read_admin_or_reseller" on public.renewals;
create policy "renewals_read_admin_or_reseller" on public.renewals
for select to authenticated
using (
  (select private.is_admin())
  or exists (select 1 from public.clients c where c.id = renewals.client_id and c.reseller_id = (select auth.uid()))
);

drop policy if exists "renewals_insert_admin_or_reseller" on public.renewals;
create policy "renewals_insert_admin_or_reseller" on public.renewals
for insert to authenticated
with check (
  (select private.is_admin())
  or exists (select 1 from public.clients c where c.id = renewals.client_id and c.reseller_id = (select auth.uid()))
);

drop policy if exists "renewals_update_admin_only" on public.renewals;
create policy "renewals_update_admin_only" on public.renewals
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

drop policy if exists "audit_admin_read" on public.audit_log;
create policy "audit_admin_read" on public.audit_log
for select to authenticated
using ((select private.is_admin()));

drop policy if exists "audit_admin_insert" on public.audit_log;
create policy "audit_admin_insert" on public.audit_log
for insert to authenticated
with check ((select private.is_admin()));

grant select on public.profiles, public.plans, public.clients, public.payments, public.renewals, public.audit_log to authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update, delete on public.plans to authenticated;
grant insert, update, delete on public.clients to authenticated;
grant insert, update, delete on public.payments to authenticated;
grant insert, update, delete on public.renewals to authenticated;
grant insert on public.audit_log to authenticated;
