import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
const mins = (t: string) => { const [h, m] = t.split(":").map(Number); return h * 60 + m; };

// À remplacer par l'appel réel à l'API marchande Wave / Orange Money
async function initiatePayment(_p: { method: string; amount: number; bookingCode: string; paymentId: string }): Promise<{ reference: string; checkoutUrl: string }> {
  throw new Error("initiatePayment non implémentée");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "Non connecté" }, 401);
  const db = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Requête invalide" }, 400); }
  const { pitch_id, starts_at, duration_hours, payment_method } = body;
  const dur = Number(duration_hours), start = new Date(starts_at);
  if (!pitch_id || isNaN(start.getTime()) || !Number.isInteger(dur) || dur < 1) return json({ error: "Paramètres invalides" }, 400);
  if (!["wave", "orange_money"].includes(payment_method)) return json({ error: "Moyen de paiement invalide" }, 400);
  if (start.getUTCMinutes() !== 0 || start.getUTCSeconds() !== 0) return json({ error: "Heure pile requise" }, 400);
  if (start.getTime() <= Date.now()) return json({ error: "Ce créneau est déjà passé" }, 400);

  const { data: pitch } = await db.from("pitches").select("price_per_hour, opening_time, closing_time, is_active").eq("id", pitch_id).maybeSingle();
  if (!pitch || !pitch.is_active) return json({ error: "Terrain indisponible" }, 404);

  // Kaolack = UTC+0 : l'heure UTC est l'heure locale
  const open = mins(pitch.opening_time); let close = mins(pitch.closing_time);
  if (close <= open) close += 1440;
  let s = start.getUTCHours() * 60;
  if (s < open && close > 1440) s += 1440;
  if (s < open || s + dur * 60 > close) return json({ error: "Créneau hors des horaires du terrain" }, 400);

  const { data: rows } = await db.from("app_settings").select("key, value").in("key", ["hold_minutes", "deposit_amount", "commission_amount"]);
  const st = Object.fromEntries((rows ?? []).map((r) => [r.key, Number(r.value)]));
  if (!st.hold_minutes || !st.deposit_amount || st.commission_amount == null) return json({ error: "Paramètres manquants" }, 500);

  // Anti-abus : un joueur ne peut pas bloquer plus de 2 créneaux non payés à la fois
  const { count } = await db.from("bookings").select("id", { count: "exact", head: true }).eq("player_id", user.id).eq("status", "paiement_en_attente");
  if ((count ?? 0) >= 2) return json({ error: "Terminez ou attendez l'expiration de vos paiements en cours" }, 429);

  const total = pitch.price_per_hour * dur;
  const deposit = Math.min(st.deposit_amount, total);
  const commission = Math.min(st.commission_amount, deposit);
  const expiresAt = new Date(Date.now() + st.hold_minutes * 60_000);

  let booking: any = null;
  for (let i = 0; i < 3 && !booking; i++) {
    const { data, error } = await db.from("bookings").insert({
      player_id: user.id, pitch_id, starts_at: start.toISOString(), duration_hours: dur,
      ends_at: new Date(start.getTime() + dur * 3600_000).toISOString(),
      total_price: total, deposit_amount: deposit, remaining_amount: total - deposit,
      commission_amount: commission, owner_amount: deposit - commission, // part de l'avance à reverser au terrain
      status: "paiement_en_attente", expires_at: expiresAt.toISOString(),
    }).select("id, code").single();
    if (!error) booking = data;
    else if (error.code === "23P01") return json({ error: "Ce créneau vient d'être réservé" }, 409);
    else if (error.code !== "23505") { console.error(error); return json({ error: "Erreur de réservation" }, 500); }
  }
  if (!booking) return json({ error: "Erreur de réservation" }, 500);

  const { data: pay } = await db.from("payments").insert({ booking_id: booking.id, method: payment_method, amount: deposit }).select("id").single();
  if (!pay) { await db.from("bookings").update({ status: "expiree" }).eq("id", booking.id); return json({ error: "Erreur de paiement" }, 500); }

  try {
    const { reference, checkoutUrl } = await initiatePayment({ method: payment_method, amount: deposit, bookingCode: booking.code, paymentId: pay.id });
    await db.from("payments").update({ provider_reference: reference }).eq("id", pay.id);
    return json({ booking_code: booking.code, expires_at: expiresAt.toISOString(), total, deposit, remaining: total - deposit, checkout_url: checkoutUrl });
  } catch (e) {
    console.error(e);
    await db.from("payments").update({ status: "echoue" }).eq("id", pay.id);
    await db.from("bookings").update({ status: "expiree" }).eq("id", booking.id);
    return json({ error: "Impossible de lancer le paiement, réessayez" }, 502);
  }
});
