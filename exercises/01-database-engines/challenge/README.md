# Challenge 1: JSON vs PostgreSQL with concurrent writes

10 processes each add 1,000 records at the same time, once to a JSON file and once to a PostgreSQL table. We expect 10,000 records in each. The script counts how many survive.

## Run

You need Docker and [uv](https://docs.astral.sh/uv/).

1. Start PostgreSQL:

```bash
docker compose up -d postgres
```

2. Create a `.env` file in the project root:

```
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-password
```

3. Run the script:

```bash
uv run script.py
```

The script creates the `race_demo` database and the `records` table by itself. When it finishes, it waits 30 seconds and then deletes `01_challenge.json`.

To stop PostgreSQL when you are done:

```bash
docker compose down
```

## Options

```bash
uv run script.py --auto-delete 60   # change the wait before deleting (0 = never)
uv run script.py --no-delete        # keep the JSON file
uv run script.py --delete           # only delete the JSON file
uv run script.py --sequential       # run the processes one by one
```

## Result

| Storage | Expected | Found |
|---|---|---|
| JSON file | 10,000 | about 60 (changes on every run) |
| PostgreSQL | 10,000 | 10,000 |

## Why

- **JSON file:** each process reads the whole file, adds its record and writes the whole file back. Two processes can read the same version, so the one that writes last overwrites the other's record.
- **PostgreSQL:** each insert is a transaction, so the database handles the concurrent writes and no record is lost.
- **Sequential mode:** with `--sequential` there is no overlap, so the JSON file should keep all records too.