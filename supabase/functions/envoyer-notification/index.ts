// Edge Function Supabase : un gérant envoie une notification push.
// Appelée par l'app avec { radioId, titre, texte }.
// radioId = slug de la radio, ou "national" pour envoyer à tout le monde.
//
// Secret à créer (Dashboard > Edge Functions > Secrets) :
//   FIREBASE_SERVICE_ACCOUNT = contenu du fichier JSON du compte de service Firebase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

// Réponse JSON avec un code HTTP.
function reponse(code: number, contenu: object) {
  return new Response(JSON.stringify(contenu), {
    status: code,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const { radioId, titre, texte } = await req.json();
  if (!radioId || !titre || !texte) {
    return reponse(400, { erreur: "Il manque la radio, le titre ou le texte." });
  }
  if (titre.length > 100 || texte.length > 500) {
    return reponse(400, { erreur: "Titre (100) ou texte (500 caractères) trop long." });
  }

  // Client avec la clé secrète : il peut lire et écrire toutes les tables.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1. Qui envoie ? L'app envoie le jeton de connexion du gérant.
  const jeton = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: connexion } = await supabase.auth.getUser(jeton);
  const user = connexion.user;
  if (!user) {
    return reponse(401, { erreur: "Tu dois être connecté." });
  }

  // 2. A-t-il le droit ? Il faut gérer cette radio, ou être le gérant national.
  const { data: lignes } = await supabase
    .from("gerants")
    .select("radio_id")
    .eq("user_id", user.id);
  const radiosGerees = (lignes ?? []).map((ligne) => ligne.radio_id);
  const estNational = radiosGerees.includes("national");
  if (!estNational && !radiosGerees.includes(radioId)) {
    return reponse(403, { erreur: "Tu ne gères pas cette radio." });
  }

  // 3. On garde une trace de la notification.
  await supabase.from("notifications").insert({
    radio_id: radioId,
    titre: titre,
    texte: texte,
    auteur: user.id,
  });

  // 4. Envoi par Firebase au "topic" : "toutes" (tout le monde) ou "radio_<slug>".
  // Les téléphones s'abonnent à ces topics dans l'app (NotificationService).
  let topic = "radio_" + radioId;
  if (radioId === "national") {
    topic = "toutes";
  }
  const compte = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const google = new JWT({
    email: compte.client_email,
    key: compte.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { access_token } = await google.authorize();
  const envoi = await fetch(
    `https://fcm.googleapis.com/v1/projects/${compte.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + access_token,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: { topic: topic, notification: { title: titre, body: texte } },
      }),
    },
  );
  if (!envoi.ok) {
    return reponse(502, { erreur: "Firebase a refusé l'envoi : " + (await envoi.text()) });
  }
  return reponse(200, { ok: true });
});
