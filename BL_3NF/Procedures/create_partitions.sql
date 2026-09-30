--  Quarterly partitions for bl_3nf.ce_fact_sales
--  Covers every quarter from the earliest to the latest order_dt in the clean layer,
--  so new data never falls outside the partitioned range. Safe to run repeatedly.
CREATE OR REPLACE PROCEDURE bl_3nf.create_partitions()
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_date DATE;
    v_max_date DATE;
    v_partition_start DATE;
    v_partition_name TEXT;
BEGIN
    SELECT MIN(order_dt), MAX(order_dt) INTO v_min_date, v_max_date
    FROM (
        SELECT order_dt FROM bl_cl.clean_local_sales
        UNION ALL
        SELECT order_dt FROM bl_cl.clean_global_sales
    ) AS all_dates;

    IF v_min_date IS NULL THEN
        RAISE NOTICE 'No clean-layer data yet; no partitions created.';
        RETURN;
    END IF;

    v_partition_start := date_trunc('quarter', v_min_date)::DATE;
    WHILE v_partition_start <= v_max_date LOOP
        v_partition_name := format('ce_fact_sales_%s', to_char(v_partition_start, 'YYYYMM'));
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS bl_3nf.%I PARTITION OF bl_3nf.ce_fact_sales FOR VALUES FROM (%L) TO (%L)',
            v_partition_name, v_partition_start, (v_partition_start + INTERVAL '3 months')::DATE
        );
        v_partition_start := (v_partition_start + INTERVAL '3 months')::DATE;
    END LOOP;
END;
$$;
