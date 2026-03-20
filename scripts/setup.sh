#!/bin/bash
# Hardened Debian // Wilmore Dynamics.
# Interface CLI - v1.3.1 "Signature"
# Philosophie : Minimalisme, Sécurité, Souveraineté.

set -e 

# --- Configuration & Couleurs ---
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DARK_GRAY='\033[1;30m'
NC='\033[0m'

# --- Identité Visuelle Wilmore ---
print_logo() {
    # ASCII Art repensé pour reproduire ton logo SVG
    echo -e "${DARK_GRAY}"
    echo "       /   \       "
    echo "      (     )      "
    echo "       \ _ /       "
    echo "  /   \     /   \  "
    echo " (     )   (     ) "
    echo "  \ _ /     \ _ /  "
    echo -e "${NC}"
    echo -e " ${BOLD}  WILMORE DYNAMICS${NC}"
    echo -e "  Artisanat Numérique\n"
}

# --- Nouvelles Fonctions ---

setup_motd() {
    echo -e "${GREEN}[*] Personnalisation de l'accueil Wilmore (MOTD)...${NC}"
    
    # Création du fichier temporaire pour le logo (version compacte)
    cat > /tmp/motd_wilmore << 'EOF'
 
       / \       
      (   )      
       \_/       
  / \     / \  
 (   )   (   ) 
  \_/     \_/  
EOF

    # Conversion en ANSI et injection dans le fichier officiel
    echo -e "\033[1;30m$(cat /tmp/motd_wilmore)\033[0m" > /etc/motd
    echo -e "\n\033[1;37m --- Serveur Sécurisé par Wilmore Dynamics --- \033[0m\n" >> /etc/motd
    echo -e "\033[1;32m ✔ Noyau durci\033[0m | \033[1;32m ✔ SSH sécurisé\033[0m | \033[1;32m ✔ Firewall actif\033[0m\n" >> /etc/motd
    rm /tmp/motd_wilmore

    echo -e "${BOLD}✔ MOTD Wilmore Dynamics installé.${NC}"
}

hardening_anssi() {
    echo -e "${GREEN}[*] Application des règles ANSSI (Niveau Renforcé)...${NC}"
    
    # 1. Restriction dmesg (évite fuite d'infos)
    echo "kernel.dmesg_restrict = 1" > /etc/sysctl.d/50-anssi.conf
    
    # 2. Masquage adresses noyau via kptr_restrict
    echo "kernel.kptr_restrict = 2" >> /etc/sysctl.d/50-anssi.conf
    
    # Application immédiate
    # On gère l'erreur au cas où on serait sur un LXC qui bloque sysctl
    sysctl -p /etc/sysctl.d/50-anssi.conf > /dev/null || echo -e "${RED}[!] Note: Restriction sysctl bloquée (LXC?).${NC}"
    
    # 3. Permissions strictes sur fichiers sensibles
    # Seul root peut accéder à son répertoire
    chmod 700 /root
    # Fichier de config SSH critique
    chmod 600 /etc/ssh/sshd_config
    
    echo -e "${BOLD}✔ Règles ANSSI appliquées : Système verrouillé.${NC}"
}

# --- Tes fonctions existantes (modulées) ---

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

    echo -e "Analyse des clés pour l'utilisateur : ${BOLD}$TARGET_USER${NC}"

    if [ ! -f "$AUTHORIZED_KEYS" ] || [ ! -s "$AUTHORIZED_KEYS" ]; then
        echo -e "${RED}⚠ ERREUR : Aucune clé SSH valide dans $AUTHORIZED_KEYS${NC}"
        echo -e "${RED}Action : Ajoutez une clé Ed25519 à $TARGET_USER avant de continuer.${NC}"
        # On utilise return pour stopper la fonction mais pas tout le script
        return 1
    else
        echo -e "${GREEN}✔ Clé SSH détectée pour $TARGET_USER. Sécurisation autorisée.${NC}"
    fi

    # Sauvegarde et application de la config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    mkdir -p /etc/ssh/sshd_config.d/
    cp configs/sshd_config /etc/ssh/sshd_config.d/wilmore-hardened.conf

    # Vérification de la syntaxe avant redémarrage
    if sshd -t; then
        systemctl restart ssh
        echo -e "${BOLD}✔ SSH sécurisé.${NC}"
    else
        echo -e "${RED}Erreur de syntaxe SSH détectée. Annulation.${NC}"
        return 1
    fi
}

setup_security_apps() {
    echo -e "${GREEN}[*] Configuration Firewall & Fail2Ban...${NC}"
    # Firewall (UFW)
    apt install ufw -y > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    
    # Récupération dynamique du port SSH depuis la config
    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config.d/wilmore-hardened.conf | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-2222}
    
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH Port'
    ufw --force enable
    
    # Fail2Ban
    apt install fail2ban -y > /dev/null
    cp configs/jail.local /etc/fail2ban/jail.local
    # Dynamisation du port dans Fail2ban
    sed -i "s/^port *=.*/port = $SSH_PORT/" /etc/fail2ban/jail.local
    systemctl restart fail2ban
    
    echo -e "${BOLD}✔ Sécurité active : UFW sur le port $SSH_PORT et Fail2Ban opérationnel.${NC}"
}

# --- Menu Principal ---
clear
print_logo

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Lancez avec sudo.${NC}"
   exit 1
fi

echo "Sélectionnez votre profil de durcissement :"
echo "-------------------------------------------"
echo "1) Full Hardening (Standard Wilmore Dynamics)"
echo "2) Mode ANSSI (Sécurité Maximale - Serveur critique)"
echo "3) Mise à jour système uniquement"
echo "4) Sécuriser SSH uniquement (Clés + Port)"
echo "5) Installer MOTD Wilmore uniquement"
echo "6) Quitter"
echo ""
read -p "Choix [1-6] : " choice

case $choice in
    1) update_system; hardening_kernel; hardening_ssh; setup_security_apps; setup_motd ;;
    2) update_system; hardening_kernel; hardening_ssh; setup_security_apps; hardening_anssi; setup_motd ;;
    3) update_system ;;
    4) hardening_ssh ;;
    5) setup_motd ;;
    6) exit 0 ;;
    *) echo -e "${RED}Option invalide.${NC}" ;;
esac

echo -e "\n${BOLD}Opération terminée.${NC}"
echo -e "Vérifiez votre accès SSH sur le port choisi avant de vous déconnecter."