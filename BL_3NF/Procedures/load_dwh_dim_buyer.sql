--  Incremental Load for Buyer
CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_buyer()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_buyer (buyer_id, buyer_name, buyer_country)
        SELECT buyer_id, 'UNKNOWN', 'N/A'
        FROM bl_3nf.ce_buyer
        ON CONFLICT (buyer_id) DO UPDATE 
        SET buyer_name = EXCLUDED.buyer_name,
            buyer_country = EXCLUDED.buyer_country
        RETURNING (xmax = 0) AS is_insert
    )
    SELECT COUNT(*) FILTER (WHERE is_insert) INTO v_rows_inserted FROM inserted_data;

    CALL bl_log.insert_log('load_dwh_dim_buyer', COALESCE(v_rows_inserted, 0), 'Incremental Buyer Load Completed.');
END $$;