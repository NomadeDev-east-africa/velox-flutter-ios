# Politique de Confidentialité — Velox

**Application :** Velox — Client  
**Éditeur :** Velox  
**Pays d'exercice :** République de Djibouti  
**Dernière mise à jour :** 22 avril 2026

---

## 1. Introduction

Velox (ci-après « nous », « notre » ou « la Société ») exploite l'application mobile **Velox Client** (ci-après « l'Application »), une plateforme multi-services permettant aux résidents et visiteurs de Djibouti de commander des courses VTC/taxi et des repas livrés à domicile.

La présente Politique de Confidentialité a pour objet de vous informer, de manière transparente, sur la nature des données personnelles que nous collectons, la finalité de leur traitement, leur durée de conservation ainsi que vos droits.

En utilisant l'Application, vous acceptez les pratiques décrites dans cette politique.

---

## 2. Données collectées

### 2.1 Données que vous nous fournissez directement

| Donnée | Contexte de collecte |
|--------|----------------------|
| Nom complet | Création de compte |
| Numéro de téléphone | Création de compte, identification |
| Adresse e-mail | Création de compte (optionnel) |
| Photo de profil | Modification du profil (optionnel) |
| Adresses de livraison enregistrées | Fonctionnalité « adresses sauvegardées » |
| Méthode de paiement (cash / WaafiPay / D-Money) | Passage de commande |

### 2.2 Données collectées automatiquement lors de l'utilisation

| Donnée | Finalité |
|--------|----------|
| Localisation GPS (point de départ / destination) | Calcul d'itinéraire et estimation tarifaire pour les courses taxi |
| Token FCM (Firebase Cloud Messaging) | Envoi de notifications push |
| Horodatages d'activité (`lastActiveAt`) | Sécurité et détection de comptes inactifs |
| Historique des courses taxi | Affichage de l'historique utilisateur |
| Historique des commandes food | Affichage de l'historique utilisateur |
| Notes et avis soumis | Amélioration du service et évaluation des partenaires |

### 2.3 Données que nous ne collectons PAS

- Données de localisation en continu en arrière-plan
- Contacts téléphoniques
- Données biométriques
- Numéros de carte bancaire (les paiements mobiles sont traités par WaafiPay ou D-Money)

---

## 3. Finalités du traitement

Vos données sont utilisées pour :

1. **Fournir le service** : mise en relation avec les chauffeurs, traitement des commandes de repas, suivi en temps réel.
2. **Vous identifier et sécuriser votre compte** : authentification Firebase, détection de fraude.
3. **Vous envoyer des notifications** : confirmation de course, statut de commande, alertes importantes.
4. **Améliorer la qualité du service** : analyse des avis et notes, optimisation du matching chauffeur.
5. **Respecter nos obligations légales** : conservation des transactions conformément au droit djiboutien applicable.

---

## 4. Base légale du traitement

Le traitement de vos données repose sur :

- **L'exécution du contrat** : les données nécessaires à la fourniture du service (localisation, coordonnées).
- **Votre consentement** : pour les notifications push et la photo de profil.
- **Notre intérêt légitime** : sécurité de la plateforme, prévention de la fraude, amélioration du service.

---

## 5. Partage des données

Vos données personnelles ne sont jamais vendues à des tiers. Elles peuvent être partagées dans les cas suivants :

| Destinataire | Données partagées | Raison |
|---|---|---|
| Chauffeur assigné à votre course | Nom, numéro de téléphone | Prise en charge de la course |
| Restaurant partenaire | Nom, téléphone, adresse de livraison | Préparation et livraison de commande |
| Livreur assigné | Nom, téléphone, adresse de livraison | Livraison de commande |
| Google Firebase (infrastructure) | Données d'authentification et Firestore | Hébergement sécurisé des données |
| WaafiPay / D-Money | Référence de transaction | Traitement du paiement mobile |

Firebase est opéré par Google LLC et traite les données conformément au RGPD et aux certifications SOC 2 / ISO 27001.

---

## 6. Localisation géographique

La localisation GPS est collectée **uniquement** dans les cas suivants :

- Lors de la saisie du point de départ ou de destination pour une course taxi.
- Pour afficher votre position sur la carte de suivi de course.

**Nous ne collectons pas votre position en arrière-plan.** L'accès à la localisation est demandé en premier plan uniquement, et vous pouvez le révoquer à tout moment dans les paramètres de votre appareil.

---

## 7. Conservation des données

| Catégorie | Durée de conservation |
|---|---|
| Compte utilisateur actif | Durée de vie du compte |
| Historique des courses | 24 mois après la course |
| Historique des commandes | 24 mois après la commande |
| Données de facturation | 5 ans (obligations légales) |
| Token FCM | Mis à jour à chaque connexion, supprimé à la désinscription |
| Compte supprimé | 30 jours après suppression, puis effacement définitif |

---

## 8. Sécurité des données

Nous mettons en œuvre les mesures suivantes pour protéger vos données :

- **Authentification Firebase** : jetons sécurisés, sessions limitées dans le temps.
- **Règles Firestore** : chaque utilisateur ne peut accéder qu'à ses propres données (isolation par `auth.uid`).
- **Transport chiffré** : toutes les communications entre l'Application et nos serveurs utilisent HTTPS / TLS.
- **Accès restreint** : seules les Cloud Functions autorisées (via Admin SDK) peuvent modifier les données sensibles (tarifs, statuts de course, notes agrégées).
- **Aucun stockage local sensible** : les données critiques ne sont pas stockées en clair sur l'appareil.

---

## 9. Vos droits

Conformément aux principes généraux de protection des données, vous disposez des droits suivants :

- **Droit d'accès** : obtenir une copie des données vous concernant.
- **Droit de rectification** : corriger des données inexactes (nom, téléphone, photo).
- **Droit à l'effacement** : demander la suppression de votre compte et de vos données.
- **Droit d'opposition** : vous opposer au traitement de vos données à des fins de marketing.
- **Droit à la portabilité** : recevoir vos données dans un format structuré.
- **Retrait du consentement** : désactiver les notifications push à tout moment dans les paramètres de l'Application.

Pour exercer ces droits, contactez-nous à l'adresse indiquée à la section 11.

---

## 10. Cookies et technologies similaires

L'Application mobile n'utilise pas de cookies au sens traditionnel. Firebase peut utiliser des identifiants d'installation anonymes à des fins d'analyse de performance et de stabilité.

---

## 11. Contact

Pour toute question relative à cette politique ou pour exercer vos droits :

**Velox**  
Djibouti, République de Djibouti  
E-mail : **devchirdon@gmail.com**  
Téléphone : disponible dans l'Application

---

## 12. Modifications de la politique

Nous nous réservons le droit de modifier cette politique à tout moment. En cas de changement substantiel, vous serez notifié via l'Application ou par e-mail. La date de dernière mise à jour est indiquée en haut de ce document.

L'utilisation continue de l'Application après notification vaut acceptation de la politique mise à jour.

---

*Velox — Votre partenaire de mobilité et de livraison à Djibouti.*
