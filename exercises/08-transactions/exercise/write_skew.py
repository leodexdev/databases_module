import os
import sys
import threading

import psycopg
from psycopg import errors

DBNAME = os.getenv("EX08_DB", "ex08")
MODE = sys.argv[1] if len(sys.argv) > 1 else "read-committed"


def dsn() -> str:
    return (
        f"host={os.getenv('POSTGRES_HOST', '127.0.0.1')} "
        f"port={os.getenv('POSTGRES_PORT', '5432')} "
        f"dbname={DBNAME} "
        f"user={os.getenv('POSTGRES_USER', 'postgres')} "
        f"password={os.getenv('POSTGRES_PASSWORD', '')}"
    )


def active_ids() -> list[int]:
    with psycopg.connect(dsn()) as conn:
        return [r[0] for r in conn.execute(
            "SELECT staff_id FROM staff WHERE store_id = 1 AND active ORDER BY staff_id"
        )]


def count_active(conn) -> int:
    return conn.execute("SELECT count(*) FROM staff WHERE store_id = 1 AND active").fetchone()[0]


def read_committed_worker(staff_id: int, barrier: threading.Barrier) -> None:
    with psycopg.connect(dsn()) as conn:              
        count = count_active(conn)
        barrier.wait()                                
        if count > 1:
            conn.execute("UPDATE staff SET active = false WHERE staff_id = %s", (staff_id,))


def serializable_worker(staff_id: int, barrier: threading.Barrier | None) -> int:
    attempts = 0
    while True:
        attempts += 1
        try:
            with psycopg.connect(dsn()) as conn:
                conn.execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
                count = count_active(conn)
                if barrier is not None and attempts == 1:
                    barrier.wait(timeout=120)         
                if count > 1:
                    conn.execute("UPDATE staff SET active = false WHERE staff_id = %s", (staff_id,))
            return attempts                           
        except errors.SerializationFailure:           
            continue                                  


def main() -> None:
    ids = active_ids()
    print(f"Active staff of store 1 before the run: {len(ids)}")
    if MODE == "read-committed":
        barrier = threading.Barrier(len(ids))
        threads = [threading.Thread(target=read_committed_worker, args=(sid, barrier)) for sid in ids]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
    elif MODE == "serializable":
        barrier = threading.Barrier(len(ids))
        results = {}

        def run(sid):
            results[sid] = serializable_worker(sid, barrier)

        threads = [threading.Thread(target=run, args=(sid,)) for sid in ids]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        retried = {sid: n for sid, n in results.items() if n > 1}
        print(f"Threads that needed retries: {len(retried)}")
    else:
        sys.exit("Usage: write_skew.py [read-committed|serializable]")

    final = active_ids()
    print(f"Active staff of store 1 after the run ({MODE}): {len(final)}")
    print(f"Active ids: {final}")


if __name__ == "__main__":
    main()