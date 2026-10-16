-- Seed synthetic notes for the connected workspace role.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO private_notes (note_text)
SELECT seed.note_text
FROM (VALUES
    ('Quarterly planning notes for the engineering team.'::text),
    ('Synthetic note: review the next release checklist.'::text)
) AS seed(note_text)
WHERE NOT EXISTS (
    SELECT 1
    FROM private_notes AS existing
    WHERE existing.owner_name = current_user
      AND existing.note_text = seed.note_text
);

ANALYZE private_notes;
