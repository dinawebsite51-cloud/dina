create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
grant select on public.admin_users to anon, authenticated;
create policy "Admins can read their own admin record" on public.admin_users
for select to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique,
 image_url text, sort_order integer not null default 0, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), name text not null, slug text unique, description text,
 price numeric(12,2) not null default 0 check(price >= 0),
 compare_at_price numeric(12,2) check(compare_at_price is null or compare_at_price >= 0),
 image_url text, images jsonb not null default '[]'::jsonb,
 category_id uuid references public.categories(id) on delete set null,
 stock integer not null default 0 check(stock >= 0), is_active boolean not null default true,
 is_featured boolean not null default false, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists products_category_id_idx on public.products(category_id);
create index if not exists products_active_created_idx on public.products(is_active, created_at desc);

create table if not exists public.discounts (
 id uuid primary key default gen_random_uuid(), title text not null, code text unique, description text,
 discount_type text not null default 'percentage' check(discount_type in ('percentage','fixed')),
 discount_value numeric(12,2) not null check(discount_value > 0), starts_at timestamptz, ends_at timestamptz,
 is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.giveaways (
 id uuid primary key default gen_random_uuid(), title text not null, description text, image_url text,
 starts_at timestamptz, ends_at timestamptz, prize text, is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(), customer_name text not null, customer_email text,
 customer_phone text not null, shipping_address text, items jsonb not null default '[]'::jsonb,
 total numeric(12,2) not null check(total >= 0),
 status text not null default 'pending' check(status in ('pending','confirmed','processing','shipped','delivered','cancelled')),
 notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists orders_created_at_idx on public.orders(created_at desc);

do $$ declare t text; begin
 foreach t in array array['categories','products','discounts','giveaways','orders'] loop
  execute format('alter table public.%I enable row level security',t);
 end loop;
end $$;

grant select on public.categories, public.products, public.discounts, public.giveaways to anon, authenticated;
grant insert, update, delete on public.categories, public.products, public.discounts, public.giveaways to authenticated;
grant insert on public.orders to anon, authenticated;
grant select, update on public.orders to authenticated;

create policy "Anyone can view active categories" on public.categories for select to anon, authenticated
using(is_active or exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins manage categories" on public.categories for all to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Anyone can view active products" on public.products for select to anon, authenticated
using(is_active or exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins manage products" on public.products for all to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Public can view active discounts" on public.discounts for select to anon, authenticated
using(is_active or exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins manage discounts" on public.discounts for all to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Public can view active giveaways" on public.giveaways for select to anon, authenticated
using(is_active or exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins manage giveaways" on public.giveaways for all to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Customers can create orders" on public.orders for insert to anon, authenticated with check(status='pending');
create policy "Admins can read orders" on public.orders for select to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins can update orders" on public.orders for update to authenticated
using(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())));

create trigger set_updated_at before update on public.categories for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.products for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.orders for each row execute function public.set_updated_at();


-- Public product image bucket; only verified admins may upload or manage objects.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=5242880, allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];

create policy "Public can view product images" on storage.objects
for select to anon, authenticated using (bucket_id='product-images');
create policy "Admins can upload product images" on storage.objects
for insert to authenticated with check (bucket_id='product-images' and exists (select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins can update product images" on storage.objects
for update to authenticated using (bucket_id='product-images' and exists (select 1 from public.admin_users a where a.user_id=(select auth.uid())))
with check (bucket_id='product-images' and exists (select 1 from public.admin_users a where a.user_id=(select auth.uid())));
create policy "Admins can delete product images" on storage.objects
for delete to authenticated using (bucket_id='product-images' and exists (select 1 from public.admin_users a where a.user_id=(select auth.uid())));
