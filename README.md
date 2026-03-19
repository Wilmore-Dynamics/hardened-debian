# <p align="center">Hardened Debian</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Wilmore-Dynamics/design/refs/heads/main/assets/logo-cream.svg" width="96" alt="Logo Wilmore Dynamics">
</p>

<p align="center">
  <strong>Sécurisation et optimisation de Debian.</strong>
</p>

---

## Philosophie
Réduction de la surface d'attaque par l'automatisation. Ce dépôt fournit une base souveraine, minimaliste et rigoureusement documentée pour déployer des instances Debian sécurisées.

## Composants Core
* **Kernel :** Durcissement via `sysctl.conf` (Protection réseau L3/L4).
* **Accès :** Configuration SSH stricte (Ed25519, No-Root, Custom Port).
* **Réseau :** Firewalling restrictif via `UFW`.
* **Défense :** Protection active contre le brute-force avec `Fail2ban`.

## Structure
* `/scripts` : Logique d'automatisation Bash.
* `/configs` : Templates de configuration durcis.

---

<p align="right">
  <sub>© 2026 Wilmore Dynamics. Moins, mais mieux.</sub>
</p>
