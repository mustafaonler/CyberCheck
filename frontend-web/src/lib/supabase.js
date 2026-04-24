import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// createClient fonksiyonuna iki parametreyi aralarında virgül olacak şekilde gönderiyoruz
export const supabase = createClient(
    supabaseUrl || '',
    supabaseAnonKey || ''
);


