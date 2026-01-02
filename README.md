# UptimeKuma auf Raspberry Pi

UptimeKuma auf einem Raspberry Pi 5, unabhängig von den anderen Diensten.

## Installation

Pi OS downloaden, unxz.
Nachdem das Image mit dd auf die SD-Karte geschrieben wurde, nicht vergessen, ssh zu aktivieren und einen Nutzer zu erstellen. 

## Ansible-Setup
Passwort-Datei erstellen (`.vault_pass`). 
IP in `inventory/hosts.yaml` anpassen -> `ansible-playbook playbook.yaml --ask-pass`.
Dauert 30+ Minuten.

Danach ist Passwort-SSH deaktiviert.

Tailscale aufsetzen mit `tailscale login`. 
Öffentlich erreichbar machen mit `sudo tailscale funnel --bg --https=443 80`. 
Hostname über `tailscale status` -> CNAME-record:
```
Name: uptime-staging
Target: <uptime-pi.tail-abc123.ts.net>
```
