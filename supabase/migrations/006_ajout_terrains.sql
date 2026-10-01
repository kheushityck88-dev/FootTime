-- L'administrateur peut ajouter et supprimer des terrains
create policy pitches_admin_insert on pitches for insert with check (is_admin());
create policy pitches_admin_delete on pitches for delete using (is_admin());
