INSERT INTO ingredient (name, kcal_per_100g) VALUES ('Sugar', -1);
-- ERROR: new row for relation "ingredient" violates check constraint "ingredient_kcal_per_100g_check"

INSERT INTO recipe (author_id, title, servings) VALUES (999, 'Soup', 4);
-- ERROR: insert or update on table "recipe" violates foreign key constraint "recipe_author_id_fkey"

INSERT INTO author (name, email) VALUES ('Ana', 'ana@example.com'), ('Ana 2', 'ana@example.com');
-- ERROR: duplicate key value violates unique constraint "author_email_key"