#!/bin/bash
# Hardened Debian // Wilmore Dynamics.
# Script de durcissement pour Debian.
# Philosophie : Minimalisme, Sécurité, Souveraineté.

set -e 

# --- Couleurs ---
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}--- Hardened Debian // Wilmore Dynamics ---${NC}\n"

# 1. Privilèges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Ce script doit être lancé en tant que root.${NC}"
   exit 1
fi

# 2. Mise à jour
echo -e "${GREEN}[1/5] Mise à jour du système...${NC}"
apt update && apt full-upgrade -y
apt autoremove -y && apt autoclean

# 3. Noyau (sysctl)
echo -e "${GREEN}[2/5] Application du durcissement réseau (sysctl)...${NC}"
if systemd-detect-virt -c > /dev/null; then
    echo -e "${RED}[!] Environnement LXC détecté : Saut de la configuration sysctl.${NC}"
else
    if [ -f "configs/sysctl.conf" ]; then
        cp configs/sysctl.conf /etc/sysctl.d/99-hardened.conf
        sysctl -p /etc/sysctl.d/99-hardened.conf > /dev/null
        echo -e "${BOLD}Paramètres réseau sécurisés avec succès.${NC}"
    else
        echo -e "${RED}Erreur : configs/sysctl.conf introuvable.${NC}"
    fi
fi

# 4. SSH (Adaptatif)
echo -e "${GREEN}[3/5] Configuration du service SSH (Hardening)...${NC}"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
AUTHORIZED_KEYS="$TARGET_HOME/.ssh/authorized_keys"

if [ ! -f "$AUTHORIZED_KEYS" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
    echo -e "${RED}⚠ ERREUR : Aucune clé SSH valide dans $AUTHORIZED_KEYS${NC}"
    exit 1
fi

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
mkdir -p /etc/ssh/sshd_config.d/
cp configs/sshd_config /etc/ssh/sshd_config.d/wilmore-hardened.conf

if sshd -t; then
    systemctl restart ssh
    echo -e "${BOLD}SSH sécurisé.${NC}"
else
    echo -e "${RED}Erreur de syntaxe SSH. Annulation.${NC}"
    exit 1
fi

# 5. UFW
echo -e "${GREEN}[4/5] Configuration du Pare-feu (UFW)...${NC}"
apt install ufw -y > /dev/null
ufw default deny incoming
ufw default allow outgoing

SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config.d/wilmore-hardened.conf | awk '{print $2}')
SSH_PORT=${SSH_PORT:-2222}

ufw allow "$SSH_PORT"/tcp comment 'Custom SSH Port'
ufw --force enable
echo -e "${BOLD}Pare-feu actif sur le port $SSH_PORT.${NC}"

# 6. Fail2Ban
echo -e "${GREEN}[5/5] Installation de Fail2Ban...${NC}"
apt install fail2ban -y > /dev/null
cp configs/jail.local /etc/fail2ban/jail.local
sed -i "s/^port *=.*/port = $SSH_PORT/" /etc/fail2ban/jail.local
systemctl restart fail2ban

# --- RAPPORT FINAL ---
echo -e "\n${BOLD}📊 RAPPORT DE DURCISSEMENT - WILMORE DYNAMICS${NC}"
echo -e "--------------------------------------------------"
printf "| %-20s | %-20s |\n" "Composant" "Statut"
echo -e "--------------------------------------------------"
printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Système" "À jour"
printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Utilisateur" "$TARGET_USER"
printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Port SSH" "$SSH_PORT"
printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Firewall" "Actif"
printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Fail2Ban" "Actif"
echo -e "--------------------------------------------------"
echo -e "${BOLD}Vérifiez votre accès SSH sur le port $SSH_PORT avant de quitter.${NC}"