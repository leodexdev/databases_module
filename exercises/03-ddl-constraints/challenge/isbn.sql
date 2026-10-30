-- Challenge 03: the database rejects invalid ISBN-13 values.
-- Run on an empty database. The DROP lines make the script safe to run again.

SET client_min_messages = warning;

DROP TABLE IF EXISTS book;
DROP DOMAIN IF EXISTS isbn13;
DROP FUNCTION IF EXISTS is_valid_isbn13(text);

-- 1. The function.
-- Format: digits, with single hyphens only between digits (no hyphen at the start,
-- at the end or twice in a row). Then exactly 13 digits.
-- Check digit: first 12 digits times 1, 3, 1, 3 ... added up,
-- and the last digit must be (10 - sum % 10) % 10.
-- CASE is used so the checks run in order: the digit maths only runs on clean input.
-- Only the argument is used (no tables, no clock), so it is IMMUTABLE.
CREATE FUNCTION is_valid_isbn13(isbn text) RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT AS $func$
    SELECT CASE
        WHEN isbn !~ '^[0-9]+(-[0-9]+)*$' THEN false
        WHEN length(replace(isbn, '-', '')) <> 13 THEN false
        ELSE (
            SELECT (10 - sum(substr(replace(isbn, '-', ''), i, 1)::int
                             * CASE WHEN i % 2 = 1 THEN 1 ELSE 3 END) % 10) % 10
            FROM generate_series(1, 12) AS i
        ) = right(isbn, 1)::int
    END
$func$;

-- 2. The domain and the table.
CREATE DOMAIN isbn13 AS text CHECK (is_valid_isbn13(VALUE));

CREATE TABLE book (
    book_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    isbn    isbn13 NOT NULL UNIQUE,
    title   text NOT NULL
);

-- 3. Valid values: these 3 inserts must work.
INSERT INTO book (isbn, title) VALUES ('978-0-306-40615-7', 'Valid, with hyphens');
INSERT INTO book (isbn, title) VALUES ('9781402894626',     'Valid, no hyphens');
INSERT INTO book (isbn, title) VALUES ('978-3-16-148410-0', 'Valid, check digit 0');

-- Invalid values: these 4 inserts must fail.
-- All 4 are rejected by isbn13_check (the CHECK of the domain isbn13).

INSERT INTO book (isbn, title) VALUES ('978-0-306-40615-8', 'Wrong check digit');

INSERT INTO book (isbn, title) VALUES ('978-0-306-4061',    'Too short');

INSERT INTO book (isbn, title) VALUES ('-9780306406157',    'Leading hyphen');

INSERT INTO book (isbn, title) VALUES ('978--0306406157',   'Two hyphens in a row');

SELECT book_id, isbn, title FROM book ORDER BY book_id;