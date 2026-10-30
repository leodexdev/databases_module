-- Exercise 04: CRUD on Pagila.
-- Run on a fresh copy, top to bottom:
--   ./scripts/create-db.sh ex04 --pagila --reset
--   psql -d ex04 -v ON_ERROR_STOP=1 -f queries.sql

-- 1. PG-13 films longer than 120 minutes, sorted by title. Expected: 118 rows.
SELECT film_id, title, rating, length
FROM film
WHERE rating = 'PG-13' AND length > 120
ORDER BY title;

-- 2. Actors whose last name contains "son", in any case. Expected: 9 rows.
SELECT actor_id, first_name, last_name
FROM actor
WHERE last_name ILIKE '%son%'
ORDER BY last_name, first_name;

-- 3. Rentals not returned yet. Expected: 241 rows.
-- NULL is not a value, so "= NULL" never matches; IS NULL is needed.
SELECT rental_id, rental_date, inventory_id, customer_id
FROM rental
WHERE return_date IS NULL
ORDER BY rental_id;

-- 4. Distinct rental durations, ascending. Expected: 5 rows, 3 to 7.
SELECT DISTINCT rental_duration
FROM film
ORDER BY rental_duration;

-- 5. Third page of films, 10 per page. Expected: 10 rows,
--    AMERICAN CIRCUS to ANYTHING SAVANNAH.
-- Page 3 skips 2 pages of 10 = 20 rows. A unique tie-breaker keeps the order stable.
SELECT film_id, title
FROM film
ORDER BY title, film_id
LIMIT 10 OFFSET 20;

-- 6. Rentals in January 2026, written twice. Expected: 746 and 781.
SELECT count(*) AS with_between
FROM rental
WHERE rental_date BETWEEN '2026-01-01' AND '2026-01-31';

SELECT count(*) AS with_half_open
FROM rental
WHERE rental_date >= '2026-01-01' AND rental_date < '2026-02-01';
-- Why they differ: rental_date is a timestamp. BETWEEN includes both ends, and
-- '2026-01-31' means 2026-01-31 00:00:00, so every rental on 31 January after
-- midnight is lost (781 - 746 = 35 rentals). The half-open version
-- (>= start, < first instant of next month) is correct: it covers the whole
-- month, never overlaps the next month and works for any timestamp precision.

-- 7. Insert the actor ADA LOVELACE. Expected: 1 row, actor_id 201.
INSERT INTO actor (first_name, last_name)
VALUES ('ADA', 'LOVELACE')
RETURNING actor_id;

-- 8. Raise rental_rate by 0.50 for NC-17 films shorter than 60 minutes.
--    Expected: 21 rows in both.
BEGIN;

SELECT count(*) AS to_update
FROM film
WHERE rating = 'NC-17' AND length < 60;

UPDATE film
SET rental_rate = rental_rate + 0.50
WHERE rating = 'NC-17' AND length < 60
RETURNING film_id, title, rental_rate;

COMMIT;

-- 9. Upsert: add one award to actor 1. Run twice. Expected: awards = 2.
CREATE TABLE actor_award (
    actor_id integer PRIMARY KEY REFERENCES actor,
    awards   integer NOT NULL DEFAULT 0
);

INSERT INTO actor_award (actor_id, awards)
VALUES (1, 1)
ON CONFLICT (actor_id) DO UPDATE
SET awards = actor_award.awards + 1;

INSERT INTO actor_award (actor_id, awards)
VALUES (1, 1)
ON CONFLICT (actor_id) DO UPDATE
SET awards = actor_award.awards + 1;

SELECT actor_id, awards FROM actor_award WHERE actor_id = 1;

-- 10. Insert actor 2 with 5 awards, DO NOTHING, run twice.
--     Expected: first run INSERT 0 1, second run INSERT 0 0.
INSERT INTO actor_award (actor_id, awards)
VALUES (2, 5)
ON CONFLICT DO NOTHING;

INSERT INTO actor_award (actor_id, awards)
VALUES (2, 5)
ON CONFLICT DO NOTHING;

-- 11. Insert 3 test payments in one statement. Expected: 3 rows.
INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 1, 2, 76, 0.01, '2026-07-30 12:00+00'
FROM generate_series(1, 3)
RETURNING payment_id;

-- 12. Delete the 3 test payments. Expected: 3 rows in both.
BEGIN;

SELECT count(*) AS to_delete
FROM payment
WHERE customer_id = 1 AND staff_id = 2 AND rental_id = 76
  AND amount = 0.01 AND payment_date = '2026-07-30 12:00+00';

DELETE FROM payment
WHERE customer_id = 1 AND staff_id = 2 AND rental_id = 76
  AND amount = 0.01 AND payment_date = '2026-07-30 12:00+00'
RETURNING payment_id;

COMMIT;