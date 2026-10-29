CREATE TABLE author (
    author_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       text NOT NULL,
    email      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ingredient (
    ingredient_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text NOT NULL UNIQUE,
    kcal_per_100g numeric(6,1) NOT NULL CHECK (kcal_per_100g >= 0)
);

CREATE TABLE recipe (
    recipe_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- RESTRICT: an author with published recipes cannot be deleted by accident
    author_id    integer NOT NULL REFERENCES author ON DELETE RESTRICT,
    title        text NOT NULL,
    servings     integer NOT NULL CHECK (servings BETWEEN 1 AND 50),
    published_at timestamptz,
    UNIQUE (author_id, title)
);

CREATE TABLE recipe_ingredient (
    -- CASCADE: the ingredient list means nothing without its recipe
    recipe_id     integer NOT NULL REFERENCES recipe ON DELETE CASCADE,
    ingredient_id integer NOT NULL REFERENCES ingredient ON DELETE RESTRICT,
    grams         numeric(7,1) NOT NULL CHECK (grams > 0),
    PRIMARY KEY (recipe_id, ingredient_id)
);