# JSON vs PostgreSQL: concurrent writes

10 processes each add 1,000 records (10,000 expected) to a JSON file and to a PostgreSQL table, then the script compares how many survived.

## Run

1. Start PostgreSQL:

   ```bash
   docker compose up -d postgres
   ```

2. Add your credentials to `.env` in the project root:

   ```
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=your-password
   ```

3. Run the script (needs [uv](https://docs.astral.sh/uv/)):

   ```bash
   uv run script.py
   ```

The script creates the `race_demo` database and `records` table itself. After the run it deletes `01_challenge.json` following a 30 second cooldown.

## Options

```bash
uv run script.py --auto-delete 60   # different cooldown (0 = off)
uv run script.py --no-delete        # keep the JSON file
uv run script.py --delete           # only delete the JSON file
```

## Result

| Storage | Expected | Found |
|---|---|---|
| JSON file | 10,000 | ~60 |
| PostgreSQL | 10,000 | 10,000 |

The JSON file loses records because every process reads the whole file and writes it back, so they overwrite each other. PostgreSQL handles each insert as an atomic transaction, so nothing is lost.