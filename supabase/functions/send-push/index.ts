// ============================================================
// Edge Function: send-push
// Receives a notification payload, checks user preferences,
// fetches FCM tokens, and delivers via FCM HTTP v1 API.
//
// Secrets required (set via `supabase secrets set`):
//   FCM_SERVICE_ACCOUNT_JSON  — contents of your Firebase
//                               service account JSON file
//   SUPABASE_URL              — auto-injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected by Supabase
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SA_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? ''

// ── FCM HTTP v1 helpers ────────────────────────────────────

/** Convert PEM private key string to CryptoKey for RS256 signing */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '')
  const binary = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

/** Base64url-encode a string or Uint8Array */
function base64url(input: string | Uint8Array): string {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : input
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

/** Build a signed JWT for the Google OAuth2 token endpoint */
async function buildJwt(
  clientEmail: string,
  privateKey: CryptoKey,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64url(
    JSON.stringify({
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )
  const signingInput = `${header}.${payload}`
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signingInput),
  )
  return `${signingInput}.${base64url(new Uint8Array(signature))}`
}

/** Exchange signed JWT for a Google OAuth2 access token */
async function getAccessToken(
  clientEmail: string,
  privateKey: CryptoKey,
): Promise<string> {
  const jwt = await buildJwt(clientEmail, privateKey)
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const json = await res.json()
  if (!res.ok) throw new Error(`OAuth error: ${JSON.stringify(json)}`)
  return json.access_token as string
}

/** Send one FCM message to a single token */
async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        data,
        android: {
          notification: { sound: 'default', priority: 'high' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      },
    }),
  })
  if (!res.ok) {
    const err = await res.text()
    console.warn(`FCM send failed for token ${fcmToken.slice(0, 10)}...: ${err}`)
  }
}

// ── Preference column map ───────────────────────────────────
// Maps notification.type → notification_preferences column name
const TYPE_TO_PREF: Record<string, string> = {
  quote_submitted: 'push_maintenance',
  job_approved: 'push_maintenance',
  incident_status_change: 'push_maintenance',
  rent_overdue: 'push_rent',
  compliance_expiring: 'push_compliance',
  new_application: 'push_applications',
  invitation_received: 'push_maintenance', // always deliver invites
}

// ── Main handler ───────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify the request came from our own service-role bearer
  const auth = req.headers.get('Authorization') ?? ''
  if (!auth.startsWith('Bearer ') || auth.slice(7) !== SUPABASE_SERVICE_KEY) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: {
    user_id: string
    type: string
    title: string
    body: string
    data: Record<string, unknown>
  }

  try {
    payload = await req.json()
  } catch {
    return new Response('Bad JSON', { status: 400 })
  }

  const { user_id, type, title, body, data } = payload

  // If FCM is not configured, return early gracefully
  if (!FCM_SA_JSON) {
    console.warn('FCM_SERVICE_ACCOUNT_JSON not set — skipping push')
    return new Response(JSON.stringify({ skipped: true }), { status: 200 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

  // Check notification preferences
  const prefCol = TYPE_TO_PREF[type] ?? 'push_maintenance'
  const { data: prefs } = await supabase
    .from('notification_preferences')
    .select(`push_enabled, ${prefCol}`)
    .eq('user_id', user_id)
    .maybeSingle()

  // Default: send if no prefs row (new user)
  const pushEnabled = prefs === null ? true : prefs.push_enabled
  const typeEnabled = prefs === null ? true : prefs[prefCol as keyof typeof prefs]
  if (!pushEnabled || !typeEnabled) {
    return new Response(JSON.stringify({ suppressed: true }), { status: 200 })
  }

  // Fetch FCM tokens for this user
  const { data: tokens } = await supabase
    .from('fcm_tokens')
    .select('token')
    .eq('user_id', user_id)

  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ no_tokens: true }), { status: 200 })
  }

  // Build FCM access token once for all sends
  let serviceAccount: { client_email: string; private_key: string; project_id: string }
  try {
    serviceAccount = JSON.parse(FCM_SA_JSON)
  } catch {
    console.error('Invalid FCM_SERVICE_ACCOUNT_JSON')
    return new Response('Server config error', { status: 500 })
  }

  const privateKey = await importPrivateKey(serviceAccount.private_key)
  const accessToken = await getAccessToken(serviceAccount.client_email, privateKey)

  // Stringify data values for FCM (all must be strings)
  const stringData: Record<string, string> = {}
  for (const [k, v] of Object.entries(data ?? {})) {
    stringData[k] = String(v)
  }
  stringData['type'] = type

  // Send to all tokens concurrently
  await Promise.allSettled(
    tokens.map(({ token }: { token: string }) =>
      sendFcmMessage(
        serviceAccount.project_id,
        accessToken,
        token,
        title,
        body,
        stringData,
      ),
    ),
  )

  return new Response(
    JSON.stringify({ sent: tokens.length }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  )
})
