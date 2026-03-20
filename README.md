# <p align="center">Hardened Debian</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Wilmore-Dynamics/design/refs/heads/main/assets/logo-cream.svg" width="96" alt="Logo Wilmore Dynamics">
</p>

<p align="center">
  <strong>Console de sécurisation et d'optimisation Debian.</strong>
</p>

---

## Philosophie

Réduction de la surface d'attaque par l'artisanat numérique. Ce dépôt fournit une **interface CLI interactive** pour déployer une base souveraine, minimaliste et rigoureusement durcie.

## Capacités v1.4.2 "Emerald"

- **Console Interactive :** Menu de gestion persistant pour un déploiement modulaire.
- **Mode ANSSI :** Durcissement des privilèges et isolation du noyau (LXC friendly).
- **Mises à jour Auto :** Intégration de `unattended-upgrades` (Sécurité critique uniquement).
- **Signature MOTD :** Accueil personnalisé Wilmore Dynamics à la connexion SSH.
- **Core :** SSH Ed25519 (Port 2222), UFW (Drop-all), Fail2ban.

## Installation & Usage

```bash
git clone [https://github.com/Wilmore-Dynamics/hardened-debian.git](https://github.com/Wilmore-Dynamics/hardened-debian.git)
cd hardened-debian
chmod +x scripts/setup.sh
sudo ./scripts/setup.sh
```

## Structure

- `/scripts` : setup.sh — Console de durcissement interactive (v1.4.2).
- `/configs` : Templates durcis pour sshd, sysctl et fail2ban.

---

<p align="right">
<sub>© 2026 Wilmore Dynamics. Moins, mais mieux.</sub>
</p>
