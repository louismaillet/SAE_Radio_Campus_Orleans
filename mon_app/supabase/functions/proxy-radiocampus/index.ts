// Edge Function Supabase : relais vers l'API Radio Campus, pour la version WEB de l'app.
// Les navigateurs bloquent l'API (pas d'en-tête CORS) ; cette fonction l'appelle à leur place
// et ajoute le CORS. Android et Windows n'en ont pas besoin.
// Appel : .../functions/v1/proxy-radiocampus?chemin=/api/radios&page=1
// Déploiement : supabase functions deploy proxy-radiocampus --no-verify-jwt (données publiques).

const HOTE = "https://api.radiocampus.org";
const CORS = { "Access-Control-Allow-Origin": "*" };

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const chemin = url.searchParams.get("chemin") ?? "";
  // Seul /api/... de Radio Campus est relayé (évite d'en faire un proxy ouvert).
  if (!chemin.startsWith("/api/") || chemin.includes("..")) {
    return new Response("chemin invalide", { status: 400, headers: CORS });
  }
  const cible = new URL(HOTE + chemin);
  url.searchParams.forEach((valeur, cle) => {
    if (cle !== "chemin") cible.searchParams.set(cle, valeur);
  });
  const reponse = await fetch(cible, { headers: { Accept: "application/ld+json" } });
  return new Response(reponse.body, {
    status: reponse.status,
    headers: { ...CORS, "Content-Type": "application/ld+json; charset=utf-8" },
  });
});
