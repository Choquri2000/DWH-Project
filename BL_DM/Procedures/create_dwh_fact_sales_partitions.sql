CREATE OR REPLACE PROCEDURE bl_dm.create_dwh_fact_sales_partitions()
LANGUAGE plpgsql
AS $$
DECLARE 
    v_start_date DATE := '2022-01-01';
    v_end_date DATE := '2026-01-01';
    v_partition_start DATE;
    v_partition_end DATE;
    v_partition_name TEXT;
BEGIN
    v_partition_start := v_start_date;

    WHILE v_partition_start < v_end_date LOOP
        v_partition_end := v_partition_start + INTERVAL '3 months';
        v_partition_name := 'dwh_fact_sales_' || TO_CHAR(v_partition_start, 'YYYY_MM');

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = v_partition_name AND table_schema = 'bl_dm'
        ) THEN
            EXECUTE FORMAT(
                'CREATE TABLE bl_dm.%I PARTITION OF bl_dm.dwh_fact_sales 
                FOR VALUES FROM (%L) TO (%L)',
                v_partition_name, v_partition_start, v_partition_end
            );
            RAISE NOTICE 'Partition created: %', v_partition_name;
        ELSE
            RAISE NOTICE 'Partition already exists: %', v_partition_name;
        END IF;

        v_partition_start := v_partition_end;
    END LOOP;
END $$;