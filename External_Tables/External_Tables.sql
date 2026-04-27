--  Enable Foreign Data Wrapper for reading external CSV files
CREATE EXTENSION IF NOT EXISTS file_fdw;

--  Server for Local Sales CSV
CREATE SERVER IF NOT EXISTS local_sales_server
    FOREIGN DATA WRAPPER file_fdw;

--  Server for International Sales CSV
CREATE SERVER IF NOT EXISTS global_sales_server
    FOREIGN DATA WRAPPER file_fdw;

--  Foreign Table for Local Sales CSV
CREATE FOREIGN TABLE IF NOT EXISTS sa_local.ext_local_sales (
    order_src_id INT,
    order_dt DATE,
    location TEXT,
    state TEXT,
    product_src_id INT,
    product_category TEXT,
    supplier_name TEXT,
    supplier_country TEXT,
    supplier_rating DECIMAL(2,1),
    buyer_src_id INT,
    branch_src_id INT,
    sales_price DECIMAL(10,2),
    revenue DECIMAL(10,2),
    product_cost DECIMAL(10,2),
    profit DECIMAL(10,2)
)
SERVER local_sales_server
OPTIONS (filename 'C:\\temp\\local_sales.csv', format 'csv', header 'true');

--  Foreign Table for International Sales CSV
CREATE FOREIGN TABLE IF NOT EXISTS sa_global.ext_international_sales (
    order_src_id INT,
    order_dt DATE,
    country TEXT,
    region TEXT,
    product_src_id INT,
    product_category TEXT,
    supplier_name TEXT,
    supplier_country TEXT,
    supplier_rating DECIMAL(2,1),
    buyer_src_id INT,
    branch_src_id INT,
    sales_price DECIMAL(10,2),
    revenue DECIMAL(10,2),
    product_cost DECIMAL(10,2),
    profit DECIMAL(10,2)
)
SERVER global_sales_server
OPTIONS (filename 'C:\\temp\\international_sales.csv', format 'csv', header 'true');
