import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

// All app data lives in the default "public" schema.
export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export const GALLERY_BUCKET = 'frv-buk-p-01';
