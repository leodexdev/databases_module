import json
import os
from multiprocessing import Pool

import psycopg2
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())

JSON_FILE = os.path.join(os.path.dirname(__file__), "challenge1.json")
DSN = os.environ.get("DATABASE_URL", "dbname=postgres")
N_PROCESSES = 10
N_RECORDS = 1000


# ---------- JSON file ----------

# create the file with an empty list (or empty it, if it already exists)
def create_file():
    with open(JSON_FILE, "w") as file:
        json.dump([], file)


def process_work(process_id):
    for number in range(N_RECORDS):
        try:
            with open(JSON_FILE) as file:
                data = json.load(file)
        except json.JSONDecodeError:
            continue
        data.append({"process": process_id, "number": number})
        with open(JSON_FILE, "w") as file:
            json.dump(data, file)


def count_json():
    try:
        with open(JSON_FILE) as file:
            return len(json.load(file))
    except json.JSONDecodeError:
        return 0


# ---------- PostgreSQL ----------

def create_table():
    connection = psycopg2.connect(DSN)
    cursor = connection.cursor()
    cursor.execute("create table if not exists records (id serial primary key, process int, number int)")
    cursor.execute("truncate records restart identity")
    connection.commit()
    connection.close()


def process_work_db(process_id):
    connection = psycopg2.connect(DSN)
    cursor = connection.cursor()
    for number in range(N_RECORDS):
        cursor.execute("insert into records (process, number) values (%s, %s)", (process_id, number))
        connection.commit()
    connection.close()


def count_db():
    connection = psycopg2.connect(DSN)
    cursor = connection.cursor()
    cursor.execute("select count(*) from records")
    total = cursor.fetchone()[0]
    connection.close()
    return total


if __name__ == "__main__":
    expected = N_PROCESSES * N_RECORDS

    create_file()
    with Pool(N_PROCESSES) as pool:
        pool.map(process_work, range(N_PROCESSES))
    print(f"json file:  {count_json()} / {expected}")

    create_table()
    with Pool(N_PROCESSES) as pool:
        pool.map(process_work_db, range(N_PROCESSES))
    print(f"postgresql: {count_db()} / {expected}")