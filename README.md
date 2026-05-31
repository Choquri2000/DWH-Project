<!--
  DWH Project – Data Warehouse Implementation
  Bilingual README – Paste into Choquri2000/DWH-Project
-->

<p align="center">
  <a href="#english">🇺🇸 English</a> &nbsp;•&nbsp;
  <a href="#georgian">🇬🇪 ქართული</a>
</p>

<hr>

<!-- ############################## ENGLISH ############################## -->
<a id="english"></a>

<h1 align="center">DWH Project – Data Warehouse Implementation</h1>
<p align="center"><em>Kimball dimensional modeling · Incremental ETL · Production-grade SQL</em></p>

---

### 📋 Overview

Multi-layer data warehouse processing local and international sales data from CSV files. Built on **Kimball dimensional modeling** methodology with **SCD Type 2** historical tracking, **incremental loading**, and **query-optimized star schemas** — a production-grade foundation for analytics and DS workloads.

**Engine:** PostgreSQL 14+ | **Code:** 100% PL/pgSQL

---

### 🏗️ Architecture

```
CSV Files
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  External Tables   (file-level access via FDW)                      │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Source Layer      (sa_local, sa_global) — raw import, unchanged    │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Clean Layer       (BL_CL) — standardization, dedup, type casting   │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Core Layer (3NF)  (bl_3nf) — dimensions + facts, SCD Type 2       │
└─────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Data Mart         (bl_dm) — star schema, materialized views       │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 🔍 SQL Window Functions in Action

Used throughout the pipeline for deduplication, running aggregates, and change detection:

**ROW_NUMBER() — Source dedup:**
```sql
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY sale_id ORDER BY load_timestamp DESC
  ) AS rn
  FROM sa_local.src_sales
)
DELETE FROM sa_local.src_sales
WHERE (sale_id, load_timestamp) IN (
  SELECT sale_id, load_timestamp FROM ranked WHERE rn > 1
);
```

**LAG() — SCD Type 2 change detection:**
```sql
SELECT product_id, product_name, unit_price,
       LAG(unit_price) OVER (
         PARTITION BY product_id ORDER BY effective_date
       ) AS prev_price
FROM bl_3nf.dim_products_scd;
```

**SUM() OVER — Running totals in Data Mart:**
```sql
SELECT payment_date, payment_amount,
       SUM(payment_amount) OVER (
         ORDER BY payment_date
       ) AS cumulative_revenue
FROM bl_dm.v_fact_payments;
```

---

### ⚡ Incremental Loading

High-watermark pattern — only new/changed records are processed:

```
1. Read last max load_id from bl_log.control_table
2. Extract source rows WHERE load_id > watermark
3. MERGE into BL_CL (INSERT new, UPDATE changed)
4. MERGE into bl_3nf dimensions (SCD Type 2 logic)
5. INSERT into bl_dm fact tables
6. Update watermark in bl_log.control_table
```

Execution:
```sql
CALL bl_master.execute_full_dwh_load();
```

---

### 📈 Scalability Design

| Technique | Implementation |
|-----------|---------------|
| **Table Partitioning** | Fact tables partitioned by quarter (`PARTITION BY RANGE (payment_date)`) |
| **Materialized Views** | Pre-aggregated daily/ monthly/ quarterly snapshots, refreshed via cron |
| **Indexing Strategy** | B-tree on FK columns, BRIN on date columns for partitioned fact tables |
| **ETL Monitoring** | Full execution log (`bl_log.procedure_execution_log`) with duration, row counts, error codes |

---

### 🚀 Setup

```sql
CREATE DATABASE dwh_project;

CREATE SCHEMA sa_local;   CREATE SCHEMA sa_global;
CREATE SCHEMA BL_CL;      CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;      CREATE SCHEMA bl_log;
CREATE SCHEMA bl_master;
```

Run SQL files in order:
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

### 🔄 Monitoring

```sql
-- Check last ETL run
SELECT * FROM bl_log.procedure_execution_log ORDER BY start_time DESC LIMIT 5;

-- Verify row counts across layers
SELECT 'sa_local' AS layer, COUNT(*) FROM sa_local.src_sales
UNION ALL
SELECT 'bl_dm', COUNT(*) FROM bl_dm.fact_sales;
```

---

<hr>

<!-- ############################## GEORGIAN ############################## -->
<a id="georgian"></a>

<h1 align="center">DWH პროექტი – მონაცემთა საწყობის იმპლემენტაცია</h1>
<p align="center"><em>Kimball-ის მოდელირება · ინკრემენტალური ETL · საწარმოო SQL</em></p>

---

### 📋 მიმოხილვა

მრავალფენიანი მონაცემთა საწყობი, რომელიც ამუშავებს ადგილობრივი და საერთაშორისო გაყიდვების მონაცემებს CSV ფაილებიდან. დაფუძნებულია **Kimball-ის განზომილებიანი მოდელირების** მეთოდოლოგიაზე, **SCD Type 2** ისტორიული თრექინგით, **ინკრემენტალური ჩატვირთვით** და ოპტიმიზებული ვარსკვლავური სქემებით.

**ძრავა:** PostgreSQL 14+ | **კოდი:** 100% PL/pgSQL

---

### 🏗️ არქიტექტურა

```
CSV ფაილები → External Tables → SA (raw) → BL_CL (clean) → bl_3nf (core) → bl_dm (mart)
```

---

### 🔍 SQL Window Functions მაგალითები

**ROW_NUMBER() — დუბლიკატების მოცილება:**
```sql
WITH ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY sale_id ORDER BY load_timestamp DESC
  ) AS rn
  FROM sa_local.src_sales
)
DELETE FROM sa_local.src_sales WHERE rn > 1;
```

**LAG() — SCD Type 2 ცვლილებების აღმოჩენა:**
```sql
SELECT product_id, unit_price,
       LAG(unit_price) OVER (
         PARTITION BY product_id ORDER BY effective_date
       ) AS prev_price
FROM bl_3nf.dim_products_scd;
```

**SUM() OVER — კუმულაციური ჯამი:**
```sql
SELECT payment_date, payment_amount,
       SUM(payment_amount) OVER (ORDER BY payment_date) AS cumulative_revenue
FROM bl_dm.v_fact_payments;
```

---

### ⚡ ინკრემენტალური ჩატვირთვა

High-watermark პატერნი — მხოლოდ ახალი/შეცვლილი ჩანაწერები მუშავდება:

```
1. წინა max load_id წაკითხვა bl_log.control_table-დან
2. წყაროდან იმ ჩანაწერების ამოღება, სადაც load_id > watermark
3. MERGE BL_CL-ში (INSERT + UPDATE)
4. MERGE bl_3nf განზომილებებში (SCD Type 2)
5. INSERT bl_dm fact ცხრილებში
6. watermark-ის განახლება
```

```sql
CALL bl_master.execute_full_dwh_load();
```

---

### 📈 მასშტაბირება

| ტექნიკა | აღწერა |
|---------|---------|
| **Partitioning** | Fact ცხრილების კვარტალური დაყოფა `RANGE (payment_date)` |
| **Materialized Views** | წინასწარ აგრეგირებული ყოველდღიური/თვიური/კვარტალური სნეპშოტები, განახლება cron-ით |
| **ინდექსები** | B-tree FK სვეტებზე, BRIN თარიღის სვეტებზე |
| **მონიტორინგი** | `bl_log.procedure_execution_log` — ხანგრძლივობა, რაოდენობა, შეცდომები |

---

### 🚀 გაშვება

```sql
CREATE DATABASE dwh_project;
-- შექმენით 7 სქემა (sa_local, sa_global, BL_CL, bl_3nf, bl_dm, bl_log, bl_master)
-- გაუშვით SQL ფაილები 1-დან 8-მდე თანმიმდევრობით
```

```sql
CALL bl_master.execute_full_dwh_load();
SELECT * FROM bl_log.procedure_execution_log ORDER BY start_time DESC LIMIT 5;
```
