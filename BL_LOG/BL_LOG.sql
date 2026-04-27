--  Log Table to Track Last Successful Load
DROP TABLE IF EXISTS bl_log.incremental_load_log;
CREATE TABLE IF NOT EXISTS bl_log.incremental_load_log (
    table_name TEXT PRIMARY KEY,
    last_order_date DATE DEFAULT '1900-01-01',
    inserted_rows INT DEFAULT 0,
    status TEXT DEFAULT 'SUCCESS',
    error_message TEXT DEFAULT NULL
);

--  Procedure Execution Log Table
DROP TABLE IF EXISTS bl_log.procedure_execution_log;
CREATE TABLE IF NOT EXISTS bl_log.procedure_execution_log (
    id SERIAL PRIMARY KEY,
    procedure_name TEXT,
    execution_time TIMESTAMP DEFAULT NOW(),
    rows_inserted INT DEFAULT 0,
    status_message TEXT DEFAULT 'SUCCESS'
);

--  Clean Layer Log Table
DROP TABLE IF EXISTS bl_log.clean_load_log;
CREATE TABLE IF NOT EXISTS bl_log.clean_load_log (
    table_name TEXT PRIMARY KEY,
    last_order_date DATE DEFAULT '1900-01-01',
    inserted_rows INT DEFAULT 0,
    status TEXT DEFAULT 'SUCCESS',
    error_message TEXT DEFAULT NULL
);

--  Ensure Log Table Has an Initial Entry
INSERT INTO bl_log.incremental_load_log (table_name, last_order_date, inserted_rows, status)
VALUES 
    ('sa_local.src_local_sales', '1900-01-01', 0, 'PENDING'),
    ('sa_global.src_international_sales', '1900-01-01', 0, 'PENDING')
ON CONFLICT (table_name) DO NOTHING;

INSERT INTO bl_log.clean_load_log (table_name, last_order_date, inserted_rows, status)
VALUES 
    ('BL_CL.CLEAN_LOCAL_SALES', '1900-01-01', 0, 'PENDING'),
    ('BL_CL.CLEAN_GLOBAL_SALES', '1900-01-01', 0, 'PENDING')
ON CONFLICT (table_name) DO NOTHING;

--  Insert Log Procedure
CREATE OR REPLACE PROCEDURE bl_log.insert_log(
    p_procedure_name TEXT,
    p_rows_inserted INT,
    p_status_message TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bl_log.procedure_execution_log 
        (procedure_name, execution_time, rows_inserted, status_message)
    VALUES (p_procedure_name, NOW(), p_rows_inserted, p_status_message);
END $$;

