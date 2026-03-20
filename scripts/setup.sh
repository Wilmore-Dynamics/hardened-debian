#!/bin/bash
# Hardened Debian // Wilmore Dynamics.
# Script de durcissement pour Debian.
# Philosophie : Minimalisme, Sécurité, Souveraineté.

set -e # Arrête le script en cas d'erreur

# --- Couleurs (Design System Wilmore) ---
# Nous utilisons des codes simples pour le terminal
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}--- Hardened Debian // Wilmore Dynamics ---${NC}\n"

# 1. Vérification des privilèges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Ce script doit être lancé en tant que root.${NC}"
   exit 1
fi

# 2. Mise à jour et nettoyage
echo -e "${GREEN}[1/5] Mise à jour du système...${NC}"
apt update && apt full-upgrade -y
apt autoremove -y && apt autoclean

if systemd-detect-virt -c > /dev/null; then
    echo -e "${RED}[!] Environnement LXC détecté : Saut de la configuration sysctl (doit être faite sur l'hôte).${NC}"
else
    # Appliquer sysctl normalement (C'est une VM ou un Bare Metal)
    cp configs/sysctl.conf /etc/sysctl.d/99-hardened.conf
    sysctl -p /etc/sysctl.d/99-hardened.conf > /dev/null
fi

# 3. Configuration du Noyau (sysctl)
echo -e "${GREEN}[2/5] Application du durcissement réseau (sysctl)...${NC}"

# Copie du template de configuration vers le répertoire système
cp configs/sysctl.conf /etc/sysctl.d/99-hardened.conf

# Chargement immédiat des nouveaux paramètres sans redémarrer
sysctl -p /etc/sysctl.d/99-hardened.conf > /dev/null

echo -e "${BOLD}Paramètres réseau sécurisés avec succès.${NC}"

# --- 4. Sécurisation de SSH (Version Adaptative) ---
echo -e "${GREEN}[3/5] Configuration du service SSH (Hardening)...${NC}"

# Détection de l'utilisateur réel (celui qui a tapé la commande)
# SUDO_USER est rempli par sudo, sinon on prend USER
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
AUTHORIZED_KEYS="$TARGET_HOME/.ssh/authorized_keys"

echo -e "Analyse des clés pour l'utilisateur : ${BOLD}$TARGET_USER${NC}"

if [ ! -f "$AUTHORIZED_KEYS" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
    echo -e "${RED}⚠ ERREUR : Aucune clé SSH valide dans $AUTHORIZED_KEYS${NC}"
    echo -e "${RED}Action : Ajoutez une clé Ed25519 à $TARGET_USER avant de continuer.${NC}"
    exit 1
else
    echo -e "${GREEN}✔ Clé SSH détectée pour $TARGET_USER. Sécurisation autorisée.${NC}"
fi

# Sauvegarde et application de la config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
mkdir -p /etc/ssh/sshd_config.d/
cp configs/sshd_config /etc/ssh/sshd_config.d/wilmore-hardened.conf

# Vérification de la syntaxe
if sshd -t; then
    systemctl restart ssh
    echo -e "${BOLD}SSH sécurisé sur le port choisi.${NC}"
else
    echo -e "${RED}Erreur de syntaxe SSH. Annulation.${NC}"
    exit 1
fi
# 5. Pare-feu (UFW)
echo -e "${GREEN}[4/5] Configuration du Pare-feu (UFW)...${NC}"

# Installation silencieuse de UFW
apt install ufw -y > /dev/null

# Définition des politiques par défaut
ufw default deny incoming
ufw default allow outgoing

# Récupération dynamique du port SSH depuis ta config (ou port 2222 par défaut)
SSH_PORT=$(grep "Port" /etc/ssh/sshd_config.d/wilmore-hardened.conf | awk '{print $2}')
SSH_PORT=${SSH_PORT:-2222}

# Ouverture du port SSH spécifique
ufw allow "$SSH_PORT"/tcp comment 'Custom SSH Port'

# Optionnel : Ouvrir HTTP/HTTPS si c'est un serveur web
# ufw allow 80/tcp
# ufw allow 443/tcp

# Activation de UFW (le --force évite la question de confirmation interactive)
ufw --force enable

echo -e "${BOLD}Pare-feu actif : Seul le port $SSH_PORT est ouvert en entrée.${NC}"

# 6. Protection Active (Fail2Ban)
echo -e "${GREEN}[5/5] Installation et configuration de Fail2Ban...${NC}"

# Installation
apt install fail2ban -y > /dev/null

# Préparation du fichier de configuration
cp configs/jail.local /etc/fail2ban/jail.local

# Dynamisation du port SSH dans Fail2ban (pour correspondre à SSH_PORT)
# On remplace le port par défaut par celui détecté plus haut dans le script
sed i "s/port     = 2222/port     = $SSH_PORT/g" /etc/fail2ban/jail.local

# Redémarrage du service
systemctl restart fail2ban

echo -e "${BOLD}Fail2Ban est actif et surveille le port $SSH_PORT.${NC}"

# --- FIN DU SCRIPT ---
echo -e "\n${GREEN}✔ Hardening Debian terminé avec succès !${NC}"
echo -e "Résumé : Noyau durci, SSH sur port $SSH_PORT (Clés seules), Firewall actif, Fail2ban opérationnel."