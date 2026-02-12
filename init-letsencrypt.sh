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
RSA_KEY_SIZE=4096
STAGING=0 # Set to 1 for testing to avoid rate limits

echo "### Creating directories ..."
mkdir -p "$DATA_PATH/conf/live/$DOMAIN_NAME"
mkdir -p "$DATA_PATH/www"

echo "### Downloading recommended TLS parameters ..."
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
  > "$DATA_PATH/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
  > "$DATA_PATH/conf/ssl-dhparams.pem"

echo "### Creating dummy certificate for $DOMAIN_NAME ..."
openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
  -keyout "$DATA_PATH/conf/live/$DOMAIN_NAME/privkey.pem" \
  -out "$DATA_PATH/conf/live/$DOMAIN_NAME/fullchain.pem" \
  -subj "/CN=localhost"

echo "### Starting nginx ..."
docker compose up -d nginx

echo "### Removing dummy certificate ..."
rm -rf "$DATA_PATH/conf/live/$DOMAIN_NAME"

echo "### Requesting Let's Encrypt certificate for $DOMAIN_NAME ..."

STAGING_ARG=""
if [ $STAGING -eq 1 ]; then
  STAGING_ARG="--staging"
fi

EMAIL_ARG="--register-unsafely-without-email"
if [ -n "$EMAIL" ]; then
  EMAIL_ARG="--email $EMAIL"
fi

docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  $STAGING_ARG \
  $EMAIL_ARG \
  -d "$DOMAIN_NAME" \
  --agree-tos \
  --no-eff-email \
  --force-renewal

echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload

echo "### Done! SSL certificate installed for $DOMAIN_NAME"
