#!/bin/bash
set -e

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found. Copy .env.example to .env and adjust values."
  exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
  echo "Error: DOMAIN_NAME is not set in .env"
  exit 1
fi

DATA_PATH="./certbot"
EMAIL="${CERTBOT_EMAIL:-}" # Optional: set CERTBOT_EMAIL in .env for expiry notifications
STAGING=0 # Set to 1 for testing to avoid rate limits

echo "### Creating directories ..."
mkdir -p "$DATA_PATH/conf"
mkdir -p "$DATA_PATH/www"

echo "### Downloading recommended TLS parameters ..."
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
  > "$DATA_PATH/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
  > "$DATA_PATH/conf/ssl-dhparams.pem"

echo "### Stopping any running containers ..."
docker compose down 2>/dev/null || true
docker stop n8n-nginx-init 2>/dev/null || true
docker rm n8n-nginx-init 2>/dev/null || true

echo "### Starting temporary nginx for ACME challenge ..."
docker run -d --name n8n-nginx-init \
  -p 80:80 \
  -v "$(pwd)/nginx/init.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
  nginx:alpine

echo "### Waiting for nginx to start ..."
sleep 2

# Verify nginx is running
if ! docker ps --filter name=n8n-nginx-init --format '{{.Status}}' | grep -q "Up"; then
  echo "Error: nginx failed to start. Logs:"
  docker logs n8n-nginx-init
  exit 1
fi

echo "### Requesting Let's Encrypt certificate for $DOMAIN_NAME ..."

STAGING_ARG=""
if [ $STAGING -eq 1 ]; then
  STAGING_ARG="--staging"
fi

EMAIL_ARG="--register-unsafely-without-email"
if [ -n "$EMAIL" ]; then
  EMAIL_ARG="--email $EMAIL"
fi

docker run --rm \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  $STAGING_ARG \
  $EMAIL_ARG \
  -d "$DOMAIN_NAME" \
  --agree-tos \
  --no-eff-email \
  --force-renewal

echo "### Stopping temporary nginx ..."
docker stop n8n-nginx-init && docker rm n8n-nginx-init

echo "### Done! SSL certificate installed for $DOMAIN_NAME"
echo "### Run 'docker compose up -d' to start everything."
