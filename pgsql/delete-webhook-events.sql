DO $$
DECLARE
    rows_deleted INTEGER;
BEGIN
    LOOP
        DELETE FROM webhook_events
        WHERE ctid IN (
            SELECT ctid
            FROM webhook_events
            WHERE created_at < '2026-01-10'
            LIMIT 10000
        );

        GET DIAGNOSTICS rows_deleted = ROW_COUNT;

        EXIT WHEN rows_deleted = 0;

        PERFORM pg_sleep(0.2); -- small pause to reduce load
    END LOOP;
END $$;


select count(*) from webhook_events;
