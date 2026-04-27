CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_product()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    --  Insert new products into the data warehouse dimension
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_product (product_id, product_name, product_category, supplier_id)
        SELECT product_id, product_name, product_category, supplier_id
        FROM bl_3nf.ce_product_scd2
        ON CONFLICT (product_id) DO NOTHING
        RETURNING product_id
    )
    SELECT COUNT(*) INTO v_rows_inserted FROM inserted_data;

    --  Log execution
    CALL bl_log.insert_log('load_dwh_dim_product_scd2', COALESCE(v_rows_inserted, 0), 'Product Dimension Load Completed.');
END $$;

/*
Ensures only new products are inserted
Prevents duplicates using ON CONFLICT DO NOTHING
Logs execution with the count of inserted rows

Extracts product data from ce_product_scd2 (SCD2 tracking table)
Inserts only new records into dwh_dim_product
Prevents duplicate inserts using ON CONFLICT (product_id) DO NOTHING
Counts how many new products were inserted