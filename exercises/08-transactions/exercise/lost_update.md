# Task 1 and 2: lost update, and the two fixes

Setup, once in `ex08`:

```sql
ALTER TABLE customer ADD COLUMN balance numeric(10,2) NOT NULL DEFAULT 100 CHECK (balance >= 0);
```

Two `psql` sessions, `A` and `B`, both connected to `ex08`:

```bash
docker compose exec -it postgres psql -U postgres -d ex08
```

## Task 1: lost update

Each session withdraws 10 from customer 1 by reading the balance, then writing the value it computed. The steps are interleaved so that both read before either writes.

| Step | Session A | Session B | Result |
|---|---|---|---|
| 1 | `SELECT balance FROM customer WHERE customer_id = 1;` | | returns 100 |
| 2 | | `SELECT balance FROM customer WHERE customer_id = 1;` | returns 100 |
| 3 | `UPDATE customer SET balance = 100 - 10 WHERE customer_id = 1;` | | `UPDATE 1` |
| 4 | | `UPDATE customer SET balance = 100 - 10 WHERE customer_id = 1;` | `UPDATE 1` |
| 5 | `SELECT balance FROM customer WHERE customer_id = 1;` | | **returns 90** (expected 80) |

Reset:

```sql
UPDATE customer SET balance = 100 WHERE customer_id = 1;
```

**Result (paste the output of step 5):**

```
Observed: session A returned `90.00` at the end. Session B had read `100.00` before A committed (B's read happened before A's write). Both wrote `90`, so the final balance is `90.00` instead of `80.00`. Reproduction confirmed.
```

**Explanation:** both sessions read 100 before either wrote, so each one computed 90 from the same old value. The second write overwrote the first, and the first withdrawal disappeared. The final balance is 90, although two withdrawals of 10 should leave 80.

## Task 2, fix 1: atomic update

Both sessions run the same single statement, with no separate read:

| Step | Session A | Session B | Result |
|---|---|---|---|
| 1 | `UPDATE customer SET balance = balance - 10 WHERE customer_id = 1 AND balance >= 10;` | | `UPDATE 1` |
| 2 | | `UPDATE customer SET balance = balance - 10 WHERE customer_id = 1 AND balance >= 10;` | `UPDATE 1` |
| 3 | `SELECT balance FROM customer WHERE customer_id = 1;` | | **returns 80** |

The arithmetic is done by the database on the current row, so the second update sees the first update's result. The `AND balance >= 10` also stops a withdrawal from making the balance negative.

Reset: `UPDATE customer SET balance = 100 WHERE customer_id = 1;`

**Result (paste the output of step 3):**

```
Observed: session B was blocked on the `UPDATE` until A committed. Then B applied `balance - 10` to the already updated value (90), and the final balance is `80.00`. Confirmed.
```

## Task 2, fix 2: SELECT ... FOR UPDATE

Each session reads the row with a lock, inside a transaction, before computing the new value:

| Step | Session A | Session B | Result |
|---|---|---|---|
| 1 | `BEGIN;` | | |
| 2 | `SELECT balance FROM customer WHERE customer_id = 1 FOR UPDATE;` | | returns 100, A holds the lock |
| 3 | | `BEGIN;` | |
| 4 | | `SELECT balance FROM customer WHERE customer_id = 1 FOR UPDATE;` | **waits** (blocked by A) |
| 5 | `UPDATE customer SET balance = 100 - 10 WHERE customer_id = 1;` | | `UPDATE 1` |
| 6 | `COMMIT;` | | |
| 7 | | *(the SELECT of step 4 returns)* | **returns 90** |
| 8 | | `UPDATE customer SET balance = 90 - 10 WHERE customer_id = 1;` | `UPDATE 1` |
| 9 | | `COMMIT;` | |
| 10 | `SELECT balance FROM customer WHERE customer_id = 1;` | | **returns 80** |

Session B cannot read the balance until A has committed, and then it reads the new value, 90, not the old 100. So it computes from the current balance.

Reset: `UPDATE customer SET balance = 100 WHERE customer_id = 1;`

**Result (paste the output of step 10, and the step where B waited):**

```
Observed: session B was blocked on `SELECT ... FOR UPDATE` until A committed (confirmed). The value B read after A's `COMMIT` and the final balance (expected `90.00` and `80.00`) are not yet recorded in writing: to be completed.
```

**Explanation:** `FOR UPDATE` locks the row when it is read, so the second session waits for the first one to finish. The read and the write are protected by the same lock.