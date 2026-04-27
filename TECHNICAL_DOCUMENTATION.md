# DWH Project - Technical Documentation

## Project Overview

Enterprise Data Warehouse implementation using PostgreSQL with ETL pipeline processing local and international sales data through multiple business logic layers.

**Data Sources:**
- `local_Wardrobe_sales.csv` - Local sales data (50,000 rows)
- `international_Wardrobe_sales.csv` - International sales data (1,000,000 rows)

---

## Architecture Layers

```
CSV Files → External Tables → Source Layer → Clean Layer → 3NF Layer → Data Mart
```

| Layer | Schema | Purpose |
|-------|--------|---------|
| Source | `sa_local`, `sa_global` | Raw data ingestion with incremental tracking |
| Clean | `BL_CL` | Data standardization and source tagging |
| Core Enterprise | `bl_3nf` | 3NF dimensional model with SCD support |
| Data Mart | `bl_dm` | Denormalized reporting tables |
| Logging | `bl_log` | ETL execution tracking |

---

## Database Schemas

```sql
CREATE SCHEMA sa_local;
CREATE SCHEMA sa_global;
CREATE SCHEMA BL_CL;
CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;
CREATE SCHEMA bl_log;
CREATE SCHEMA bl_master;
```

---

## Layer 1: Source Layer (SA)

### SA_LOCAL - Local Sales Source

**Table: `sa_local.src_local_sales`**
```sql
CREATE TABLE sa_local.src_local_sales (
    order_src_id INT PRIMARY KEY,
    order_dt DATE NOT NULL,
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
    profit DECIMAL(10,2),
    insert_dt TIMESTAMP DEFAULT NOW()
);
```

**CSV File Structure (local_Wardrobe_sales.csv):**
```
Order_ID, Order_Date, Location, State, Product_ID, Product_Category,
Supplier_Name, Supplier_Country, Supplier_Rating, Buyer_ID, Branch_ID,
Sales_Price, Revenue, Product_Cost, Profit
```

### SA_GLOBAL - International Sales Source

**Table: `sa_global.src_international_sales`**
```sql
CREATE TABLE sa_global.src_international_sales (
    order_src_id INT PRIMARY KEY,
    order_dt DATE NOT NULL,
    country TEXT,
    city TEXT,
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
    profit DECIMAL(10,2),
    shipping_type TEXT,
    shipping_cost DECIMAL(10,2),
    insert_dt TIMESTAMP DEFAULT NOW()
);
```

**CSV File Structure (international_Wardrobe_sales.csv):**
```
Order_ID, Order_Date, Country, City, Product_ID, Product_Category,
Supplier_Name, Supplier_Country, Supplier_Rating, Buyer_ID, Branch_ID,
Sales_Price, Revenue, Product_Cost, Profit, Shipping_Type, Shipping_Cost
```

---

## Layer 2: Clean Layer (BL_CL)

### CLEAN_LOCAL_SALES

```sql
CREATE TABLE BL_CL.CLEAN_LOCAL_SALES (
    ORDER_SRC_ID INT PRIMARY KEY,
    ORDER_DT DATE NOT NULL,
    LOCATION TEXT,
    STATE TEXT,
    PRODUCT_SRC_ID INT,
    PRODUCT_CATEGORY TEXT,
    SUPPLIER_NAME TEXT,
    SUPPLIER_COUNTRY TEXT,
    SUPPLIER_RATING DECIMAL(2,1),
    BUYER_SRC_ID INT,
    BRANCH_SRC_ID INT,
    SALES_PRICE DECIMAL(10,2),
    REVENUE DECIMAL(10,2),
    PRODUCT_COST DECIMAL(10,2),
    PROFIT DECIMAL(10,2),
    SOURCE_SYSTEM TEXT DEFAULT 'SRC',
    SOURCE_ENTITY TEXT DEFAULT 'LOCAL',
    INSERT_DT TIMESTAMP DEFAULT NOW()
);
```

### CLEAN_GLOBAL_SALES

```sql
CREATE TABLE BL_CL.CLEAN_GLOBAL_SALES (
    ORDER_SRC_ID INT PRIMARY KEY,
    ORDER_DT DATE NOT NULL,
    COUNTRY TEXT,
    CITY TEXT,
    PRODUCT_SRC_ID INT,
    PRODUCT_CATEGORY TEXT,
    SUPPLIER_NAME TEXT,
    SUPPLIER_COUNTRY TEXT,
    SUPPLIER_RATING DECIMAL(2,1),
    BUYER_SRC_ID INT,
    BRANCH_SRC_ID INT,
    SALES_PRICE DECIMAL(10,2),
    REVENUE DECIMAL(10,2),
    PRODUCT_COST DECIMAL(10,2),
    PROFIT DECIMAL(10,2),
    SHIPPING_TYPE TEXT,
    SHIPPING_COST DECIMAL(10,2),
    SOURCE_SYSTEM TEXT DEFAULT 'SRC',
    SOURCE_ENTITY TEXT DEFAULT 'GLOBAL',
    INSERT_DT TIMESTAMP DEFAULT NOW()
);
```

---

## Layer 3: Core Enterprise (BL_3NF)

### Dimension Tables

#### GEO Dimension
```sql
CREATE TABLE bl_3nf.ce_geo (
    geo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    city VARCHAR(50) NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Supplier Dimension (SCD1)
```sql
CREATE TABLE bl_3nf.ce_supplier (
    supplier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    supplier_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    supplier_country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_rating DECIMAL(2,1) CHECK (supplier_rating BETWEEN 1.0 AND 5.0) DEFAULT 0.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Buyer Dimension
```sql
CREATE TABLE bl_3nf.ce_buyer (
    buyer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    buyer_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    buyer_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    buyer_country VARCHAR(50) DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Branch Dimension (SCD1)
```sql
CREATE TABLE bl_3nf.ce_branch (
    branch_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_src_id VARCHAR(50) UNIQUE NOT NULL DEFAULT 'N/A',
    branch_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    branch_region TEXT NOT NULL DEFAULT 'N/A',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Product Dimension (SCD2 - Historical Tracking)
```sql
CREATE TABLE bl_3nf.ce_product_scd2 (
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
```

#### Time Dimension
```sql
CREATE TABLE bl_3nf.ce_time (
    time_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_date DATE UNIQUE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    week INT NOT NULL,
    day INT NOT NULL,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Fact Table

```sql
CREATE TABLE bl_3nf.ce_fact_sales (
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
```

### Partitions (Quarterly)

```sql
-- Creates partitions from 2022 to 2026
DO $$
DECLARE
    start_date DATE := '2022-01-01';
    end_date DATE := '2026-01-01';
BEGIN
    WHILE start_date < end_date LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS bl_3nf.ce_fact_sales_%s PARTITION OF bl_3nf.ce_fact_sales FOR VALUES FROM (%L) TO (%L)',
            to_char(start_date, 'YYYYMM'),
            start_date,
            start_date + INTERVAL '3 months'
        );
        start_date := start_date + INTERVAL '3 months';
    END LOOP;
END $$;
```

---

## Layer 4: Data Mart (BL_DM)

### Dimension Tables

```sql
-- GEO
CREATE TABLE bl_dm.dwh_dim_geo (
    geo_id BIGINT PRIMARY KEY,
    country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    city VARCHAR(50) NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Supplier
CREATE TABLE bl_dm.dwh_dim_supplier (
    supplier_id BIGINT PRIMARY KEY,
    supplier_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    supplier_country VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_rating DECIMAL(2,1) DEFAULT 0.0,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Buyer
CREATE TABLE bl_dm.dwh_dim_buyer (
    buyer_id BIGINT PRIMARY KEY,
    buyer_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    buyer_country VARCHAR(50) DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Branch
CREATE TABLE bl_dm.dwh_dim_branch (
    branch_id BIGINT PRIMARY KEY,
    branch_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    branch_region TEXT NOT NULL DEFAULT 'N/A',
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product
CREATE TABLE bl_dm.dwh_dim_product (
    product_id BIGINT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL DEFAULT 'N/A',
    product_category VARCHAR(50) NOT NULL DEFAULT 'N/A',
    supplier_id BIGINT NOT NULL,
    insert_dt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES bl_dm.dwh_dim_supplier(supplier_id)
);

-- Time
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
```

### Fact Table

```sql
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
```

---

## Layer 5: Logging (BL_LOG)

```sql
-- Incremental Load Log
CREATE TABLE bl_log.incremental_load_log (
    table_name TEXT PRIMARY KEY,
    last_order_date DATE DEFAULT '1900-01-01',
    inserted_rows INT DEFAULT 0,
    status TEXT DEFAULT 'SUCCESS',
    error_message TEXT DEFAULT NULL
);

-- Procedure Execution Log
CREATE TABLE bl_log.procedure_execution_log (
    id SERIAL PRIMARY KEY,
    procedure_name TEXT,
    execution_time TIMESTAMP DEFAULT NOW(),
    rows_inserted INT DEFAULT 0,
    status_message TEXT DEFAULT 'SUCCESS'
);

-- Clean Load Log
CREATE TABLE bl_log.clean_load_log (
    table_name TEXT PRIMARY KEY,
    last_order_date DATE DEFAULT '1900-01-01',
    inserted_rows INT DEFAULT 0,
    status TEXT DEFAULT 'SUCCESS',
    error_message TEXT DEFAULT NULL
);

-- Insert Log Procedure
CREATE PROCEDURE bl_log.insert_log(
    p_procedure_name TEXT,
    p_rows_inserted INT,
    p_status_message TEXT
);
```

---

## Key Features

### 1. Incremental Loading
Tracks last loaded date to only load new data on subsequent runs.

### 2. SCD Type 2 (Slowly Changing Dimensions)
Product dimension tracks historical changes with `start_dt`, `end_dt`, and `is_active` columns.

### 3. Table Partitioning
Fact tables partitioned quarterly for query performance.

### 4. Materialized Views
Auto-refreshed views for recent data access.

### 5. ETL Logging
Full execution tracking and error logging for monitoring.

---

## Execution Order

```
1. BL_LOG/BL_LOG.sql
2. External_Tables/External_Tables.sql
3. SA_LOCAL/src_local_sales.sql
4. SA_GLOBAL/src_international_sales.sql
5. BL_CL/Tables/CL_Tables.sql
6. BL_3NF/Tables/Tables.sql
7. BL_DM/Procedures/Tables/Tables.sql
8. BL_Master/BL_Master.sql
```

---

## Master Procedure

```sql
CALL bl_master.execute_full_dwh_load();
```

Executes:
1. Source layer loads (Local + International)
2. Clean layer loads
3. 3NF dimension loads
4. 3NF fact loads with partitions
5. Data Mart dimension loads
6. Data Mart fact loads