#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["psycopg2-binary"]
# ///

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
CHALLENGE_REL = Path("exercises/01-database-engines/challenge")
 
 
def find_root():
    """Project root = first directory (walking up from the script and from the
    current directory) that contains exercises/01-database-engines/challenge.
    Works the same whether run from the root or from the challenge folder."""
    script_dir = Path(__file__).resolve().parent
    for start in (script_dir, Path.cwd().resolve()):
        for p in (start, *start.parents):
            if (p / CHALLENGE_REL).is_dir():
                return p
    return script_dir  # fallback
 
 
ROOT = find_root()
CHALLENGE_DIR = ROOT / CHALLENGE_REL
JSON_FILE = CHALLENGE_DIR / "01_challenge.json"

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


def wait_for_turn(worker_id, barrier, turns):
    """Concurrent: wait at the barrier, then everyone goes together.
    Sequential: wait until the worker before us says we can go."""
    if turns:
        turns[worker_id].wait()
    else:
        barrier.wait()


def pass_turn(worker_id, turns):
    """Sequential only: tell the next worker it can start."""
    if turns:
        turns[worker_id + 1].set()


def run_workers(target, sequential):
    """Run N_PROCS workers. All 10 processes are started at the same time.
    Concurrent: a barrier makes them all write together.
    Sequential: they queue up. Worker 0 goes first, and when it finishes
    all its records it lets worker 1 go, and so on."""
    barrier = mp.Barrier(N_PROCS)
    # turns[w] is set when it is worker w's turn (one extra at the end, never used)
    turns = [mp.Event() for _ in range(N_PROCS + 1)] if sequential else None
    procs = [mp.Process(target=target, args=(w, barrier, turns)) for w in range(N_PROCS)]
    t0 = time.time()
    for p in procs:
        p.start()
    if sequential:
        turns[0].set()  # let the first worker go
    for p in procs:
        p.join()
    return procs, time.time() - t0


#JSON
def json_worker(worker_id, barrier, turns):
    wait_for_turn(worker_id, barrier, turns)
    try:
        for i in range(N_RECORDS):
            try:
                with open(JSON_FILE) as f:
                    data = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                data = []  # file was caught mid-write by another process
            data.append({"worker": worker_id, "n": i})
            with open(JSON_FILE, "w") as f:
                json.dump(data, f)
    finally:
        pass_turn(worker_id, turns)  # even if this worker crashes, don't block the queue


def run_json_test(sequential=False):
    mode = "one process at a time" if sequential else "concurrent, no lock"
    print(f"\n=== Part 1: JSON file (read -> append -> write back, {mode}) ===")
    with open(JSON_FILE, "w") as f:
        json.dump([], f)
    status(200, f"Created {JSON_FILE} (empty list)")

    _, elapsed = run_workers(json_worker, sequential)

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


def db_worker(worker_id, barrier, turns):
    import psycopg2
    conn = psycopg2.connect(dbname=DB_NAME, **PG)
    conn.autocommit = True  # one commit per record, like one file write per record
    cur = conn.cursor()
    wait_for_turn(worker_id, barrier, turns)
    try:
        for i in range(N_RECORDS):
            cur.execute("INSERT INTO records (worker, n) VALUES (%s, %s)", (worker_id, i))
    finally:
        conn.close()
        pass_turn(worker_id, turns)


def run_db_test(sequential=False):
    mode = "one connection at a time" if sequential else f"{N_PROCS} concurrent connections"
    print(f"\n=== Part 2: PostgreSQL ({mode}) ===")
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

    procs, elapsed = run_workers(db_worker, sequential)

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
    parser.add_argument("--sequential", action="store_true",
                        help="run the workers one at a time instead of concurrently")
    args = parser.parse_args()

    if args.delete:
        sys.exit(0 if delete_json() else 1)

    how = "sequentially (1 at a time)" if args.sequential else "concurrently"
    print(f"Race demo: {N_PROCS} processes x {N_RECORDS:,} records = {EXPECTED:,} expected, run {how}")
    json_count = run_json_test(args.sequential)
    db_count = run_db_test(args.sequential)

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