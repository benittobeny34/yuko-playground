-- CAST is required when the column is json type not jsonb

UPDATE webhook_events
SET webhook_data =
    jsonb_set(
        webhook_data::jsonb,
        '{first_name}',
        '"benitto raj"'::jsonb,
        true
    )::json
WHERE id = 55;
