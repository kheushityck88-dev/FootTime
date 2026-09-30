-- CORRECTIF SÉCURITÉ : ces tables n'avaient pas de RLS dans 001
alter table owners enable row level security;
create policy owners_read on owners for select using (user_id = auth.uid() or is_admin());
alter table pitch_managers enable row level security;
create policy managers_read on pitch_managers for select using (user_id = auth.uid() or can_manage_pitch(pitch_id));
alter table payouts enable row level security;
create policy payouts_read on payouts for select using (is_admin() or exists (select 1 from owners o where o.id = owner_id and o.user_id = auth.uid()));
-- Écriture sur owners / pitch_managers / payouts : uniquement via fonctions ou service role

-- Propriétaire rattaché par téléphone, même s'il n'a pas encore de compte
alter table owners alter column user_id drop not null;
alter table owners add column if not exists phone text unique;

create function add_owner(p_name text, p_phone text) returns uuid language plpgsql security definer set search_path = public as $$
declare oid uuid; uid uuid; ph text := regexp_replace(p_phone, '\D', '', 'g');
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  if length(ph) < 8 then raise exception 'Numéro invalide'; end if;
  select id into uid from profiles where regexp_replace(phone, '\D', '', 'g') = ph;
  insert into owners (business_name, phone, user_id) values (p_name, ph, uid) returning id into oid;
  if uid is not null then update profiles set role = 'PROPRIETAIRE' where id = uid and role = 'JOUEUR'; end if;
  return oid;
end $$;

-- À l'inscription d'un numéro déjà enregistré comme propriétaire : lien automatique
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'first_name',''), coalesce(new.raw_user_meta_data->>'last_name',''), coalesce(new.phone,''));
  update owners set user_id = new.id where user_id is null and phone = regexp_replace(coalesce(new.phone,''), '\D', '', 'g');
  if found then update profiles set role = 'PROPRIETAIRE' where id = new.id; end if;
  return new;
end $$;

-- Propriétaires et gestionnaires voient les joueurs qui ont réservé chez eux
create policy profiles_owner_read on profiles for select using (
  exists (select 1 from bookings b where b.player_id = profiles.id and can_manage_pitch(b.pitch_id)));
