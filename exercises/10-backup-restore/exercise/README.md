# Exercise 10: Backup, incident and restore

| File | Contents |
|------|----------|
| [`runbook.md`](runbook.md) | **The main deliverable.** When to use it, prerequisites, all commands in order, the counts for tasks 1, 3 and 5, measured RTO and RPO, verification, and improvements to the backup strategy. |
| `activity.sql` | The normal work after the backup (same as in the assignment) |
| `disaster.sql` | The incident (same as in the assignment) |
| `counts.sql` | Counts of `payment`, `film_actor`, `film_category` and of the 2026 payments |
| `verify.sql` | Row-by-row comparison of the three tables against a copy restored from the backup |

The commands, in order and starting from the repository root, are in the "Procedure" section of the runbook.

Backups go to `backups/` in the repository root, which is in `.gitignore` (as is `*.dump`), so they are not committed.

## Summary

| Table | Before | After the incident | After the restore |
|-------|--------|--------------------|-------------------|
| `payment` | 51,061 | 45,780 | 51,061 |
| `film_actor` | 5,462 | 4,135 | 5,462 |
| `film_category` | 2,367 | 2,218 | 2,367 |

- **Restore:** without dropping the database, in a single transaction (`TRUNCATE` of the two partially affected tables and reload, plus the 7 partitions of 2026). It took **0.54 s**.
- **Verification:** 0 row-by-row differences in the three tables, compared with the backup.
- **Lost (RPO):** the **5 payments from `activity.sql`** (IDs 102095 to 102099), made after the backup.