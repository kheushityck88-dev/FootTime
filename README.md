# FootTime — TROUVE. RÉSERVE. JOUE.

PWA joueur + Supabase (PostgreSQL, Edge Functions). Lancement : Kaolack.

## Mise en route
1. **Base** : exécuter `supabase/migrations/001_schema.sql` (SQL Editor ou `supabase db push`).
2. **Données** : créer la ville, le propriétaire et chaque terrain (vraies photos, vrais prix) — rien n'est inventé dans le code.
3. **Premier admin** : après une première connexion, `update profiles set role='ADMIN_FOOTTIME' where phone='+221...';`
4. **Fonctions** : `supabase functions deploy create-booking` et `payment-webhook` ; secret : `supabase secrets set WEBHOOK_SECRET=...`
5. **Paiement** : implémenter `initiatePayment` (create-booking) et le format du corps + la signature (payment-webhook) selon la doc marchande Wave / Orange Money.
6. **Front** : renseigner `SUPABASE_URL` et `SUPABASE_ANON_KEY` dans `docs/config.js`, puis héberger `docs/` (GitHub Pages, HTTPS obligatoire).
7. **Connexion WhatsApp** : activer l'authentification téléphone dans Supabase avec un fournisseur compatible WhatsApp (vérifier la doc).
8. **Valeurs à confirmer** dans `app_settings` : `deposit_amount` (5000) et `commission_amount` (500).

## Règles appliquées
Créneau bloqué 8 min pendant le paiement · annulation remboursable dans les 5 h suivant la réservation et jusqu'à 1 h avant le match · ensuite, seulement 2 changements de date/heure, sans remboursement · reversement aux terrains après match terminé (24 h).

## Non inclus dans cette version
Dashboards propriétaire et admin, avis (l'écriture est prévue côté base), notifications, remboursements, QR code.

`brand/planche-de-marque.png` : planche de marque d'origine. Les images de `docs/assets/` en sont extraites : remplacer par les fichiers logo/icône originaux en haute définition.

## Renseigner les 5 terrains
1. Exécuter `supabase/migrations/002_terrains_a_renseigner.sql` : crée Kaolack et 5 terrains vides, invisibles dans l'appli.
2. Envoyer les photos dans Storage > `pitch-photos`, copier leurs URL publiques.
3. Remplir et exécuter, un par un, les blocs de `supabase/remplir_terrains.sql` (nom, quartier, adresse, description, prix, horaires, photos), puis passer `is_active` à `true`.

## Page d'administration (`docs/admin.html`)
Exécuter `supabase/migrations/003_admin_terrains.sql`, se connecter une fois à l'appli, se passer admin (étape 3), puis ouvrir `admin.html` : les 5 blocs permettent de saisir nom, quartier, adresse, description, prix, horaires, équipements, photos et la visibilité, sans SQL.

## Liens entre les modules (migration 004 + pages)
- `004_liens_et_securite.sql` : correctif RLS (owners, pitch_managers, payouts), rattachement des propriétaires par téléphone.
- `admin.html` : tableau de bord + pour chaque terrain nom, propriétaire (existant ou nouveau), localisation, prix, photos.
- `owner.html` : espace propriétaire / gestionnaire (calendrier, réservations, revenus, commission, reversements). Un propriétaire se connecte avec le numéro enregistré par l'admin.
- Fiche terrain (`index.html`) : équipements, règles, carte, avis. Les joueurs notent leurs réservations terminées.

## Publication sur GitHub Pages
Déposer le contenu de ce dossier à la racine du dépôt, puis Settings > Pages > Source : « Deploy from a branch », branche `main`, dossier `/docs`. L'adresse sera `https://<compte>.github.io/<dépôt>/`, avec `admin.html` et `owner.html` dans le même dossier. Ne jamais déposer la clé `service_role` ni `WEBHOOK_SECRET`.
