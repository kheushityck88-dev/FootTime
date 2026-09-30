-- L'administrateur FootTime peut modifier les terrains et gérer leurs photos
create policy pitches_admin_write on pitches for update using (is_admin()) with check (is_admin());
create policy photos_admin_write on pitch_photos for all using (is_admin()) with check (is_admin());
create policy photos_storage_admin_insert on storage.objects for insert with check (bucket_id = 'pitch-photos' and is_admin());
create policy photos_storage_admin_delete on storage.objects for delete using (bucket_id = 'pitch-photos' and is_admin());
