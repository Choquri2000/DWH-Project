CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_product_scd2()
LANGUAGE plpgsql
AS $$
DECLARE 
    v_inserted_count INT := 0;
BEGIN
    -- ✅ Create a temporary table to store new products
    CREATE TEMP TABLE temp_new_products AS
    SELECT DISTINCT product_src_id::TEXT, product_category, supplier_name, supplier_country
    FROM (
        SELECT product_src_id::TEXT, product_category, supplier_name, supplier_country FROM bl_cl.clean_local_sales
        UNION ALL
        SELECT product_src_id::TEXT, product_category, supplier_name, supplier_country FROM bl_cl.clean_global_sales
    ) AS all_products;

    -- ✅ Ensure suppliers exist before inserting products
    INSERT INTO bl_3nf.ce_supplier (supplier_src_id, supplier_name, supplier_country)
    SELECT DISTINCT supplier_name || '-' || supplier_country, supplier_name, supplier_country
    FROM temp_new_products
    WHERE NOT EXISTS (
        SELECT 1 FROM bl_3nf.ce_supplier s 
        WHERE s.supplier_name = temp_new_products.supplier_name 
        AND s.supplier_country = temp_new_products.supplier_country
    )
    ON CONFLICT (supplier_src_id) DO NOTHING;

    -- ✅ Close previous versions in SCD2 if changed
    UPDATE bl_3nf.ce_product_scd2
    SET end_dt = CURRENT_DATE - INTERVAL '1 day', is_active = 'N'
    WHERE EXISTS (
        SELECT 1 FROM temp_new_products p
        WHERE bl_3nf.ce_product_scd2.product_src_id = p.product_src_id
        AND bl_3nf.ce_product_scd2.end_dt = '9999-12-31'
        AND (
            bl_3nf.ce_product_scd2.product_category <> p.product_category OR
            bl_3nf.ce_product_scd2.supplier_id <> (
                SELECT supplier_id FROM bl_3nf.ce_supplier s 
                WHERE s.supplier_name = p.supplier_name 
                AND s.supplier_country = p.supplier_country
            )
        )
    );

    -- ✅ Insert new version if changes occurred
    WITH inserted_data AS (
        INSERT INTO bl_3nf.ce_product_scd2 (product_src_id, product_name, product_category, supplier_id, start_dt, end_dt, is_active, last_updated)
        SELECT p.product_src_id, 'UNKNOWN', p.product_category, s.supplier_id, CURRENT_DATE, '9999-12-31', 'Y', CURRENT_TIMESTAMP
        FROM temp_new_products p
        INNER JOIN bl_3nf.ce_supplier s ON p.supplier_name = s.supplier_name 
        AND p.supplier_country = s.supplier_country
        WHERE NOT EXISTS ( -- ✅ Prevents inserting duplicate `product_src_id` records
            SELECT 1 FROM bl_3nf.ce_product_scd2 ps 
            WHERE ps.product_src_id = p.product_src_id
            AND ps.end_dt = '9999-12-31'
        )
        RETURNING product_src_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    -- ✅ Ensure 0 is logged correctly
    v_inserted_count := COALESCE(v_inserted_count, 0);

    -- ✅ Log Execution
    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_PRODUCT_SCD2_INCREMENTAL', CURRENT_TIMESTAMP, v_inserted_count, 'Dimension Load Completed');

    -- ✅ Drop the temporary table to clean up
    DROP TABLE temp_new_products;
END;
$$;