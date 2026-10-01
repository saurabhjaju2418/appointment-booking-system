-- Slotwise reference schema. Public booking actions should go through server routes.
create extension if not exists btree_gist;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  owner_id uuid not null references auth.users(id) on delete restrict,
  timezone text not null default 'America/New_York',
  created_at timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','staff','viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id,user_id)
);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  active boolean not null default true,
  unique (id,workspace_id)
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  duration_minutes integer not null check (duration_minutes between 5 and 720),
  buffer_minutes integer not null default 0 check (buffer_minutes between 0 and 240),
  price_cents integer not null default 0 check (price_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id,workspace_id)
);

create table public.availability_rules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  resource_id uuid not null,
  weekday smallint not null check (weekday between 0 and 6),
  local_start time not null,
  local_end time not null,
  timezone text not null,
  active boolean not null default true,
  check (local_end > local_start),
  foreign key (resource_id,workspace_id) references public.resources(id,workspace_id) on delete cascade
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  resource_id uuid not null,
  service_id uuid not null,
  customer_name text not null check (length(trim(customer_name)) between 1 and 160),
  customer_email text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'confirmed' check (status in ('held','confirmed','cancelled','completed')),
  hold_expires_at timestamptz,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  check (ends_at > starts_at),
  unique (workspace_id,idempotency_key),
  unique (id,workspace_id),
  foreign key (resource_id,workspace_id) references public.resources(id,workspace_id) on delete restrict,
  foreign key (service_id,workspace_id) references public.services(id,workspace_id) on delete restrict,
  exclude using gist (
    resource_id with =,
    tstzrange(starts_at,ends_at,'[)') with &&
  ) where (status in ('held','confirmed'))
);

create index availability_lookup_idx on public.availability_rules(workspace_id,resource_id,weekday) where active;
create index bookings_workspace_start_idx on public.bookings(workspace_id,starts_at desc);
create index bookings_customer_email_idx on public.bookings(workspace_id,lower(customer_email));

create or replace function public.is_booking_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target_workspace and m.user_id = auth.uid()
  );
$$;

create or replace function public.can_manage_booking_workspace(target_workspace uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target_workspace and m.user_id = auth.uid()
      and m.role in ('owner','admin','staff')
  );
$$;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.resources enable row level security;
alter table public.services enable row level security;
alter table public.availability_rules enable row level security;
alter table public.bookings enable row level security;

create policy workspace_member_read on public.workspaces for select
  using (public.is_booking_workspace_member(id));
create policy workspace_owner_create on public.workspaces for insert
  with check (owner_id = auth.uid());
create policy workspace_members_read on public.workspace_members for select
  using (public.is_booking_workspace_member(workspace_id));
create policy workspace_members_manage on public.workspace_members for all
  using (public.can_manage_booking_workspace(workspace_id))
  with check (public.can_manage_booking_workspace(workspace_id));
create policy resources_member_read on public.resources for select
  using (public.is_booking_workspace_member(workspace_id));
create policy resources_manager_write on public.resources for all
  using (public.can_manage_booking_workspace(workspace_id))
  with check (public.can_manage_booking_workspace(workspace_id));
create policy services_member_read on public.services for select
  using (public.is_booking_workspace_member(workspace_id));
create policy services_manager_write on public.services for all
  using (public.can_manage_booking_workspace(workspace_id))
  with check (public.can_manage_booking_workspace(workspace_id));
create policy availability_member_read on public.availability_rules for select
  using (public.is_booking_workspace_member(workspace_id));
create policy availability_manager_write on public.availability_rules for all
  using (public.can_manage_booking_workspace(workspace_id))
  with check (public.can_manage_booking_workspace(workspace_id));
create policy bookings_member_read on public.bookings for select
  using (public.is_booking_workspace_member(workspace_id));
create policy bookings_manager_write on public.bookings for all
  using (public.can_manage_booking_workspace(workspace_id))
  with check (public.can_manage_booking_workspace(workspace_id));

-- The exclusion constraint is the final concurrency guard. A booking hold must be
-- created by a server-side route that also validates service duration and openings.

