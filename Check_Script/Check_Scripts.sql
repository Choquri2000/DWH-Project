-- Check for Duplicates in the Target Table, Nothing should be returned
SELECT ORDER_ID, ORDER_DT, COUNT(*)
FROM bl_dm.DWH_FACT_SALES
GROUP BY ORDER_ID, ORDER_DT
HAVING COUNT(*) > 1;

-- Ensure All Records from SA Layer Exist in the Business Layer, Nothing should be returned
SELECT sa.ORDER_ID, sa.ORDER_DT
FROM bl_3nf.CE_FACT_SALES sa
LEFT JOIN bl_dm.DWH_FACT_SALES dm
ON sa.ORDER_ID = dm.ORDER_ID AND sa.ORDER_DT = dm.ORDER_DT
WHERE dm.ORDER_ID IS NULL;

-- ✅ Check Log Table for Load Status
SELECT * FROM bl_log.incremental_load_log ORDER BY last_order_date DESC;

-- ✅ Check Log Table for Load Status
SELECT * FROM BL_LOG.CLEAN_LOAD_LOG ORDER BY last_order_date DESC;

SELECT * FROM bl_log.procedure_execution_log ORDER BY log_id DESC;
/*
SELECT * 
FROM bl_log.procedure_execution_log 
WHERE procedure_name = 'LOAD_CE_FACT_SALES_INCREMENTAL' 
ORDER BY execution_time DESC 
LIMIT 10;
*/

SELECT * FROM bl_log.procedure_execution_log ORDER BY log_id DESC;

SELECT * 
FROM bl_log.procedure_execution_log 
WHERE procedure_name = 'LOAD_CE_FACT_SALES_INCREMENTAL' 
ORDER BY execution_time DESC 


-- SCD2 TEST    END_DT should be updated but it is not updated now
UPDATE bl_cl.clean_local_sales
SET product_category = 'EPAM Clothing'
WHERE product_src_id = 2
AND order_src_id = 2
;

CALL bl_3nf.load_ce_product_scd2();

SELECT * FROM bl_3nf.ce_product_scd2 WHERE product_src_id = '2' ORDER BY start_dt DESC;



----------------------- SCD1 Test

-- Select the initial branch state before update
SELECT * FROM bl_3nf.ce_branch WHERE branch_id = '222';

-- Update branch name (Modify branch_id as needed)
UPDATE bl_3nf.ce_branch
SET branch_name = 'New NEWEST Branch Name'
WHERE branch_id = '222';

--  Verify update success - old name should no longer exist
SELECT * FROM bl_3nf.ce_branch WHERE branch_id = '222';

-- Check if multiple records exist for the same branch (should be 1 if replaced). UPDATED LAST_UPDATED
SELECT branch_id, branch_name, COUNT(*)
FROM bl_3nf.ce_branch
WHERE branch_id = '222'
GROUP BY branch_id, branch_name;
