-- Le joueur peut modifier son prénom, son nom et son email, jamais son rôle
revoke update on profiles from anon, authenticated;
grant update (first_name, last_name, email) on profiles to authenticated;
create policy profiles_self_update on profiles for update using (id = auth.uid()) with check (id = auth.uid());
