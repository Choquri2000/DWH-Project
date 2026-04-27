CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_geo()
LANGUAGE plpgsql
AS $$
DECLARE v_inserted_count INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_3nf.ce_geo (country, city, insert_dt)
        SELECT DISTINCT country, city, CURRENT_TIMESTAMP
        FROM (
            SELECT country, city FROM bl_cl.clean_global_sales
            UNION ALL
            SELECT 'N/A' AS country, location AS city FROM bl_cl.clean_local_sales
        ) AS all_locations
        WHERE NOT EXISTS (
            SELECT 1 FROM bl_3nf.ce_geo g WHERE g.city = all_locations.city AND g.country = all_locations.country
        )
        RETURNING geo_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_GEO_INCREMENTAL', CURRENT_TIMESTAMP, v_inserted_count, 'Dimension Load Completed');
END;
$$;