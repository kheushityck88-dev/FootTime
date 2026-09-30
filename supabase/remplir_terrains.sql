-- À REMPLIR : un bloc par terrain. Exécuter UN bloc à la fois, après l'avoir rempli.
-- Photos : Supabase > Storage > bucket « pitch-photos » > envoyer les images > copier l'URL publique.
-- Le prix doit être > 0 (sinon la base refuse). Passer is_active à true seulement quand tout est renseigné.
-- Rattacher plus tard un propriétaire : update pitches set owner_id = '<id du propriétaire>' where id = '<id du terrain>';

-- ===== TERRAIN 1 =====
update pitches set
  name = 'NOM DU TERRAIN',
  district = 'QUARTIER',
  address = 'ADRESSE',
  description = 'DESCRIPTION',
  price_per_hour = 0,                                   -- prix réel en FCFA par heure
  opening_time = '08:00', closing_time = '23:00',       -- horaires réels
  amenities = '{"eclairage":false,"vestiaires":false,"douches":false,"parking":false}',
  is_active = false                                     -- true quand tout est rempli
where id = '00000000-0000-0000-0000-000000000001';

delete from pitch_photos where pitch_id = '00000000-0000-0000-0000-000000000001';
insert into pitch_photos (pitch_id, url, kind, position) values
  ('00000000-0000-0000-0000-000000000001', 'URL_PHOTO_1', 'vue générale', 0),
  ('00000000-0000-0000-0000-000000000001', 'URL_PHOTO_2', 'surface', 1),
  ('00000000-0000-0000-0000-000000000001', 'URL_PHOTO_3', 'vestiaires', 2);

-- ===== TERRAIN 2 =====
update pitches set
  name = 'NOM DU TERRAIN',
  district = 'QUARTIER',
  address = 'ADRESSE',
  description = 'DESCRIPTION',
  price_per_hour = 0,                                   -- prix réel en FCFA par heure
  opening_time = '08:00', closing_time = '23:00',       -- horaires réels
  amenities = '{"eclairage":false,"vestiaires":false,"douches":false,"parking":false}',
  is_active = false                                     -- true quand tout est rempli
where id = '00000000-0000-0000-0000-000000000002';

delete from pitch_photos where pitch_id = '00000000-0000-0000-0000-000000000002';
insert into pitch_photos (pitch_id, url, kind, position) values
  ('00000000-0000-0000-0000-000000000002', 'URL_PHOTO_1', 'vue générale', 0),
  ('00000000-0000-0000-0000-000000000002', 'URL_PHOTO_2', 'surface', 1),
  ('00000000-0000-0000-0000-000000000002', 'URL_PHOTO_3', 'vestiaires', 2);

-- ===== TERRAIN 3 =====
update pitches set
  name = 'NOM DU TERRAIN',
  district = 'QUARTIER',
  address = 'ADRESSE',
  description = 'DESCRIPTION',
  price_per_hour = 0,                                   -- prix réel en FCFA par heure
  opening_time = '08:00', closing_time = '23:00',       -- horaires réels
  amenities = '{"eclairage":false,"vestiaires":false,"douches":false,"parking":false}',
  is_active = false                                     -- true quand tout est rempli
where id = '00000000-0000-0000-0000-000000000003';

delete from pitch_photos where pitch_id = '00000000-0000-0000-0000-000000000003';
insert into pitch_photos (pitch_id, url, kind, position) values
  ('00000000-0000-0000-0000-000000000003', 'URL_PHOTO_1', 'vue générale', 0),
  ('00000000-0000-0000-0000-000000000003', 'URL_PHOTO_2', 'surface', 1),
  ('00000000-0000-0000-0000-000000000003', 'URL_PHOTO_3', 'vestiaires', 2);

-- ===== TERRAIN 4 =====
update pitches set
  name = 'NOM DU TERRAIN',
  district = 'QUARTIER',
  address = 'ADRESSE',
  description = 'DESCRIPTION',
  price_per_hour = 0,                                   -- prix réel en FCFA par heure
  opening_time = '08:00', closing_time = '23:00',       -- horaires réels
  amenities = '{"eclairage":false,"vestiaires":false,"douches":false,"parking":false}',
  is_active = false                                     -- true quand tout est rempli
where id = '00000000-0000-0000-0000-000000000004';

delete from pitch_photos where pitch_id = '00000000-0000-0000-0000-000000000004';
insert into pitch_photos (pitch_id, url, kind, position) values
  ('00000000-0000-0000-0000-000000000004', 'URL_PHOTO_1', 'vue générale', 0),
  ('00000000-0000-0000-0000-000000000004', 'URL_PHOTO_2', 'surface', 1),
  ('00000000-0000-0000-0000-000000000004', 'URL_PHOTO_3', 'vestiaires', 2);

-- ===== TERRAIN 5 =====
update pitches set
  name = 'NOM DU TERRAIN',
  district = 'QUARTIER',
  address = 'ADRESSE',
  description = 'DESCRIPTION',
  price_per_hour = 0,                                   -- prix réel en FCFA par heure
  opening_time = '08:00', closing_time = '23:00',       -- horaires réels
  amenities = '{"eclairage":false,"vestiaires":false,"douches":false,"parking":false}',
  is_active = false                                     -- true quand tout est rempli
where id = '00000000-0000-0000-0000-000000000005';

delete from pitch_photos where pitch_id = '00000000-0000-0000-0000-000000000005';
insert into pitch_photos (pitch_id, url, kind, position) values
  ('00000000-0000-0000-0000-000000000005', 'URL_PHOTO_1', 'vue générale', 0),
  ('00000000-0000-0000-0000-000000000005', 'URL_PHOTO_2', 'surface', 1),
  ('00000000-0000-0000-0000-000000000005', 'URL_PHOTO_3', 'vestiaires', 2);
