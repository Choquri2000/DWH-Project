# DWH Project: ტესტირების ნაბიჯ-ნაბიჯ სახელმძღვანელო

ეს სახელმძღვანელო აღწერს, როგორ ავაწყოთ Data Warehouse ნულიდან და როგორ შევამოწმოთ თითოეული layer-ის ჩატვირთვა.

## წინაპირობები

- დაინსტალირებული PostgreSQL 14+ (pgAdmin ან psql) და `file_fdw` extension.
- CSV ფაილები უნდა მდებარეობდეს შემდეგ მისამართებზე: `C:\temp\local_sales.csv` და `C:\temp\international_sales.csv`.

---

## ნაბიჯი 1: schema-ების შექმნა

პირველ რიგში შექმენით ყველა schema:

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

## ნაბიჯი 2: ლოგირების layer (BL_LOG)

გაუშვით `BL_LOG/BL_LOG.sql`. სკრიპტი შექმნის:
- `bl_log.incremental_load_log`: source layer-ის incremental load-ის ლოგი (watermark)
- `bl_log.clean_load_log`: clean layer-ის ჩატვირთვის ლოგი
- `bl_log.procedure_execution_log`: procedure-ების შესრულების ლოგი
- `bl_log.insert_log()`: ლოგში ჩანაწერის დამატების procedure

```sql
-- pgAdmin-ში: File → Open → BL_LOG/BL_LOG.sql → Execute
```

---

## ნაბიჯი 3: external table-ები (CSV-დან წაკითხვა)

გაუშვით `External_Tables/External_Tables.sql`.

```sql
-- შეამოწმეთ, რომ მონაცემები იკითხება:
SELECT * FROM sa_local.ext_local_sales LIMIT 5;
SELECT * FROM sa_global.ext_international_sales LIMIT 5;
```

**შეცდომის შემთხვევაში შეამოწმეთ:**
- არსებობს თუ არა CSV ფაილები `C:\temp\` საქაღალდეში;
- გაშვებულია თუ არა PostgreSQL-ის service.

---

## ნაბიჯი 4: source layer (SA)

გაუშვით შემდეგი ფაილები:

### 4.1. SA_LOCAL
```sql
-- გახსენით და გაუშვით: SA_LOCAL/src_local_sales.sql
```

### 4.2. SA_GLOBAL
```sql
-- გახსენით და გაუშვით: SA_GLOBAL/src_international_sales.sql
```

### 4.3. შემოწმება: source layer-ის ჩატვირთვა
```sql
CALL sa_local.incremental_load_local_sales();
CALL sa_global.incremental_load_international_sales();

-- შეამოწმეთ ჩატვირთული ჩანაწერების რაოდენობა:
SELECT COUNT(*) FROM sa_local.src_local_sales;
SELECT COUNT(*) FROM sa_global.src_international_sales;
```

---

## ნაბიჯი 5: clean layer (BL_CL)

### 5.1. შექმენით clean layer-ის ცხრილები
გაუშვით `BL_CL/Tables/CL_Tables.sql`. სკრიპტი შექმნის შემდეგ ცხრილებს:

```sql
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

### 5.2. შექმენით clean layer-ის procedure-ები
```sql
-- BL_CL/Procedures/CL_Local.sql
-- BL_CL/Procedures/CL_Global.sql
```

### 5.3. შემოწმება: clean layer-ის ჩატვირთვა
```sql
CALL BL_CL.LOAD_SRC_TO_CLEAN_LOCAL();
CALL BL_CL.LOAD_SRC_TO_CLEAN_GLOBAL();

-- შეამოწმეთ ჩანაწერების რაოდენობა:
SELECT COUNT(*) FROM BL_CL.CLEAN_LOCAL_SALES;
SELECT COUNT(*) FROM BL_CL.CLEAN_GLOBAL_SALES;

-- შეამოწმეთ ლოგი:
SELECT * FROM BL_LOG.CLEAN_LOAD_LOG;
```

---

## ნაბიჯი 6: 3NF layer (BL_3NF)

### 6.1. შექმენით ცხრილები
```sql
-- BL_3NF/Tables/Tables.sql
-- სკრიპტი ასევე ქმნის ce_fact_sales-ის კვარტალურ partition-ებს (DO ბლოკი).
```

### 6.2. გაუშვით procedure-ები (BL_3NF/Procedures/)
თითოეული ცალ-ცალკე:
```sql
CALL bl_3nf.load_ce_geo();
CALL bl_3nf.load_ce_supplier();
CALL bl_3nf.load_ce_buyer();
CALL bl_3nf.load_ce_product_scd2();
CALL bl_3nf.load_ce_branch();
CALL bl_3nf.load_ce_time();
```

> **შენიშვნა:** `bl_3nf.load_ce_buyer()` procedure რეპოზიტორიაში ჯერ არ არის განსაზღვრული. ფაილი `BL_3NF/Procedures/load_dwh_dim_buyer.sql` შეიცავს `bl_dm.load_dwh_dim_buyer()`-ს. ეს ცნობილი შეზღუდვაა და README-შია აღწერილი.

### 6.3. fact table
```sql
CALL bl_3nf.create_partitions();
CALL bl_3nf.load_fact_sales();
```

> **შენიშვნა:** `bl_3nf.create_partitions()` procedure სახით არ არსებობს. partition-ები 6.1 ნაბიჯში უკვე შეიქმნა `DO` ბლოკით, ამიტომ საკმარისია `CALL bl_3nf.load_fact_sales();`-ის გაშვება. partition-ები 2022-01-01-დან 2026-01-01-მდე პერიოდს მოიცავს.

### 6.4. შემოწმება
```sql
SELECT COUNT(*) FROM bl_3nf.ce_geo;
SELECT COUNT(*) FROM bl_3nf.ce_product_scd2;
SELECT COUNT(*) FROM bl_3nf.ce_fact_sales;
```

---

## ნაბიჯი 7: data mart layer (BL_DM)

### 7.1. შექმენით ცხრილები
```sql
-- BL_DM/Procedures/Tables/Tables.sql
```

### 7.2. გაუშვით procedure-ები
```sql
CALL bl_dm.load_dwh_dim_geo();
CALL bl_dm.load_dwh_dim_supplier();
CALL bl_dm.load_dwh_dim_buyer();
CALL bl_dm.load_dwh_dim_branch();
CALL bl_dm.load_dwh_dim_product();
CALL bl_dm.load_dwh_dim_time();
```

### 7.3. fact table
```sql
CALL bl_dm.create_dwh_fact_sales_partitions();
CALL bl_dm.load_dwh_fact_sales_incremental();
```

### 7.4. შემოწმება
```sql
SELECT COUNT(*) FROM bl_dm.dwh_dim_product;
SELECT COUNT(*) FROM bl_dm.dwh_fact_sales;
```

---

## ნაბიჯი 8: სრული ჩატვირთვა (BL_Master)

```sql
CALL bl_master.execute_full_dwh_load();
```

### შედეგის შემოწმება
```sql
SELECT * FROM bl_log.procedure_execution_log ORDER BY execution_time DESC;
SELECT * FROM bl_log.incremental_load_log;
```

---

## პრობლემების მოგვარება

### შეცდომა: "relation does not exist"
შესაბამისი schema ან ცხრილი არ არსებობს. შექმენით schema (ნაბიჯი 1) და გაუშვით შესაბამისი layer-ის ცხრილების სკრიპტი:
```sql
CREATE SCHEMA IF NOT EXISTS bl_3nf;
CREATE SCHEMA IF NOT EXISTS bl_dm;
```

### შეცდომა: "could not open file"
external table CSV ფაილს ვერ პოულობს. შეამოწმეთ:
1. არსებობს თუ არა CSV ფაილი `C:\temp\` საქაღალდეში;
2. გაშვებულია თუ არა PostgreSQL-ის service.

### შეცდომა: "permission denied"
PostgreSQL-ის service-ს უნდა ჰქონდეს `C:\temp\` საქაღალდის წაკითხვის უფლება. საჭიროების შემთხვევაში ფაილის მისამართი შეცვალეთ:
```sql
ALTER FOREIGN TABLE sa_local.ext_local_sales OPTIONS (SET filename '/tmp/local_sales.csv');
```

---

## CSV ფაილების სტრუქტურა

### local_sales.csv
```csv
order_src_id,order_dt,location,state,product_src_id,product_category,supplier_name,supplier_country,supplier_rating,buyer_src_id,branch_src_id,sales_price,revenue,product_cost,profit
```

### international_sales.csv
```csv
order_src_id,order_dt,country,region,product_src_id,product_category,supplier_name,supplier_country,supplier_rating,buyer_src_id,branch_src_id,sales_price,revenue,product_cost,profit
```

---

## შეჯამება: სკრიპტების გაშვების თანმიმდევრობა

```
 1. BL_LOG/BL_LOG.sql                      ← ლოგირების ცხრილები
 2. External_Tables/External_Tables.sql    ← CSV-თან კავშირი
 3. SA_LOCAL/src_local_sales.sql           ← ადგილობრივი წყარო
 4. SA_GLOBAL/src_international_sales.sql  ← საერთაშორისო წყარო
 5. BL_CL/Tables/CL_Tables.sql             ← clean layer-ის ცხრილები
 6. BL_CL/Procedures/CL_Local.sql          ← ადგილობრივი მონაცემების გაწმენდა
 7. BL_CL/Procedures/CL_Global.sql         ← საერთაშორისო მონაცემების გაწმენდა
 8. BL_3NF/Tables/Tables.sql               ← 3NF ცხრილები და partition-ები
 9. BL_3NF/Procedures/*.sql                ← 3NF procedure-ები
10. BL_DM/Procedures/Tables/Tables.sql     ← data mart-ის ცხრილები
11. BL_DM/Procedures/*.sql                 ← data mart-ის procedure-ები
12. BL_Master/BL_Master.sql                ← სრული ჩატვირთვა
```
