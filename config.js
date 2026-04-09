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

function formatSupabaseError(err) {
  if (!err) return 'Unknown Supabase error.';
  if (typeof err === 'string') return err;

  const bits = [];
  if (err.message) bits.push(err.message);
  if (err.code) bits.push(`code: ${err.code}`);
  if (err.details) bits.push(`details: ${err.details}`);
  if (err.hint) bits.push(`hint: ${err.hint}`);

  if (bits.length) return bits.join(' · ');
  return 'Unknown Supabase error.';
}

function getSupabaseTroubleshootingHint(err) {
  const text = formatSupabaseError(err).toLowerCase();

  if (text.includes('failed to fetch') || text.includes('network') || text.includes('timeout')) {
    return 'Check your internet connection, firewall/proxy, and that your Supabase project URL is reachable.';
  }
  if (text.includes('invalid api key') || text.includes('jwt') || text.includes('apikey')) {
    return 'Your API key appears invalid. Copy the current publishable (or anon) key from Supabase Dashboard → Settings → API.';
  }
  if (text.includes('relation') && text.includes('does not exist')) {
    return 'A required table is missing. Run schema.sql in your Supabase SQL editor.';
  }
  if (text.includes('permission denied') || text.includes('row-level security') || text.includes('rls')) {
    return 'RLS policy is blocking reads/writes. Update policies for the trees and pending_changes tables.';
  }
  return 'Open DevTools Console for the exact Supabase error and verify URL/key in config.js.';
}

window.HONMOKU_CONFIG = {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  getSupabaseStatus,
  createHonmokuSupabaseClient,
  formatSupabaseError,
  getSupabaseTroubleshootingHint
};
