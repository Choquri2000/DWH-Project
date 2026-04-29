# 🏗️ DWH Project - Data Warehouse Implementation

🌐 **აირჩიეთ ენა / Choose Language:**  
[🇬🇪 ქართული](#georgian) | [🇺🇸 English](#english)

---

<a name="georgian"></a>
## 🇬🇪 ქართული ვერსია

**Data Warehouse Implementation** - PostgreSQL-ით შემუშავებული ETL პაიპლაინი.

პროექტი Kimball-ის დიმენსიური მოდელირების მეთოდოლოგიით აანალიზებს გაყიდვების მონაცემებს. არქიტექტურა ორიენტირებულია მონაცემთა ინჟინერიის საუკეთესო პრაქტიკებზე, რაც ქმნის მყარ საფუძველს **Data Science** და ანალიტიკური ამოცანებისთვის.

### 🛠️ არქიტექტურა
```
CSV Files → External Tables → Source Layer → Clean Layer → 3NF Layer → Data Mart
```

### ფენები (Layers):
| ფენა | სქემა | მიზანი |
|-------|--------|---------|
| **Source** | `sa_local`, `sa_global` | Raw მონაცემების იმპორტი |
| **Clean** | `BL_CL` | მონაცემების სტანდარტიზაცია |
| **3NF** | `bl_3nf` | Dimensional model SCD support-ით |
| **Data Mart** | `bl_dm` | რეპორტინგისთვის ოპტიმიზებული ცხრილები |
| **Logging** | `bl_log` | ETL მონიტორინგი |

### ✨ მახასიათებლები (Features)
- **Incremental Loading** - მხოლოდ ახალი მონაცემების ჩატვირთვა რესურსების დასაზოგად.
- **SCD Type 2** - ისტორიული ცვლილებების თრექინგი პროდუქტის დიმენსიაში.
- **Table Partitioning** - Fact ცხრილების კვარტალური დაყოფა წარმადობისთვის.
- **ETL Logging** - პროცესების სრული აღრიცხვა და მონიტორინგი.
- **Materialized Views** - სწრაფი წვდომა წინასწარ დამუშავებულ მონაცემებზე.

### 🚀 ინსტალაცია (Setup)

#### პრერეკვიზიტები
- PostgreSQL 14+
- pgAdmin ან psql

#### ნაბიჯები
1. **შექმენი Database:**
```sql
CREATE DATABASE dwh_project;
```
2. **შექმენი Schemas:**
```sql
CREATE SCHEMA sa_local;
CREATE SCHEMA sa_global;
CREATE SCHEMA BL_CL;
CREATE SCHEMA bl_3nf;
CREATE SCHEMA bl_dm;
CREATE SCHEMA bl_log;
CREATE SCHEMA bl_master;
```
3. **გაუშვი SQL ფაილები თანმიმდევრობით:**
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

### 🔄 ETL გაშვება და მონიტორინგი
```sql
CALL bl_master.execute_full_dwh_load(); -- გაშვება
SELECT * FROM bl_log.incremental_load_log; -- ლოგების შემოწმება
```

### 📂 სტრუქტურა
```
DWH Project/
├── BL_Master/           # ETL Orchestration
├── BL_3NF/              # Core Enterprise Layer
├── BL_CL/               # Clean Layer
├── BL_DM/               # Data Mart Layer
├── BL_LOG/              # Logging
├── SA_LOCAL/            # Local Source
├── SA_GLOBAL/           # International Source
└── External_Tables/     # CSV Connections
```

---

<a name="english"></a>
## 🇺🇸 English Version

**Data Warehouse Implementation** - ETL Pipeline developed with PostgreSQL.

The project processes local and international sales data from CSV files using Kimball's dimensional modeling methodology. This scalable architecture serves as a production-grade foundation for **Data Science** workflows and advanced analytics.

### 🛠️ Architecture
```
CSV Files → External Tables → Source Layer → Clean Layer → 3NF Layer → Data Mart
```

### Layers:
| Layer | Schema | Purpose |
|-------|--------|---------|
| **Source** | `sa_local`, `sa_global` | Raw data import |
| **Clean** | `BL_CL` | Data cleansing & standardization |
| **3NF** | `bl_3nf` | Core dimensional model with SCD support |
| **Data Mart** | `bl_dm` | Star schema optimized for reporting |
| **Logging** | `bl_log` | ETL execution monitoring |

### ✨ Features
- **Incremental Loading** - Efficiently processing only new records.
- **SCD Type 2** - Historical tracking in product dimensions.
- **Table Partitioning** - Fact tables split by quarters for high performance.
- **ETL Logging** - Full execution tracking and monitoring.
- **Materialized Views** - Faster access to aggregated data.

### 🚀 Setup Steps
1. **Create Database:** `CREATE DATABASE dwh_project;`
2. **Schema Setup:** Initialize all 7 schemas from `sa_local` to `bl_master`.
3. **Execute SQL files in order:** Run scripts from folders 1 to 8 sequentially.
4. **CSV Data:** Place source files in `C:\temp\`.

### 🔄 Monitoring & Run
```sql
CALL bl_master.execute_full_dwh_load(); -- Trigger ETL
SELECT * FROM bl_log.procedure_execution_log; -- Track status
```

---
*📍 Documentation: [TESTING_GUIDE.md](TESTING_GUIDE.md) | [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)*
