#!/bin/sh
# Feedbacks for Railway: validate the variables, derive what upstream wants from them, create the S3 bucket and the
# owner, then exec the upstream server.
set -eu

fail() { echo "railway-entrypoint: $*" >&2; exit 1; }

[ -n "${POSTGRES_HOST:-}" ] && [ -n "${POSTGRES_USER:-}" ] && [ -n "${POSTGRES_DB:-}" ] || fail "POSTGRES_HOST, POSTGRES_USER and POSTGRES_DB are required"
[ -n "${POSTGRES_PASSWORD:-}" ] || fail "POSTGRES_PASSWORD is required"
[ -n "${ADMIN_EMAIL:-}" ] || fail "ADMIN_EMAIL is required"
P="${ADMIN_PASSWORD:-}"; [ "${#P}" -ge 12 ] || fail "ADMIN_PASSWORD is required (12 characters or more)"
[ -n "${S3_HOST:-}" ] || fail "S3_HOST is required (the public domain of the minio service)"
[ -n "${S3_ACCESS_KEY_ID:-}" ] && [ -n "${S3_SECRET_ACCESS_KEY:-}" ] || fail "S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY are required"
[ -n "${PUBLIC_DOMAIN:-}" ] || fail "PUBLIC_DOMAIN is required (this service's public domain)"

# Railway injects PORT (8080) and the edge and healthcheck dial it, so the server listens on it.
export PORT="${PORT:-8080}"
export NODE_ENV=production
export APP_ORIGIN="https://${PUBLIC_DOMAIN}"
export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/${POSTGRES_DB}"
export ASSET_DRIVER=s3
export S3_ENDPOINT="https://${S3_HOST}"
export S3_REGION="${S3_REGION:-us-east-1}"
export S3_BUCKET="${S3_BUCKET:-feedbacks}"
# Railway's X-Forwarded-For is "<client>, <edge>" and the socket peer is Railway's proxy, so two hops reach the client.
export TRUST_PROXY_HOPS="${TRUST_PROXY_HOPS:-2}"
# A stable UUID per deployment, derived from the database password so it survives redeploys and differs per deploy.
H=$(printf 'feedbacks-organization:%s' "$POSTGRES_PASSWORD" | sha256sum | cut -c1-32)
export ORGANIZATION_ID="$(printf '%s' "$H" | cut -c1-8)-$(printf '%s' "$H" | cut -c9-12)-4$(printf '%s' "$H" | cut -c14-16)-8$(printf '%s' "$H" | cut -c18-20)-$(printf '%s' "$H" | cut -c21-32)"

cd /app
node /app/railway-init.mjs wait-s3 || fail "object storage never became reachable"
node /app/railway-init.mjs bucket || fail "could not create the bucket"
if ! BOOTSTRAP_EMAIL="$ADMIN_EMAIL" BOOTSTRAP_PASSWORD="$ADMIN_PASSWORD" BOOTSTRAP_NAME="${ADMIN_NAME:-Owner}" node dist/cli/bootstrap.js; then
  echo "railway-entrypoint: owner bootstrap did not create an account (an owner exists already, or the database is not ready)" >&2
fi
exec "$@"
