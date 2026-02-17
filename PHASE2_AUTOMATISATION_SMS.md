# Phase 2 : Automatisation via SMS (Africa's Talking)

## Configuration Africa's Talking

### 1. Créer un compte
- Site : https://africastalking.com
- Pays supportés : Togo, Bénin, Burkina, Côte d'Ivoire, etc.
- Tarifs : ~0.01F/SMS reçu

### 2. Configurer le numéro virtuel
```bash
# Obtenir un numéro virtuel (shared number)
# Togo : +228 XX XX XX XX
# Configuration : Recevoir SMS + Callback URL
```

### 3. Configuration Supabase Edge Function

#### Créer la fonction
```bash
cd supabase/functions
supabase functions new process-payment-sms
```

#### Code de la fonction
```typescript
// supabase/functions/process-payment-sms/index.ts
import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Vérifier la signature Africa's Talking (sécurité)
    const signature = req.headers.get('x-africastalking-signature')
    // TODO: Valider signature
    
    // Parser le body du webhook
    const formData = await req.formData()
    const from = formData.get('from') as string        // Ex: +22890123456
    const text = formData.get('text') as string        // Ex: "Vous avez reçu 12,750 FCFA..."
    const date = formData.get('date') as string
    
    console.log(`[SMS] From: ${from}, Text: ${text}`)
    
    // Parser le SMS selon le format de l'opérateur
    const parsed = parseMobileMoneySmS(text)
    
    if (!parsed) {
      return new Response("SMS format not recognized", { status: 400 })
    }
    
    // Connexion Supabase avec service_role (admin)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    // Chercher le paiement correspondant (30 min max)
    const { data: purchase } = await supabase
      .from('token_purchases')
      .select()
      .eq('status', 'pending')
      .eq('total_amount', parsed.amount)
      .gte('created_at', new Date(Date.now() - 30*60*1000).toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    
    if (!purchase) {
      console.log(`[SMS] No matching purchase for ${parsed.amount} FCFA`)
      return new Response("No matching purchase", { status: 404 })
    }
    
    // Validation automatique !
    const { error } = await supabase.rpc('validate_token_purchase', {
      p_purchase_id: purchase.id,
      p_admin_notes: `Auto-validé via SMS Africa's Talking à ${date} - Expéditeur: ${parsed.senderPhone}`
    })
    
    if (error) {
      console.error('[SMS] Validation error:', error)
      return new Response("Validation failed", { status: 500 })
    }
    
    console.log(`[SMS] ✅ Auto-validated purchase ${purchase.id}`)
    
    // TODO: Envoyer notification push au chauffeur
    
    return new Response("Payment validated", { status: 200 })
    
  } catch (error) {
    console.error('[SMS] Error:', error)
    return new Response("Internal error", { status: 500 })
  }
})

// =====================================================
// PARSER SMS PAR OPÉRATEUR
// =====================================================

interface ParsedSMS {
  amount: number
  senderPhone: string
  operator: string
}

function parseMobileMoneySmS(smsText: string): ParsedSMS | null {
  // Formats connus :
  // MTN : "Vous avez reçu 12,750 FCFA de +228 90 12 34 56"
  // Moov : "Paiement de 12750F depuis 90123456"
  // Togocom : "Crédit 12750 FCFA - 90123456"
  // Yas/Mixx : "Vous avez reçu 12,750 FCFA de +228 XX XX XX XX"
  
  // Pattern MTN/Yas (le plus courant)
  const mtnPattern = /reçu\s+(\d+[,\s]?\d*)\s*(?:FCFA|F)\s*de\s*(\+?\d[\d\s]+)/i
  let match = smsText.match(mtnPattern)
  
  if (match) {
    const amount = parseInt(match[1].replace(/[,\s]/g, ''))
    const phone = match[2].replace(/\s+/g, '')
    return { amount, senderPhone: phone, operator: 'MTN/Yas' }
  }
  
  // Pattern Moov
  const moovPattern = /Paiement\s+de\s+(\d+)\s*F\s+depuis\s+(\d+)/i
  match = smsText.match(moovPattern)
  
  if (match) {
    const amount = parseInt(match[1])
    const phone = match[2]
    return { amount, senderPhone: phone, operator: 'Moov' }
  }
  
  // Pattern Togocom
  const togocomPattern = /Crédit\s+(\d+)\s*(?:FCFA|F)\s*-\s*(\d+)/i
  match = smsText.match(togocomPattern)
  
  if (match) {
    const amount = parseInt(match[1])
    const phone = match[2]
    return { amount, senderPhone: phone, operator: 'Togocom' }
  }
  
  return null
}
```

### 4. Déployer la fonction

```bash
# Déployer sur Supabase
supabase functions deploy process-payment-sms

# Récupérer l'URL du webhook
# https://[PROJECT].supabase.co/functions/v1/process-payment-sms
```

### 5. Configurer Africa's Talking

1. **Dashboard → SMS → Incoming Messages**
2. **Callback URL** : `https://[PROJECT].supabase.co/functions/v1/process-payment-sms`
3. **Method** : POST
4. **Format** : application/x-www-form-urlencoded

### 6. Variables d'environnement

```bash
# Dans Supabase Dashboard → Settings → Edge Functions
SUPABASE_URL=https://[PROJECT].supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbG... (clé admin)
AFRICASTALKING_API_KEY=xxx (pour validation signature)
```

## Flux complet (Phase 2)

```
1. Chauffeur → Clic pack (10 jetons, 12,000 F)
2. Modal → Sélection MTN, code 1234
3. USSD → *133*1*1*12750*1234# composé automatiquement
4. Driver → Confirme avec PIN dans menu MTN
5. MTN → Paiement réussi

--- AUTOMATISATION ICI ---

6. Yas → Envoie SMS au numéro Africa's Talking
   "Vous avez reçu 12,750 FCFA de +228 90 12 34 56"
   
7. Africa's Talking → Webhook POST vers Edge Function
   
8. Edge Function → Parse SMS
   - Montant : 12,750 F
   - Expéditeur : +228 90 12 34 56
   
9. Edge Function → Recherche dans DB
   SELECT * FROM token_purchases
   WHERE status = 'pending'
   AND total_amount = 12750
   AND created_at > NOW() - INTERVAL '30 minutes'
   
10. Edge Function → Match trouvé !
    
11. Edge Function → Appelle validate_token_purchase()
    
12. PostgreSQL → Crédite jetons via add_tokens()
    
13. Balance chauffeur → Mise à jour en temps réel (Supabase stream)
    
14. Edge Function → Notification push au chauffeur
    "✅ 12 jetons crédités ! Nouveau solde : 15 jetons"
    
--- DÉLAI TOTAL : < 30 secondes ---
```

## Coûts estimés (Phase 2)

| Volume | SMS/mois | Coût Africa's Talking | Total/mois |
|--------|----------|----------------------|------------|
| 50 chauffeurs | 150 SMS | 1.50 F | 1.50 F |
| 200 chauffeurs | 600 SMS | 6.00 F | 6.00 F |
| 500 chauffeurs | 1,500 SMS | 15.00 F | 15.00 F |

**Rentabilité** : Dès 100+ paiements/mois, économie de temps admin justifie le coût.

## Sécurité

1. **Signature validation** : Vérifier `x-africastalking-signature`
2. **Time window** : Seulement paiements < 30 min
3. **Amount matching** : Montant exact requis
4. **Service role key** : Stockée en variable d'environnement
5. **Logs** : Tous les SMS parsés enregistrés pour audit

## Tests

### Simulation SMS (développement)

```bash
# Tester le webhook en local
curl -X POST http://localhost:54321/functions/v1/process-payment-sms \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "from=+22890123456&text=Vous avez reçu 12,750 FCFA de +228 90 12 34 56&date=2025-12-15T14:30:00Z"
```

### Vérifier les logs

```bash
# Supabase logs en temps réel
supabase functions logs process-payment-sms --tail
```

## Migration Phase 1 → Phase 2

1. ✅ **Phase 1 fonctionne** : Validation manuelle opérationnelle
2. 📊 **Mesurer volume** : Si > 50 paiements/semaine → Phase 2
3. 🔧 **Déployer Edge Function** : Sans toucher au code existant
4. 🧪 **Tests parallèles** : SMS parsés mais validation manuelle maintenue
5. ✅ **Activation auto-validation** : Quand 95%+ de match réussis
6. 📱 **Garder interface admin** : Pour cas d'erreur ou montants non-standard

## Alternative : Parsing SMS local (Android admin)

Si budget limité, utiliser app mobile admin avec permission SMS :

```dart
// mobile_driver/lib/services/sms_parser_service.dart
import 'package:telephony/telephony.dart';

class SmsParserService {
  final Telephony telephony = Telephony.instance;
  
  Future<void> startListening() async {
    // Demander permission
    await telephony.requestPhoneAndSmsPermissions;
    
    // Écouter SMS entrants
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (_isMobileMoneyConfirmation(message.body)) {
          _autoValidateFromSms(message);
        }
      },
    );
  }
  
  bool _isMobileMoneyConfirmation(String? body) {
    if (body == null) return false;
    return body.contains('reçu') && 
           body.contains('FCFA') &&
           (body.contains('MTN') || body.contains('Moov'));
  }
}
```

**Coût** : Gratuit, mais nécessite téléphone admin dédié + app running 24/7.
