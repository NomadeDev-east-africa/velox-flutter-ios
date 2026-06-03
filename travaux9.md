# Travaux 9 — Diagnostic & Fix CF onTaxiRideCreated

## Problème identifié

Course `qFr564SGebRYw304oDYF` créée avec succès côté client mais le chauffeur ne recevait rien.

**Cause racine** : `onTaxiRideCreated` crashait silencieusement à cause de l'index Firestore composite
`(isOnline + isAvailable + lastHeartbeat)` non déployé sur Firebase → exception `FAILED_PRECONDITION`
catchée sans mise à jour du statut → course bloquée à `"requested"` indéfiniment.

**Preuve** : document taxiRides sans `targetedDriverId`, `driverQueue`, ni `offerExpiresAt`
(ces champs sont écrits après la query drivers — jamais atteints).

---

## Fichier modifié

`functions/index.js`

### Changement 1 — Nouvelle fonction helper `assignDriverToRide()`

Toute la logique d'assignation driver extraite dans une fonction réutilisable :
- Recherche drivers (isOnline + isAvailable + heartbeat < 2min)
- Filtre par distance (rayon adaptatif 5→10→15→30→50 km)
- Vérification courses actives
- Écriture `targetedDriverId` + `driverQueue` + envoi FCM

**Fix critique** : le `catch` met maintenant le statut à `"no_driver_available"` au lieu
de laisser la course bloquée à `"requested"` indéfiniment.

### Changement 2 — `onTaxiRideCreated` simplifié

Corps réduit de 60 lignes à 1 ligne :
```javascript
await assignDriverToRide(getFirestore(), snap.ref, rideId, ride);
```

### Changement 3 — `cleanupExpiredOffers` : récupération des rides abandonnées

Section ajoutée dans le scheduler (toutes les 1 min) :
- Détecte les courses `status == "requested"` depuis > 2 min sans `driverQueue`
- Relance `assignDriverToRide()` automatiquement sur ces courses
- Suppression du `return` prématuré qui empêchait cette section de s'exécuter

---

## Déploiement nécessaire

```bash
firebase deploy --only functions,firestore:indexes
```

L'index composite `drivers (isOnline + isAvailable + lastHeartbeat)` est défini dans
`firestore.indexes.json` mais n'était pas déployé — c'est la cause du crash.

Attendre que l'index passe en statut **"Activé"** dans Firebase Console avant de tester.

---

## Problèmes secondaires identifiés (non bloquants)

- FCM token du driver non rafraîchi depuis mars 2026 (68 jours) → à corriger côté app driver
- Heartbeat driver à 1min50 avant la course (seuil = 2min) → marge très serrée
- Règles Firestore du projet (`firestore.rules`) obsolètes vs production
  (`C:\Users\PC\Desktop\FINAL 253 NOMADE\client app\production\firestore_rules.rules`)
