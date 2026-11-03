WITH active_month AS (
    SELECT DISTINCT customer_id,
           (extract(year FROM rental_date) * 12 + extract(month FROM rental_date) - 1)::integer AS month_no
    FROM rental
),
grouped AS (
    SELECT customer_id, month_no,
           month_no - row_number() OVER (PARTITION BY customer_id ORDER BY month_no) AS island
    FROM active_month
),
island AS (
    SELECT customer_id, min(month_no) AS first_no, max(month_no) AS last_no, count(*) AS months
    FROM grouped
    GROUP BY customer_id, island
),
longest AS (
    SELECT *, row_number() OVER (PARTITION BY customer_id ORDER BY months DESC, first_no) AS pick
    FROM island
)
SELECT customer_id,
       to_char(make_date(first_no / 12, first_no % 12 + 1, 1), 'YYYY-MM') AS first_month,
       to_char(make_date(last_no / 12, last_no % 12 + 1, 1), 'YYYY-MM') AS last_month,
       months
FROM longest
WHERE pick = 1
ORDER BY months DESC, customer_id
LIMIT 10;