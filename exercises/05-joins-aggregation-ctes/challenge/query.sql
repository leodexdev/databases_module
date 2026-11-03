
WITH RECURSIVE
edge (actor_id, other_actor_id) AS (
    SELECT fa1.actor_id, fa2.actor_id
    FROM film_actor fa1
    JOIN film_actor fa2 ON fa2.film_id = fa1.film_id AND fa2.actor_id <> fa1.actor_id
    GROUP BY fa1.actor_id, fa2.actor_id
    HAVING count(*) >= 3
),
search (actor_id, distance, path) AS (
    SELECT 1, 0, ARRAY[1]
    UNION ALL
    SELECT e.other_actor_id, s.distance + 1, s.path || e.other_actor_id
    FROM search s
    JOIN edge e ON e.actor_id = s.actor_id
    WHERE s.distance < 3                          
      AND e.other_actor_id <> ALL (s.path)        
)
SELECT a.actor_id, a.first_name, a.last_name, min(s.distance) AS distance
FROM search s
JOIN actor a ON a.actor_id = s.actor_id
WHERE s.actor_id <> 1
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY distance, a.actor_id;

WITH RECURSIVE
edge (actor_id, other_actor_id) AS (
    SELECT fa1.actor_id, fa2.actor_id
    FROM film_actor fa1
    JOIN film_actor fa2 ON fa2.film_id = fa1.film_id AND fa2.actor_id <> fa1.actor_id
    GROUP BY fa1.actor_id, fa2.actor_id
    HAVING count(*) >= 3
),
search (actor_id, distance, path) AS (
    SELECT 1, 0, ARRAY[1]
    UNION ALL
    SELECT e.other_actor_id, s.distance + 1, s.path || e.other_actor_id
    FROM search s
    JOIN edge e ON e.actor_id = s.actor_id
    WHERE s.distance < 3
      AND e.other_actor_id <> ALL (s.path)
),
shortest AS (
    SELECT actor_id, min(distance) AS distance
    FROM search
    WHERE actor_id <> 1
    GROUP BY actor_id
)
SELECT distance, count(*) AS actors
FROM shortest
GROUP BY distance
ORDER BY distance;

WITH RECURSIVE
edge (actor_id, other_actor_id) AS (
    SELECT fa1.actor_id, fa2.actor_id
    FROM film_actor fa1
    JOIN film_actor fa2 ON fa2.film_id = fa1.film_id AND fa2.actor_id <> fa1.actor_id
    GROUP BY fa1.actor_id, fa2.actor_id
    HAVING count(*) >= 3
),
search (actor_id, distance, path) AS (
    SELECT 1, 0, ARRAY[1]
    UNION ALL
    SELECT e.other_actor_id, s.distance + 1, s.path || e.other_actor_id
    FROM search s
    JOIN edge e ON e.actor_id = s.actor_id
    WHERE s.distance < 5                          
      AND s.actor_id <> 200                       
      AND e.other_actor_id <> ALL (s.path)
),
best AS (
    SELECT path
    FROM search
    WHERE actor_id = 200
    ORDER BY distance, path
    LIMIT 1
)
SELECT step.position - 1 AS step, a.actor_id, a.first_name || ' ' || a.last_name AS actor
FROM best
CROSS JOIN LATERAL unnest(best.path) WITH ORDINALITY AS step (actor_id, position)
JOIN actor a ON a.actor_id = step.actor_id
ORDER BY step.position;