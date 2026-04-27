--  Ensure Schema Exists
CREATE SCHEMA IF NOT EXISTS bl_3nf;

--  Geographic Dimension Table
CREATE TABLE IF NOT EXISTS bl_3nf.ce_geo (
    geo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    city VARCHAR(50) NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Supplier Dimension Table (SCD1 Handling)
CREATE TABLE IF NOT EXISTS bl_3nf.ce_supplier (
    supplier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    supplier_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    supplier_country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_rating DECIMAL(2,1) CHECK (supplier_rating BETWEEN 1.0 AND 5.0) DEFAULT 0.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Buyer Dimension Table
CREATE TABLE IF NOT EXISTS bl_3nf.ce_buyer (
    buyer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    buyer_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    buyer_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    buyer_country VARCHAR(50) DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Branch Table as SCD1
CREATE TABLE IF NOT EXISTS bl_3nf.ce_branch (
    branch_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    branch_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    branch_region TEXT NOT NULL DEFAULT 'N/A',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Product Table as SCD2
CREATE TABLE IF NOT EXISTS bl_3nf.ce_product_scd2 (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_src_id VARCHAR(50) NOT NULL DEFAULT 'N/A',
    product_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    product_category VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_id BIGINT NOT NULL DEFAULT 0,
    start_dt DATE NOT NULL DEFAULT CURRENT_DATE,
    end_dt DATE DEFAULT '9999-12-31',
    is_active CHAR(1) NOT NULL DEFAULT 'Y',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES bl_3nf.ce_supplier(supplier_id)
);

--  Time Dimension Table
CREATE TABLE IF NOT EXISTS bl_3nf.ce_time (
    time_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_date DATE UNIQUE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    week INT NOT NULL,
    day INT NOT NULL,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bl_3nf.ce_fact_sales (
    transaction_id BIGINT GENERATED ALWAYS AS IDENTITY,
    order_id BIGINT NOT NULL,
    order_dt DATE NOT NULL,
    product_id BIGINT NOT NULL,
    supplier_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    branch_id BIGINT NOT NULL,
    geo_id BIGINT NOT NULL,
    time_id BIGINT NOT NULL,
    sales_price DECIMAL(10,2) NOT NULL,
    revenue DECIMAL(10,2) NOT NULL,
    product_cost DECIMAL(10,2) NOT NULL,
    profit DECIMAL(10,2) NOT NULL,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system VARCHAR(50) NOT NULL,
    source_entity VARCHAR(50) NOT NULL,
    source_id VARCHAR(50) NOT NULL,
    shipping_type TEXT DEFAULT 'N/A',
    shipping_cost DECIMAL(10,2) DEFAULT 0.00,
    PRIMARY KEY (order_id, order_dt),
    FOREIGN KEY (product_id) REFERENCES bl_3nf.ce_product_scd2(product_id),
    FOREIGN KEY (supplier_id) REFERENCES bl_3nf.ce_supplier(supplier_id),
    FOREIGN KEY (buyer_id) REFERENCES bl_3nf.ce_buyer(buyer_id),
    FOREIGN KEY (branch_id) REFERENCES bl_3nf.ce_branch(branch_id),
    FOREIGN KEY (geo_id) REFERENCES bl_3nf.ce_geo(geo_id),
    FOREIGN KEY (time_id) REFERENCES bl_3nf.ce_time(time_id)
) PARTITION BY RANGE (order_dt);

CREATE MATERIALIZED VIEW IF NOT EXISTS bl_3nf.mv_fact_sales AS
SELECT 
    order_id, order_dt, product_id, supplier_id, buyer_id, branch_id, geo_id, time_id,
    sales_price, revenue, product_cost, profit, insert_dt, source_system, source_entity, source_id,
    shipping_type, shipping_cost
FROM bl_3nf.ce_fact_sales
WHERE insert_dt >= (SELECT COALESCE(MAX(insert_dt), '1900-01-01') FROM bl_3nf.ce_fact_sales) - INTERVAL '1 day';

CREATE UNIQUE INDEX mv_fact_sales_unique_idx 
ON bl_3nf.mv_fact_sales (order_id, order_dt);


DO $$ 
DECLARE 
    start_date DATE := '2022-01-01'; -- Adjust to the earliest order date in your data
    end_date DATE := '2026-01-01'; -- Future-proofing the partitions
    partition_name TEXT;
BEGIN
    WHILE start_date < end_date LOOP
        partition_name := format('ce_fact_sales_%s', to_char(start_date, 'YYYYMM'));

        EXECUTE format('
            CREATE TABLE IF NOT EXISTS bl_3nf.%I
            PARTITION OF bl_3nf.ce_fact_sales 
            FOR VALUES FROM (%L) TO (%L);',
            partition_name, start_date, start_date + INTERVAL '3 months'
        );

        start_date := start_date + INTERVAL '3 months';
    END LOOP;
END $$;