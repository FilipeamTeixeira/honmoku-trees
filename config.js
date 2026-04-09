// ============================================================================
// Supabase configuration — edit this file once for all pages
// Find your values at: Supabase Dashboard → Settings → API
// ============================================================================
const SUPABASE_URL      = 'https://xgnoqhikgvpltpbcgfwu.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_P2I_fEyQdpcBJWRMt5yHCw_UsOUMnEL';

// Shared runtime helpers for all pages.
function getSupabaseStatus() {
  const url = (SUPABASE_URL || '').trim();
  const key = (SUPABASE_ANON_KEY || '').trim();
  const placeholderUrl = !url || url.includes('YOUR_PROJECT_ID');
  const placeholderKey = !key || key.includes('YOUR_ANON_KEY');
  const runningFromFile = window.location.protocol === 'file:';

  if (placeholderUrl || placeholderKey) {
    return {
      enabled: false,
      reason: 'missing_config',
      message: 'Supabase is not configured. Update SUPABASE_URL and SUPABASE_ANON_KEY in config.js.'
    };
  }

  if (runningFromFile) {
    return {
      enabled: false,
      reason: 'file_protocol',
      message: 'This app is opened as a local file (file://). Start a local web server (http://localhost) to use Supabase login and database.'
    };
  }

  return { enabled: true, reason: 'ok', message: '' };
}

function createHonmokuSupabaseClient() {
  const status = getSupabaseStatus();
  if (!status.enabled) return null;
  if (!window.supabase?.createClient) {
    throw new Error('Supabase JS failed to load. Check network / CDN availability.');
  }
  return window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

window.HONMOKU_CONFIG = {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  getSupabaseStatus,
  createHonmokuSupabaseClient
};
