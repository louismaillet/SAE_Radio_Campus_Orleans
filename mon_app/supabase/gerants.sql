-- À coller dans Supabase > SQL Editor > Run. Utilise les tables existantes "User" et "Radio".
create extension if not exists pgcrypto with schema extensions;

-- 1) Lien avec l'API Radio Campus : le slug de la radio (ex. 'radio-campus-lille').
alter table public."Radio" add column if not exists slug text unique;
-- À remplir pour chaque radio : update public."Radio" set slug = 'slug-api' where id = 1;

-- 2) Hacher les mots de passe encore en clair (les ignore s'ils sont déjà hachés).
-- Le mot de passe à taper reste le même, mais il ne sera plus lisible dans la table.
update public."User" set password = extensions.crypt(password, extensions.gen_salt('bf'))
where password not like '$2%';

-- 3) RLS activé : plus personne ne lit "User" depuis l'app (vérifier qu'aucune règle ne l'autorise, voir Policies).
alter table public."User" enable row level security;

-- 4) Seul moyen de tester un login : renvoie vrai si nom + mot de passe + radio correspondent.
create or replace function public.connexion_gerant(p_utilisateur text, p_mot_de_passe text, p_radio_slug text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public."User" u
    join public."Radio" r on r.id = u.radio
    where u.name = p_utilisateur
      and r.slug = p_radio_slug
      and u.password = crypt(p_mot_de_passe, u.password)
  );
$$;

grant execute on function public.connexion_gerant(text, text, text) to anon;

-- 5) Remplir "Radio" avec les 35 radios de l'API (site = a un site officiel dans l'app). Relançable sans doublon.
insert into public."Radio" (slug, site) values
  ('radio-campus-france', false),
  ('radiocampusmusique', false),
  ('radio-campus-47', true),
  ('radio-campus-amiens-amiens', true),
  ('radio-campus-angers', true),
  ('radio-campus-avignon', true),
  ('radio-campus-besancon', true),
  ('radio-campus-bordeaux', true),
  ('programmationatradio-u-org', true),
  ('radio-campus-bruxelles', false),
  ('radio-phenix', true),
  ('radiom-campus-castres', true),
  ('radio-campus-clermont-ferrand', true),
  ('nebbia-campus-corte', false),
  ('radio-dijon-campus', true),
  ('radio-campus-grenoble', true),
  ('radio-campus-lille', true),
  ('radio-brume-lyon', true),
  ('radio-grenouille-marseille', true),
  ('radio-campus-montpellier', true),
  ('radio-mne-mulhouse', true),
  ('radio-campus-lorraine-nancy-metz', true),
  ('radio-campus-orleans', true),
  ('www-radiocampusparis-org', true),
  ('radio-campus-pau', true),
  ('radio-campus-66-perpignan', false),
  ('radio-pulsar-poitiers', true),
  ('c-lab-campus-rennes', true),
  ('making-waves', false),
  ('radio-campus-rouen', false),
  ('radio-coco-la-reunion', false),
  ('cfak-quebec', false),
  ('radio-en-construction', true),
  ('campus-fm-toulouse', true),
  ('radio-campus-tours', true)
on conflict (slug) do update set site = excluded.site;

-- 6) Compte de test : rattacher "avengers" à Radio Campus Lille.
update public."User" set radio = (select id from public."Radio" where slug = 'radio-campus-lille')
where name = 'avengers';

-- 7) Login sans choisir la radio : renvoie le slug de la radio du gérant (ou rien si identifiants faux).
create or replace function public.radio_du_gerant(p_utilisateur text, p_mot_de_passe text)
returns text
language sql
security definer
set search_path = public, extensions
as $$
  select r.slug from public."User" u
  join public."Radio" r on r.id = u.radio
  where u.name = p_utilisateur
    and u.password = crypt(p_mot_de_passe, u.password)
  limit 1;
$$;

grant execute on function public.radio_du_gerant(text, text) to anon;
-- L'ancienne fonction (avec choix de la radio) n'est plus utilisée.
drop function if exists public.connexion_gerant(text, text, text);
