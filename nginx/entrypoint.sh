#!/bin/sh
# Periodic reload to pick up renewed SSL certs
(while :; do sleep 6h; nginx -s reload 2>/dev/null; done) &
# Run original entrypoint (processes templates, then starts nginx)
exec /docker-entrypoint.sh "$@"
