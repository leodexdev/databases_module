SELECT 'CREATE DATABASE challenge_db'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'challenge_db'
)\gexec

\c challenge_db

CREATE TABLE IF NOT EXISTS records (
    id SERIAL PRIMARY KEY,
    process INT NOT NULL,
    line INT NOT NULL
);