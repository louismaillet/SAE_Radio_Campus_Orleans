-- Historique des notifications envoyées par les gérants.
-- À coller dans Supabase > SQL Editor > Run (après gerants.sql).

-- Nettoyage de la première version (tables "gerants" et "notifications" liées à Supabase Auth,
-- remplacées par la table "User" de gerants.sql). Sans danger : ce n'était que des essais.
drop table if exists gerants;
drop table if exists notifications;

create table notifications (
  id bigint generated always as identity primary key,
  radio_id text not null, -- slug de la radio, ou 'national' pour tout le monde
  titre text not null,
  texte text not null,
  auteur text not null, -- nom du gérant (colonne name de la table "User")
  envoyee_le timestamptz not null default now()
);

-- Personne ne lit ni n'écrit cette table depuis l'app : seule la fonction
-- envoyer-notification (clé secrète, qui ignore la RLS) y écrit.
alter table notifications enable row level security;
