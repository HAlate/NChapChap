import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get Stripe secret key from environment
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      throw new Error("STRIPE_SECRET_KEY not configured");
    }

    // Initialize Stripe
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2023-10-16",
      httpClient: Stripe.createFetchHttpClient(),
    });

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    // Get user from token
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      throw new Error("Invalid user token");
    }

    // Parse request body
    const { packageId, currency = "usd" } = await req.json();

    if (!packageId) {
      throw new Error("packageId is required");
    }

    // Get package details from database
    const { data: tokenPackage, error: packageError } = await supabase
      .from("token_packages")
      .select("*")
      .eq("id", packageId)
      .eq("is_active", true)
      .single();

    if (packageError || !tokenPackage) {
      throw new Error("Token package not found or inactive");
    }

    // Calculate amount in cents based on currency
    let amountCents: number;
    if (currency === "usd") {
      amountCents =
        tokenPackage.price_usd_cents || Math.round(tokenPackage.price_fcfa / 6); // Fallback conversion
    } else if (currency === "fcfa") {
      // Convert USD to F CFA (approximate 1 USD = 0.92 F CFA)
      amountCents = Math.round(
        (tokenPackage.price_usd_cents ||
          Math.round(tokenPackage.price_fcfa / 6)) * 0.92
      );
    } else {
      throw new Error("Unsupported currency");
    }

    // Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        userId: user.id,
        packageId: packageId,
        tokenAmount: tokenPackage.token_amount.toString(),
        bonusTokens: tokenPackage.bonus_tokens.toString(),
      },
    });

    // Store payment intent in our database
    const { data: dbIntent, error: dbError } = await supabase.rpc(
      "create_stripe_payment_intent",
      {
        p_user_id: user.id,
        p_token_package_id: packageId,
        p_amount_cents: amountCents,
        p_currency: currency,
        p_payment_intent_id: paymentIntent.id,
        p_client_secret: paymentIntent.client_secret,
      }
    );

    if (dbError) {
      console.error("Database error:", dbError);
      throw new Error("Failed to store payment intent");
    }

    // Return payment intent details
    return new Response(
      JSON.stringify({
        paymentIntentId: paymentIntent.id,
        clientSecret: paymentIntent.client_secret,
        amount: amountCents,
        currency: currency,
        tokenAmount: tokenPackage.token_amount,
        bonusTokens: tokenPackage.bonus_tokens,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
