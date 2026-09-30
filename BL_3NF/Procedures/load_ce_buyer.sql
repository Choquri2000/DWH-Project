--  Incremental Load for Buyer (3NF)
--  Inserts every new buyer_src_id found in the clean layer into bl_3nf.ce_buyer.
--  The sources carry no buyer attributes, so name and country keep their 'N/A' defaults.
CREATE OR REPLACE PROCEDURE bl_3nf.load_ce_buyer()
LANGUAGE plpgsql
AS $$
DECLARE v_inserted_count INT := 0;
BEGIN
    WITH inserted_data AS (
        INSERT INTO bl_3nf.ce_buyer (buyer_src_id)
        SELECT DISTINCT buyer_src_id::VARCHAR(50)
        FROM (
            SELECT buyer_src_id FROM bl_cl.clean_local_sales
            UNION
            SELECT buyer_src_id FROM bl_cl.clean_global_sales
        ) AS all_buyers
        WHERE buyer_src_id IS NOT NULL
        ON CONFLICT (buyer_src_id) DO NOTHING
        RETURNING buyer_id
    )
    SELECT COUNT(*) INTO v_inserted_count FROM inserted_data;

    INSERT INTO bl_log.procedure_execution_log (procedure_name, execution_time, rows_inserted, status_message)
    VALUES ('LOAD_CE_BUYER_INCREMENTAL', CURRENT_TIMESTAMP, COALESCE(v_inserted_count, 0), 'Dimension Load Completed');
END;
$$;
