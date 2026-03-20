#!/bin/bash
# Hardened Debian // Wilmore Dynamics.
# Interface CLI - v1.2
# Philosophie : Minimalisme, Sécurité, Souveraineté.

set -e 

# --- Configuration & Couleurs ---
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# --- Fonctions de Durcissement ---

update_system() {
    echo -e "${GREEN}[*] Mise à jour du système...${NC}"
    apt update && apt full-upgrade -y
    apt autoremove -y && apt autoclean
}

hardening_kernel() {
    echo -e "${GREEN}[*] Application du durcissement réseau (sysctl)...${NC}"
    if systemd-detect-virt -c > /dev/null; then
        echo -e "${RED}[!] Environnement LXC détecté : Saut de sysctl.${NC}"
    else
        if [ -f "configs/sysctl.conf" ]; then
            cp configs/sysctl.conf /etc/sysctl.d/99-hardened.conf
            sysctl -p /etc/sysctl.d/99-hardened.conf > /dev/null
            echo -e "${BOLD}✔ Paramètres réseau sécurisés.${NC}"
        else
            echo -e "${RED}Erreur : configs/sysctl.conf introuvable.${NC}"
        fi
    fi
}

hardening_ssh() {
    echo -e "${GREEN}[*] Configuration du service SSH...${NC}"
    TARGET_USER="${SUDO_USER:-$USER}"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    AUTHORIZED_KEYS="$TARGET_HOME/.ssh/authorized_keys"

    if [ ! -f "$AUTHORIZED_KEYS" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
        echo -e "${RED}⚠ ERREUR : Aucune clé SSH dans $AUTHORIZED_KEYS. Annulation.${NC}"
        return 1
    fi

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    mkdir -p /etc/ssh/sshd_config.d/
    cp configs/sshd_config /etc/ssh/sshd_config.d/wilmore-hardened.conf

    if sshd -t; then
        systemctl restart ssh
        echo -e "${BOLD}✔ SSH sécurisé.${NC}"
    else
        echo -e "${RED}Erreur syntaxe SSH.${NC}"
        return 1
    fi
}

setup_security_apps() {
    echo -e "${GREEN}[*] Configuration Firewall & Fail2Ban...${NC}"
    # Firewall
    apt install ufw -y > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    
    # Récupération du port
    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config.d/wilmore-hardened.conf | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-2222}
    
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH Port'
    ufw --force enable
    
    # Fail2Ban
    apt install fail2ban -y > /dev/null
    cp configs/jail.local /etc/fail2ban/jail.local
    sed -i "s/^port *=.*/port = $SSH_PORT/" /etc/fail2ban/jail.local
    systemctl restart fail2ban
    echo -e "${BOLD}✔ Sécurité active (UFW + Fail2Ban).${NC}"
}

show_report() {
    echo -e "\n${BOLD}📊 RAPPORT DE DURCISSEMENT${NC}"
    echo "--------------------------------------------------"
    printf "| %-20s | %-20s |\n" "Composant" "Statut"
    echo "--------------------------------------------------"
    printf "| %-20s | ${GREEN}%-20s${NC} |\n" "Utilisateur" "${SUDO_USER:-$USER}"
    printf "| %-20s | ${GREEN}%-20s${NC} |\n" "État Global" "Hardened"
    echo "--------------------------------------------------"
}

# --- Menu Principal ---

clear
echo -e "${BOLD}--- Hardened Debian // Wilmore Dynamics ---${NC}"
echo -e "Interface de gestion de la sécurité\n"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Lancez avec sudo.${NC}"
   exit 1
fi

echo "Sélectionnez une option :"
echo "1) Full Hardening (Tout automatiser)"
echo "2) Mise à jour système uniquement"
echo "3) Sécuriser SSH (Clés + Port)"
echo "4) Activer Pare-feu & Fail2Ban"
echo "5) Quitter"
echo ""
read -p "Choix [1-5] : " choice

case $choice in
    1) update_system; hardening_kernel; hardening_ssh; setup_security_apps; show_report ;;
    2) update_system ;;
    3) hardening_ssh ;;
    4) setup_security_apps ;;
    5) exit 0 ;;
    *) echo -e "${RED}Option invalide.${NC}" ;;
esac

echo -e "\n${BOLD}Opération terminée.${NC}"