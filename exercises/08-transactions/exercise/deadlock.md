# Task 3: deadlock

Two `psql` sessions, `A` and `B`, both connected to `ex08`. Each transaction locks one customer and then asks for the other, so each waits for the other.

| Step | Session A | Session B | Result |
|---|---|---|---|
| 1 | `BEGIN;` | `BEGIN;` | |
| 2 | `UPDATE customer SET balance = balance - 1 WHERE customer_id = 1;` | | `UPDATE 1`, A locks customer 1 |
| 3 | | `UPDATE customer SET balance = balance - 1 WHERE customer_id = 2;` | `UPDATE 1`, B locks customer 2 |
| 4 | `UPDATE customer SET balance = balance - 1 WHERE customer_id = 2;` | | **waits** for B |
| 5 | | `UPDATE customer SET balance = balance - 1 WHERE customer_id = 1;` | **deadlock detected** (one of the sessions is aborted) |

Reset after the test, in the session that was not aborted or in a new one:

```sql
ROLLBACK;
UPDATE customer SET balance = 100 WHERE customer_id IN (1, 2);
```

**Full error message (observed in session B, at step 6):**

```
ERROR:  deadlock detected
DETAIL:  Process 38499 waits for ShareLock on transaction 11381; blocked by process 38475.
Process 38475 waits for ShareLock on transaction 11382; blocked by process 38499.
HINT:  See server log for query details.
CONTEXT:  while locking tuple (17,23) in relation "customer"
```

Session B is process 38499, session A is process 38475. The statement that was aborted is B's `UPDATE ... customer_id = 1`.

## Explanation of each line

The usual lines of the message are:

- `ERROR:  deadlock detected`: PostgreSQL found a cycle of waits and aborted one transaction, so the cycle breaks.
- `DETAIL:  Process <pid> waits for ShareLock on transaction <xid>; blocked by process <pid>.`: the first process is waiting for the other one's transaction to finish.
- `Process <pid> waits for ShareLock on transaction <xid>; blocked by process <pid>.`: the second process is waiting for the first, which closes the cycle.
- `HINT:  See server log for query details.`: the statements of both processes are written to the server log.
- `CONTEXT:` and `STATEMENT:`: the statement that was aborted.

Line by line, for this run:

- `ERROR: deadlock detected`: B was chosen as the victim. PostgreSQL aborted B's statement so that the cycle breaks, and A can continue.
- `Process 38499 waits for ShareLock on transaction 11381; blocked by process 38475.`: B (38499) is waiting for transaction 11381, which is A's transaction, because A updated customer 1 at step 3 and still holds that row.
- `Process 38475 waits for ShareLock on transaction 11382; blocked by process 38499.`: A (38475) is waiting for transaction 11382, which is B's transaction, because B updated customer 2 at step 4. This second line closes the cycle: A waits for B and B waits for A.
- `HINT: See server log for query details.`: the statements of both processes are in the PostgreSQL server log.
- `CONTEXT: while locking tuple (17,23) in relation "customer"`: the statement that failed was trying to lock the row stored at page 17, position 23 of the `customer` table, which is customer 1's row.

After the error, A's blocked `UPDATE` on customer 2 is not aborted. It continues as soon as B's transaction is rolled back, because B's locks are released. Run `ROLLBACK;` in B, then check that A's `UPDATE` finishes with `UPDATE 1` and run `COMMIT;` in A.

## How to prevent it

- **Lock in a fixed order.** If every transaction updates the lower `customer_id` first, the cycle cannot form. In this exercise, both sessions would lock customer 1 before customer 2.
- **Keep transactions short.** Less time holding locks means less time for a cycle to form.
- **Retry on deadlock.** PostgreSQL aborts only one transaction, so the application can run that transaction again.
- **Set a timeout.** `SET lock_timeout = '2s';` makes a waiting statement fail instead of waiting forever.