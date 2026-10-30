import psycopg2
from faker import Faker

fake = Faker()

conn = psycopg2.connect(
    dbname="{dbname}",
    user="postgres",
    password="change-me-postgres",
    host="localhost",
    port="5432"
)

cursor= conn.cursor()
total_rental = 1_000_000

query = """
    INSERT INTO rental (rental_id, date, inventory_id, costumer_id, return_date, staff_id, last_update, uuid)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
"""

try:
    for i in range(total_rental):  
        data = (
            fake.id(),
            fake.date(),
            fake.id(),
            fake.id(),
            fake.date(),
            fake.id(),
            fake.timestamp(),
            fake.id()
        )
        cursor.execute(insert_query, data)
    
    conn.commit()
    print("Fake data inserted successfully!")



def seed_rental(total_rental):
    for i in range(number):
        rental = {
            "id": fake.id(),
            "date": fake.timestamp(),
            "inventory_id": fake.foreign_key(),
            "costumer_id": fake.foreign_key(),
            "return_date": fake.timestamp({return_date} > {date}),
            "staff_id": fake.foreign_key(),
            "last_update": fake.timestamp(),
            "uuid": fake.uuid()
        }
        rental.add(rental)
    return rental