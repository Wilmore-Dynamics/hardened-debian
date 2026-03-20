#!/bin/bash
# Hardened Debian // Wilmore Dynamics.
# Interface CLI - v1.4 "Interactive & ANSSI+"
# Philosophie : Minimalisme, Sécurité, Souveraineté.

set -e 

# --- Configuration & Couleurs ---
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DARK_GRAY='\033[1;30m'
NC='\033[0m'

# Correction Terminal pour Kitty/SSH
if ! infocmp "$TERM" >/dev/null 2>&1; then
    export TERM=xterm-256color
fi

# --- Identité Visuelle Wilmore ---
print_logo() {
    clear
    echo -e "${GREEN}"
    echo "          .--.          "
    echo "         (    )         "
    echo "          '--'          "
    echo "    .--.        .--.    "
    echo "   (    )      (    )   "
    echo "    '--'        '--'    "
    echo -e "${NC}"
    echo -e "${BOLD}      WILMORE DYNAMICS${NC}"
    echo -e "      Artisanat Numérique\n"
}

# --- Fonctions de Durcissement ---

setup_auto_updates() {
    echo -e "${GREEN}[*] Activation des mises à jour de sécurité (Unattended)...${NC}"
    apt install unattended-upgrades apt-listchanges -y > /dev/null
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Origins-Pattern { "origin=Debian,codename=\${distro_codename},label=Debian-Security"; };
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    echo -e "${BOLD}✔ Mises à jour auto configurées.${NC}"
}

setup_motd() {
    echo -e "${GREEN}[*] Installation du MOTD Wilmore...${NC}"
    cat > /etc/motd << EOF
$(echo -e "${GREEN}")
          .--.          
         (    )         
          '--'          
    .--.        .--.    
   (    )      (    )   
    '--'        '--'    
$(echo -e "${NC}")
 --- Serveur Sécurisé par Wilmore Dynamics --- 
 
 ✔ Noyau durci | ✔ SSH sécurisé | ✔ Firewall actif
EOF
    echo -e "${BOLD}✔ MOTD Wilmore Dynamics installé.${NC}"
}

hardening_anssi() {
    echo -e "${GREEN}[*] Application des règles ANSSI (Niveau Renforcé)...${NC}"
    echo "kernel.dmesg_restrict = 1" > /etc/sysctl.d/50-anssi.conf
    echo "kernel.kptr_restrict = 2" >> /etc/sysctl.d/50-anssi.conf
    sysctl -p /etc/sysctl.d/50-anssi.conf > /dev/null || echo -e "${RED}[!] Restriction sysctl limitée (LXC).${NC}"
    chmod 700 /root
    chmod 600 /etc/ssh/sshd_config
    setup_auto_updates
    echo -e "${BOLD}✔ Règles ANSSI & Auto-updates appliquées.${NC}"
}

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
    echo -e "${GREEN}[*] Configuration du service SSH (Hardening)...${NC}"
    TARGET_USER="${SUDO_USER:-$USER}"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    AUTHORIZED_KEYS="$TARGET_HOME/.ssh/authorized_keys"

    if [ ! -f "$AUTHORIZED_KEYS" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
        echo -e "${RED}⚠ ERREUR : Aucune clé SSH valide dans $AUTHORIZED_KEYS${NC}"
        return 1
    fi

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    mkdir -p /etc/ssh/sshd_config.d/
    cp configs/sshd_config /etc/ssh/sshd_config.d/wilmore-hardened.conf

    if sshd -t; then
        systemctl restart ssh
        echo -e "${BOLD}✔ SSH sécurisé.${NC}"
    else
        echo -e "${RED}Erreur syntaxe SSH. Annulation.${NC}"
        return 1
    fi
}

setup_security_apps() {
    echo -e "${GREEN}[*] Configuration Firewall & Fail2Ban...${NC}"
    apt install ufw -y > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    
    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config.d/wilmore-hardened.conf | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-2222}
    
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH Port'
    ufw --force enable
    
    apt install fail2ban -y > /dev/null
    cp configs/jail.local /etc/fail2ban/jail.local
    sed -i "s/^port *=.*/port = $SSH_PORT/" /etc/fail2ban/jail.local
    systemctl restart fail2ban
    
    echo -e "${BOLD}✔ Sécurité active (Port $SSH_PORT).${NC}"
}

# --- Boucle Interactive ---

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Lancez avec sudo.${NC}"
   exit 1
fi

RUNNING=true
while [ "$RUNNING" = true ]; do
    print_logo
    echo "Sélectionnez une option de durcissement :"
    echo "-------------------------------------------"
    echo "1) Full Hardening (Standard Wilmore)"
    echo "2) Mode ANSSI (Max + Mises à jour auto)"
    echo "3) Mise à jour système uniquement"
    echo "4) Sécuriser SSH uniquement"
    echo "5) Installer le MOTD Wilmore"
    echo "6) QUITTER"
    echo ""
    read -p "Choix [1-6] : " choice

    case $choice in
        1) update_system; hardening_kernel; hardening_ssh; setup_security_apps; setup_motd; read -p "Terminé. Entrée pour continuer..." ;;
        2) update_system; hardening_kernel; hardening_ssh; setup_security_apps; hardening_anssi; setup_motd; read -p "Terminé. Entrée pour continuer..." ;;
        3) update_system; read -p "Terminé. Entrée pour continuer..." ;;
        4) hardening_ssh; read -p "Terminé. Entrée pour continuer..." ;;
        5) setup_motd; read -p "Terminé. Entrée pour continuer..." ;;
        6) RUNNING=false ;;
        *) echo -e "${RED}Option invalide.${NC}"; sleep 1 ;;
    esac
done

clear
echo -e "${BOLD}Merci d'avoir utilisé les outils Wilmore Dynamics.${NC}"
