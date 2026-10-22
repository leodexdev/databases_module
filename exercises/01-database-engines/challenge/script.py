import json
import os
from multiprocessing import Pool
import psycopg2


JSON_FILE = os.path.join(os.path.dirname(__file__), "challenge1.json")
N_RECORDS = 1000

#check if the file exist, if not, will create one
def create_file():
    if not os.path.exists(JSON_FILE):
        with open(JSON_FILE, "w") as file:
            json.dump([], file)

def process_work(process_id):
    for n in range(N_RECORDS):
        try:
            with open(JSON_FILE) as file:
                data = json.load(file)
        except json.JSONDecodeError:
            continue
        data.append({"process": process_id, "number": number})

