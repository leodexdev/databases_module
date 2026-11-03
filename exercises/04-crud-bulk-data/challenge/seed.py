import os
import sys
import time
from datetime import UTC, datetime, timedelta

import psycopg
from faker import Faker

SEED = 42
FIRST_ID = 100_001
ROWS = 1_000_000
LAST_ID = FIRST_ID + ROWS - 1
START = datetime(2022, 1, 1, tzinfo=UTC)
END = datetime(2026, 7, 31, 23, 59, 59, tzinfo=UTC)
NOT_RETURNED_PCT = 2
MAX_RENTAL_SECONDS = 10 * 24 * 3600  


def ids(conn: psycopg.Connection, query: str) -> list[int]:
    return [row[0] for row in conn.execute(query)]


def generate(inventory: list[int], customers: list[int], staff: list[int], taken: set):
    Faker.seed(SEED)
    fake = Faker()
    span = int((END - START).total_seconds())

    for rental_id in range(FIRST_ID, LAST_ID + 1):
        while True:
            rental_date = START + timedelta(seconds=fake.random_int(0, span))
            inventory_id = fake.random.choice(inventory)
            customer_id = fake.random.choice(customers)
            key = (rental_date, inventory_id, customer_id)
            if key not in taken:
                taken.add(key)
                break

        if fake.boolean(chance_of_getting_true=NOT_RETURNED_PCT):
            return_date = None
        else:
            return_date = rental_date + timedelta(seconds=fake.random_int(1, MAX_RENTAL_SECONDS))

        yield rental_id, rental_date, inventory_id, customer_id, return_date, fake.random.choice(staff)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("Usage: uv run seed.py <database name>")
    dbname = sys.argv[1]

    started = time.perf_counter()
    with psycopg.connect(os.environ["DATABASE_URL"], dbname=dbname) as conn:
        existing = conn.execute(
            "SELECT count(*) FROM rental WHERE rental_id BETWEEN %s AND %s",
            (FIRST_ID, LAST_ID),
        ).fetchone()[0]
        if existing == ROWS:
            print(f"{dbname}: the {ROWS} rentals already exist, nothing to do.")
            return
        if existing:
            sys.exit(f"{dbname}: only {existing} of the {ROWS} rentals exist, recreate the database.")

        inventory = ids(conn, "SELECT inventory_id FROM inventory ORDER BY inventory_id")
        customers = ids(conn, "SELECT customer_id FROM customer ORDER BY customer_id")
        staff = ids(conn, "SELECT staff_id FROM staff ORDER BY staff_id")
        taken = set(conn.execute("SELECT rental_date, inventory_id, customer_id FROM rental"))

        with conn.cursor() as cur, cur.copy(
            "COPY rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id)"
            " FROM STDIN"
        ) as copy:
            for row in generate(inventory, customers, staff, taken):
                copy.write_row(row)

        conn.execute("SELECT setval('rental_rental_id_seq', %s)", (LAST_ID,))

    print(f"{dbname}: {ROWS} rentals inserted in {time.perf_counter() - started:.1f}s")


if __name__ == "__main__":
    main()