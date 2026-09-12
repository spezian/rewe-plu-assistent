-- Im Supabase SQL Editor einmalig ausführen. Das Skript ist idempotent.
-- Unter Authentication -> Sign In / Providers muss "Allow anonymous sign-ins"
-- aktiviert sein. Die App erstellt daraus keine sichtbaren Benutzerkonten.

-- Supabase keeps extension functions outside public. The security-definer
-- functions below therefore qualify every pgcrypto call with extensions.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.markets (
  id uuid primary key default gen_random_uuid(),
  -- Die Marktnummer wird niemals im Klartext gespeichert oder ausgeliefert.
  market_number_hash bytea not null unique,
  editor_pin_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.market_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete cascade,
  access_level text not null check (access_level in ('viewer', 'editor')),
  updated_at timestamptz not null default now()
);

create index if not exists market_sessions_market
  on public.market_sessions(market_id);

create table if not exists public.products (
  id uuid primary key,
  market_id uuid not null references public.markets(id) on delete cascade,
  -- Bleibt nur als rückwärtskompatibles, nicht mehr ausgewertetes Datenfeld.
  owner_id uuid,
  name text not null,
  category text not null,
  description text not null default '',
  aliases text[] not null default '{}',
  image_url text,
  is_pinned boolean not null default false,
  is_organic boolean not null default false,
  is_promotion boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);

alter table public.products
  add column if not exists market_id uuid references public.markets(id) on delete cascade;
alter table public.products
  add column if not exists aliases text[] not null default '{}';
alter table public.products
  add column if not exists is_organic boolean not null default false;
alter table public.products
  add column if not exists is_promotion boolean not null default false;
alter table public.products
  drop constraint if exists products_owner_id_fkey;
alter table public.products
  alter column owner_id drop not null;
alter table public.products
  alter column owner_id drop default;

create table if not exists public.product_codes (
  id uuid primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  owner_id uuid,
  type text not null check (type in ('plu', 'price', 'barcode', 'cashierTile')),
  value text not null,
  is_active boolean not null default false,
  note text not null default '',
  display_category text,
  created_at timestamptz not null,
  retired_at timestamptz
);

alter table public.product_codes
  add column if not exists display_category text;
alter table public.product_codes
  drop constraint if exists product_codes_type_check;
alter table public.product_codes
  add constraint product_codes_type_check
  check (type in ('plu', 'price', 'barcode', 'cashierTile'));
alter table public.product_codes
  drop constraint if exists product_codes_owner_id_fkey;
alter table public.product_codes
  alter column owner_id drop not null;
alter table public.product_codes
  alter column owner_id drop default;

create table if not exists public.product_images (
  id uuid primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  owner_id uuid,
  remote_url text,
  source_page_url text,
  attribution text,
  license text,
  sort_order integer not null default 0,
  created_at timestamptz not null
);

alter table public.product_images
  add column if not exists source_page_url text;
alter table public.product_images
  add column if not exists attribution text;
alter table public.product_images
  add column if not exists license text;
alter table public.product_images
  drop constraint if exists product_images_owner_id_fkey;
alter table public.product_images
  alter column owner_id drop not null;
alter table public.product_images
  alter column owner_id drop default;

create unique index if not exists one_active_code_per_product
  on public.product_codes(product_id)
  where is_active;
create index if not exists products_market_updated
  on public.products(market_id, updated_at desc);
create index if not exists product_codes_product
  on public.product_codes(product_id);
create index if not exists product_images_product
  on public.product_images(product_id, sort_order);

-- Administrative Einrichtung eines Marktes. Nur im SQL Editor bzw. mit dem
-- Service-Role-Schlüssel aufrufen. p_adopt_legacy_products ordnet einmalig alle
-- Zeilen aus dem früheren Einzelkonto-Modell diesem Markt zu.
create or replace function public.create_market(
  p_market_number text,
  p_editor_pin text,
  p_adopt_legacy_products boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_market_id uuid;
  v_market_number text := btrim(p_market_number);
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and session_user not in ('postgres', 'supabase_admin') then
    raise exception 'MARKET_ADMIN_ONLY' using errcode = '42501';
  end if;
  if v_market_number !~ '^[0-9]{1,20}$' then
    raise exception 'Marktnummer muss aus 1 bis 20 Ziffern bestehen.';
  end if;
  if p_editor_pin !~ '^[0-9]{4,8}$' then
    raise exception 'PIN muss aus 4 bis 8 Ziffern bestehen.';
  end if;

  insert into public.markets (market_number_hash, editor_pin_hash)
  values (
    extensions.digest(v_market_number, 'sha256'::text),
    extensions.crypt(
      p_editor_pin,
      extensions.gen_salt('bf'::text, 10)
    )
  )
  returning id into v_market_id;

  if p_adopt_legacy_products then
    update public.products
    set market_id = v_market_id
    where market_id is null;
  end if;
  return v_market_id;
end;
$$;

revoke all on function public.create_market(text, text, boolean)
  from public, anon, authenticated;
grant execute on function public.create_market(text, text, boolean) to service_role;

-- Öffnet genau den eingegebenen Markt. Ohne PIN wird immer nur Leserechte
-- erteilt; eine korrekte PIN erteilt Bearbeitungsrechte. Fehler verraten nicht,
-- ob die Marktnummer oder die PIN falsch war.
create or replace function public.enter_market(
  p_market_number text,
  p_pin text default null
)
returns table (market_id uuid, access_level text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_market public.markets%rowtype;
  v_access text := 'viewer';
begin
  if auth.uid() is null then
    raise exception 'MARKET_ACCESS_DENIED' using errcode = 'P0001';
  end if;

  select * into v_market
  from public.markets
  where market_number_hash = extensions.digest(
    btrim(p_market_number),
    'sha256'::text
  );

  if not found then
    raise exception 'MARKET_ACCESS_DENIED' using errcode = 'P0001';
  end if;
  if p_pin is not null then
    if extensions.crypt(p_pin, v_market.editor_pin_hash)
       <> v_market.editor_pin_hash then
      raise exception 'MARKET_ACCESS_DENIED' using errcode = 'P0001';
    end if;
    v_access := 'editor';
  end if;

  insert into public.market_sessions as session (
    user_id,
    market_id,
    access_level,
    updated_at
  ) values (
    auth.uid(),
    v_market.id,
    v_access,
    now()
  )
  on conflict (user_id) do update set
    market_id = excluded.market_id,
    access_level = excluded.access_level,
    updated_at = excluded.updated_at;

  return query select v_market.id, v_access;
end;
$$;

create or replace function public.current_market_access()
returns table (market_id uuid, access_level text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select session.market_id, session.access_level
  from public.market_sessions as session
  where session.user_id = auth.uid()
$$;

create or replace function public.upgrade_market_access(p_pin text)
returns table (market_id uuid, access_level text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_market_id uuid;
  v_pin_hash text;
begin
  select session.market_id, market.editor_pin_hash
  into v_market_id, v_pin_hash
  from public.market_sessions as session
  join public.markets as market on market.id = session.market_id
  where session.user_id = auth.uid();

  if v_market_id is null
     or extensions.crypt(p_pin, v_pin_hash) <> v_pin_hash then
    raise exception 'MARKET_PIN_DENIED' using errcode = 'P0001';
  end if;

  update public.market_sessions
  set access_level = 'editor', updated_at = now()
  where user_id = auth.uid();
  return query select v_market_id, 'editor'::text;
end;
$$;

create or replace function public.leave_market()
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  delete from public.market_sessions where user_id = auth.uid()
$$;

revoke all on function public.enter_market(text, text) from public, anon;
revoke all on function public.current_market_access() from public, anon;
revoke all on function public.upgrade_market_access(text) from public, anon;
revoke all on function public.leave_market() from public, anon;
grant execute on function public.enter_market(text, text) to authenticated;
grant execute on function public.current_market_access() to authenticated;
grant execute on function public.upgrade_market_access(text) to authenticated;
grant execute on function public.leave_market() to authenticated;

alter table public.markets enable row level security;
alter table public.market_sessions enable row level security;
alter table public.products enable row level security;
alter table public.product_codes enable row level security;
alter table public.product_images enable row level security;

-- Die Markttabelle bleibt vollständig verborgen. Von der Sitzung darf ein
-- Client nur seine eigene interne Markt-ID und Zugriffsstufe lesen; die
-- Marktnummer und der PIN-Hash liegen ausschließlich in public.markets.
drop policy if exists "users read own market session" on public.market_sessions;
create policy "users read own market session" on public.market_sessions
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "owners read products" on public.products;
drop policy if exists "owners insert products" on public.products;
drop policy if exists "owners update products" on public.products;
drop policy if exists "owners delete products" on public.products;
drop policy if exists "market viewers read products" on public.products;
create policy "market viewers read products" on public.products
  for select to authenticated
  using (
    exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id = products.market_id
    )
  );
drop policy if exists "market editors insert products" on public.products;
create policy "market editors insert products" on public.products
  for insert to authenticated
  with check (
    exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id = products.market_id
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors update products" on public.products;
create policy "market editors update products" on public.products
  for update to authenticated
  using (
    exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id = products.market_id
        and session.access_level = 'editor'
    )
  )
  with check (
    exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id = products.market_id
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors delete products" on public.products;
create policy "market editors delete products" on public.products
  for delete to authenticated
  using (
    exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id = products.market_id
        and session.access_level = 'editor'
    )
  );

drop policy if exists "owners read codes" on public.product_codes;
drop policy if exists "owners insert codes" on public.product_codes;
drop policy if exists "owners update codes" on public.product_codes;
drop policy if exists "owners delete codes" on public.product_codes;
drop policy if exists "market viewers read codes" on public.product_codes;
create policy "market viewers read codes" on public.product_codes
  for select to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_codes.product_id
        and session.user_id = auth.uid()
    )
  );
drop policy if exists "market editors insert codes" on public.product_codes;
create policy "market editors insert codes" on public.product_codes
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_codes.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors update codes" on public.product_codes;
create policy "market editors update codes" on public.product_codes
  for update to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_codes.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  )
  with check (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_codes.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors delete codes" on public.product_codes;
create policy "market editors delete codes" on public.product_codes
  for delete to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_codes.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );

drop policy if exists "owners read images" on public.product_images;
drop policy if exists "owners insert images" on public.product_images;
drop policy if exists "owners update images" on public.product_images;
drop policy if exists "owners delete images" on public.product_images;
drop policy if exists "market viewers read images" on public.product_images;
create policy "market viewers read images" on public.product_images
  for select to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_images.product_id
        and session.user_id = auth.uid()
    )
  );
drop policy if exists "market editors insert images" on public.product_images;
create policy "market editors insert images" on public.product_images
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_images.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors update images" on public.product_images;
create policy "market editors update images" on public.product_images
  for update to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_images.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  )
  with check (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_images.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );
drop policy if exists "market editors delete images" on public.product_images;
create policy "market editors delete images" on public.product_images
  for delete to authenticated
  using (
    exists (
      select 1
      from public.products product
      join public.market_sessions session on session.market_id = product.market_id
      where product.id = product_images.product_id
        and session.user_id = auth.uid()
        and session.access_level = 'editor'
    )
  );

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "owners read stored product images" on storage.objects;
drop policy if exists "owners upload product images" on storage.objects;
drop policy if exists "owners update product images" on storage.objects;
drop policy if exists "owners delete product images" on storage.objects;
drop policy if exists "market viewers read stored product images" on storage.objects;
create policy "market viewers read stored product images" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.market_id::text = (storage.foldername(name))[1]
    )
  );
drop policy if exists "market editors upload product images" on storage.objects;
create policy "market editors upload product images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.access_level = 'editor'
        and session.market_id::text = (storage.foldername(name))[1]
    )
  );
drop policy if exists "market editors update product images" on storage.objects;
create policy "market editors update product images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.access_level = 'editor'
        and session.market_id::text = (storage.foldername(name))[1]
    )
  )
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.access_level = 'editor'
        and session.market_id::text = (storage.foldername(name))[1]
    )
  );
drop policy if exists "market editors delete product images" on storage.objects;
create policy "market editors delete product images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from public.market_sessions session
      where session.user_id = auth.uid()
        and session.access_level = 'editor'
        and session.market_id::text = (storage.foldername(name))[1]
    )
  );
