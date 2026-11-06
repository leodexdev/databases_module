INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT customer_id, staff_id, rental_id, 1.99, timestamptz '2026-07-30 12:00+00'
FROM rental ORDER BY rental_id DESC LIMIT 5;
