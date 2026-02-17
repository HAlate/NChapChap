# Rapport de Duplication Supabase
Date: 2026-01-15 14:21:19
Environnement: staging

## Nouveau Projet
- Project Ref: lpbfemncwasppngjmubn
- URL: https://lpbfemncwasppngjmubn.supabase.co

## Fichiers de Configuration Crees
- mobile_driver\.env.staging
- admin\.env.staging


## Prochaines Etapes Manuelles

### 1. Activer les Extensions PostgreSQL
Allez dans Database > Extensions et activez:
- postgis (geolocalisation)
- pg_net (webhooks)
- uuid-ossp (UUID)

### 2. Configurer l'Authentification
Allez dans Authentication > Settings:
- Email Confirmation: A configurer selon vos besoins
- Site URL: A configurer
- Redirect URLs: A ajouter

### 3. Configurer les Secrets des Edge Functions
Allez dans Edge Functions > Secrets et ajoutez:
- STRIPE_SECRET_KEY=...
- STRIPE_WEBHOOK_SECRET=...

### 4. Configurer les Webhooks Stripe (si necessaire)
URL du webhook: https://lpbfemncwasppngjmubn.supabase.co/functions/v1/stripe-webhook
Evenements: payment_intent.succeeded, payment_intent.payment_failed

### 5. Tester la Connexion
- Lancez l'application mobile avec .env.staging
- Verifiez que la connexion fonctionne
- Creez un utilisateur de test

### 6. Verifications SQL a Executer
Voir le guide GUIDE_DUPLICATION_SUPABASE.md pour les requetes SQL de verification.

## Credentials (A Sauvegarder dans un Gestionnaire de Mots de Passe)

Project Ref: lpbfemncwasppngjmubn
URL: https://lpbfemncwasppngjmubn.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwYmZlbW5jd2FzcHBuZ2ptdWJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NzMyNTEsImV4cCI6MjA4NDA0OTI1MX0.DWxYyu9-mQEh1RAGqV_0HYE8sayi4RzGl-bjUEO5U7s


---
Genere automatiquement par duplicate_supabase_project.ps1
