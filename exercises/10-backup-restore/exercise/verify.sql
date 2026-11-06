CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER verify_srv FOREIGN DATA WRAPPER postgres_fdw OPTIONS (dbname 'ex10_verify');
CREATE USER MAPPING FOR CURRENT_USER SERVER verify_srv OPTIONS (user 'postgres');
CREATE SCHEMA verify;
IMPORT FOREIGN SCHEMA public LIMIT TO (payment, film_actor, film_category) FROM SERVER verify_srv INTO verify;

SELECT 'payment' AS table_name,
       (SELECT count(*) FROM (SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date FROM payment
                              EXCEPT SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date FROM verify.payment) d) AS only_in_ex10,
       (SELECT count(*) FROM (SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date FROM verify.payment
                              EXCEPT SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date FROM payment) d) AS only_in_backup
UNION ALL
SELECT 'film_actor',
       (SELECT count(*) FROM (SELECT actor_id, film_id FROM film_actor EXCEPT SELECT actor_id, film_id FROM verify.film_actor) d),
       (SELECT count(*) FROM (SELECT actor_id, film_id FROM verify.film_actor EXCEPT SELECT actor_id, film_id FROM film_actor) d)
UNION ALL
SELECT 'film_category',
       (SELECT count(*) FROM (SELECT film_id, category_id FROM film_category EXCEPT SELECT film_id, category_id FROM verify.film_category) d),
       (SELECT count(*) FROM (SELECT film_id, category_id FROM verify.film_category EXCEPT SELECT film_id, category_id FROM film_category) d);

DROP SCHEMA verify CASCADE;
DROP USER MAPPING FOR CURRENT_USER SERVER verify_srv;
DROP SERVER verify_srv;
DROP EXTENSION postgres_fdw;
