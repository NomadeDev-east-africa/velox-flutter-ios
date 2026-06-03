# Correction des règles Firestore — Nomade 253
**Date** : 24 mai 2026  
**Apps concernées** : Client, Livreur  
**Fichier de règles** : `C:\Users\PC\Desktop\FINAL 253 NOMADE\client app\production\firestore.rules`

---

## Problème racine : accès par notation pointée sur un champ absent

### Explication technique

En Firestore Security Rules, il existe deux façons d'accéder à un champ :

```javascript
// ❌ DANGEREUX — si le champ est absent du document, lève une erreur runtime → PERMISSION_DENIED
request.resource.data.monChamp == null

// ✅ SÛREMENT — retourne la valeur par défaut si le champ est absent
request.resource.data.get('monChamp', null) == null
```

**Règle d'or** : utiliser `.get('champ', valeurParDefaut)` pour tout champ qui peut être **absent** du document (jamais écrit, ou écrit conditionnellement côté client/Cloud Functions).

---

## Erreur 1 — App client : impossible de créer une commande (`orders`)

### Symptôme
```
PERMISSION_DENIED sur orders/.add()
```
L'app client ne pouvait pas placer de commande. Les documents tentés n'existaient pas dans Firestore (écriture rejetée).

### Cause
Dans `Order.toMap()`, le champ `deliveryDriverId` est **omis du payload** quand il est `null` :
```dart
if (deliveryDriverId != null) map['deliveryDriverId'] = deliveryDriverId;
```
La règle Firestore accédait à ce champ absent via notation pointée :
```javascript
&& request.resource.data.deliveryDriverId == null  // ❌ champ absent → erreur
```

### Correction appliquée
```javascript
// AVANT
&& request.resource.data.deliveryDriverId == null

// APRÈS
&& request.resource.data.get('deliveryDriverId', null) == null
```
**Fichier** : `firestore.rules` — bloc `orders / allow create`

---

## Erreur 2 — App client : impossible de créer une course taxi (`taxiRides`)

### Symptôme
```
PERMISSION_DENIED sur taxiRides/.add()
```

### Cause
Dans `ride_service.dart`, `createRide()` n'envoie jamais `targetedDriverId` ni `driverQueue` dans le payload (ces champs sont réservés aux Cloud Functions via Admin SDK). La règle accédait à ces champs absents :
```javascript
&& request.resource.data.targetedDriverId == null  // ❌ absent
&& request.resource.data.driverQueue      == null  // ❌ absent
```

### Correction appliquée
```javascript
// AVANT
&& request.resource.data.driverId         == null
&& request.resource.data.targetedDriverId == null
&& request.resource.data.driverQueue      == null

// APRÈS
&& request.resource.data.get('driverId', null)         == null
&& request.resource.data.get('targetedDriverId', null) == null
&& request.resource.data.get('driverQueue', null)      == null
```
**Fichier** : `firestore.rules` — bloc `taxiRides / allow create`

---

## Erreur 3 — App livreur : impossible d'accepter une commande (`orders`)

### Symptôme
```
PERMISSION_DENIED sur orders update (self-assign livreur)
```
Le livreur ne pouvait ni lire les commandes disponibles ni s'auto-assigner.

### Cause
Les commandes sont créées **sans** le champ `deliveryDriverId` (voir Erreur 1). Quand le livreur tente de lire ou d'accepter une commande existante, les règles accèdent à ce champ absent via `resource.data` (document existant) :

```javascript
// Règle read
isOwner(resource.data.deliveryDriverId)      // ❌ champ absent
resource.data.deliveryDriverId == null       // ❌ champ absent

// Règle update (self-assign)
resource.data.deliveryDriverId == null       // ❌ champ absent

// Règle update (annulation livreur)
isOwner(resource.data.deliveryDriverId)      // ❌ champ absent
request.resource.data.deliveryDriverId == null  // ❌ peut être absent
```

### Corrections appliquées (4 endroits)

**1. `allow read` — livreur assigné**
```javascript
// AVANT
isOwner(resource.data.deliveryDriverId)
// APRÈS
isOwner(resource.data.get('deliveryDriverId', ''))
```

**2. `allow read` — commandes libres pour les livreurs**
```javascript
// AVANT
resource.data.deliveryDriverId == null
// APRÈS
resource.data.get('deliveryDriverId', null) == null
```

**3. `allow update` — self-assign livreur**
```javascript
// AVANT
resource.data.deliveryDriverId == null
// APRÈS
resource.data.get('deliveryDriverId', null) == null
```

**4. `allow update` — annulation livreur assigné**
```javascript
// AVANT
isOwner(resource.data.deliveryDriverId)
request.resource.data.deliveryDriverId == null
// APRÈS
isOwner(resource.data.get('deliveryDriverId', ''))
request.resource.data.get('deliveryDriverId', null) == null
```
**Fichier** : `firestore.rules` — bloc `orders / allow read` et `orders / allow update`

---

## Erreur 4 — App client : impossible de noter restaurant et livreur (`orders`)

### Symptôme
```
PERMISSION_DENIED sur orders update (notation client)
```

### Cause
Le champ `ratedAt` n'existe pas dans le document d'une commande complétée **avant** que le client ne soumette sa note. La règle accédait à ce champ absent :
```javascript
&& resource.data.ratedAt == null  // ❌ champ absent avant la 1ère notation
```

### Correction appliquée
```javascript
// AVANT
&& resource.data.ratedAt == null

// APRÈS
&& resource.data.get('ratedAt', null) == null
```
**Fichier** : `firestore.rules` — bloc `orders / allow update / CLIENT — noter`

---

## Erreur 5 — App client : impossible de noter le chauffeur taxi (`taxiRides`)

### Symptôme
```
PERMISSION_DENIED sur taxiRides update (notation chauffeur)
```

### Cause
Même pattern : `userRating` n'existe pas dans le document d'une course terminée avant la notation.

### Correction appliquée
```javascript
// AVANT
&& resource.data.userRating == null

// APRÈS
&& resource.data.get('userRating', null) == null
```
**Fichier** : `firestore.rules` — bloc `taxiRides / allow update / CLIENT — noter`

---

## Erreur 6 — Notification client → restaurant non reçue

### Symptôme
Le restaurant ne recevait pas de notification à la création d'une nouvelle commande.

### Diagnostic
Le log client montrait :
```
✅ [FoodNotification] Notification envoyée via Cloud Function
  - Résultat: {success: false, message: Pas de token FCM}
```
Vérification Firestore sur `restaurants/4vssNhx3VxPkh415gTyLW8QipUx2` :
```json
"fcmToken": null,
"fcmTokenUpdatedAt": "2026-05-21T15:53:56.723Z"
```

### Cause
La Cloud Function `sendRestaurantNotification` avait mis le `fcmToken` à `null` lors d'un envoi précédent (token devenu invalide — app réinstallée ou appareil changé). La Cloud Function `onOrderCreated` ne notifiait pas du tout le restaurant de son côté.

### Correction appliquée

**1. `functions/index.js` — ajout notification dans `onOrderCreated`**

La notification restaurant est désormais envoyée directement dans le trigger `onOrderCreated` (Admin SDK, côté serveur) en plus du callable `sendRestaurantNotification`. Si le token est invalide, il est nettoyé automatiquement.

**2. Action opérationnelle**

Le restaurant doit ouvrir l'app restaurant pour régénérer un token FCM valide dans Firestore.

---

## Récapitulatif des règles modifiées

| Collection | Règle | Champ corrigé | Type d'accès |
|---|---|---|---|
| `taxiRides` | `allow create` | `driverId` | `request.resource.data` |
| `taxiRides` | `allow create` | `targetedDriverId` | `request.resource.data` |
| `taxiRides` | `allow create` | `driverQueue` | `request.resource.data` |
| `taxiRides` | `allow update` | `userRating` | `resource.data` |
| `orders` | `allow create` | `deliveryDriverId` | `request.resource.data` |
| `orders` | `allow read` | `deliveryDriverId` | `resource.data` (×2) |
| `orders` | `allow update` | `deliveryDriverId` | `resource.data` + `request.resource.data` |
| `orders` | `allow update` | `ratedAt` | `resource.data` |

**Règle universelle appliquée** : tout champ absent du payload d'écriture (omis côté Flutter quand `null`, ou réservé aux Cloud Functions) doit être vérifié avec `.get('champ', valeurDefaut)` et non par notation pointée directe.
