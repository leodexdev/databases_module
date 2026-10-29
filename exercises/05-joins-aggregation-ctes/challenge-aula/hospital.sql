create table patient (
    id serial primary key not null,
    name text not null,
    surname text not null,
    date_of_birth date not null check (date_of_birth <= current_date),
    nif int not null unique check (nif between 100000000 and 999999999),
    contact text not null
);

create table unit (
    id serial primary key not null,
    name text not null,
    street text not null,
    postal_code text not null,
    city text not null,
    country text not null
);

create table medic_unit (
    id serial primary key not null,
    name text not null,
    unit_id int not null references unit(id)
);

create table room (
    id serial primary key not null,
    name text not null,
    medic_unit_id int not null references medic_unit(id),
    unique (medic_unit_id, name)
);

create table staff (
    id serial primary key not null,
    name text not null,
    surname text not null,
    date_of_birth date not null check (date_of_birth <= current_date),
    contact text not null,
    role text not null
);

create table shift (
    id serial primary key not null,
    start_at timestamptz not null,
    finish_at timestamptz not null,
    medic_unit_id int not null references medic_unit(id),
    staff_id int not null references staff(id),
    check (finish_at > start_at)
);

create table "case" (
    id serial primary key not null,
    content text not null,
    created_at timestamptz not null default now(),
    closed_at timestamptz,
    value numeric(10,2) not null,
    patient_id int not null references patient(id),
    check (closed_at is null or closed_at >= created_at)
);

create table episode (
    id serial primary key not null,
    content text not null,
    case_id int not null references "case"(id)
);

create table staff_episode (
    id serial primary key not null,
    staff_id int not null references staff(id),
    episode_id int not null references episode(id),
    unique (staff_id, episode_id)
);

create table insurance (
    id serial primary key not null,
    name text not null
);

create table finance (
    id serial primary key not null,
    nif int not null check (nif between 100000000 and 999999999),
    value numeric(10,2) not null,
    created_at timestamptz not null default now(),
    case_id int not null references "case"(id)
);

create table insurance_finance (
    id serial primary key not null,
    insurance_id int not null references insurance(id),
    finance_id int not null references finance(id),
    unique (insurance_id, finance_id)
);

create table report (
    id serial primary key not null,
    staff_id int not null references staff(id),
    patient_id int not null references patient(id),
    finance_id int not null references finance(id)
);