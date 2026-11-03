#!/usr/bin/env bash
# Seeds the rental table in both databases (ch04_a and ch04_b).
# Usage: bash script.sh
set -euo pipefail

cd "$(dirname "$0")"

# Finds a file by name in this folder or the nearest parent folder (same lookup as seed.py).
find_up() {
    local dir
    dir="$(pwd)"
    while true; do
        if [ -f "$dir/$1" ]; then
            echo "$dir/$1"
            return 0
        fi
        [ "$dir" = "/" ] && return 1
        dir="$(dirname "$dir")"
    done
}

# If there is no .env yet, create it next to the nearest .env.example.
if ! ENV_FILE="$(find_up .env)"; then
    if EXAMPLE="$(find_up .env.example)"; then
        ENV_FILE="$(dirname "$EXAMPLE")/.env"
        cp "$EXAMPLE" "$ENV_FILE"
        echo "Created $ENV_FILE from $EXAMPLE"
    else
        echo "Error: no .env and no .env.example found in this folder or any parent." >&2
        exit 1
    fi
fi
echo "Using $ENV_FILE"

# Locate scripts/create-db.sh (this folder or the nearest parent) and run it from
# the folder that contains scripts/, like ./scripts/create-db.sh.
if ! CREATE_DB="$(find_up scripts/create-db.sh)"; then
    echo "Error: scripts/create-db.sh not found in this folder or any parent." >&2
    exit 1
fi
CREATE_DB_ROOT="$(dirname "$(dirname "$CREATE_DB")")"

create_db() {
    echo "Creating $1 (running from $CREATE_DB_ROOT)"
    (cd "$CREATE_DB_ROOT" && ./scripts/create-db.sh "$1" --pagila --reset)
}

# Load the .env and build the connection URL that seed.py reads.
set -a
. "$ENV_FILE"
set +a
export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${PGHOST:-localhost}:5432"

# uv installs the requirements on the fly, no manual pip install needed.
run_seed() {
    uv run --with "psycopg[binary]" --with faker seed.py "$1"
}

for db in ch04_a ch04_b; do
    create_db "$db"
    run_seed "$db"
done

echo "Done: ch04_a and ch04_b seeded."