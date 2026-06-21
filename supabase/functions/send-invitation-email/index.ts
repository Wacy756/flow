import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface InvitePayload {
  // Agent inviting a landlord
  invited_email?: string;
  agency_name?: string;
  invite_type?: 'agent_landlord' | 'contractor_invite';
  // Landlord inviting a tenant
  tenant_email?: string;
  landlord_name?: string;
  property_address?: string;
  tenancy_id?: string;
  // Contractor invite (admin → contractor)
  contractor_email?: string;
}

async function sendEmail(to: string, subject: string, html: string): Promise<void> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'Abode <noreply@useabode.co.uk>',
      to,
      subject,
      html,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await callerClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const payload = await req.json() as InvitePayload;

    let to: string;
    let subject: string;
    let htmlBody: string;

    if (payload.invite_type === 'agent_landlord' && payload.invited_email) {
      to = payload.invited_email;
      const agencyName = payload.agency_name ?? 'Your letting agent';
      subject = `${agencyName} has invited you to Abode`;
      htmlBody = `
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
          <h2 style="color:#111;font-size:22px;font-weight:700;margin-bottom:8px">
            You've been invited to Abode
          </h2>
          <p style="color:#555;font-size:15px;line-height:1.6;margin-bottom:24px">
            <strong>${agencyName}</strong> has added you as a landlord client on
            Abode — the property management platform that keeps you in control.
          </p>
          <p style="color:#555;font-size:15px;line-height:1.6;margin-bottom:24px">
            Sign up at <a href="https://app.useabode.co.uk" style="color:#2563eb">app.useabode.co.uk</a>
            using this email address to connect with your agent and manage your properties.
          </p>
          <div style="background:#f5f5f5;border-radius:10px;padding:16px;margin-bottom:24px">
            <p style="color:#333;font-size:13px;margin:0">
              Sign up with: <strong>${to}</strong>
            </p>
          </div>
          <p style="color:#999;font-size:12px">
            If you didn't expect this invitation, you can safely ignore this email.
          </p>
        </div>`;
    } else if (payload.tenant_email && payload.landlord_name) {
      to = payload.tenant_email;
      const address = payload.property_address ?? 'your property';
      subject = `${payload.landlord_name} has invited you to Abode`;
      htmlBody = `
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
          <h2 style="color:#111;font-size:22px;font-weight:700;margin-bottom:8px">
            Your landlord has invited you to Abode
          </h2>
          <p style="color:#555;font-size:15px;line-height:1.6;margin-bottom:24px">
            <strong>${payload.landlord_name}</strong> has invited you to manage
            your tenancy at <strong>${address}</strong> through Abode.
          </p>
          <p style="color:#555;font-size:15px;line-height:1.6;margin-bottom:24px">
            Sign up at <a href="https://app.useabode.co.uk" style="color:#2563eb">app.useabode.co.uk</a>
            using this exact email address — your tenancy invite will appear automatically.
          </p>
          <div style="background:#f5f5f5;border-radius:10px;padding:16px;margin-bottom:24px">
            <p style="color:#333;font-size:13px;margin:0">
              Sign up with: <strong>${to}</strong>
            </p>
          </div>
          <p style="color:#999;font-size:12px">
            If you didn't expect this invitation, you can safely ignore this email.
          </p>
        </div>`;
    } else if (payload.invite_type === 'contractor_invite' && payload.contractor_email) {
      to = payload.contractor_email;
      subject = "You've been invited to join Abode as a contractor";
      htmlBody = `
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
          <h2 style="color:#111;font-size:22px;font-weight:700;margin-bottom:8px">
            Join Abode as a contractor
          </h2>
          <p style="color:#555;font-size:15px;line-height:1.6;margin-bottom:24px">
            You've been personally invited by the Abode team to register as a
            contractor on our platform. We connect trusted tradespeople with
            landlords and letting agents across the UK.
          </p>
          <a href="https://app.useabode.co.uk/auth?role=contractor&mode=signup"
             style="display:inline-block;background:#1a1a1a;color:#fff;
                    font-size:15px;font-weight:700;padding:14px 28px;
                    border-radius:10px;text-decoration:none;margin-bottom:24px">
            Set up your contractor account
          </a>
          <p style="color:#555;font-size:14px;line-height:1.6;margin-bottom:16px">
            Sign up with this email address (<strong>${to}</strong>) to claim your invite.
            Once registered, our team will review your credentials and you'll be
            ready to start receiving jobs.
          </p>
          <p style="color:#999;font-size:12px">
            If you didn't expect this, you can safely ignore this email.
          </p>
        </div>`;
    } else {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    await sendEmail(to, subject, htmlBody);

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('send-invitation-email error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
