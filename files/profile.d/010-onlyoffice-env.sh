#!/usr/bin/env bash

# Ensure runtime config directory exists (avoids getFsType ENOENT warning)
mkdir -p /app/config/runtime

export OO_DS_RABBITMQ_URL="${OO_DS_RABBITMQ_URL:-""}"

# Detect if TLS is used (rediss://)
if [[ "$REDIS_URL" == rediss://* ]]; then
  REDIS_TLS="{"rejectUnauthorized": false}"
else
  REDIS_TLS="\"\""
fi

# Remove the protocol prefix (redis:// or rediss://)
REDIS_URL_CLEAN="${REDIS_URL#redis://}"
REDIS_URL_CLEAN="${REDIS_URL_CLEAN#rediss://}"

# Split credentials (user:password) and host:port
USER_PASS="${REDIS_URL_CLEAN%@*}"    # part before the @
HOST_PORT="${REDIS_URL_CLEAN#*@}"    # part after the @

# Extract username and password
REDIS_USERNAME="${USER_PASS%%:*}"    # before the first :
REDIS_PASSWORD="${USER_PASS#*:}"     # after the first :

# If username is empty, set it explicitly to empty
[ "$REDIS_USERNAME" = "$REDIS_PASSWORD" ] && REDIS_USERNAME=""

# Extract host and port
REDIS_HOST="${HOST_PORT%%:*}"        # before the :
REDIS_PORT="${HOST_PORT#*:}"         # after the :

OO_DS_SERVICES_COAUTHORING_REDIS_HOST="${OO_DS_SERVICES_COAUTHORING_REDIS_HOST:-"${REDIS_HOST:-""}"}"
OO_DS_SERVICES_COAUTHORING_REDIS_PORT="${OO_DS_SERVICES_COAUTHORING_REDIS_PORT:-"${REDIS_PORT:-""}"}"
OO_DS_SERVICES_COAUTHORING_REDIS_USERNAME="${OO_DS_SERVICES_COAUTHORING_REDIS_USERNAME:-"${REDIS_USERNAME:-""}"}"
OO_DS_SERVICES_COAUTHORING_REDIS_PASSWORD="${OO_DS_SERVICES_COAUTHORING_REDIS_PASSWORD:-"${REDIS_PASSWORD:-""}"}"
OO_DS_SERVICES_COAUTHORING_REDIS_TLS="${REDIS_TLS}"

export OO_DS_SERVICES_COAUTHORING_REDIS_HOST
export OO_DS_SERVICES_COAUTHORING_REDIS_PORT
export OO_DS_SERVICES_COAUTHORING_REDIS_USERNAME
export OO_DS_SERVICES_COAUTHORING_REDIS_PASSWORD
export OO_DS_SERVICES_COAUTHORING_REDIS_TLS


OO_DS_SERVICES_COAUTHORING_SQL_TYPE="postgresql"

POSTGRESQL_HOST="$( echo "${POSTGRES_URL}" \
	| cut -d "@" -f2 | cut -d ":" -f1 )"

POSTGRESQL_USER="$( echo "${POSTGRES_URL}" \
	| cut -d "/" -f3 | cut -d ":" -f1 )"

POSTGRESQL_PORT="$( echo "${POSTGRES_URL}" \
	| cut -d ":" -f4 | cut -d "/" -f1 )"

POSTGRESQL_PASS="$( echo "${POSTGRES_URL}" \
	| cut -d "@" -f1 | cut -d ":" -f3 )"

POSTGRESQL_DBNAME="$( echo "${POSTGRES_URL}" \
	| cut -d "?" -f1 | cut -d "/" -f4 )"

OO_DS_SERVICES_COAUTHORING_SQL_DBHOST="${OO_DS_SERVICES_COAUTHORING_SQL_DBHOST:-"${POSTGRESQL_HOST:-""}"}"
OO_DS_SERVICES_COAUTHORING_SQL_DBPORT="${OO_DS_SERVICES_COAUTHORING_SQL_DBPORT:-"${POSTGRESQL_PORT:-""}"}"
OO_DS_SERVICES_COAUTHORING_SQL_DBUSER="${OO_DS_SERVICES_COAUTHORING_SQL_DBUSER:-"${POSTGRESQL_USER:-""}"}"
OO_DS_SERVICES_COAUTHORING_SQL_DBPASS="${OO_DS_SERVICES_COAUTHORING_SQL_DBPASS:-"${POSTGRESQL_PASS:-""}"}"
OO_DS_SERVICES_COAUTHORING_SQL_DBNAME="${OO_DS_SERVICES_COAUTHORING_SQL_DBNAME:-"${POSTGRESQL_DBNAME:-""}"}"

export OO_DS_SERVICES_COAUTHORING_SQL_DBTYPE
export OO_DS_SERVICES_COAUTHORING_SQL_DBHOST
export OO_DS_SERVICES_COAUTHORING_SQL_DBPORT
export OO_DS_SERVICES_COAUTHORING_SQL_DBUSER
export OO_DS_SERVICES_COAUTHORING_SQL_DBPASS
export OO_DS_SERVICES_COAUTHORING_SQL_DBNAME


NODE_CONFIG_DIR="/app/config"
export NODE_CONFIG_DIR

NODE_ENV="${NODE_ENV:-"production"}"
export NODE_ENV

LD_LIBRARY_PATH="/app/server/FileConverter/bin${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LD_LIBRARY_PATH


# S3 storage settings
OO_S3_STORAGE_FOLDER_NAME="${OO_S3_STORAGE_FOLDER_NAME:-"onlyoffice"}"
OO_S3_USE_PATH_STYLE="${OO_S3_USE_PATH_STYLE:-"false"}"

export OO_S3_STORAGE_FOLDER_NAME
export OO_S3_USE_PATH_STYLE

if [ -n "${OO_DS_LICENCE:-}" ]; then
	echo "${OO_DS_LICENCE}" | base64 --decode > /app/data/license.lic
fi

# Auto-calculate memory limits from cgroup (overridable via env vars)
_CGROUP_MEM_BYTES=""
if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    _CGROUP_MEM_BYTES=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
elif [ -f /sys/fs/cgroup/memory.max ] && [ "$(cat /sys/fs/cgroup/memory.max)" != "max" ]; then
    _CGROUP_MEM_BYTES=$(cat /sys/fs/cgroup/memory.max)
fi

if [ -n "$_CGROUP_MEM_BYTES" ] && [ "$_CGROUP_MEM_BYTES" -gt 0 ] 2>/dev/null; then
    _MEM_MB=$(( _CGROUP_MEM_BYTES / 1024 / 1024 ))
    # x2t gets 50% of container memory
    _X2T_MB=$(( _MEM_MB * 50 / 100 ))
    # Node.js heap gets 35% of container memory (leaves room for x2t + OS)
    _NODE_MB=$(( _MEM_MB * 35 / 100 ))

    export X2T_MEMORY_LIMIT="${_X2T_MB}MB"
    export NODE_OPTIONS="--max-old-space-size=${_NODE_MB}"

    echo "[onlyoffice-env] Container: ${_MEM_MB}MB → X2T_MEMORY_LIMIT=${X2T_MEMORY_LIMIT} NODE_OPTIONS=${NODE_OPTIONS}"
fi