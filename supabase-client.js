/*
 * Dina Store Supabase browser client.
 * Safe to include in public frontend: this uses a publishable/anon key only.
 * Never place a Supabase service_role or secret key in browser code.
 *
 * Before use, load @supabase/supabase-js v2 (UMD build) before this file.
 */
(function () {
  const SUPABASE_URL = "https://ptllrowwgjrlmmuanpyj.supabase.co";
  const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_fKj6i2v8y4jYenPOzjHIBQ_F3tWgvFa";
  if (!window.supabase || !window.supabase.createClient) {
    console.error("Dina Store: load the Supabase JS v2 library before supabase-client.js");
    return;
  }
  window.dinaSupabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
})();