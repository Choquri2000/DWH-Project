-- Loads unique branch IDs from clean_global_sales & clean_local_sales
-- Inserts new branches into bl_3nf.ce_branch
-- Updates last_updated timestamp if branch already exists
-- Logs execution details in bl_log.procedure_execution_log

CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_branch()
LANGUAGE plpgsql
AS $$
DECLARE 
    v_inserted_count INT := 0;
BEGIN
    --  Extract distinct branch IDs
	-- 	Gets all unique branch_src_ids from both clean_global_sales & clean_local_sales
	--	Ensures no duplicates before insertion

    WITH new_branches AS (
        SELECT DISTINCT branch_src_id::VARCHAR(50) FROM bl_cl.clean_global_sales
        UNION ALL
        SELECT DISTINCT branch_src_id::VARCHAR(50) FROM bl_cl.clean_local_sales
    ),
    inserted_data AS (
        INSERT INTO bl_3nf.ce_branch (branch_src_id, branch_name, branch_region, last_updated, insert_dt)
        SELECT nb.branch_src_id, 'UNKNOWN', 'UNKNOWN', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM new_branches nb
        ON CONFLICT (branch_src_id) DO UPDATE 
        SET last_updated = CURRENT_TIMESTAMP
        WHERE ce_branch.branch_src_id = EXCLUDED.branch_src_id
        RETURNING (xmax = 0) AS is_insert  --  `xmax = 0` indicates a true insert,Checks if row was newly inserted (xmax = 0 means new insert)
    )
    SELECT COUNT(*) FILTER (WHERE is_insert) INTO v_inserted_count FROM inserted_data;
--	 Counts only rows that were inserted, ignoring updates
    
	
	--  Ensure 0 is logged correctly, COALESCE Prevents NULL values in logging
    v_inserted_count := COALESCE(v_inserted_count, 0);

    --  Log Execution
    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_BRANCH_INCREMENTAL', CURRENT_TIMESTAMP, v_inserted_count, 'Dimension Load Completed');
END;
$$;