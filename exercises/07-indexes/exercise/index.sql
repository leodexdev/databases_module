CREATE INDEX big_rental_open_customer ON big_rental (customer_id) WHERE returned_at IS NULL;

CREATE INDEX big_rental_rented_at ON big_rental (rented_at);

CREATE INDEX big_rental_customer_rented_at ON big_rental (customer_id, rented_at);

ANALYZE big_rental;