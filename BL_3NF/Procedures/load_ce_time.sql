CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_time()
LANGUAGE plpgsql
AS $$
DECLARE v_inserted_count INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_3nf.ce_time (order_date, year, quarter, month, week, day, insert_dt)
        SELECT DISTINCT order_dt, EXTRACT(YEAR FROM order_dt), EXTRACT(QUARTER FROM order_dt),
                        EXTRACT(MONTH FROM order_dt), EXTRACT(WEEK FROM order_dt), EXTRACT(DAY FROM order_dt),
                        CURRENT_TIMESTAMP
        FROM (
            SELECT order_dt FROM bl_cl.clean_local_sales
            UNION ALL
            SELECT order_dt FROM bl_cl.clean_global_sales
        ) AS all_dates
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_3nf.ce_time t WHERE t.order_date = all_dates.order_dt
        )
        RETURNING time_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_TIME_INCREMENTAL', CURRENT_TIMESTAMP, v_inserted_count, 'Dimension Load Completed');
END;
$$;