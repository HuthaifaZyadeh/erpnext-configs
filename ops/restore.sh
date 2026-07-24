#!/usr/bin/env bash

set -euo pipefail

source .env.ops

# Expect a flavor argument (e.g. dev, local, production) and backup id
FLAVOR="${1:-}"
BACKUP_ID="${2:-}"

if [ -z "$FLAVOR" ] || [ -z "$BACKUP_ID" ]; then
  echo "Usage: $0 <flavor> <backup-id>  # e.g. dev 20260101_120000"
  exit 1
fi

# Look for a flavor-specific env file in a sibling folder (../<flavor>/.env)
# or a local env file named .env.<flavor>
ENV_FILE="../${FLAVOR}/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Env file for flavor '$FLAVOR' not found. Tried: $ENV_FILE or .env.${FLAVOR}"
  exit 1
fi

extract_required_env_value() {
  local key="$1"
  local value

  value="$(grep -E "^${key}=" "$ENV_FILE" | head -n 1 | cut -d= -f2- | tr -d '\r')"
  if [ -z "$value" ]; then
    echo "Required variable '$key' not found in '$ENV_FILE'" >&2
    exit 1
  fi

  printf '%s' "$value"
}

PROJECT_NAME="$(extract_required_env_value "PROJECT_NAME")"
SITE_NAME="$(extract_required_env_value "SITE_NAME")"

# Use a flavor-specific subdirectory under BACKUP_ROOT
BACKUP_ROOT="${BACKUP_ROOT%/}/$FLAVOR"

RESTORE_DIR="$BACKUP_ROOT/$BACKUP_ID"

echo "Stopping scheduler..."

docker compose -p "$PROJECT_NAME" exec -T backend \
bench --site "$SITE_NAME" disable-scheduler

DB_BACKUP=$(find "$RESTORE_DIR" -name "*database.sql.gz" | head -1)
FILES_BACKUP=$(find "$RESTORE_DIR" -name "*files.tar" | grep -v private | head -1)
PRIVATE_FILES_BACKUP=$(find "$RESTORE_DIR" -name "*private-files.tar" | head -1)

echo "Copying backups into container..."

docker compose -p "$PROJECT_NAME" cp \
"$DB_BACKUP" \
backend:/tmp/database.sql.gz

docker compose -p "$PROJECT_NAME" cp \
"$FILES_BACKUP" \
backend:/tmp/files.tar

docker compose -p "$PROJECT_NAME" cp \
"$PRIVATE_FILES_BACKUP" \
backend:/tmp/private-files.tar

echo "Restoring database..."

docker compose -p "$PROJECT_NAME" exec -T backend \
bench --site "$SITE_NAME" restore /tmp/database.sql.gz

echo "Restoring files..."

docker compose -p "$PROJECT_NAME" exec -T backend \
bash -c "
tar xf /tmp/files.tar \
-C sites/$SITE_NAME/public/files

tar xf /tmp/private-files.tar \
-C sites/$SITE_NAME/private/files
"

echo "Restoring site config..."

docker compose -p "$PROJECT_NAME" cp \
"$RESTORE_DIR/site_config.json" \
backend:/home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json

echo "Migrating..."

docker compose -p "$PROJECT_NAME" exec -T backend \
bench --site "$SITE_NAME" migrate

docker compose -p "$PROJECT_NAME" exec -T backend \
bench --site "$SITE_NAME" enable-scheduler

echo "Restore completed."