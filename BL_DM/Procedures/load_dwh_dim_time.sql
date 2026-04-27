CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_time()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_time (time_id, order_date, year, quarter, month, week, day)
        SELECT time_id, order_date, year, quarter, month, week, day
        FROM bl_3nf.ce_time
        ON CONFLICT (time_id) DO UPDATE 
        SET order_date = EXCLUDED.order_date,
            year = EXCLUDED.year,
            quarter = EXCLUDED.quarter,
            month = EXCLUDED.month,
            week = EXCLUDED.week,
            day = EXCLUDED.day
        RETURNING (xmax = 0) AS is_insert
    )
    SELECT COUNT(*) FILTER (WHERE is_insert) INTO v_rows_inserted FROM inserted_data;

    CALL bl_log.insert_log('load_dwh_dim_time', COALESCE(v_rows_inserted, 0), 'Incremental Time Load Completed.');
END $$;