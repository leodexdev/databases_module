
-- 1. Rejected by: copy_condition_valid (CHECK)
-- Adds a copy with condition 'broken', which is not new, good, worn or damaged.
INSERT INTO copy (barcode, isbn13, copy_condition) VALUES ('C-0003', '9780306406157', 'broken');

-- 2. Rejected by: book_author_position_unique (composite UNIQUE)
-- Puts a second author in position 1 of the same book.
INSERT INTO book_author (isbn13, author_id, author_position)
    SELECT '9780306406157', author_id, 1 FROM author WHERE surname = 'Costa';

-- 3. Rejected by: loan_one_open_per_copy (unique index, one open loan per copy)
-- Lends copy C-0001 again while its first loan is still open.
INSERT INTO loan (reader_id, copy_id, loan_date, due_date)
    SELECT r.reader_id, c.copy_id, '2026-10-20', '2026-11-03'
    FROM reader r, copy c WHERE r.card_number = 'R-0001' AND c.barcode = 'C-0001';

-- 4. Rejected by: loan_due_14 (CHECK, due date must be loan date + 14 days)
-- Loan on 2026-10-01 due on 2026-10-20, but 2026-10-01 + 14 days is 2026-10-15.
INSERT INTO loan (reader_id, copy_id, loan_date, due_date)
    SELECT r.reader_id, c.copy_id, '2026-10-01', '2026-10-20'
    FROM reader r, copy c WHERE r.card_number = 'R-0001' AND c.barcode = 'C-0002';

-- 5. Rejected by: loan_copy_fk (ON DELETE RESTRICT, the copy has a loan)
-- Deletes copy C-0001, but a loan still points to it.
DELETE FROM copy WHERE barcode = 'C-0001';