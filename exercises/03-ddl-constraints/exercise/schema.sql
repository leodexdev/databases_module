CREATE TABLE publisher (
    publisher_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL,
    country      text NOT NULL,
    CONSTRAINT publisher_name_unique UNIQUE (name)
);

CREATE TABLE reader (
    reader_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_number       text NOT NULL,
    name              text NOT NULL,
    surname           text NOT NULL,
    email             text NOT NULL,
    phone             text NOT NULL,
    address           text NOT NULL,
    registration_date date NOT NULL DEFAULT current_date,
    CONSTRAINT reader_card_number_unique UNIQUE (card_number),
    CONSTRAINT reader_email_unique UNIQUE (email),
    CONSTRAINT reader_email_format CHECK (email LIKE '%_@_%')
);

CREATE TABLE book (
    isbn13           text PRIMARY KEY,
    title            text NOT NULL,
    genres           text,
    number_of_pages  integer,
    publication_year smallint NOT NULL,
    publisher_id     integer NOT NULL,
    CONSTRAINT book_isbn13_format CHECK (isbn13 ~ '^[0-9]{13}$'),
    CONSTRAINT book_pages_positive CHECK (number_of_pages > 0),
    CONSTRAINT book_year_range CHECK (publication_year BETWEEN 1400 AND 2100),
    CONSTRAINT book_publisher_fk FOREIGN KEY (publisher_id)
        REFERENCES publisher (publisher_id) ON DELETE RESTRICT
);

CREATE TABLE author (
    author_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      text NOT NULL,
    surname   text NOT NULL,
    age       integer,
    email     text,
    CONSTRAINT author_age_range CHECK (age BETWEEN 0 AND 150)
);

CREATE TABLE book_author (
    isbn13          text    NOT NULL,
    author_id       integer NOT NULL,
    author_position smallint NOT NULL,
    PRIMARY KEY (isbn13, author_id),
    CONSTRAINT book_author_position_unique UNIQUE (isbn13, author_position),
    CONSTRAINT book_author_position_positive CHECK (author_position >= 1),
    CONSTRAINT book_author_book_fk FOREIGN KEY (isbn13)
        REFERENCES book (isbn13) ON DELETE CASCADE,
    CONSTRAINT book_author_author_fk FOREIGN KEY (author_id)
        REFERENCES author (author_id) ON DELETE RESTRICT
);

CREATE TABLE copy (
    copy_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    barcode          text NOT NULL,
    isbn13           text NOT NULL,
    acquisition_date date NOT NULL DEFAULT current_date,
    copy_condition   text NOT NULL DEFAULT 'new',
    CONSTRAINT copy_barcode_unique UNIQUE (barcode),
    CONSTRAINT copy_condition_valid
        CHECK (copy_condition IN ('new', 'good', 'worn', 'damaged')),
    CONSTRAINT copy_book_fk FOREIGN KEY (isbn13)
        REFERENCES book (isbn13) ON DELETE RESTRICT
);

CREATE TABLE loan (
    loan_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reader_id   integer NOT NULL,
    copy_id     integer NOT NULL,
    loan_date   date NOT NULL DEFAULT current_date,
    due_date    date NOT NULL,
    return_date date,
    CONSTRAINT loan_due_14 CHECK (due_date = loan_date + 14),
    CONSTRAINT loan_return_after_loan CHECK (return_date >= loan_date),
    CONSTRAINT loan_copy_fk FOREIGN KEY (copy_id)
        REFERENCES copy (copy_id) ON DELETE RESTRICT,
    CONSTRAINT loan_reader_fk FOREIGN KEY (reader_id)
        REFERENCES reader (reader_id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX loan_one_open_per_copy ON loan (copy_id) WHERE return_date IS NULL;

CREATE TABLE reservation (
    reservation_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reader_id      integer NOT NULL,
    isbn13         text NOT NULL,
    reserved_at    timestamptz NOT NULL DEFAULT now(),
    status         text NOT NULL DEFAULT 'active',
    CONSTRAINT reservation_status_valid
        CHECK (status IN ('active', 'fulfilled', 'cancelled')),
    CONSTRAINT reservation_reader_fk FOREIGN KEY (reader_id)
        REFERENCES reader (reader_id) ON DELETE CASCADE,
    CONSTRAINT reservation_book_fk FOREIGN KEY (isbn13)
        REFERENCES book (isbn13) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX reservation_one_active_per_reader_book
    ON reservation (reader_id, isbn13) WHERE status = 'active';

CREATE INDEX reservation_queue ON reservation (isbn13, reserved_at) WHERE status = 'active';

CREATE TABLE fine (
    fine_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id   integer NOT NULL,
    amount    numeric(6, 2) NOT NULL,  
    paid_date date,                    
    CONSTRAINT fine_loan_unique UNIQUE (loan_id),
    CONSTRAINT fine_amount_positive CHECK (amount > 0),
    CONSTRAINT fine_loan_fk FOREIGN KEY (loan_id)
        REFERENCES loan (loan_id) ON DELETE RESTRICT
);