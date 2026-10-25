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
- Product images can be uploaded by verified admins to the `product-images` Storage bucket (maximum 5 MB per image).

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
4. Sign in at `/admin.html` using that account's Supabase Auth password. Do not use a hardcoded shared password.

## Frontend client
The root `index.html` is a Supabase-connected storefront with search, cart/order submission, and realtime product refresh. `admin.html` provides admin sign-in, product create/edit/delete, direct image upload, and order status updates.

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
`netlify.toml` is configured to publish the repository root. If the Netlify site is linked to this GitHub repository, new commits should trigger a deploy. The live Netlify site was not directly verifiable from this environment, so check the Netlify Deploys page to confirm that the repository is connected and the latest commit has deployed. Never put a service-role key in Netlify frontend variables or public files.

## Important order security
Public order insertion is enabled for storefront checkout. For production, validate prices and stock server-side before trusting order totals; do not treat client-submitted totals as authoritative.
