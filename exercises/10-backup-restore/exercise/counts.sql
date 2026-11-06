SELECT 'payment' AS table_name, count(*) AS rows FROM payment
UNION ALL SELECT 'film_actor', count(*) FROM film_actor
UNION ALL SELECT 'film_category', count(*) FROM film_category
UNION ALL SELECT 'payment 2026 (p2026_01..07)', count(*) FROM payment WHERE payment_date >= '2026-01-01';
