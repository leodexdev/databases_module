"""Compare lost updates: unsynchronised JSON file vs. PostgreSQL table.

Usage:  DATABASE_URL=postgresql://user:pw@host/db python race.py
"""
import json
import os
import sys
import tempfile
from multiprocessing import Pool

import psycopg2

N_PROCS = 10
N_RECORDS = 1000
JSON_PATH = os.path.join(tempfile.gettempdir(), "race_records.json")
DSN = os.environ.get("DATABASE_URL", "dbname=postgres")


# ---------- JSON file: read -> append -> write back, no locking ----------
def json_worker(worker_id):
    """Returns (corrupt_reads, resets). Gives up on a file that stays unparseable."""
    corrupt = resets = 0
    for seq in range(N_RECORDS):
        data = None
        for _ in range(20):
            try:
                with open(JSON_PATH) as f:
                    data = json.load(f)
                break
            except json.JSONDecodeError:  # another writer is mid-write, or left garbage behind
                corrupt += 1
        if data is None:  # file stayed corrupt: a naive program would start over from empty
            data = []
            resets += 1
        data.append({"worker": worker_id, "seq": seq})
        with open(JSON_PATH, "w") as f:
            json.dump(data, f)
    return corrupt, resets


def run_json():
    with open(JSON_PATH, "w") as f:
        json.dump([], f)
    with Pool(N_PROCS) as pool:
        results = pool.map(json_worker, range(N_PROCS))
    corrupt = sum(r[0] for r in results)
    resets = sum(r[1] for r in results)
    try:
        with open(JSON_PATH) as f:
            n = len(json.load(f))
    except json.JSONDecodeError:
        n = 0  # final file is not even valid JSON
    return n, corrupt, resets


# ---------- PostgreSQL: one connection per process, INSERT + commit ----------
def pg_worker(worker_id):
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    for seq in range(N_RECORDS):
        cur.execute("INSERT INTO records (worker, seq) VALUES (%s, %s)", (worker_id, seq))
        conn.commit()
    conn.close()


def run_pg():
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS records")
    cur.execute("CREATE TABLE records (id serial PRIMARY KEY, worker int, seq int)")
    conn.commit()
    with Pool(N_PROCS) as pool:
        pool.map(pg_worker, range(N_PROCS))
    cur.execute("SELECT count(*) FROM records")
    n = cur.fetchone()[0]
    conn.close()
    return n


if __name__ == "__main__":
    expected = N_PROCS * N_RECORDS
    n_json, corrupt, resets = run_json()
    print(f"JSON file : {n_json:>6} / {expected} records "
          f"({expected - n_json} lost; {corrupt} unparseable reads, {resets} resets-to-empty)")
    try:
        n_pg = run_pg()
        print(f"PostgreSQL: {n_pg:>6} / {expected} records ({expected - n_pg} lost)")
    except psycopg2.Error as e:
        print(f"PostgreSQL part failed: {e}", file=sys.stderr)
        sys.exit(1)