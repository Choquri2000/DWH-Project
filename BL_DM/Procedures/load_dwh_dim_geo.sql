CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_geo()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_geo (geo_id, country, city, insert_dt)
        SELECT geo_id, country, city, insert_dt
        FROM bl_3nf.ce_geo
        ON CONFLICT (geo_id) DO UPDATE 
        SET country = EXCLUDED.country,
            city = EXCLUDED.city
        RETURNING (xmax = 0) AS is_insert
    )
    SELECT COUNT(*) FILTER (WHERE is_insert) INTO v_rows_inserted FROM inserted_data;

    CALL bl_log.insert_log('load_dwh_dim_geo', COALESCE(v_rows_inserted, 0), 'Incremental Geo Load Completed.');
END $$;
