import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";

serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature");

  if (!signature) {
    return new Response("No signature", { status: 400 });
  }

  try {
    // Get Stripe keys from environment
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

    if (!stripeSecretKey || !stripeWebhookSecret) {
      throw new Error("Stripe keys not configured");
    }

    // Initialize Stripe
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2023-10-16",
      httpClient: Stripe.createFetchHttpClient(),
    });

    // Get raw body as text for signature verification
    const body = await req.text();

    // Verify webhook signature
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      stripeWebhookSecret,
      undefined,
      Stripe.createSubtleCryptoProvider()
    );

    console.log("Received event:", event.type);

    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Handle different event types
    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log("Payment succeeded:", paymentIntent.id);

        // Get payment method details
        const paymentMethodType =
          paymentIntent.payment_method_types?.[0] || "card";

        // Confirm payment in our database
        const { data, error } = await supabase.rpc("confirm_stripe_payment", {
          p_payment_intent_id: paymentIntent.id,
          p_payment_method_type: paymentMethodType,
        });

        if (error) {
          console.error("Error confirming payment:", error);
          throw error;
        }

        console.log("Payment confirmed in database:", data);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log("Payment failed:", paymentIntent.id);

        const errorMessage =
          paymentIntent.last_payment_error?.message || "Payment failed";

        // Mark payment as failed in our database
        const { error } = await supabase.rpc("cancel_stripe_payment", {
          p_payment_intent_id: paymentIntent.id,
          p_error_message: errorMessage,
        });

        if (error) {
          console.error("Error canceling payment:", error);
          throw error;
        }

        console.log("Payment marked as failed in database");
        break;
      }

      case "payment_intent.canceled": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log("Payment canceled:", paymentIntent.id);

        // Mark payment as canceled in our database
        const { error } = await supabase.rpc("cancel_stripe_payment", {
          p_payment_intent_id: paymentIntent.id,
          p_error_message: "Payment canceled by user",
        });

        if (error) {
          console.error("Error canceling payment:", error);
          throw error;
        }

        console.log("Payment marked as canceled in database");
        break;
      }

      case "payment_intent.processing": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        console.log("Payment processing:", paymentIntent.id);

        // Update status to processing
        const { error } = await supabase
          .from("stripe_payment_intents")
          .update({
            status: "processing",
            updated_at: new Date().toISOString(),
          })
          .eq("payment_intent_id", paymentIntent.id);

        if (error) {
          console.error("Error updating payment status:", error);
        }
        break;
      }

      default:
        console.log("Unhandled event type:", event.type);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    });
  }
});
