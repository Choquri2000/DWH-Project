CREATE OR REPLACE PROCEDURE bl_dm.load_dwh_dim_branch()
LANGUAGE plpgsql AS $$
DECLARE v_rows_inserted INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_dm.dwh_dim_branch (branch_id, branch_name, branch_region)
        SELECT branch_id, branch_name, branch_region
        FROM bl_3nf.ce_branch
        ON CONFLICT (branch_id) DO UPDATE 
        SET branch_name = EXCLUDED.branch_name,
            branch_region = EXCLUDED.branch_region
        RETURNING (xmax = 0) AS is_insert
    )
    SELECT COUNT(*) FILTER (WHERE is_insert) INTO v_rows_inserted FROM inserted_data;

    CALL bl_log.insert_log('load_dwh_dim_branch', COALESCE(v_rows_inserted, 0), 'Incremental Branch Load Completed.');
END $$;