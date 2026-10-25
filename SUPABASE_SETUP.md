# Dina Store — Supabase setup

Project: `dina-store`
Project ref: `ptllrowwgjrlmmuanpyj`
URL: https://ptllrowwgjrlmmuanpyj.supabase.co

## What is configured
- Products and categories with public read access for active items.
- Discounts and giveaways with public read access for active campaigns.
- Orders can be submitted publicly; only admins can read or update orders.
- Row Level Security is enabled on all public tables.
- Only users listed in `public.admin_users` can manage catalog/campaign content.

## Make your account an admin
1. In Supabase Dashboard, open Authentication > Users and create/invite the admin user using your intended admin email.
2. Copy that user's UUID.
3. Open SQL Editor and run this statement after replacing the UUID and email with the exact values:
   ```sql
   insert into public.admin_users (user_id, email)
   values ('PASTE_AUTH_USER_UUID_HERE', 'dinawebsite51@gmail.com')
   on conflict (user_id) do update set email = excluded.email;
   ```
   Do not let the browser create admin_users records. This table is intentionally protected.
4. Sign in with Supabase Auth from the admin page. Do not use a hardcoded shared password.

## Frontend client
Load Supabase JS v2 before `supabase-client.js`, then use `window.dinaSupabase`:
```js
const { data, error } = await window.dinaSupabase
  .from('products')
  .select('*')
  .order('created_at', { ascending: false });
```

For realtime product updates:
```js
const channel = window.dinaSupabase
  .channel('dina-products-live')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, payload => {
    window.dispatchEvent(new CustomEvent('dina:products-changed', { detail: payload }));
  })
  .subscribe();
```

## Netlify
If this repository is linked to the Netlify site, new commits deploy automatically. Set the publish directory to the directory containing the actual storefront HTML. This repository currently contains only a README at its root, so the live site frontend is not yet confirmed to be in this repository. Add `supabase-client.js` to the real storefront and load the Supabase JS v2 CDN script first. Never put a service-role key in Netlify frontend variables or public files.

## Important order security
Public order insertion is enabled for storefront checkout. For production, validate prices and stock server-side before trusting order totals; do not treat client-submitted totals as authoritative.
