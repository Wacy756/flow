import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);

Deno.serve(async (req) => {
  const signature = req.headers.get('stripe-signature');
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');

  if (!signature || !webhookSecret) {
    return new Response('Missing signature or webhook secret', { status: 400 });
  }

  const body = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return new Response('Invalid signature', { status: 400 });
  }

  try {
    // ── One-time payment events (clerk booking requests) ──────────────────────
    if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object as Stripe.PaymentIntent;
      await supabase
        .from('clerk_booking_requests')
        .update({ payment_status: 'paid', booking_status: 'confirmed' })
        .eq('stripe_payment_intent_id', pi.id);
    }

    if (event.type === 'payment_intent.payment_failed') {
      const pi = event.data.object as Stripe.PaymentIntent;
      await supabase
        .from('clerk_booking_requests')
        .update({ payment_status: 'failed' })
        .eq('stripe_payment_intent_id', pi.id);
    }

    // ── Subscription events ───────────────────────────────────────────────────

    // checkout.session.completed fires when the user finishes Stripe Checkout.
    // client_reference_id is set to the Supabase user ID in create-checkout-session.
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      if (session.mode === 'subscription' && session.client_reference_id) {
        const userId = session.client_reference_id;
        const stripeCustomerId = typeof session.customer === 'string'
          ? session.customer
          : (session.customer as Stripe.Customer | null)?.id ?? null;
        const stripeSubscriptionId = typeof session.subscription === 'string'
          ? session.subscription
          : (session.subscription as Stripe.Subscription | null)?.id ?? null;

        // Fetch subscription to get interval
        let billingInterval = 'monthly';
        if (stripeSubscriptionId) {
          const sub = await stripe.subscriptions.retrieve(stripeSubscriptionId);
          const planInterval = sub.items.data[0]?.plan?.interval;
          if (planInterval === 'year') billingInterval = 'annual';
        }

        await supabase.from('profiles').update({
          stripe_customer_id: stripeCustomerId,
          stripe_subscription_id: stripeSubscriptionId,
          subscription_status: 'active',
          selected_plan: 'essential',
          billing_interval: billingInterval,
        }).eq('id', userId);
      }
    }

    // Subscription updated — status can be active, past_due, unpaid, etc.
    if (event.type === 'customer.subscription.updated') {
      const sub = event.data.object as Stripe.Subscription;
      const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer?.id;
      const status = sub.status; // active | past_due | unpaid | canceled | trialing
      const isActive = status === 'active' || status === 'trialing';
      const billingInterval = sub.items.data[0]?.plan?.interval === 'year' ? 'annual' : 'monthly';

      await supabase.from('profiles').update({
        subscription_status: status,
        billing_interval: billingInterval,
        selected_plan: isActive ? 'essential' : 'free',
      }).eq('stripe_customer_id', customerId);
    }

    // Subscription cancelled (immediately or at period end)
    if (event.type === 'customer.subscription.deleted') {
      const sub = event.data.object as Stripe.Subscription;
      const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer?.id;

      await supabase.from('profiles').update({
        subscription_status: 'cancelled',
        stripe_subscription_id: null,
        selected_plan: 'free',
      }).eq('stripe_customer_id', customerId);
    }

  } catch (err) {
    console.error('Error processing webhook event:', err);
    return new Response('Internal error', { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
