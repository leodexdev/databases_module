#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["psycopg2-binary"]
# ///
"""
Run with just:  uv run script.py

  * Dependencies are declared above, so uv installs them automatically.
  * Credentials are read from the .env file in the project root (next to this
    script): POSTGRES_USER / POSTGRES_PASSWORD. Optional: POSTGRES_HOST and
    POSTGRES_PORT (default localhost:5432). Real environment variables take
    priority over .env.

Options:
  --delete               only delete 01_challenge.json and exit
  --auto-delete SECONDS  cooldown before deleting the JSON file after the run (default 30, 0 = off)
  --no-delete            keep the JSON file after the run
"""
import argparse
import json
import multiprocessing as mp
import os
import sys
import time
from pathlib import Path

N_PROCS = 10
N_RECORDS = 1000
EXPECTED = N_PROCS * N_RECORDS
JSON_FILE = "01_challenge.json"

ROOT = Path(__file__).resolve().parent


def load_env():
    env_file = ROOT / ".env"
    if not env_file.is_file():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


load_env()

PG = dict(
    host=os.getenv("POSTGRES_HOST", "localhost"),
    port=int(os.getenv("POSTGRES_PORT", "5432")),
    user=os.getenv("POSTGRES_USER", "postgres"),
    password=os.getenv("POSTGRES_PASSWORD", "change-me-postgres"),
)
DB_NAME = "01_challenge"


def status(code, message):
    reason = {200: "OK", 500: "Internal Server Error"}.get(code, "")
    print(f"  [{code} {reason}] {message}")


def delete_json():
    try:
        path = Path(JSON_FILE)
        if path.exists():
            path.unlink()
            status(200, f"Deleted {JSON_FILE}")
        else:
            status(200, f"{JSON_FILE} does not exist, nothing to delete")
        return True
    except OSError as e:
        status(500, f"Could not delete {JSON_FILE}: {e}")
        return False


def cooldown_then_delete(seconds):
    print(f"\nCooldown: deleting {JSON_FILE} in {seconds}s (Ctrl+C to cancel)")
    try:
        for remaining in range(seconds, 0, -1):
            print(f"\r  {remaining:>3}s left ", end="", flush=True)
            time.sleep(1)
        print("\r  0s left      ")
    except KeyboardInterrupt:
        print("\n  Cancelled, file kept.")
        return
    delete_json()


#JSON
def json_worker(worker_id, barrier):
    barrier.wait()  # all processes start at the same moment
    for i in range(N_RECORDS):
        try:
            with open(JSON_FILE) as f:
                data = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            data = []  # file was caught mid-write by another process
        data.append({"worker": worker_id, "n": i})
        with open(JSON_FILE, "w") as f:
            json.dump(data, f)


def run_json_test():
    print("\n=== Part 1: JSON file (read -> append -> write back, no lock) ===")
    with open(JSON_FILE, "w") as f:
        json.dump([], f)
    status(200, f"Created {JSON_FILE} (empty list)")

    barrier = mp.Barrier(N_PROCS)
    procs = [mp.Process(target=json_worker, args=(w, barrier)) for w in range(N_PROCS)]
    t0 = time.time()
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    elapsed = time.time() - t0

    try:
        with open(JSON_FILE) as f:
            count = len(json.load(f))
        status(200, f"Read {JSON_FILE} back successfully ({elapsed:.1f}s)")
    except json.JSONDecodeError:
        count = 0
        status(500, f"{JSON_FILE} is corrupted (invalid JSON) after the race")

    print(f"  Expected: {EXPECTED:,} records | Found: {count:,} | "
          f"Lost: {EXPECTED - count:,} ({(EXPECTED - count) / EXPECTED:.1%})")
    return count


#POSTGRE
def setup_database():
    import psycopg2
    from psycopg2 import sql

    admin = psycopg2.connect(dbname="postgres", **PG)
    admin.autocommit = True
    with admin.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
        if cur.fetchone():
            status(200, f"Database '{DB_NAME}' already exists")
        else:
            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(DB_NAME)))
            status(200, f"Database '{DB_NAME}' created")
    admin.close()

    conn = psycopg2.connect(dbname=DB_NAME, **PG)
    with conn, conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS records")
        cur.execute("""
            CREATE TABLE records (
                id      BIGSERIAL PRIMARY KEY,
                worker  INT NOT NULL,
                n       INT NOT NULL
            )
        """)
    conn.close()
    status(200, "Table 'records' created")


def db_worker(worker_id, barrier):
    import psycopg2
    conn = psycopg2.connect(dbname=DB_NAME, **PG)
    conn.autocommit = True  # one commit per record, like one file write per record
    cur = conn.cursor()
    barrier.wait()
    for i in range(N_RECORDS):
        cur.execute("INSERT INTO records (worker, n) VALUES (%s, %s)", (worker_id, i))
    conn.close()


def run_db_test():
    print("\n=== Part 2: PostgreSQL (10 concurrent connections) ===")
    try:
        import psycopg2
    except ImportError:
        status(500, "psycopg2 not installed -> run: pip install psycopg2-binary")
        return None

    try:
        setup_database()
    except Exception as e:
        status(500, f"Could not connect/set up PostgreSQL at "
                    f"{PG['host']}:{PG['port']}: {e}".strip())
        return None

    barrier = mp.Barrier(N_PROCS)
    procs = [mp.Process(target=db_worker, args=(w, barrier)) for w in range(N_PROCS)]
    t0 = time.time()
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    elapsed = time.time() - t0

    if any(p.exitcode != 0 for p in procs):
        status(500, "One or more worker connections failed")
        return None
    status(200, f"All {N_PROCS} connections finished inserting ({elapsed:.1f}s)")

    conn = psycopg2.connect(dbname=DB_NAME, **PG)
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM records")
        count = cur.fetchone()[0]
        cur.execute("SELECT worker, count(*) FROM records GROUP BY worker ORDER BY worker")
        per_worker = cur.fetchall()
    conn.close()
    status(200, "SELECT count(*) executed")
    print(f"  Expected: {EXPECTED:,} records | Found: {count:,} | Lost: {EXPECTED - count:,}")
    print("  Per worker:", ", ".join(f"w{w}={c}" for w, c in per_worker))
    return count


# --------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="JSON vs PostgreSQL race demo")
    parser.add_argument("--delete", action="store_true",
                        help="only delete the JSON file and exit")
    parser.add_argument("--auto-delete", type=int, default=30, metavar="SECONDS",
                        help="after the run, wait SECONDS (default 30, 0 = off) then delete the JSON file")
    parser.add_argument("--no-delete", action="store_true",
                        help="keep the JSON file after the run")
    args = parser.parse_args()

    if args.delete:
        sys.exit(0 if delete_json() else 1)

    print(f"Race demo: {N_PROCS} processes x {N_RECORDS:,} records = {EXPECTED:,} expected")
    json_count = run_json_test()
    db_count = run_db_test()

    print("\n=== Comparison ===")
    print(f"  {'Storage':<14}{'Expected':>10}{'Found':>10}{'Lost':>10}")
    print(f"  {'JSON file':<14}{EXPECTED:>10,}{json_count:>10,}{EXPECTED - json_count:>10,}")
    if db_count is not None:
        print(f"  {'PostgreSQL':<14}{EXPECTED:>10,}{db_count:>10,}{EXPECTED - db_count:>10,}")
    else:
        print(f"  {'PostgreSQL':<14}{'(not run - see errors above)':>30}")

    if not args.no_delete and args.auto_delete > 0:
        cooldown_then_delete(args.auto_delete)
    sys.exit(0 if (db_count == EXPECTED) else 1)


if __name__ == "__main__":
    main()