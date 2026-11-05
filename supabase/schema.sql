-- Tables pour les notifications des gérants.
-- À coller dans Supabase : Dashboard > SQL Editor > New query > Run.

-- Qui gère quelle radio.
-- radio_id = slug de la radio dans l'API (ex : 'radio-campus-orleans'),
-- ou 'national' pour le gérant de Radio Campus France (envoie à tout le monde).
create table gerants (
  user_id uuid not null references auth.users (id) on delete cascade,
  radio_id text not null,
  primary key (user_id, radio_id)
);

-- Historique des notifications envoyées (radio_id = 'national' pour tout le monde).
create table notifications (
  id bigint generated always as identity primary key,
  radio_id text not null,
  titre text not null,
  texte text not null,
  auteur uuid not null references auth.users (id),
  envoyee_le timestamptz not null default now()
);

-- Sécurité : personne ne modifie ces tables depuis l'app.
-- Seule la fonction envoyer-notification (clé secrète) écrit dans "notifications".
alter table gerants enable row level security;
alter table notifications enable row level security;

-- Un gérant connecté peut lire ses propres lignes (pour savoir quelles radios il gère).
create policy "un gérant lit ses radios" on gerants
  for select using (auth.uid() = user_id);

-- Pour ajouter un gérant (après avoir créé son compte dans Authentication > Users) :
-- insert into gerants (user_id, radio_id) values ('<uuid du compte>', 'radio-campus-orleans');
-- insert into gerants (user_id, radio_id) values ('<uuid du compte>', 'national');
