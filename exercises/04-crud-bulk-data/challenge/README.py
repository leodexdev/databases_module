# Challenge: seed 1,000,000 rentals

`seed.py` inserts 1,000,000 fake rentals into the `rental` table of a Pagila database. `script.sh` recreates two databases (`ch04_a` and `ch04_b`) and seeds both, so you get two identical copies to compare.


## Requirements

- The Postgres container running

The Python packages (`psycopg[binary]` and `faker`) are installed automatically by `uv run`, so there is nothing to install by hand.

## How to run

From the repo root:

```
./script/load-pagila.sh
./exercises/04-crud-bulk-data/challenge/script.sh
```

Or from inside the `challenge` folder:

```
./script.sh
```

For each of `ch04_a` and `ch04_b`, the script does the following:

1. Finds the nearest `.env`. If there is none, it copies the nearest `.env.example` to `.env` next to it. If your Postgres uses different passwords from the example, edit the `.env` before the first run.
2. Runs `./scripts/create-db.sh <db> --pagila --reset` from the repo root, which drops and recreates the database with Pagila loaded.
3. Runs `uv run --with "psycopg[binary]" --with faker seed.py <db>`. Before that, `script.sh` loads the `.env` and builds `DATABASE_URL` from it.

## What gets generated

- Rental IDs `100001` to `1100000`.
- Rental dates spread randomly from 2022-01-01 to 2026-07-31.
- Random existing inventory items, customers and staff members.
- About 2% of rentals are never returned (`return_date` is empty). The rest are returned up to 10 days later.
- No two rentals share the same `(rental_date, inventory_id, customer_id)`, so the unique index is respected.
- The random seed is fixed (`42`) and the lists are sorted, so both databases get exactly the same data.
- Everything is loaded in one transaction: either all rows go in, or none do. Afterwards the `rental_rental_id_seq` sequence is moved to `1100000`, so the next insert without an ID gets `1100001`.

## Troubleshooting

- **`KeyError: 'DATABASE_URL'`:** `seed.py` was run on its own without the variable. Run it through `script.sh`, or export `DATABASE_URL` first.
- **Connection refused, or host name not found:** set `PGHOST` in the `.env` to the name of your Postgres service.
- **`only N of the 1000000 rentals exist`:** an earlier run was interrupted. Recreate the database with `./scripts/create-db.sh <db> --pagila --reset` from the repo root.
- **Password errors during the create step:** `create-db.sh` may read its settings from a `.env` in the repo root. Copy the `.env` there.