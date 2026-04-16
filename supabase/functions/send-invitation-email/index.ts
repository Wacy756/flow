// ============================================================
// Edge Function: send-invitation-email
//
// Called by a Supabase DB webhook on INSERT to the tenancies table
// (or directly from the app after creating a tenancy).
//
// Sends a tenant invitation email via Resend.
//
// Secrets required (supabase secrets set):
//   RESEND_API_KEY      — from resend.com
//   FROM_EMAIL          — verified sender, e.g. noreply@flow.app
//   APP_URL             — your app's public URL, e.g. https://flow.app
//   SUPABASE_URL        — auto-injected
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected
// ============================================================

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL') ?? 'noreply@flow.app'
const APP_URL        = Deno.env.get('APP_URL') ?? 'https://flow.app'
const SERVICE_KEY    = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

interface InvitationPayload {
  tenant_email: string
  tenant_name?: string
  landlord_name: string
  property_address: string
  tenancy_id: string
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify caller is our own service
  const auth = req.headers.get('Authorization') ?? ''
  if (!auth.startsWith('Bearer ') || auth.slice(7) !== SERVICE_KEY) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: InvitationPayload
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad JSON', { status: 400 })
  }

  const {
    tenant_email,
    tenant_name,
    landlord_name,
    property_address,
    tenancy_id,
  } = payload

  if (!tenant_email) {
    return new Response('tenant_email required', { status: 400 })
  }

  if (!RESEND_API_KEY) {
    console.warn('RESEND_API_KEY not set — skipping email')
    return new Response(JSON.stringify({ skipped: true }), { status: 200 })
  }

  const greeting = tenant_name ? `Hi ${tenant_name},` : 'Hi,'
  const signupUrl = `${APP_URL}/auth?mode=signup&role=tenant`

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>You've been invited to Flow</title>
</head>
<body style="margin:0;padding:0;background:#0f0f0f;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0f0f0f;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width:560px;background:#1a1a1a;border-radius:16px;border:1px solid #2a2a2a;overflow:hidden;">

          <!-- Header -->
          <tr>
            <td style="padding:32px 36px 24px;border-bottom:1px solid #2a2a2a;">
              <p style="margin:0;font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">Flow</p>
              <p style="margin:6px 0 0;font-size:13px;color:#888;">Property management that flows.</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px 36px;">
              <p style="margin:0 0 16px;font-size:15px;color:#cccccc;line-height:1.6;">${greeting}</p>
              <p style="margin:0 0 20px;font-size:15px;color:#cccccc;line-height:1.6;">
                <strong style="color:#ffffff;">${landlord_name}</strong> has invited you to manage your tenancy
                at <strong style="color:#ffffff;">${property_address}</strong> through Flow.
              </p>

              <!-- Property card -->
              <table width="100%" style="background:#0f0f0f;border-radius:12px;border:1px solid #2a2a2a;margin-bottom:24px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0;font-size:10px;font-weight:700;color:#666;letter-spacing:0.8px;text-transform:uppercase;">Your property</p>
                    <p style="margin:6px 0 0;font-size:15px;font-weight:700;color:#ffffff;">${property_address}</p>
                    <p style="margin:4px 0 0;font-size:12px;color:#888;">Invited by ${landlord_name}</p>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 20px;font-size:14px;color:#aaaaaa;line-height:1.6;">
                With Flow you can:
              </p>
              <ul style="margin:0 0 28px;padding-left:20px;color:#aaaaaa;font-size:14px;line-height:1.8;">
                <li>View your tenancy details and rent history</li>
                <li>Report maintenance issues instantly</li>
                <li>Access safety certificates and compliance docs</li>
                <li>Receive updates on repairs in real time</li>
              </ul>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <a href="${signupUrl}"
                       style="display:inline-block;background:#22c55e;color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;padding:14px 36px;border-radius:12px;letter-spacing:-0.2px;">
                      Accept invitation &amp; sign up
                    </a>
                  </td>
                </tr>
              </table>

              <p style="margin:0;font-size:12px;color:#666;line-height:1.6;text-align:center;">
                Sign up using this email address (<strong style="color:#888;">${tenant_email}</strong>)
                so your landlord can link you to the property automatically.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px 36px;border-top:1px solid #2a2a2a;">
              <p style="margin:0;font-size:11px;color:#555;text-align:center;line-height:1.6;">
                You received this email because ${landlord_name} added your email address to a tenancy on Flow.<br>
                If you don't recognise this, you can safely ignore this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`

  const text = `
${greeting}

${landlord_name} has invited you to manage your tenancy at ${property_address} through Flow.

Accept your invitation and sign up at: ${signupUrl}

Make sure to sign up using this email address (${tenant_email}) so your landlord can link you to the property automatically.

— The Flow Team
`

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [tenant_email],
      subject: `${landlord_name} invited you to manage your tenancy on Flow`,
      html,
      text,
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    console.error('Resend error:', err)
    return new Response(JSON.stringify({ error: err }), { status: 502 })
  }

  const data = await res.json()
  console.log('Email sent:', data.id)
  return new Response(JSON.stringify({ sent: true, id: data.id }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
