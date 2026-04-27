# DWH Project - ნაბიჯ-ნაბიჯ ტესტირების გზამოთი

## პრერეკვიზიტები
- PostgreSQL ინსტალირებული უნდა გქონდეს (pgAdmin ან psql)
- CSV ფაილები უნდა იყოს აქ: `C:\temp\local_sales.csv` და `C:\temp\international_sales.csv`

---

## STEP 1: Schemas-ის შექმნა

პირველ რიგში შექმენი ყველა schema:

```sql
CREATE SCHEMA IF NOT EXISTS sa_local;
CREATE SCHEMA IF NOT EXISTS sa_global;
CREATE SCHEMA IF NOT EXISTS BL_CL;
CREATE SCHEMA IF NOT EXISTS bl_3nf;
CREATE SCHEMA IF NOT EXISTS bl_dm;
CREATE SCHEMA IF NOT EXISTS bl_log;
CREATE SCHEMA IF NOT EXISTS bl_master;
```

---

## STEP 2: Logging Layer (BL_LOG)

გაუშვი `BL_LOG/BL_LOG.sql` - ეს შექმნის:
- `bl_log.incremental_load_log` - წყაროს ტოპ ტვირთვის ლოგი
- `bl_log.clean_load_log` - Clean layer-ის ლოგი
- `bl_log.procedure_execution_log` - Procedure-ების execution ლოგი
- `bl_log.insert_log()` - logging procedure

```sql
-- pgAdmin-ში: ფაილი -> გახსენი -> BL_LOG/BL_LOG.sql -> Execute
```

---

## STEP 3: External Tables (CSV-დან კითხვა)

გაუშვი `External_Tables/External_Tables.sql`

```sql
-- შეამოწმე რომ მუშაობს:
SELECT * FROM sa_local.ext_local_sales LIMIT 5;
SELECT * FROM sa_global.ext_international_sales LIMIT 5;
```

**თუ შეცდომა გაქვს:**
- შემოწმება: CSV ფაილი არსებობს `C:\temp\` ფოლდერში?
- PostgreSQL-ის service უნდა იყოს გაშვებული

---

## STEP 4: Source Layer (SA)

გაუშვი შემდეგი ფაილები:

### 4.1. SA_LOCAL
```sql
-- გახსენი და გაუშვი: SA_LOCAL/src_local_sales.sql
```

### 4.2. SA_GLOBAL
```sql
-- გახსენი და გაუშვი: SA_GLOBAL/src_international_sales.sql
```

### 4.3. ტესტი: Source Layer-დან ჩატვირთვა
```sql
CALL sa_local.incremental_load_local_sales();
CALL sa_global.incremental_load_international_sales();

-- შეამოწმე რამდენი ჩაიტვირთა:
SELECT COUNT(*) FROM sa_local.src_local_sales;
SELECT COUNT(*) FROM sa_global.src_international_sales;
```

---

## STEP 5: Clean Layer (BL_CL)

### 5.1. ჯერ შექმენი Clean Layer-ის ცხრილები
```sql
-- BL_CL/Tables/CL_Tables.sql
CREATE SCHEMA BL_CL;

CREATE TABLE IF NOT EXISTS BL_CL.CLEAN_LOCAL_SALES (
    order_src_id INT PRIMARY KEY,
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
    profit DECIMAL(10,2),
    source_system TEXT DEFAULT 'LOCAL',
    source_entity TEXT DEFAULT 'LOCAL_SALES',
    insert_dt TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS BL_CL.CLEAN_GLOBAL_SALES (
    order_src_id INT PRIMARY KEY,
    order_dt DATE,
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
    source_system TEXT DEFAULT 'GLOBAL',
    source_entity TEXT DEFAULT 'INTERNATIONAL_SALES',
    insert_dt TIMESTAMP DEFAULT NOW()
);
```

### 5.2. გაუშვი Clean Layer-ის Procedures
```sql
-- BL_CL/Procedures/CL_Local.sql
-- BL_CL/Procedures/CL_Global.sql
```

### 5.3. ტესტი: Clean Layer-დან ჩატვირთვა
```sql
CALL BL_CL.LOAD_SRC_TO_CLEAN_LOCAL();
CALL BL_CL.LOAD_SRC_TO_CLEAN_GLOBAL();

-- შეამოწმე:
SELECT COUNT(*) FROM BL_CL.CLEAN_LOCAL_SALES;
SELECT COUNT(*) FROM BL_CL.CLEAN_GLOBAL_SALES;

-- შეამოწმე ლოგი:
SELECT * FROM BL_LOG.CLEAN_LOAD_LOG;
```

---

## STEP 6: 3NF Layer (BL_3NF)

### 6.1. შექმენი Tables
```sql
-- BL_3NF/Tables/Tables.sql
```

### 6.2. გაუშვი Procedures (BL_3NF/Procedures/)
თითოეული ცალკე:
```sql
CALL bl_3nf.load_ce_geo();
CALL bl_3nf.load_ce_supplier();
CALL bl_3nf.load_ce_buyer();
CALL bl_3nf.load_ce_product_scd2();
CALL bl_3nf.load_ce_branch();
CALL bl_3nf.load_ce_time();
```

### 6.3. Fact Table
```sql
CALL bl_3nf.create_partitions();
CALL bl_3nf.load_fact_sales();
```

### 6.4. ტესტი
```sql
SELECT COUNT(*) FROM bl_3nf.ce_geo;
SELECT COUNT(*) FROM bl_3nf.ce_product_scd2;
SELECT COUNT(*) FROM bl_3nf.ce_fact_sales;
```

---

## STEP 7: Data Mart Layer (BL_DM)

### 7.1. შექმენი Tables
```sql
-- BL_DM/Procedures/Tables/Tables.sql
```

### 7.2. გაუშვი Procedures
```sql
CALL bl_dm.load_dwh_dim_geo();
CALL bl_dm.load_dwh_dim_supplier();
CALL bl_dm.load_dwh_dim_buyer();
CALL bl_dm.load_dwh_dim_branch();
CALL bl_dm.load_dwh_dim_product();
CALL bl_dm.load_dwh_dim_time();
```

### 7.3. Fact Table
```sql
CALL bl_dm.create_dwh_fact_sales_partitions();
CALL bl_dm.load_dwh_fact_sales_incremental();
```

### 7.4. ტესტი
```sql
SELECT COUNT(*) FROM bl_dm.dwh_dim_product;
SELECT COUNT(*) FROM bl_dm.dwh_fact_sales;
```

---

## STEP 8: Full Load (BL_Master)

```sql
CALL bl_master.execute_full_dwh_load();
```

### შედეგის შემოწმება:
```sql
SELECT * FROM bl_log.procedure_execution_log ORDER BY execution_time DESC;
SELECT * FROM bl_log.incremental_load_log;
```

---

## Პრობლემების გადაჭრა

### შეცდომა: "relation does not exist"
```
Schema არ არსებობს. უნდა შექმნა:
CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;
```

### შეცდომა: "function/file not found"
```
External Table-ს ვერ პოულობს. შეამოწმე:
1. CSV ფაილი არსებობს C:\temp\ ფოლდერში?
2. PostgreSQL service გაშვებულია?
```

### შეცდომა: "permission denied"
```
PostgreSQL-ს უნდა ჰქონდეს წვდომა C:\temp\ ფოლდერზე.
შესაძლოა საჭირო იყო�:
ALTER TABLE ... OPTIONS (filename '/tmp/...');
```

---

## CSV ფაილების სტრუქტურა

### local_sales.csv:
```csv
order_src_id,order_dt,location,state,product_src_id,product_category,supplier_name,supplier_country,supplier_rating,buyer_src_id,branch_src_id,sales_price,revenue,product_cost,profit
```

### international_sales.csv:
```csv
order_src_id,order_dt,country,region,product_src_id,product_category,supplier_name,supplier_country,supplier_rating,buyer_src_id,branch_src_id,sales_price,revenue,product_cost,profit
```

---

## Შეჯამება - Execution Order

```
1. BL_LOG/BL_LOG.sql                      ← Logging setup
2. External_Tables/External_Tables.sql    ← CSV connection
3. SA_LOCAL/src_local_sales.sql          ← Local source
4. SA_GLOBAL/src_international_sales.sql ← Global source
5. BL_CL/Tables/CL_Tables.sql             ← Clean tables
6. BL_CL/Procedures/CL_Local.sql         ← Local clean
7. BL_CL/Procedures/CL_Global.sql        ← Global clean
8. BL_3NF/Tables/Tables.sql              ← 3NF tables
9. BL_3NF/Procedures/*.sql               ← 3NF procedures
10. BL_DM/Procedures/Tables/Tables.sql   ← DM tables
11. BL_DM/Procedures/*.sql               ← DM procedures
12. BL_Master/BL_Master.sql              ← Full load
```