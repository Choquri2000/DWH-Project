--  Incremental Load for Local Sales
CREATE OR REPLACE PROCEDURE BL_CL.LOAD_SRC_TO_CLEAN_LOCAL()
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_order_date DATE;
    v_new_max_date DATE;
    v_inserted_count INT := 0;
BEGIN
    -- Get last successfully loaded `order_dt`
    SELECT COALESCE(last_order_date, '1900-01-01') INTO v_last_order_date
    FROM BL_LOG.CLEAN_LOAD_LOG
    WHERE table_name = 'BL_CL.CLEAN_LOCAL_SALES'
    FOR UPDATE;

    -- Insert Only New `order_dt` Values, Avoiding Duplicate `ORDER_SRC_ID`
    WITH inserted_data AS (
        INSERT INTO BL_CL.CLEAN_LOCAL_SALES
        SELECT DISTINCT ON (ORDER_SRC_ID) *
        FROM sa_local.src_local_sales
        WHERE order_dt > v_last_order_date
        ON CONFLICT (ORDER_SRC_ID) DO UPDATE 
        SET order_dt = EXCLUDED.order_dt  -- Ensures updated order_dt is inserted
        RETURNING ORDER_SRC_ID
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    --  Update last order date only if new rows were inserted
    IF v_inserted_count > 0 THEN
        SELECT MAX(order_dt) INTO v_new_max_date FROM BL_CL.CLEAN_LOCAL_SALES;
    ELSE
        v_new_max_date := v_last_order_date;
    END IF;

-- Updates last_order_date only if new rows were inserted
-- Otherwise, keeps v_last_order_date unchanged

    --  Update Log Table
    UPDATE BL_LOG.CLEAN_LOAD_LOG
    SET last_order_date = v_new_max_date,
        inserted_rows = v_inserted_count,
        status = 'SUCCESS',
        error_message = NULL
    WHERE table_name = 'BL_CL.CLEAN_LOCAL_SALES';

EXCEPTION
    WHEN OTHERS THEN
        --  Log Failure
        UPDATE BL_LOG.CLEAN_LOAD_LOG 
        SET status = 'FAILED', error_message = SQLERRM 
        WHERE table_name = 'BL_CL.CLEAN_LOCAL_SALES';
END;
$$;
-- If an error occurs, logs FAILED status and error message

    CALL BL_CL.LOAD_SRC_TO_CLEAN_LOCAL();



--  Check Log Table for Load Status
SELECT * FROM BL_LOG.CLEAN_LOAD_LOG ORDER BY last_order_date DESC;
