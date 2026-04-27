CREATE OR REPLACE PROCEDURE bl_3nf.load_fact_sales()
LANGUAGE plpgsql
AS $$
DECLARE 
    v_inserted_count INT := 0;
    v_procedure_name TEXT := 'LOAD_CE_FACT_SALES_INCREMENTAL';
    v_execution_time TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    --  Log Start (ONLY FOR FACT TABLE)
    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES (v_procedure_name, v_execution_time, NULL, 'STARTED');  -- NULL for rows_inserted (to be updated later)

    --  Insert New Fact Data
/*Extracts distinct sales transactions from both local & global clean tables
Maps source columns to standardized fact table structure
Ensures referential integrity by linking dimensions (product_id, supplier_id, buyer_id, branch_id, geo_id, time_id)
Uses COALESCE(g.geo_id, 1), COALESCE(t.time_id, 1) as fallbacks for missing geo/time dimensions
*/

    WITH new_fact_data AS (
        SELECT DISTINCT 
            all_sales.order_src_id AS order_id, all_sales.order_dt, 
            p.product_id, s.supplier_id, b.buyer_id, br.branch_id, 
            COALESCE(g.geo_id, 1), COALESCE(t.time_id, 1),
            all_sales.sales_price, all_sales.revenue, all_sales.product_cost, all_sales.profit, 
            all_sales.shipping_type, all_sales.shipping_cost, 
            CURRENT_TIMESTAMP AS insert_dt, 'SRC' AS source_system, all_sales.source_entity, 
            COALESCE(all_sales.order_src_id::TEXT, 'UNKNOWN') AS source_id
        FROM (
            SELECT 
                order_src_id, order_dt, location, state AS city, product_src_id, product_category, 
                supplier_name, supplier_country, supplier_rating, buyer_src_id, branch_src_id, 
                sales_price, revenue, product_cost, profit, 
                'N/A' AS shipping_type,  
                0.00 AS shipping_cost,   
                'LOCAL' AS source_entity
            FROM bl_cl.clean_local_sales
            
            UNION ALL
            
            SELECT 
                order_src_id, order_dt, country AS location, city, product_src_id, product_category, 
                supplier_name, supplier_country, supplier_rating, buyer_src_id, branch_src_id, 
                sales_price, revenue, product_cost, profit, 
                shipping_type, shipping_cost,  
                'GLOBAL' AS source_entity
            FROM bl_cl.clean_global_sales
        ) AS all_sales

        LEFT JOIN bl_3nf.ce_product_scd2 p ON all_sales.product_src_id::TEXT = p.product_src_id::TEXT  
        LEFT JOIN bl_3nf.ce_supplier s ON all_sales.supplier_name = s.supplier_name AND all_sales.supplier_country = s.supplier_country
        LEFT JOIN bl_3nf.ce_buyer b ON all_sales.buyer_src_id::TEXT = b.buyer_src_id::TEXT  
        LEFT JOIN bl_3nf.ce_branch br ON all_sales.branch_src_id::TEXT = br.branch_src_id::TEXT  
        LEFT JOIN bl_3nf.ce_geo g ON g.city = all_sales.city AND g.country = all_sales.location
        LEFT JOIN bl_3nf.ce_time t ON all_sales.order_dt = t.order_date
    ) -- Ensures every fact sale has valid foreign keys for dimension tables
    
    --  Insert New Fact Data Using ON CONFLICT
    , inserted_fact AS (
        INSERT INTO bl_3nf.ce_fact_sales (
            order_id, order_dt, product_id, supplier_id, buyer_id, branch_id, geo_id, time_id,
            sales_price, revenue, product_cost, profit, shipping_type, shipping_cost, 
            insert_dt, source_system, source_entity, source_id
        )
        SELECT * FROM new_fact_data
        ON CONFLICT (order_id, order_dt) DO NOTHING  --  Avoids Duplicate Key Violation
        RETURNING order_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_fact;
/*
 Ensures new records are inserted without duplication
 Uses ON CONFLICT (order_id, order_dt) DO NOTHING to prevent key violations
 Tracks the count of inserted rows (v_inserted_count)
*/

    --  Auto Refresh the Materialized View After Insert
    BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY bl_3nf.mv_fact_sales;
    EXCEPTION
        WHEN others THEN
            REFRESH MATERIALIZED VIEW bl_3nf.mv_fact_sales;
    END;

    --  Update Execution Log (Ensures It Always Runs)
    UPDATE bl_log.procedure_execution_log 
    SET rows_inserted = COALESCE(v_inserted_count, 0), 
        status_message = 'Incremental Fact Sales Load Completed'
    WHERE procedure_name = v_procedure_name
    AND execution_time = v_execution_time;

END;
$$;