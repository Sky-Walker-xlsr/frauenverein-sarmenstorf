import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

// All app data lives in the "frv-p-01" schema (must be added to
// Project Settings -> API -> Exposed schemas in Supabase).
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  db: { schema: 'frv-p-01' },
});

export const GALLERY_BUCKET = 'frv-buk-p-01';
