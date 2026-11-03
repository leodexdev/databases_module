WITH film_rentals AS (
    SELECT c.name AS category, f.title, count(*) AS rentals
    FROM rental r
    JOIN inventory i      ON i.inventory_id = r.inventory_id
    JOIN film f           ON f.film_id = i.film_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c       ON c.category_id = fc.category_id
    GROUP BY c.category_id, c.name, f.film_id, f.title
),
ranked AS (
    SELECT category, title, rentals,
           dense_rank() OVER (PARTITION BY category ORDER BY rentals DESC) AS position
    FROM film_rentals
)
SELECT category, position, title, rentals
FROM ranked
WHERE position <= 3
ORDER BY category, position, title;

SELECT day, revenue,
       sum(revenue) OVER (ORDER BY day) AS running_total
FROM (
    SELECT payment_date::date AS day, sum(amount) AS revenue
    FROM payment
    WHERE payment_date >= '2026-07-01' AND payment_date < '2026-08-01'
    GROUP BY payment_date::date
) daily
ORDER BY day;

SELECT month, revenue,
       lag(revenue) OVER w AS previous_revenue,
       revenue - lag(revenue) OVER w AS change,
       round(100 * (revenue - lag(revenue) OVER w) / lag(revenue) OVER w, 1) AS change_pct
FROM (
    SELECT date_trunc('month', payment_date)::date AS month, sum(amount) AS revenue
    FROM payment
    GROUP BY 1
) monthly
WINDOW w AS (ORDER BY month)
ORDER BY month;

WITH customer_total AS (
    SELECT cu.customer_id, cu.store_id, cu.first_name, cu.last_name,
           coalesce(sum(p.amount), 0) AS total_paid
    FROM customer cu
    LEFT JOIN payment p ON p.customer_id = cu.customer_id
    GROUP BY cu.customer_id
)
SELECT store_id, customer_id, first_name, last_name, total_paid,
       rank() OVER (PARTITION BY store_id ORDER BY total_paid DESC) AS position
FROM customer_total
ORDER BY store_id, position, customer_id;

WITH customer_total AS (
    SELECT cu.customer_id, cu.store_id, cu.first_name, cu.last_name,
           coalesce(sum(p.amount), 0) AS total_paid
    FROM customer cu
    LEFT JOIN payment p ON p.customer_id = cu.customer_id
    GROUP BY cu.customer_id
),
ranked AS (
    SELECT *, rank() OVER (PARTITION BY store_id ORDER BY total_paid DESC) AS position
    FROM customer_total
)
SELECT store_id, position, customer_id, first_name, last_name, total_paid
FROM ranked
WHERE position <= 5
ORDER BY store_id, position, customer_id;

CREATE MATERIALIZED VIEW monthly_revenue AS
SELECT date_trunc('month', payment_date)::date AS month, sum(amount) AS revenue
FROM payment
GROUP BY 1;

CREATE UNIQUE INDEX monthly_revenue_month ON monthly_revenue (month);

SELECT month, revenue FROM monthly_revenue WHERE month = '2026-07-01';

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
VALUES (1, 2, 76, 100.00, '2026-07-30 12:00+00')
RETURNING payment_id, amount, payment_date;

SELECT 'view' AS source, revenue FROM monthly_revenue WHERE month = '2026-07-01'
UNION ALL
SELECT 'live query', sum(amount) FROM payment
WHERE payment_date >= '2026-07-01' AND payment_date < '2026-08-01';

REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_revenue;

SELECT month, revenue FROM monthly_revenue WHERE month = '2026-07-01';