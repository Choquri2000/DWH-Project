<p align="center">
  <a href="#english">🇺🇸 English</a> &nbsp;•&nbsp;
  <a href="#georgian">🇬🇪 ქართული</a>
</p>

<hr>

<!-- ############################## ENGLISH ############################## -->
<a id="english"></a>

<h1 align="center">DWH Project: Sales Data Warehouse</h1>
<p align="center"><em>Layered architecture · 3NF core + star schema · SCD Type 2 · Incremental loading · PL/pgSQL</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/PostgreSQL-14%2B-336791" alt="PostgreSQL 14+">
  <img src="https://img.shields.io/badge/code-PL%2FpgSQL-blue" alt="PL/pgSQL">
</p>

---

### Overview

A multi-layer Data Warehouse that integrates two sales sources, local sales (~50,000 rows) and international sales (~1,000,000 rows), from CSV files into an analytical star schema. The whole ETL process is written in PL/pgSQL stored procedures. It covers:
- incremental loading
- SCD Type 2 history for products
- range-partitioned fact tables
- execution logging at every layer

---

### Architecture

```
CSV files (local_sales.csv, international_sales.csv)
   │  file_fdw
   ▼
External tables       sa_local.ext_local_sales, sa_global.ext_international_sales
   │  incremental load (order_dt watermark)
   ▼
Source layer (SA)     sa_local.src_local_sales, sa_global.src_international_sales
   │  deduplication, source tagging
   ▼
Clean layer (BL_CL)   BL_CL.CLEAN_LOCAL_SALES, BL_CL.CLEAN_GLOBAL_SALES
   │  surrogate keys, normalisation, SCD Type 2
   ▼
Core layer (BL_3NF)   ce_geo, ce_supplier, ce_buyer, ce_branch, ce_product_scd2, ce_time, ce_fact_sales
   │  star schema, upserts, partitioning
   ▼
Data mart (BL_DM)     dwh_dim_* dimensions, dwh_fact_sales, mv_fact_sales
```

| Schema | Role |
|--------|------|
| `sa_local`, `sa_global` | Raw source data, loaded incrementally from the external tables |
| `BL_CL` | Cleaned, deduplicated records tagged with `source_system` / `source_entity` |
| `bl_3nf` | Normalised core model (3NF) with SCD Type 2 product history |
| `bl_dm` | Star schema for reporting: six dimensions and a partitioned fact table |
| `bl_log` | Watermarks and procedure execution log |
| `bl_master` | Orchestration procedure for the full load |

---

### Key Techniques

**Incremental loading (watermark pattern)**
- Every source and clean-layer load reads its last loaded `order_dt` from `bl_log.incremental_load_log` or `bl_log.clean_load_log`.
- It processes only newer records. `ON CONFLICT ... DO UPDATE` keeps re-runs idempotent.
- It then advances the watermark and records the row count and status. On failure, the status is set to `FAILED` together with the error message.

**SCD Type 2**: `bl_3nf.ce_product_scd2`
- When a product's category or supplier changes, the current version is closed and a new active version is inserted:

```sql
UPDATE bl_3nf.ce_product_scd2
SET end_dt = CURRENT_DATE - INTERVAL '1 day', is_active = 'N'
WHERE ... AND end_dt = '9999-12-31'
  AND (product_category <> p.product_category OR supplier_id <> ...);

INSERT INTO bl_3nf.ce_product_scd2 (..., start_dt, end_dt, is_active, ...)
SELECT ..., CURRENT_DATE, '9999-12-31', 'Y', ...;
```

**Data mart loading**: `bl_dm`
- **Dimensions:** geo, buyer, branch and time are upserted with `INSERT ... ON CONFLICT DO UPDATE` (SCD Type 1), and new rows are counted with `xmax = 0`. Supplier and product are insert-only (new keys only).
- **Fact table:** `bl_dm.dwh_fact_sales` is loaded incrementally. Changed rows are updated using `IS DISTINCT FROM` comparison, and only new rows are inserted.

**Partitioning and performance**
- `bl_3nf.ce_fact_sales` and `bl_dm.dwh_fact_sales` are partitioned by `RANGE (order_dt)` into quarterly partitions. `bl_3nf.create_partitions()` and `bl_dm.create_dwh_fact_sales_partitions()` create them dynamically from the actual `order_dt` range, so new dates never fall outside the partitioned range.
- The materialized view `bl_dm.mv_fact_sales` has a unique index and is refreshed with `REFRESH MATERIALIZED VIEW CONCURRENTLY` after each load. If a concurrent refresh fails, it falls back to a regular refresh.
- The fact tables have indexes on `(order_id, order_dt)`.

**Logging**
- Every procedure writes the procedure name, execution time, row count and status to `bl_log.procedure_execution_log`.

---

### How to Run

**Requirements**
- PostgreSQL 14+ with the `file_fdw` extension
- The source CSV files at the paths defined in `External_Tables/External_Tables.sql` (default: `C:\temp\`)

**1. Create the schemas**
```sql
CREATE SCHEMA sa_local;  CREATE SCHEMA sa_global;
CREATE SCHEMA BL_CL;     CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;     CREATE SCHEMA bl_log;
CREATE SCHEMA bl_master;
```

**2. Run the scripts in this order**
```
 1. BL_LOG/BL_LOG.sql
 2. External_Tables/External_Tables.sql
 3. SA_LOCAL/src_local_sales.sql
 4. SA_GLOBAL/src_international_sales.sql
 5. BL_CL/Tables/CL_Tables.sql
 6. BL_CL/Procedures/CL_Local.sql, BL_CL/Procedures/CL_Global.sql
 7. BL_3NF/Tables/Tables.sql
 8. BL_3NF/Procedures/*.sql
 9. BL_DM/Procedures/Tables/Tables.sql
10. BL_DM/Procedures/*.sql
11. BL_Master/BL_Master.sql
```

**3. Run the full load and check the result**
```sql
CALL bl_master.execute_full_dwh_load();

SELECT * FROM bl_log.procedure_execution_log ORDER BY execution_time DESC LIMIT 10;
SELECT * FROM bl_log.incremental_load_log;
SELECT COUNT(*) FROM bl_dm.dwh_fact_sales;
```

The step-by-step guide (in Georgian) is in [TESTING_GUIDE.md](TESTING_GUIDE.md). Data quality checks are in [Check_Script/Check_Scripts.sql](Check_Script/Check_Scripts.sql).

---

### Documentation

- [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md): table definitions and procedure descriptions for every layer
- [TESTING_GUIDE.md](TESTING_GUIDE.md): step-by-step testing guide
- [Presentation_Final_Project.pdf](Presentation_Final_Project.pdf): project presentation
- [Business_Template.docx](Business_Template.docx): business requirements template

---

### Known Limitations and Roadmap

- CSV paths in `External_Tables.sql` are Windows-specific.
- Planned: a Docker Compose setup for one-command deployment, and automated data quality tests in CI.

<p align="right"><a href="#georgian">🇬🇪 ქართული ↓</a></p>

<hr>

<!-- ############################## GEORGIAN ############################## -->
<a id="georgian"></a>

<h1 align="center">DWH Project: გაყიდვების Data Warehouse</h1>
<p align="center"><em>მრავალშრიანი არქიტექტურა · 3NF core + star schema · SCD Type 2 · Incremental loading · PL/pgSQL</em></p>

---

### მიმოხილვა

პროექტი წარმოადგენს მრავალშრიან Data Warehouse-ს, რომელიც ორი წყაროს მონაცემებს აერთიანებს CSV ფაილებიდან ანალიტიკურ star schema-ში. ეს წყაროებია ადგილობრივი გაყიდვები (~50 000 ჩანაწერი) და საერთაშორისო გაყიდვები (~1 000 000 ჩანაწერი). ETL პროცესი მთლიანად PL/pgSQL stored procedure-ებით არის დაწერილი და მოიცავს:
- incremental loading-ს
- პროდუქტების ისტორიის შენახვას SCD Type 2 მეთოდით
- partitioning-ს fact table-ებში
- შესრულების ლოგირებას ყველა layer-ზე

---

### არქიტექტურა

```
CSV ფაილები (local_sales.csv, international_sales.csv)
   │  file_fdw
   ▼
External tables       sa_local.ext_local_sales, sa_global.ext_international_sales
   │  incremental load (order_dt watermark)
   ▼
Source layer (SA)     sa_local.src_local_sales, sa_global.src_international_sales
   │  დუბლიკატების მოცილება, წყაროს მონიშვნა
   ▼
Clean layer (BL_CL)   BL_CL.CLEAN_LOCAL_SALES, BL_CL.CLEAN_GLOBAL_SALES
   │  surrogate key-ები, ნორმალიზაცია, SCD Type 2
   ▼
Core layer (BL_3NF)   ce_geo, ce_supplier, ce_buyer, ce_branch, ce_product_scd2, ce_time, ce_fact_sales
   │  star schema, upsert, partitioning
   ▼
Data mart (BL_DM)     dwh_dim_* dimension-ები, dwh_fact_sales, mv_fact_sales
```

| Schema | დანიშნულება |
|--------|-------------|
| `sa_local`, `sa_global` | წყაროს ნედლი მონაცემები, რომლებიც external table-ებიდან incremental load-ით იტვირთება |
| `BL_CL` | გაწმენდილი, დუბლიკატებისგან თავისუფალი ჩანაწერები `source_system` / `source_entity` მონიშვნით |
| `bl_3nf` | ნორმალიზებული core მოდელი (3NF), პროდუქტების SCD Type 2 ისტორიით |
| `bl_dm` | Star schema რეპორტინგისთვის: ექვსი dimension და დანაწილებული fact table |
| `bl_log` | Watermark-ები და procedure-ების შესრულების ლოგი |
| `bl_master` | სრული ჩატვირთვის მმართველი procedure |

---

### ძირითადი ტექნიკები

**Incremental loading (watermark მიდგომა)**
- Source და clean layer-ის ყოველი ჩატვირთვა ბოლოს ჩატვირთულ `order_dt`-ს კითხულობს `bl_log.incremental_load_log`-იდან ან `bl_log.clean_load_log`-იდან.
- მუშავდება მხოლოდ უფრო ახალი ჩანაწერები. `ON CONFLICT ... DO UPDATE` განმეორებით გაშვებას უსაფრთხოს ხდის.
- ბოლოს watermark ახლდება და ფიქსირდება ჩანაწერების რაოდენობა და სტატუსი. შეცდომის შემთხვევაში სტატუსი ხდება `FAILED` და ინახება შეცდომის ტექსტი.

**SCD Type 2**: `bl_3nf.ce_product_scd2`
- როცა პროდუქტის კატეგორია ან მომწოდებელი იცვლება, მიმდინარე ვერსია იხურება და ემატება ახალი აქტიური ვერსია:

```sql
UPDATE bl_3nf.ce_product_scd2
SET end_dt = CURRENT_DATE - INTERVAL '1 day', is_active = 'N'
WHERE ... AND end_dt = '9999-12-31'
  AND (product_category <> p.product_category OR supplier_id <> ...);

INSERT INTO bl_3nf.ce_product_scd2 (..., start_dt, end_dt, is_active, ...)
SELECT ..., CURRENT_DATE, '9999-12-31', 'Y', ...;
```

**Data mart-ის ჩატვირთვა**: `bl_dm`
- **Dimension-ები:** geo, buyer, branch და time იტვირთება `INSERT ... ON CONFLICT DO UPDATE`-ით (SCD Type 1), ახალი ჩანაწერების რაოდენობა კი `xmax = 0` პირობით ითვლება. Supplier და product dimension-ებს მხოლოდ ახალი key-ები ემატება.
- **Fact table:** `bl_dm.dwh_fact_sales` incremental load-ით ივსება. შეცვლილი ჩანაწერები `IS DISTINCT FROM` შედარებით ახლდება, ემატება მხოლოდ ახალი ჩანაწერები.

**Partitioning და წარმადობა**
- `bl_3nf.ce_fact_sales` და `bl_dm.dwh_fact_sales` დაყოფილია `RANGE (order_dt)` პრინციპით კვარტალურ partition-ებად. მათ დინამიკურად ქმნიან `bl_3nf.create_partitions()` და `bl_dm.create_dwh_fact_sales_partitions()` რეალური `order_dt` დიაპაზონის მიხედვით, ამიტომ ახალი თარიღები partition-ების გარეთ არასოდეს რჩება.
- Materialized view `bl_dm.mv_fact_sales`-ს აქვს unique index და ყოველი ჩატვირთვის შემდეგ ახლდება `REFRESH MATERIALIZED VIEW CONCURRENTLY` ბრძანებით. თუ concurrent განახლება ვერ სრულდება, სრულდება ჩვეულებრივი განახლება.
- Fact table-ებზე შექმნილია index-ები `(order_id, order_dt)` სვეტებზე.

**ლოგირება**
- ყოველი procedure `bl_log.procedure_execution_log`-ში იწერს სახელს, შესრულების დროს, ჩანაწერების რაოდენობასა და სტატუსს.

---

### გაშვება

**მოთხოვნები**
- PostgreSQL 14+ და `file_fdw` extension
- წყაროს CSV ფაილები `External_Tables/External_Tables.sql`-ში მითითებულ მისამართზე (ნაგულისხმევად `C:\temp\`)

**1. შექმენით schema-ები**
```sql
CREATE SCHEMA sa_local;  CREATE SCHEMA sa_global;
CREATE SCHEMA BL_CL;     CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;     CREATE SCHEMA bl_log;
CREATE SCHEMA bl_master;
```

**2. გაუშვით სკრიპტები შემდეგი თანმიმდევრობით**
```
 1. BL_LOG/BL_LOG.sql
 2. External_Tables/External_Tables.sql
 3. SA_LOCAL/src_local_sales.sql
 4. SA_GLOBAL/src_international_sales.sql
 5. BL_CL/Tables/CL_Tables.sql
 6. BL_CL/Procedures/CL_Local.sql, BL_CL/Procedures/CL_Global.sql
 7. BL_3NF/Tables/Tables.sql
 8. BL_3NF/Procedures/*.sql
 9. BL_DM/Procedures/Tables/Tables.sql
10. BL_DM/Procedures/*.sql
11. BL_Master/BL_Master.sql
```

**3. გაუშვით სრული ჩატვირთვა და შეამოწმეთ შედეგი**
```sql
CALL bl_master.execute_full_dwh_load();

SELECT * FROM bl_log.procedure_execution_log ORDER BY execution_time DESC LIMIT 10;
SELECT * FROM bl_log.incremental_load_log;
SELECT COUNT(*) FROM bl_dm.dwh_fact_sales;
```

დეტალური, ნაბიჯ-ნაბიჯ ინსტრუქცია მოცემულია [TESTING_GUIDE.md](TESTING_GUIDE.md)-ში. მონაცემთა ხარისხის შემოწმების query-ები მოცემულია [Check_Script/Check_Scripts.sql](Check_Script/Check_Scripts.sql)-ში.

---

### დოკუმენტაცია

- [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md): ცხრილებისა და procedure-ების აღწერა ყველა layer-ისთვის
- [TESTING_GUIDE.md](TESTING_GUIDE.md): ტესტირების ნაბიჯ-ნაბიჯ სახელმძღვანელო
- [Presentation_Final_Project.pdf](Presentation_Final_Project.pdf): პროექტის პრეზენტაცია
- [Business_Template.docx](Business_Template.docx): ბიზნეს მოთხოვნების შაბლონი

---

### ცნობილი შეზღუდვები და სამომავლო გეგმა

- `External_Tables.sql`-ში CSV ფაილების მისამართები Windows-ზეა მორგებული.
- დაგეგმილია: Docker Compose ერთი ბრძანებით გასაშვებად და მონაცემთა ხარისხის ავტომატური ტესტები CI-ში.

<p align="right"><a href="#english">🇺🇸 English ↑</a></p>
