import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Adapter le format du corps et la vérification de signature à la doc de Wave / Orange Money
Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) return new Response("forbidden", { status: 403 });
  const { reference, status } = await req.json(); // status attendu : "success" | "failed" | "cancelled"
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: p } = await db.from("payments").select("id, booking_id, status").eq("provider_reference", reference).maybeSingle();
  if (!p) return new Response("inconnu", { status: 404 });
  if (p.status === "reussi") return new Response("ok"); // idempotent

  if (status !== "success") {
    await db.from("payments").update({ status: status === "cancelled" ? "annule" : "echoue" }).eq("id", p.id);
    await db.from("bookings").update({ status: "expiree" }).eq("id", p.booking_id).eq("status", "paiement_en_attente");
    return new Response("ok");
  }

  await db.from("payments").update({ status: "reussi" }).eq("id", p.id);
  // Paiement tardif : la réservation peut être réactivée si le créneau est encore libre (sinon la contrainte SQL refuse)
  const { data, error } = await db.from("bookings").update({ status: "confirmee", expires_at: null })
    .eq("id", p.booking_id).in("status", ["paiement_en_attente", "expiree"]).select("id");
  if (error || !data?.length) await db.from("payments").update({ needs_refund: true }).eq("id", p.id);
  return new Response("ok");
});
