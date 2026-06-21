import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Require a valid Supabase session
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorised' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorised' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const { product, propertyId, partner, accessMethod, preferredDate, notes } = body;

    // Pricing (in pence)
    const PRICES: Record<string, number> = {
      'aiic': 9900,         // £99 — AIIC clerk booking
      'no_letting_go': 8900, // £89 — No Letting Go booking
    };

    const amount = PRICES[partner as string];
    if (!amount) {
      return new Response(JSON.stringify({ error: 'Unknown partner' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'gbp',
      automatic_payment_methods: { enabled: true },
      metadata: {
        landlord_id: user.id,
        property_id: propertyId ?? '',
        partner: partner ?? '',
        access_method: accessMethod ?? '',
        preferred_date: preferredDate ?? '',
      },
    });

    // Pre-create the booking row in pending state so we have a record
    // before the client confirms payment. Webhook updates payment_status to 'paid'.
    await supabase.from('clerk_booking_requests').insert({
      landlord_id: user.id,
      property_id: propertyId,
      partner,
      access_method: accessMethod,
      preferred_date: preferredDate || null,
      notes: notes || null,
      stripe_payment_intent_id: paymentIntent.id,
      payment_status: 'pending',
    });

    return new Response(
      JSON.stringify({ clientSecret: paymentIntent.client_secret }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
