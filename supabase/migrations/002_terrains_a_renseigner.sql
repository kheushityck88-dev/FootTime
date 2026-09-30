-- 5 emplacements de terrains vides, INVISIBLES (is_active = false) tant qu'ils ne sont pas renseignés
alter table pitches alter column owner_id drop not null;  -- le propriétaire pourra être rattaché plus tard

insert into storage.buckets (id, name, public) values ('pitch-photos', 'pitch-photos', true) on conflict (id) do nothing;

insert into cities (name) values ('Kaolack') on conflict (name) do nothing;

insert into pitches (id, city_id, name, price_per_hour, opening_time, closing_time, is_active)
select ('00000000-0000-0000-0000-00000000000' || n)::uuid,
       (select id from cities where name = 'Kaolack'),
       'Terrain ' || n || ' (à renseigner)', 1, '08:00', '23:00', false
from generate_series(1, 5) n
on conflict (id) do nothing;
