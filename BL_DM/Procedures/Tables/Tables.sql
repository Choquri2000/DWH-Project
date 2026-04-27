--  Geographic Dimension Table
CREATE TABLE bl_dm.dwh_dim_geo (
    geo_id BIGINT PRIMARY KEY,
    country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    city VARCHAR(50) NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Supplier Dimension Table
CREATE TABLE bl_dm.dwh_dim_supplier (
    supplier_id BIGINT PRIMARY KEY,
    supplier_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    supplier_country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_rating DECIMAL(2,1) CHECK (supplier_rating BETWEEN 1.0 AND 5.0) DEFAULT 0.0,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Buyer Dimension Table
CREATE TABLE bl_dm.dwh_dim_buyer (
    buyer_id BIGINT PRIMARY KEY,
    buyer_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    buyer_country VARCHAR(50) DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--  Branch Dimension Table (SCD1)
CREATE TABLE bl_dm.dwh_dim_branch (
    branch_id BIGINT PRIMARY KEY,
    branch_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    branch_region TEXT NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ✅ Product Dimension Table (SCD2)
CREATE TABLE bl_dm.dwh_dim_product (
    product_id BIGINT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    product_category VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_id BIGINT NOT NULL,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES bl_dm.dwh_dim_supplier(supplier_id)
);

--  Time Dimension Table
CREATE TABLE bl_dm.dwh_dim_time (
    time_id BIGINT PRIMARY KEY,
    order_date DATE UNIQUE NOT NULL,
    year INT NOT NULL DEFAULT 2000,
    quarter INT NOT NULL DEFAULT 1,
    month INT NOT NULL DEFAULT 1,
    week INT NOT NULL DEFAULT 1,
    day INT NOT NULL DEFAULT 1,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bl_dm.dwh_fact_sales (
    fact_id BIGINT GENERATED ALWAYS AS IDENTITY,
    order_id BIGINT NOT NULL,
    order_dt DATE NOT NULL,
    product_id BIGINT NOT NULL,
    supplier_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    branch_id BIGINT NOT NULL,
    geo_id BIGINT NOT NULL,
    time_id BIGINT NOT NULL,
    sales_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    revenue DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    product_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    profit DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system VARCHAR(50) NOT NULL DEFAULT 'N/A',
    source_entity VARCHAR(50) NOT NULL DEFAULT 'N/A',
    source_id VARCHAR(50) NOT NULL DEFAULT 'N/A',
    shipping_type TEXT DEFAULT 'N/A',
    shipping_cost DECIMAL(10,2) DEFAULT 0.00,
    PRIMARY KEY (order_id, order_dt), 
    FOREIGN KEY (product_id) REFERENCES bl_dm.dwh_dim_product(product_id),
    FOREIGN KEY (supplier_id) REFERENCES bl_dm.dwh_dim_supplier(supplier_id),
    FOREIGN KEY (buyer_id) REFERENCES bl_dm.dwh_dim_buyer(buyer_id),
    FOREIGN KEY (branch_id) REFERENCES bl_dm.dwh_dim_branch(branch_id),
    FOREIGN KEY (geo_id) REFERENCES bl_dm.dwh_dim_geo(geo_id),
    FOREIGN KEY (time_id) REFERENCES bl_dm.dwh_dim_time(time_id)
) PARTITION BY RANGE (order_dt);

CREATE MATERIALIZED VIEW IF NOT EXISTS bl_dm.mv_fact_sales AS
SELECT 
    order_id, order_dt, product_id, supplier_id, buyer_id, branch_id, geo_id, time_id,
    sales_price, revenue, product_cost, profit, shipping_type, shipping_cost, insert_dt, 
    source_system, source_entity, source_id
FROM bl_dm.dwh_fact_sales
WHERE insert_dt >= (SELECT COALESCE(MAX(insert_dt), '1900-01-01') FROM bl_dm.dwh_fact_sales) - INTERVAL '1 day';


CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_fact_sales_unique
ON bl_dm.mv_fact_sales (order_id, order_dt);

CREATE INDEX IF NOT EXISTS idx_fact_sales_order ON bl_dm.dwh_fact_sales (order_id, order_dt);
CREATE INDEX IF NOT EXISTS idx_ce_fact_sales_order ON bl_3nf.ce_fact_sales (order_id, order_dt);