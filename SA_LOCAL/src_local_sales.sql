-- Source Table for Local Sales
CREATE TABLE IF NOT EXISTS sa_local.src_local_sales (
    order_src_id INT PRIMARY KEY,
    order_dt DATE NOT NULL,
    location TEXT,
    state TEXT,
    product_src_id INT,
    product_category TEXT,
    supplier_name TEXT,
    supplier_country TEXT,
    supplier_rating DECIMAL(2,1),
    buyer_src_id INT,
    branch_src_id INT,
    sales_price DECIMAL(10,2),
    revenue DECIMAL(10,2),
    product_cost DECIMAL(10,2),
    profit DECIMAL(10,2),
    insert_dt TIMESTAMP DEFAULT NOW()
);


CREATE OR REPLACE PROCEDURE sa_local.incremental_load_local_sales()
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_order_date DATE;
    v_new_max_date DATE;
    v_inserted_count INT := 0;
BEGIN
    --  Get last successfully loaded `order_dt` (Fix: Handle Empty Table)
    SELECT COALESCE(MAX(last_order_date), '1900-01-01') 
    INTO v_last_order_date
    FROM bl_log.incremental_load_log
    WHERE table_name = 'sa_local.src_local_sales';

    --  If no records exist, ensure we load everything
    IF v_last_order_date = '1900-01-01' THEN
        SELECT COALESCE(MIN(order_dt), '1900-01-01') INTO v_last_order_date
        FROM sa_local.ext_local_sales;
    END IF;

    --  Debugging: Show the last order date
    RAISE NOTICE 'Last order date: %', v_last_order_date;


-- Retrieves the last loaded order_dt from bl_log.incremental_load_log
-- If no records exist, takes the earliest date from ext_local_sales
-- Ensures new loads don’t miss data by tracking order_dt

    --  Insert New Records, Ensuring First Load Works
    INSERT INTO sa_local.src_local_sales (
        order_src_id, order_dt, location, state, product_src_id, product_category, 
        supplier_name, supplier_country, supplier_rating, buyer_src_id, branch_src_id, 
        sales_price, revenue, product_cost, profit, insert_dt
    )
    SELECT DISTINCT
        e.order_src_id, e.order_dt, e.location, e.state, e.product_src_id, e.product_category, 
        e.supplier_name, e.supplier_country, e.supplier_rating, e.buyer_src_id, e.branch_src_id, 
        e.sales_price, e.revenue, e.product_cost, e.profit, NOW()
    FROM sa_local.ext_local_sales e
    WHERE e.order_dt >= v_last_order_date  --  >= to load first time correctly
    ON CONFLICT (order_src_id) DO UPDATE 
    SET revenue = EXCLUDED.revenue,
        product_cost = EXCLUDED.product_cost,
        profit = EXCLUDED.profit,
        order_dt = EXCLUDED.order_dt;

-- Loads new data from ext_local_sales where order_dt is newer
-- Uses ON CONFLICT (order_src_id) DO UPDATE to prevent duplicates
-- Updates revenue, product cost, profit if an existing order_src_id is found

    --  Get inserted row count
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    --  Debugging: Check how many rows were inserted
    RAISE NOTICE 'Inserted rows: %', v_inserted_count;


    --  Update last order date only if new rows were inserted
    IF v_inserted_count > 0 THEN
        SELECT MAX(order_dt) INTO v_new_max_date FROM sa_local.src_local_sales;
    ELSE
        v_new_max_date := v_last_order_date;
    END IF;

    --  Update Log Table
    INSERT INTO bl_log.incremental_load_log (table_name, last_order_date, inserted_rows, status, error_message)
    VALUES ('sa_local.src_local_sales', v_new_max_date, v_inserted_count, 'SUCCESS', NULL)
    ON CONFLICT (table_name) 
    DO UPDATE SET last_order_date = v_new_max_date, inserted_rows = v_inserted_count, status = 'SUCCESS', error_message = NULL;

-- Tracks how many rows were inserted (v_inserted_count)
-- Updates the last_order_date if new data was inserted
-- Ensures the incremental log (bl_log.incremental_load_log) is updated

EXCEPTION
    WHEN OTHERS THEN
        --  Log Failure
        UPDATE bl_log.incremental_load_log 
        SET status = 'FAILED', error_message = SQLERRM 
        WHERE table_name = 'sa_local.src_local_sales';
        RAISE;
END;
$$;



--  Master Procedure to Execute Both Incremental Loads
CREATE OR REPLACE PROCEDURE bl_log.master_incremental_load()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sa_local.incremental_load_local_sales();
    CALL sa_global.incremental_load_international_sales();
END;
$$;

--  Execute the Master Procedure
CALL bl_log.master_incremental_load();