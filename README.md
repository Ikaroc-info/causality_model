# Causal Experience Manager

Une application desktop Windows pour calculer des effets causaux à partir de données CSV, en utilisant DoWhy, pandas et customtkinter.

---

## 🚀 Premier lancement (installation automatique)

> ⚠️ **Important** : il faut passer par l'**invite de commandes** (CMD), pas double-cliquer directement sur le fichier. Voir les étapes ci-dessous.

### Étape 1 — Télécharger le projet

Télécharge le projet sous forme de `.zip` depuis GitHub, puis **extrais-le** dans un dossier de ton choix (par exemple `C:\Users\TonNom\Downloads\causality_model`).

### Étape 2 — Ouvrir l'invite de commandes dans le bon dossier

1. Ouvre le dossier extrait dans l'**Explorateur de fichiers**
2. Clique sur la **barre d'adresse** en haut (là où il y a le chemin du dossier)
3. Tape `cmd` et appuie sur **Entrée**

> Une fenêtre noire (invite de commandes) s'ouvre directement dans le bon dossier.

**Alternative** : tu peux aussi ouvrir CMD manuellement :
- Appuie sur `Windows + R`, tape `cmd`, appuie sur Entrée
- Puis navigue jusqu'au dossier avec : `cd C:\chemin\vers\causality_model`

### Étape 3 — Lancer l'installation

Dans l'invite de commandes, tape :

```
launch.bat
```

Et appuie sur **Entrée**.

Le script s'occupe automatiquement de :
1. 📦 Télécharger et installer **Python 3.11** (via Miniconda, sans droits admin, sans modifier le système)
2. 🐍 Créer un **environnement virtuel** isolé
3. 📚 Installer toutes les **dépendances** depuis `requirements.txt`
4. 🖥️ Lancer l'**application**

> ⏱️ La première installation prend **5 à 10 minutes** (téléchargement ~85 MB + dépendances).
> Les lancements suivants sont **quasi-instantanés** (Python et les paquets sont déjà en cache).

### Ce qui est installé sur ta machine

Après installation, deux dossiers sont créés dans ton profil utilisateur :

| Dossier | Contenu |
|---|---|
| `%USERPROFILE%\miniconda_causality` | Python 3.11 + tkinter (Miniconda) |
| `%USERPROFILE%\causality_app` | Fichiers de l'application (copie permanente) |

Un **raccourci** nommé `Causality Model` est également créé sur ton **Bureau** — tu pourras utiliser celui-ci pour les lancements suivants sans avoir besoin de retourner dans le dossier de téléchargement.

---

## 🔁 Lancements suivants

Une fois installé, tu peux lancer l'application de deux façons :

- **Double-cliquer sur le raccourci** `Causality Model` sur le Bureau
- **Ou** retourner dans le dossier et retaper `launch.bat` dans CMD

---

## 🔄 Réinstallation complète

Si quelque chose ne fonctionne pas et que tu veux repartir de zéro, utilise l'option `-Clean` :

```
launch.bat -Clean
```

Cela supprime **tout** (Python, venv, fichiers copiés, raccourci bureau) et réinstalle depuis zéro.

---

## Fonctionnalités

- **Chargement CSV** : sélectionne tes jeux de données via une boîte de dialogue standard
- **Sélection de variables** : choisis les Traitements (causes), Effets, et Confondeurs (contrôles)
- **Modèle causal** :
  - `dowhy` pour l'inférence causale
  - Régression linéaire, méthodes par score de propension
  - Tests de robustesse (Placebo, Random Common Cause)
- **Diagnostics** :
  - Différence de moyennes standardisée (SMD) affichée via Matplotlib

---

## Prérequis

- **Windows 10 ou 11** (64 bits)
- **Connexion internet** pour la première installation
- Aucun autre logiciel n'est nécessaire