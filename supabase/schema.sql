-- Im Supabase SQL Editor einmalig ausführen.
-- Danach unter Authentication einen Benutzer mit E-Mail und Passwort anlegen.

create table if not exists public.products (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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
  add column if not exists aliases text[] not null default '{}';
alter table public.products
  add column if not exists is_organic boolean not null default false;
alter table public.products
  add column if not exists is_promotion boolean not null default false;

create table if not exists public.product_codes (
  id uuid primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null check (type in ('plu', 'price', 'barcode')),
  value text not null,
  is_active boolean not null default false,
  note text not null default '',
  created_at timestamptz not null,
  retired_at timestamptz
);

create table if not exists public.product_images (
  id uuid primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
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

create unique index if not exists one_active_code_per_product
  on public.product_codes(product_id)
  where is_active;
create index if not exists products_owner_updated
  on public.products(owner_id, updated_at desc);
create index if not exists product_codes_product
  on public.product_codes(product_id);
create index if not exists product_images_product
  on public.product_images(product_id, sort_order);

alter table public.products enable row level security;
alter table public.product_codes enable row level security;
alter table public.product_images enable row level security;

drop policy if exists "owners read products" on public.products;
create policy "owners read products" on public.products
  for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "owners insert products" on public.products;
create policy "owners insert products" on public.products
  for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists "owners update products" on public.products;
create policy "owners update products" on public.products
  for update to authenticated using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);
drop policy if exists "owners delete products" on public.products;
create policy "owners delete products" on public.products
  for delete to authenticated using (auth.uid() = owner_id);

drop policy if exists "owners read codes" on public.product_codes;
create policy "owners read codes" on public.product_codes
  for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "owners insert codes" on public.product_codes;
create policy "owners insert codes" on public.product_codes
  for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists "owners update codes" on public.product_codes;
create policy "owners update codes" on public.product_codes
  for update to authenticated using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);
drop policy if exists "owners delete codes" on public.product_codes;
create policy "owners delete codes" on public.product_codes
  for delete to authenticated using (auth.uid() = owner_id);

drop policy if exists "owners read images" on public.product_images;
create policy "owners read images" on public.product_images
  for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "owners insert images" on public.product_images;
create policy "owners insert images" on public.product_images
  for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists "owners update images" on public.product_images;
create policy "owners update images" on public.product_images
  for update to authenticated using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);
drop policy if exists "owners delete images" on public.product_images;
create policy "owners delete images" on public.product_images
  for delete to authenticated using (auth.uid() = owner_id);

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "owners upload product images" on storage.objects;
create policy "owners upload product images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "owners update product images" on storage.objects;
create policy "owners update product images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "owners delete product images" on storage.objects;
create policy "owners delete product images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
