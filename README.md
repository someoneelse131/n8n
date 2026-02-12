# n8n Docker Setup

n8n mit Nginx Reverse Proxy, Postgres und SSL (Let's Encrypt).

## Architektur

```
Internet → Nginx (:80/:443) → n8n (:5678) → Postgres (:5432)
```

## Setup

### 1. Konfiguration

```bash
cp .env.example .env
```

`.env` anpassen — vor allem `DOMAIN_NAME`, Passwörter und `N8N_ENCRYPTION_KEY`.

Encryption Key generieren:

```bash
openssl rand -hex 32
```

### 2. Lokal testen (ohne SSL)

Zum lokalen Testen ohne SSL den HTTPS-Redirect in `nginx/default.conf.template` deaktivieren und den SSL-Server-Block auskommentieren, oder direkt auf n8n zugreifen:

```bash
docker compose up -d postgres n8n
```

n8n ist dann auf `http://localhost:5678` erreichbar.

### 3. VPS Deployment (mit SSL)

DNS A-Record für die Domain auf die VPS-IP setzen, dann:

```bash
bash init-letsencrypt.sh
docker compose up -d
```

### 4. SSL-Zertifikat erneuern

```bash
docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload
```

Oder als Cronjob (empfohlen):

```bash
0 3 * * * cd /path/to/n8n && docker compose run --rm certbot renew && docker compose exec nginx nginx -s reload
```
