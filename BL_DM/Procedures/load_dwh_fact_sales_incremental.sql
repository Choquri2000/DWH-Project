CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_fact_sales_incremental()
LANGUAGE plpgsql AS $$
DECLARE 
    v_inserted_count INT := 0;
    v_updated_count INT := 0;
    v_procedure_name TEXT := 'LOAD_DWH_FACT_SALES_INCREMENTAL';
    v_execution_time TIMESTAMP := CURRENT_TIMESTAMP;
    v_last_insert TIMESTAMP;
BEGIN
    --  Log Start, Records the procedure start time, Sets rows_inserted = NULL initially
    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES (v_procedure_name, v_execution_time, NULL, 'STARTED');

    --  Get Last Insert Timestamp
    SELECT COALESCE(MAX(insert_dt), '1900-01-01') 
    INTO v_last_insert 
    FROM bl_dm.dwh_fact_sales;

    --  Ensure Partitions Exist Before Loading
    CALL bl_dm.create_dwh_fact_sales_partitions();

    --  Load New & Changed Records, Extracts only records modified since last insert
    WITH new_fact_data AS (
        SELECT DISTINCT 
            f.order_id, f.order_dt, t.time_id, p.product_id, f.supplier_id, f.buyer_id, 
            f.branch_id, f.geo_id, f.sales_price, f.revenue, f.product_cost, f.profit, 
            f.shipping_type, f.shipping_cost, 
            CURRENT_TIMESTAMP AS insert_dt, f.source_system, f.source_entity, 
            COALESCE(f.order_id::TEXT, 'UNKNOWN') AS source_id
        FROM bl_3nf.ce_fact_sales f
        LEFT JOIN bl_dm.dwh_dim_time t ON f.order_dt = t.order_date
        LEFT JOIN bl_dm.dwh_dim_product p ON f.product_id = p.product_id
        WHERE f.insert_dt >= v_last_insert
    )

    --  Update Only Existing Records That Changed
    UPDATE bl_dm.dwh_fact_sales d
    SET 
        sales_price = f.sales_price,
        revenue = f.revenue,
        product_cost = f.product_cost,
        profit = f.profit,
        shipping_type = f.shipping_type,
        shipping_cost = f.shipping_cost,
        insert_dt = CURRENT_TIMESTAMP
    FROM new_fact_data f
    WHERE d.order_id = f.order_id AND d.order_dt = f.order_dt
    AND (d.sales_price IS DISTINCT FROM f.sales_price OR
         d.revenue IS DISTINCT FROM f.revenue OR
         d.product_cost IS DISTINCT FROM f.product_cost OR
         d.profit IS DISTINCT FROM f.profit OR
         d.shipping_type IS DISTINCT FROM f.shipping_type OR
         d.shipping_cost IS DISTINCT FROM f.shipping_cost);

    --  Count updated rows properly
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    --  Insert Only Truly New Records
    INSERT INTO bl_dm.dwh_fact_sales (
        order_id, order_dt, time_id, product_id, supplier_id, buyer_id, branch_id, geo_id,
        sales_price, revenue, product_cost, profit, shipping_type, shipping_cost, 
        insert_dt, source_system, source_entity, source_id
    )
    SELECT DISTINCT 
        f.order_id, f.order_dt, t.time_id, p.product_id, f.supplier_id, f.buyer_id, 
        f.branch_id, f.geo_id, f.sales_price, f.revenue, f.product_cost, f.profit, 
        f.shipping_type, f.shipping_cost, 
        CURRENT_TIMESTAMP AS insert_dt, f.source_system, f.source_entity, 
        COALESCE(f.order_id::TEXT, 'UNKNOWN') AS source_id
    FROM bl_3nf.ce_fact_sales f
    LEFT JOIN bl_dm.dwh_dim_time t ON f.order_dt = t.order_date
    LEFT JOIN bl_dm.dwh_dim_product p ON f.product_id = p.product_id
    WHERE f.insert_dt >= v_last_insert
    AND NOT EXISTS (
        SELECT 1 FROM bl_dm.dwh_fact_sales d WHERE d.order_id = f.order_id AND d.order_dt = f.order_dt
    );

    --  Count inserted rows properly
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    --  Corrected Materialized View Refresh
    BEGIN
        IF v_inserted_count > 0 OR v_updated_count > 0 THEN
            REFRESH MATERIALIZED VIEW CONCURRENTLY bl_dm.mv_fact_sales;
        END IF;
    EXCEPTION
        WHEN others THEN
            REFRESH MATERIALIZED VIEW bl_dm.mv_fact_sales;
    END;

    --  Log Execution
    UPDATE bl_log.procedure_execution_log 
    SET rows_inserted = COALESCE(v_inserted_count, 0) + COALESCE(v_updated_count, 0), 
        status_message = 'Incremental DWH Fact Sales Load Completed'
    WHERE procedure_name = v_procedure_name
    AND execution_time = v_execution_time;

END;
$$;