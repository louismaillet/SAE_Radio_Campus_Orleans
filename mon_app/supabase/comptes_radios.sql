-- À coller dans Supabase > SQL Editor > Run, après gerants.sql.
-- Un compte par radio : nom d'utilisateur = mot de passe = nom court de la ville/radio.
-- COMPTES DE TEST : mots de passe faibles, à changer avant une vraie utilisation.
-- Relançable : un compte déjà existant n'est pas recréé.
insert into public."User" (name, password, radio, is_admin)
select v.nom, extensions.crypt(v.nom, extensions.gen_salt('bf')), r.id, false
from (values
  ('france', 'radio-campus-france'),
  ('musique', 'radiocampusmusique'),
  ('47', 'radio-campus-47'),
  ('amiens', 'radio-campus-amiens-amiens'),
  ('angers', 'radio-campus-angers'),
  ('avignon', 'radio-campus-avignon'),
  ('besancon', 'radio-campus-besancon'),
  ('bordeaux', 'radio-campus-bordeaux'),
  ('radio-u', 'programmationatradio-u-org'),
  ('bruxelles', 'radio-campus-bruxelles'),
  ('phenix', 'radio-phenix'),
  ('castres', 'radiom-campus-castres'),
  ('clermont', 'radio-campus-clermont-ferrand'),
  ('corte', 'nebbia-campus-corte'),
  ('dijon', 'radio-dijon-campus'),
  ('grenoble', 'radio-campus-grenoble'),
  ('lille', 'radio-campus-lille'),
  ('lyon', 'radio-brume-lyon'),
  ('marseille', 'radio-grenouille-marseille'),
  ('montpellier', 'radio-campus-montpellier'),
  ('mulhouse', 'radio-mne-mulhouse'),
  ('nancy', 'radio-campus-lorraine-nancy-metz'),
  ('orleans', 'radio-campus-orleans'),
  ('paris', 'www-radiocampusparis-org'),
  ('pau', 'radio-campus-pau'),
  ('perpignan', 'radio-campus-66-perpignan'),
  ('poitiers', 'radio-pulsar-poitiers'),
  ('rennes', 'c-lab-campus-rennes'),
  ('makingwaves', 'making-waves'),
  ('rouen', 'radio-campus-rouen'),
  ('reunion', 'radio-coco-la-reunion'),
  ('quebec', 'cfak-quebec'),
  ('construction', 'radio-en-construction'),
  ('toulouse', 'campus-fm-toulouse'),
  ('tours', 'radio-campus-tours')
) as v(nom, slug)
join public."Radio" r on r.slug = v.slug
where not exists (select 1 from public."User" u where u.name = v.nom);
