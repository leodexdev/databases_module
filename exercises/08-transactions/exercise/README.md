# Session 08 exercise: lost updates, deadlocks and write skew

## Files

- `lost_update.md`: task 1 (lost update) and task 2 (two fixes), with the commands of each session in order and the observed results.
- `deadlock.md`: task 3 (deadlock), with the full error message and an explanation of each line.
- `write_skew.py`: task 4 (write skew), with 20 threads, a barrier, and two isolation levels.
- `pyproject.toml`: the uv project.

## Setup

```bash
./scripts/create-db.sh ex08 --pagila --reset
docker compose exec -T postgres psql -U postgres -d ex08 -c "ALTER TABLE customer ADD COLUMN balance numeric(10,2) NOT NULL DEFAULT 100 CHECK (balance >= 0);"
docker compose exec -T postgres psql -U postgres -d ex08 -c "INSERT INTO staff (first_name, last_name, address_id, store_id, username) SELECT 'Temp', 'Staff ' || g, 1, 1, 'temp' || g FROM generate_series(1, 14) AS g;"
uv sync
```

## Tasks 1 to 3: summary

| Task | Result |
|---|---|
| 1. Lost update | Reproduced. Both sessions read 100 before either committed, both wrote 90, final balance 90 instead of 80. |
| 2. Fix 1: atomic `UPDATE ... balance - 10` | Session B blocked on the update until A committed, then applied the change to 90. Final balance 80. |
| 2. Fix 2: `SELECT ... FOR UPDATE` | Session B blocked on the `SELECT` until A committed. Final balance 80 (see `lost_update.md`). |
| 3. Deadlock | Reproduced. PostgreSQL aborted session B with `deadlock detected`. Details in `deadlock.md`. |

## Task 4: write skew

The rule is that every store keeps at least one active staff member. Each of the 20 active members of store 1 runs one transaction: it counts the active members, waits at a barrier so that all 20 threads have counted before any of them writes, and if the count is above 1, sets its own member to inactive. Each thread uses its own connection.

### Run 1: READ COMMITTED

```bash
uv run --env-file ../../../.env python write_skew.py read-committed
```

**Output:**

```
Active staff of store 1 before the run: 20
Active staff of store 1 after the run (read-committed): 0
Active ids: []
```

Reset before the next run:

```bash
docker compose exec -T postgres psql -U postgres -d ex08 -c "UPDATE staff SET active = true WHERE store_id = 1;"
```

**Explanation:** under READ COMMITTED, each statement sees the data that was committed when the statement started. Because of the barrier, all 20 threads count before any of them commits, so each thread sees 20 active members and decides it is allowed to deactivate itself. The `UPDATE`s touch different rows (each thread updates its own member), so they do not block each other and no conflict is detected. All 20 commit, and the store is left with 0 active members, breaking the rule that at least one must stay active.

### Run 2: SERIALIZABLE

```bash
uv run --env-file ../../../.env python write_skew.py serializable
```

**Output:**

```
Active staff of store 1 before the run: 20
Threads that needed retries: 19
Active staff of store 1 after the run (serializable): 1
Active ids: [1512]
```

**Explanation:** under SERIALIZABLE, PostgreSQL tracks what each transaction read and what the others write. The 20 transactions form a dangerous pattern: each one read the count, and each one writes a row that the count depends on. PostgreSQL lets the first transaction commit and aborts the others with SQLSTATE `40001` (serialization failure). Those 19 threads retry from the start, without the barrier. On retry, each one counts again and sees only 1 active member (the first one committed), so it does not deactivate itself. The result is exactly one active member, and the rule holds.

## Why READ COMMITTED breaks the rule and SERIALIZABLE does not

READ COMMITTED only guarantees that each statement reads committed data. It does not protect a decision that is made from a read and applied in a later write, because nothing in the database connects the two. Write skew happens when two transactions read overlapping data, make decisions that are each valid on their own, and write to different rows, so no row lock is involved.

SERIALIZABLE checks the whole set of transactions, not each one alone. It detects that the outcome could not have happened in any one-at-a-time order, and it aborts one of the transactions so that the result is equivalent to running them serially. The application must retry the aborted transactions, which is why the retry loop is part of the solution.

## Result summary

- Task 4, READ COMMITTED: 0 active members (fewer than 1, rule broken).
- Task 4, SERIALIZABLE: exactly 1 active member (rule kept).