-- FootTime : schéma complet (Supabase / PostgreSQL)
create extension if not exists btree_gist;
create extension if not exists pg_cron;

create type user_role as enum ('ADMIN_FOOTTIME','PROPRIETAIRE','GESTIONNAIRE','JOUEUR');
create type booking_status as enum ('paiement_en_attente','confirmee','terminee','annulee','expiree');
create type payment_status as enum ('en_attente','reussi','echoue','annule');

create table cities (id uuid primary key default gen_random_uuid(), name text not null unique, is_active boolean not null default true);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '', last_name text not null default '',
  phone text not null unique, email text,
  role user_role not null default 'JOUEUR', status text not null default 'actif',
  created_at timestamptz not null default now());

create table owners (id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id), business_name text, created_at timestamptz not null default now());

create table pitches (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references cities(id), owner_id uuid not null references owners(id),
  name text not null, description text, address text, district text,
  latitude numeric(9,6), longitude numeric(9,6),
  price_per_hour integer not null check (price_per_hour > 0),
  opening_time time not null, closing_time time not null,
  amenities jsonb not null default '{}', rules text,
  is_active boolean not null default true, created_at timestamptz not null default now());

create table pitch_photos (id uuid primary key default gen_random_uuid(), pitch_id uuid not null references pitches(id) on delete cascade, url text not null, kind text, position int not null default 0);

create table pitch_managers (
  id uuid primary key default gen_random_uuid(),
  pitch_id uuid not null references pitches(id) on delete cascade,
  user_id uuid not null references profiles(id), status text not null default 'actif',
  unique (pitch_id, user_id));

create table app_settings (key text primary key, value jsonb not null);

create table payouts (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references owners(id),
  amount int not null, status text not null default 'en_attente', reference text,
  created_at timestamptz not null default now(), paid_at timestamptz);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default 'FT-' || lpad((floor(random()*100000))::int::text, 5, '0'),
  player_id uuid not null references profiles(id), pitch_id uuid not null references pitches(id),
  starts_at timestamptz not null, duration_hours int not null check (duration_hours > 0), ends_at timestamptz not null,
  total_price int not null, deposit_amount int not null, remaining_amount int not null,
  commission_amount int not null, owner_amount int not null,
  status booking_status not null default 'paiement_en_attente',
  modifications_count smallint not null default 0 check (modifications_count <= 2),
  expires_at timestamptz, payout_id uuid references payouts(id),
  created_at timestamptz not null default now(),
  check (ends_at = starts_at + make_interval(hours => duration_hours)));

-- Aucun chevauchement possible sur un même terrain
alter table bookings add constraint bookings_no_overlap exclude using gist (
  pitch_id with =, tstzrange(starts_at, ends_at, '[)') with &&
) where (status in ('paiement_en_attente','confirmee','terminee'));

create table payments (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references bookings(id),
  method text not null, amount int not null, status payment_status not null default 'en_attente',
  provider_reference text, needs_refund boolean not null default false,
  created_at timestamptz not null default now());

create table reviews (
  id uuid primary key default gen_random_uuid(), player_id uuid not null references profiles(id),
  pitch_id uuid not null references pitches(id), booking_id uuid not null unique references bookings(id),
  rating smallint not null check (rating between 1 and 5), comment text,
  status text not null default 'publie', created_at timestamptz not null default now());

create index on bookings (pitch_id, starts_at);
create index on bookings (player_id);

-- Paramètres configurables (valeurs à confirmer : avance et commission)
insert into app_settings (key, value) values
  ('hold_minutes','8'), ('free_cancel_hours_after_booking','5'), ('min_hours_before_start','1'),
  ('max_modifications','2'), ('payout_delay_hours','24'), ('deposit_amount','5000'), ('commission_amount','500');

-- Profil créé automatiquement à l'inscription
create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, first_name, last_name, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'first_name',''), coalesce(new.raw_user_meta_data->>'last_name',''), coalesce(new.phone,''));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- Permissions
create function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'ADMIN_FOOTTIME'); $$;

create function can_manage_pitch(p_pitch uuid) returns boolean language sql stable security definer set search_path = public as $$
  select is_admin()
    or exists (select 1 from pitches p join owners o on o.id = p.owner_id where p.id = p_pitch and o.user_id = auth.uid())
    or exists (select 1 from pitch_managers m where m.pitch_id = p_pitch and m.user_id = auth.uid() and m.status = 'actif'); $$;

alter table cities enable row level security;       create policy cities_read on cities for select using (true);
alter table pitch_photos enable row level security; create policy photos_read on pitch_photos for select using (true);
alter table pitches enable row level security;      create policy pitches_read on pitches for select using (is_active or can_manage_pitch(id));
alter table profiles enable row level security;     create policy profiles_read on profiles for select using (id = auth.uid() or is_admin());
alter table app_settings enable row level security; create policy settings_read on app_settings for select using (key = 'deposit_amount');
alter table bookings enable row level security;     create policy bookings_read on bookings for select using (player_id = auth.uid() or can_manage_pitch(pitch_id));
alter table payments enable row level security;
create policy payments_read on payments for select using (exists (select 1 from bookings b where b.id = booking_id and (b.player_id = auth.uid() or can_manage_pitch(b.pitch_id))));
alter table reviews enable row level security;
create policy reviews_read on reviews for select using (status = 'publie' or is_admin());
create policy reviews_insert on reviews for insert with check (player_id = auth.uid() and exists (select 1 from bookings b where b.id = booking_id and b.player_id = auth.uid() and b.status = 'terminee'));
-- Réservations et paiements : écriture uniquement via les Edge Functions

-- Créneaux occupés, sans exposer les données des autres joueurs
create function get_busy_slots(p_pitch uuid, p_day date) returns table (starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select starts_at, ends_at from bookings
  where pitch_id = p_pitch and status in ('paiement_en_attente','confirmee','terminee')
    and starts_at < (p_day + 2)::timestamptz and ends_at > p_day::timestamptz; $$;

-- Annulation : uniquement dans le délai gratuit (5 h après la réservation) et jusqu'à 1 h avant le match
create function cancel_booking(p_booking uuid) returns text language plpgsql security definer set search_path = public as $$
declare b bookings%rowtype; free_h int; min_h int;
begin
  select (value #>> '{}')::int into free_h from app_settings where key = 'free_cancel_hours_after_booking';
  select (value #>> '{}')::int into min_h from app_settings where key = 'min_hours_before_start';
  select * into b from bookings where id = p_booking and player_id = auth.uid() for update;
  if not found then raise exception 'Réservation introuvable'; end if;
  if b.status <> 'confirmee' then raise exception 'Annulation impossible'; end if;
  if now() > b.created_at + make_interval(hours => free_h) then
    raise exception 'Le délai d''annulation de % h est dépassé : vous pouvez seulement changer la date ou l''heure', free_h; end if;
  if b.starts_at - make_interval(hours => min_h) <= now() then
    raise exception 'Annulation impossible à moins de % h du match', min_h; end if;
  update bookings set status = 'annulee' where id = b.id;
  return 'remboursable';
end $$;

-- Changement de créneau : après le délai d'annulation, 2 fois maximum, sans remboursement
create function change_booking_time(p_booking uuid, p_new_start timestamptz) returns void
language plpgsql security definer set search_path = public as $$
declare b bookings%rowtype; p pitches%rowtype; free_h int; max_m int; h int; o int; c int;
begin
  select (value #>> '{}')::int into free_h from app_settings where key = 'free_cancel_hours_after_booking';
  select (value #>> '{}')::int into max_m from app_settings where key = 'max_modifications';
  select * into b from bookings where id = p_booking and player_id = auth.uid() for update;
  if not found then raise exception 'Réservation introuvable'; end if;
  if b.status <> 'confirmee' or b.starts_at <= now() then raise exception 'Modification impossible'; end if;
  if now() <= b.created_at + make_interval(hours => free_h) then
    raise exception 'Dans le délai de % h, annulez puis réservez à nouveau', free_h; end if;
  if b.modifications_count >= max_m then raise exception 'Limite de % changements atteinte', max_m; end if;
  if p_new_start <= now() or date_trunc('hour', p_new_start) <> p_new_start then raise exception 'Nouvelle heure invalide'; end if;
  select * into p from pitches where id = b.pitch_id;
  h := extract(hour from p_new_start at time zone 'UTC')::int;  -- Kaolack = UTC
  o := extract(hour from p.opening_time)::int; c := extract(hour from p.closing_time)::int;
  if c <= o then c := c + 24; end if;
  if h < o and c > 24 then h := h + 24; end if;
  if h < o or h + b.duration_hours > c then raise exception 'Hors des horaires du terrain'; end if;
  update bookings set starts_at = p_new_start, ends_at = p_new_start + make_interval(hours => duration_hours),
    modifications_count = modifications_count + 1 where id = b.id;
end $$;

-- Tâches automatiques
select cron.schedule('expirer-reservations', '* * * * *', $$update bookings set status = 'expiree' where status = 'paiement_en_attente' and expires_at < now()$$);
select cron.schedule('terminer-reservations', '*/10 * * * *', $$update bookings set status = 'terminee' where status = 'confirmee' and ends_at < now()$$);

-- Montants à reverser aux propriétaires (matchs terminés, après le délai de reversement)
create view owner_balances_due with (security_invoker = true) as
select p.owner_id, sum(b.owner_amount) as amount_due, count(*) as bookings_count
from bookings b join pitches p on p.id = b.pitch_id
where b.status = 'terminee' and b.payout_id is null
  and b.ends_at <= now() - make_interval(hours => (select (value #>> '{}')::int from app_settings where key = 'payout_delay_hours'))
group by p.owner_id;
