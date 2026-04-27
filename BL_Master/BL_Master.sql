CREATE OR REPLACE PROCEDURE bl_master.execute_full_dwh_load()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_inserted INT := 0;
BEGIN
    --  External to Source Layer
    CALL sa_local.incremental_load_local_sales();
    CALL sa_global.incremental_load_international_sales();

    --  Source to Clean Layer
    CALL BL_CL.LOAD_SRC_TO_CLEAN_LOCAL();
    CALL BL_CL.LOAD_SRC_TO_CLEAN_GLOBAL();

    --  Clean to 3NF Layer
    CALL bl_3nf.load_ce_supplier();
    CALL bl_3nf.load_ce_geo();
    CALL bl_3nf.load_ce_buyer();
    CALL bl_3nf.load_ce_product_scd2();
    CALL bl_3nf.load_ce_branch();
    CALL bl_3nf.load_ce_time();
    --  Load Facts in 3NF
	CALL bl_3nf.create_partitions();
	CALL bl_3nf.load_fact_sales();

    --  Load Dimensions in DM
	CALL bl_dm.load_dwh_dim_geo();
	CALL bl_dm.load_dwh_dim_supplier();
	CALL bl_dm.load_dwh_dim_buyer();
	CALL bl_dm.load_dwh_dim_branch();
	CALL bl_dm.load_dwh_dim_product();
	CALL bl_dm.load_dwh_dim_time();

    --  Load Facts in DM
    CALL bl_dm.create_dwh_fact_sales_partitions();
    CALL bl_dm.load_dwh_fact_sales_incremental();


    --  Log Execution
    CALL bl_log.insert_log('execute_full_dwh_load', 0, 'Full DWH Load Completed Successfully.');

END $$;

-- Execute the full load
CALL bl_master.execute_full_dwh_load();

SELECT * FROM bl_log.incremental_load_log ORDER BY last_order_date DESC;

SELECT * FROM BL_LOG.CLEAN_LOAD_LOG ORDER BY last_order_date DESC;

SELECT * FROM bl_log.procedure_execution_log ORDER BY execution_time DESC;


    --  Determine if Any Rows Were Inserted
    SELECT COUNT(*) INTO v_rows_inserted FROM bl_log.procedure_execution_log 
    WHERE execution_time >= (SELECT MAX(execution_time) FROM bl_log.procedure_execution_log WHERE procedure_name = 'execute_full_dwh_load');
