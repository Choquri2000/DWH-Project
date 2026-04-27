CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_supplier()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    -- ✅ Insert only new suppliers
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_supplier (supplier_id, supplier_name, supplier_country, supplier_rating)
        SELECT DISTINCT supplier_id, supplier_name, supplier_country, supplier_rating
        FROM bl_3nf.ce_supplier
        WHERE supplier_id NOT IN (SELECT supplier_id FROM bl_dm.dwh_dim_supplier) -- ✅ Avoids duplicate conflict
        RETURNING supplier_id
    )
    SELECT COUNT(*) INTO v_rows_inserted FROM inserted_data;

    -- ✅ Log execution
    CALL bl_log.insert_log('load_dwh_dim_supplier', COALESCE(v_rows_inserted, 0), 'Supplier Dimension Load Completed.');
END $$;