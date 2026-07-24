#!/usr/bin/env bash

set -euo pipefail

source .env.ops

# Expect a flavor argument (e.g. dev, local, production)
FLAVOR="${1:-}"
if [ -z "$FLAVOR" ]; then
	echo "Usage: $0 <flavor>  # e.g. dev, local, production"
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_ROOT"

echo "Creating ERPNext backup..."

docker compose -p "$PROJECT_NAME" exec -T backend \
bench --site "$SITE_NAME" backup --with-files

echo "Finding newest backup files..."

BACKUP_PATH=$(docker compose -p "$PROJECT_NAME" exec -T backend \
bash -c "ls -dt sites/$SITE_NAME/private/backups/* | head -1" \
| tr -d '\r')

echo "Exporting backup files..."

docker compose -p "$PROJECT_NAME" cp \
backend:/home/frappe/frappe-bench/sites/$SITE_NAME/private/backups \
"$BACKUP_ROOT/$TIMESTAMP"

echo "Exporting site_config.json..."

docker compose -p "$PROJECT_NAME" cp \
backend:/home/frappe/frappe-bench/sites/$SITE_NAME/site_config.json \
"$BACKUP_ROOT/$TIMESTAMP/site_config.json"

# echo "Uploading to cloud..."

# rclone sync \
# "$BACKUP_ROOT/$TIMESTAMP" \
# "$RCLONE_REMOTE:$RCLONE_PATH/$TIMESTAMP"

echo "Cleaning local backups older than $BACKUP_RETENTION_DAYS days..."

find "$BACKUP_ROOT" \
-type d \
-mtime +"$BACKUP_RETENTION_DAYS" \
-exec rm -rf {} +

echo "Backup completed."