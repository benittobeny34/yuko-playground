DO $$
DECLARE
    rows_deleted INTEGER;
BEGIN
    LOOP
        DELETE FROM webhook_events
        WHERE ctid IN (
            SELECT ctid
            FROM webhook_events
            WHERE created_at < '2025-12-31'
            LIMIT 10000
        );

        GET DIAGNOSTICS rows_deleted = ROW_COUNT;

        EXIT WHEN rows_deleted = 0;

        PERFORM pg_sleep(0.1); -- small pause to reduce load
    END LOOP;
END $$;
