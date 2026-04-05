# UptimeKuma auf Raspberry Pi

## TODO
- [ ] Uptime Kuma Push-Monitor als zusätzlichen Alerting-Kanal für Backup-Sync und Restic-Check einrichten

UptimeKuma auf einem Raspberry Pi 5, unabhängig von den anderen Diensten.
Auch: Off-site backup über `rclone sync` von Storagebox. 

## Installation

Pi OS downloaden, unxz.
Nachdem das Image mit dd auf die SD-Karte geschrieben wurde, nicht vergessen, ssh zu aktivieren und einen Nutzer zu erstellen.

## Ansible-Setup
Passwort-Datei erstellen (`.vault_pass`).
IP in `inventory/hosts.yaml` anpassen -> `ansible-playbook playbook.yaml --ask-pass`.

Danach ist Passwort-SSH deaktiviert.

Tailscale aufsetzen mit `tailscale login`.
Öffentlich erreichbar machen mit `sudo tailscale funnel --bg --https=443 80`.
