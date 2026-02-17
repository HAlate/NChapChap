# 🚀 Installation du Dashboard Admin

## Étape 1 : Exécuter le script SQL dans Supabase

1. Ouvrez votre projet Supabase : https://app.supabase.com
2. Allez dans **SQL Editor**
3. Créez une nouvelle requête
4. Copiez-collez le contenu du fichier [`INSTALL_ADMIN_SYSTEM.sql`](./INSTALL_ADMIN_SYSTEM.sql)
5. Cliquez sur **Run**

Ce script va créer :
- ✅ La vue `pending_token_purchases`
- ✅ La fonction `validate_token_purchase()`
- ✅ La fonction `reject_token_purchase()`
- ✅ Les colonnes manquantes dans `token_purchases`
- ✅ Les permissions nécessaires

## Étape 2 : Configurer les variables d'environnement

1. Récupérez vos credentials Supabase :
   - **URL du projet** : Settings → API → Project URL
   - **Anon key** : Settings → API → Project API keys → anon/public

2. Modifiez le fichier [`.env`](./.env) :

```env
VITE_SUPABASE_URL=https://votre-projet.supabase.co
VITE_SUPABASE_ANON_KEY=votre_cle_anon_ici
```

## Étape 3 : Lancer l'application

```bash
npm run dev
```

L'application sera accessible sur **http://localhost:5174**

## ✅ Vérification

Une fois le script SQL exécuté, vérifiez dans Supabase :

```sql
-- Cette requête doit retourner un résultat
SELECT * FROM pending_token_purchases;
```

Si vous voyez des achats en attente, tout fonctionne ! 🎉

## 🎯 Utilisation

1. **Dashboard** : Vue d'ensemble des statistiques
2. **Achats en attente** : Valider/rejeter les paiements Mobile Money
3. **Utilisateurs** : Gérer tous les utilisateurs de la plateforme

## 🔐 Sécurité (Production)

⚠️ **Important** : Avant de déployer en production, ajoutez une authentification admin :

1. Créez une table `admin_users`
2. Ajoutez un login/mot de passe
3. Protégez toutes les routes avec un middleware d'authentification
4. Limitez les permissions RPC aux admins uniquement

## 📞 Support

Si vous rencontrez des erreurs :

1. Vérifiez que toutes les tables existent : `token_purchases`, `users`, `token_packages`, `mobile_money_numbers`
2. Vérifiez les permissions RLS sur ces tables
3. Consultez les logs Supabase pour voir les erreurs SQL
