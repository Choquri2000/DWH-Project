CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_supplier()
LANGUAGE plpgsql
AS $$
DECLARE v_inserted_count INT := 0;
BEGIN
    --  Insert new suppliers and return their IDs
    WITH inserted_data AS (
        INSERT INTO bl_3nf.ce_supplier (supplier_src_id, supplier_name, supplier_country, supplier_rating, last_updated)
        SELECT supplier_name || '-' || supplier_country, supplier_name, supplier_country, MAX(supplier_rating), CURRENT_TIMESTAMP
        FROM (
            SELECT supplier_name, supplier_country, supplier_rating FROM bl_cl.clean_local_sales
            UNION ALL
            SELECT supplier_name, supplier_country, supplier_rating FROM bl_cl.clean_global_sales
        ) AS all_suppliers
        GROUP BY supplier_name, supplier_country
        ON CONFLICT (supplier_src_id) DO NOTHING
        RETURNING supplier_id, supplier_src_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    --  Log Execution
    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_SUPPLIER_INCREMENTAL', CURRENT_TIMESTAMP, COALESCE(v_inserted_count, 0), 'Dimension Load Completed');
END;
$$;