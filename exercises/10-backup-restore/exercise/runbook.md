# Runbook: recovering deleted rows of `payment`, `film_actor` and `film_category` from a backup

## When to use

Use this runbook when rows of `payment`, `film_actor` and/or `film_category` in a Pagila database were deleted by mistake (or by an incident), the database is still running, and there is a backup in custom format (`pg_dump -Fc`) made before the incident.

**Do not use it** if:
- the database is corrupted or won't start. In that case the whole database has to be restored, as in the session 10 tutorial.
- the backup was made after the incident. The backup then no longer has the deleted rows.

This procedure **does not drop or recreate the database**: it only puts back the data of the affected tables, and the rest of the database stays in use.

## Prerequisites

- The module's environment running: `docker compose ps` shows `postgres` as `healthy`.
- Access to the `backups/` folder in the repository root and to the `postgres` password (`.env` in the root).
- The most recent backup **before** the incident. To confirm the time it was made:
  ```bash
  docker compose exec -T postgres pg_restore --list < backups/<file>.dump | head -3
  # ; Archive created at 2026-10-29 14:28:32 UTC
  ```
- Knowing which rows were deleted. In this incident it was `disaster.sql`:
  - `payment` with `payment_date >= '2026-01-01'` (partitions `payment_p2026_01` to `payment_p2026_07`);
  - `film_actor` with `actor_id <= 50`;
  - `film_category` with `category_id = 1`.
- Agree with the team on a window with no writes to these tables during the restore (about 1 minute). See "Risks and precautions".

All commands run from the repository root. Throughout this document, `DUMP` is the backup file:

```bash
DUMP=backups/ex10_2026-10-29_1428.dump
```

## Procedure

### 0. How the incident was reproduced (for the exercise only)

```bash
./scripts/create-db.sh ex10 --pagila --reset

# Task 1: counts before anything
docker compose exec -T postgres psql -U postgres -d ex10 < exercises/ex10-backup-restore/counts.sql

# Task 2: backup in custom format
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres -Fc ex10 > backups/ex10_$(date -u +%F_%H%M).dump

# Task 3: normal work after the backup, and the incident
docker compose exec -T postgres psql -U postgres -d ex10 -v ON_ERROR_STOP=1 < exercises/ex10-backup-restore/activity.sql
docker compose exec -T postgres psql -U postgres -d ex10 -v ON_ERROR_STOP=1 < exercises/ex10-backup-restore/disaster.sql
docker compose exec -T postgres psql -U postgres -d ex10 < exercises/ex10-backup-restore/counts.sql
```

### 1. Record the current state

Before touching anything, record the counts and the next `payment_id` (the sequence does not go back with the restore, so it is what the RPO is measured with in step 5):

```bash
docker compose exec -T postgres psql -U postgres -d ex10 < exercises/ex10-backup-restore/counts.sql
docker compose exec -T postgres psql -U postgres -d ex10 -c "SELECT last_value FROM payment_payment_id_seq;"
```

### 2. Confirm that the backup has the data of the tables to restore

```bash
docker compose exec -T postgres pg_restore --list < $DUMP | grep "TABLE DATA" | grep -E "film_actor|film_category|payment_p2026"
```

9 lines must appear: `film_actor`, `film_category` and `payment_p2026_01` to `payment_p2026_07`.

`payment` is a partitioned table: the rows are stored in the partitions, so each partition has to be named. `-t payment` alone restores nothing.

### 3. Restore, in a single transaction

```bash
time ( {
  echo "TRUNCATE film_actor, film_category;"
  docker compose exec -T postgres pg_restore --data-only \
    -t film_actor -t film_category \
    -t payment_p2026_01 -t payment_p2026_02 -t payment_p2026_03 -t payment_p2026_04 \
    -t payment_p2026_05 -t payment_p2026_06 -t payment_p2026_07 \
    -f - < $DUMP
} | docker compose exec -T postgres psql -U postgres -d ex10 --single-transaction -v ON_ERROR_STOP=1 -q )
```

What it does:

| Part | Why |
|------|-----|
| `pg_restore --data-only -t ... -f -` | Doesn't restore anything directly: it writes the SQL with the data (`COPY ... FROM stdin`) of the 9 tables listed. `--data-only` doesn't touch the structure: tables, indexes, views and constraints stay as they are. |
| `TRUNCATE film_actor, film_category` | These two tables still have part of their rows. Reloading them on top would fail with a duplicate primary key error. They are emptied and reloaded in full from the backup. `CASCADE` is not needed, because no table has foreign keys pointing to them. |
| The 2026 partitions do **not** get a `TRUNCATE` | They are empty after the incident. This way, if someone has inserted new 2026 payments in the meantime, those are kept. If one of them has the same `payment_id` as a row in the backup, the restore fails (see "Risks and precautions"). |
| `psql --single-transaction -v ON_ERROR_STOP=1` | The `TRUNCATE` and the 9 loads run in a single transaction. If anything fails, `psql` stops and PostgreSQL rolls back **everything**, including the `TRUNCATE`. A table is never left empty halfway through the restore. |

Expected output: an empty `set_config` (from the header of the SQL generated by `pg_restore`), no `ERROR`, and exit code 0.

### 4. Verify the restore

**a) Counts** (they must equal the ones from before the incident):

```bash
docker compose exec -T postgres psql -U postgres -d ex10 < exercises/ex10-backup-restore/counts.sql
```

**b) Row-by-row comparison with the backup.** Restore the whole same dump into a separate database and compare the three tables with `EXCEPT` in both directions:

```bash
docker compose exec -T postgres dropdb -U postgres --if-exists ex10_verify
docker compose exec -T postgres createdb -U postgres ex10_verify
docker compose exec -T postgres pg_restore -U postgres -d ex10_verify --no-owner < $DUMP
docker compose exec -T postgres psql -U postgres -d ex10 -q -v ON_ERROR_STOP=1 < exercises/ex10-backup-restore/verify.sql
docker compose exec -T postgres dropdb -U postgres ex10_verify
```

Expected result: `0` and `0` on all three rows. `verify.sql` uses `postgres_fdw` to read `ex10_verify` from `ex10`, and drops what it created at the end.

**c) The rows the incident deleted are back.** They must return 1,327, 149 and 5,281 (the numbers from the incident's `DELETE`, without the 5 lost payments):

```bash
docker compose exec -T postgres psql -U postgres -d ex10 \
  -c "SELECT count(*) FROM film_actor WHERE actor_id <= 50;" \
  -c "SELECT count(*) FROM film_category WHERE category_id = 1;" \
  -c "SELECT count(*) FROM payment WHERE payment_date >= '2026-01-01';"
```

### 5. Measure what was lost (RPO)

Everything written between the backup and the incident is not in the backup, so it doesn't come back. For `payment`, the sequence shows the IDs assigned after the backup:

```bash
docker compose exec -T postgres psql -U postgres -d ex10 -c "
SELECT g AS lost_payment_id
FROM generate_series((SELECT max(payment_id) + 1 FROM payment),
                     (SELECT last_value FROM payment_payment_id_seq)) AS g;"
```

For this incident it can also be confirmed from the contents of `activity.sql`: the 5 most recent rentals were left without the 1.99 payment:

```bash
docker compose exec -T postgres psql -U postgres -d ex10 -c "
SELECT r.rental_id, r.customer_id, p.payment_id
FROM (SELECT rental_id, customer_id FROM rental ORDER BY rental_id DESC LIMIT 5) r
LEFT JOIN payment p ON p.rental_id = r.rental_id AND p.amount = 1.99 AND p.payment_date = '2026-07-30 12:00+00'
ORDER BY r.rental_id DESC;"
```

### 6. Communicate

After the restore, notify:
- **The application/platform team:** that the restore is finished and writes can continue.
- **Whoever handles payments (finance, customer support):** the list of lost payments (step 5), with customer, rental and amount, so they can be entered again from another source (receipts, payment system).
- **The incident owner:** this runbook filled in (backup time, incident time, measured RTO and RPO).

## Results of this incident

### Counts

| Table | Task 1: before | Task 3: after the incident | Task 5: after the restore |
|-------|----------------|----------------------------|---------------------------|
| `payment` | 51,061 | 45,780 | **51,061** |
| `film_actor` | 5,462 | 4,135 | **5,462** |
| `film_category` | 2,367 | 2,218 | **2,367** |
| `payment` of 2026 | 5,281 | 0 | **5,281** |

Output of `disaster.sql`:

```
BEGIN
DELETE 5286
DELETE 1327
DELETE 149
COMMIT
```

The `DELETE` on `payment` removed 5,286 rows: the 5,281 from 2026 that were in the backup and the 5 payments inserted by `activity.sql` after the backup. After the restore, the three tables have exactly the counts from task 1, and the row-by-row comparison with the backup shows 0 differences:

```
  table_name   | only_in_ex10 | only_in_backup
---------------+--------------+----------------
 payment       |            0 |              0
 film_actor    |            0 |              0
 film_category |            0 |              0
```

### Timeline

| Time (UTC) | Event |
|------------|-------|
| 14:28:32 | Backup `backups/ex10_2026-10-29_1428.dump` (4.6 MB, 0.76 s) |
| 14:28:34 | `activity.sql`: 5 new payments (IDs 102095 to 102099) |
| 14:28:34 | `disaster.sql` |

### Actual RTO (restore time)

| Step | Measured time |
|------|---------------|
| Restore (step 3) | **0.54 s** |
| Restore of the whole dump into `ex10_verify` (for verification only) | 3.2 s |

The restore itself takes less than 1 second, because it only puts back 9 tables (~13,000 rows). In practice, the RTO of a real incident is dominated by everything else: understanding what was deleted, choosing the backup and verifying. With this runbook, I estimate about **10 to 15 minutes** from the alert to the confirmation.

### Actual RPO (data lost)

```
 lost_payment_id
-----------------
          102095
          102096
          102097
          102098
          102099
(5 rows)
```

```
 rental_id | customer_id | payment_id
-----------+-------------+------------
     87559 |           3 |
     87558 |         676 |
     87557 |         484 |
     87556 |         715 |
     87555 |         250 |
(5 rows)
```

**The 5 payments from `activity.sql` were lost** (IDs 102095 to 102099, 1.99 each, for rentals 87555 to 87559). They were made after the backup and deleted by the incident, so they exist nowhere. The RPO is the interval between the backup and the incident: in this exercise, 2 seconds and 5 rows. In a real database with a daily backup, it could be a whole day of payments.

`film_actor` and `film_category` lost nothing: there were no writes to them between the backup and the incident.

## Risks and precautions

- **Writes during the restore.** The `TRUNCATE` locks `film_actor` and `film_category` until the end of the transaction, so reads and writes on those tables wait (less than 1 s here). A row inserted into `film_actor` or `film_category` **between the incident and the restore** is deleted by the `TRUNCATE`. If that may have happened, use the alternative below.
- **New 2026 payments after the incident.** They are kept, because the partitions don't get a `TRUNCATE`. But a new payment never reuses a `payment_id` from the backup (the sequence only moves forward), so there are no conflicts.
- **Alternative without `TRUNCATE`**, when there are new writes to preserve: restore the whole dump into `ex10_verify` (step 4b) and copy only the missing rows, with `postgres_fdw` and `INSERT INTO film_actor SELECT ... FROM verify.film_actor EXCEPT SELECT ... FROM film_actor`.

## What I would change in the backup strategy to lose less

1. **Continuous WAL archiving and PITR (*point-in-time recovery*).** With `archive_mode = on` and a base backup (`pg_basebackup`), it is possible to restore to the second before the incident (for example `recovery_target_time = '2026-10-29 14:28:33'`). The 5 payments from `activity.sql` would come back. The RPO goes from "since the last dump" to seconds. Tools such as pgBackRest or WAL-G take care of this.
2. **More frequent and verified dumps.** Until PITR is in place, an hourly `pg_dump` limits the loss to one hour. Each dump should be verified with an automatic restore (this session's challenge).
3. **Copies off the machine.** `backups/` is on the same disk as the database. The dumps (and the archived WAL) should also go somewhere else, for example object storage with retention and protection against deletion.
4. **Prevent the incident.** `disaster.sql` ran as the superuser. The application should use a role without bulk `DELETE` (session 09), and manual changes should follow the session 04 pattern: `SELECT count(*)` with the same `WHERE` before the `DELETE`, inside a transaction. A `DELETE` on `payment` could also be recorded in an audit table by a trigger, so the deleted rows could be recovered without a backup.