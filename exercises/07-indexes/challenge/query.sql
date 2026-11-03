CREATE INDEX big_rental_page ON big_rental (rented_at DESC, id DESC);

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, rented_at, customer_id FROM big_rental
ORDER BY rented_at DESC, id DESC OFFSET 99980 LIMIT 20;

SELECT rented_at AS last_rented_at, id AS last_id
FROM big_rental ORDER BY rented_at DESC, id DESC OFFSET 99979 LIMIT 1 \gset

\echo last_rented_at = :'last_rented_at', last_id = :last_id

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;

WITH by_offset AS (
    SELECT id, rented_at, customer_id FROM big_rental
    ORDER BY rented_at DESC, id DESC OFFSET 99980 LIMIT 20
),
by_keyset AS (
    SELECT id, rented_at, customer_id FROM big_rental
    WHERE (rented_at, id) < (:'last_rented_at', :last_id)
    ORDER BY rented_at DESC, id DESC LIMIT 20
)
SELECT (SELECT count(*) FROM by_offset) AS offset_rows,
       (SELECT count(*) FROM by_keyset) AS keyset_rows,
       (SELECT count(*) FROM (SELECT * FROM by_offset EXCEPT SELECT * FROM by_keyset) d) AS only_in_offset,
       (SELECT count(*) FROM (SELECT * FROM by_keyset EXCEPT SELECT * FROM by_offset) d) AS only_in_keyset;

SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;

EXPLAIN (ANALYZE)
SELECT id, rented_at, customer_id FROM big_rental
ORDER BY rented_at DESC, id DESC OFFSET 999980 LIMIT 20;

SELECT rented_at AS last_rented_at, id AS last_id
FROM big_rental ORDER BY rented_at DESC, id DESC OFFSET 999979 LIMIT 1 \gset

EXPLAIN (ANALYZE)
SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;

SELECT rented_at AS last_rented_at, id AS last_id
FROM big_rental ORDER BY rented_at DESC, id DESC OFFSET 99979 LIMIT 1 \gset

DROP INDEX big_rental_page;
CREATE INDEX big_rental_page ON big_rental (rented_at DESC, id DESC) INCLUDE (customer_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;

UPDATE big_rental SET customer_id = customer_id WHERE id % 50 = 0;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;

VACUUM big_rental;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, rented_at, customer_id FROM big_rental
WHERE (rented_at, id) < (:'last_rented_at', :last_id)
ORDER BY rented_at DESC, id DESC LIMIT 20;