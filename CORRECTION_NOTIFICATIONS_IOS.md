# Correction — Notifications push iOS ne fonctionnaient pas sur TestFlight

## Symptôme

Les notifications push (VTC, commande resto, message de test manuel Firebase) fonctionnaient
parfaitement sur un build local (installé directement via Xcode/devicectl sur iPhone, certificat
**Apple Development**), mais n'arrivaient **jamais** sur un build **TestFlight** (certificat
Apple Distribution), et ce sur 5 builds successifs (1.0.3+2 à +5).

## Fausses pistes explorées (à ne pas refaire)

1. **Re-signer/rebuild l'IPA plusieurs fois** — vérifié à chaque fois : signature Apple
   Distribution correcte, `aps-environment: production` présent dans les entitlements ET dans
   le profil de provisionnement Apple embarqué (`embedded.mobileprovision`). Résultat identique
   à chaque build → ce n'était pas un problème de signature.
2. **`DEVELOPMENT_TEAM` absent dans le projet Xcode** — corrigé (bonne pratique en soi), mais
   n'a changé ni la signature ni le comportement du build final. Pas la cause.
3. **Fausse théorie : TestFlight utiliserait l'environnement sandbox avant publication sur
   l'App Store.** Un correctif a été écrit pour forcer `Messaging.setAPNSToken(type: .sandbox)`
   en détectant `Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"`.
   **C'était une erreur** : ce test détecte un reçu StoreKit (achats intégrés) sandbox, pas
   l'environnement APNs. Un ingénieur Apple a confirmé sur les forums développeurs que
   **TestFlight utilise toujours l'environnement APNs production**, peu importe si l'app est
   déjà publiée. Ce correctif a été retiré (revert complet de `AppDelegate.swift` et
   `FirebaseAppDelegateProxyEnabled`).

## Cause réelle

Dans **Firebase Console → Project Settings → Cloud Messaging → Apple app configuration**
(app **VELOX CLIENT**, bundle `dj.velox.client`) :
- ✅ "Development APNs auth key" : configurée (Key ID `Q5KC4J92NR`, Team ID `7XH7YBK9H6`)
- ❌ "Production APNs auth key" : **vide**

Firebase n'avait donc aucune clé pour livrer des notifications en environnement production.
Le sandbox marchait car sa clé était présente ; la production échouait systématiquement,
silencieusement (aucune erreur visible côté app ni côté Firebase Console lors de l'envoi).

## Fix

Ré-upload du même fichier `.p8` (une clé APNs Apple n'est pas restreinte à un seul
environnement) dans le champ **Production APNs auth key**, avec le même Key ID et Team ID.
Aucune modification de code nécessaire au final.

Confirmé fonctionnel sur le build **1.0.3+6** : notifications VTC, resto, et message de test
manuel Firebase toutes reçues sur un vrai build TestFlight.

## À retenir pour la prochaine fois

Si "les notifications marchent en local mais pas sur TestFlight/App Store" avec Firebase
Cloud Messaging : **vérifier en premier** que les deux champs (Development ET Production APNs
auth key) sont bien remplis dans Firebase Console, avant de suspecter le code ou la signature.
