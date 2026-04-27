# DWH Project

**Data Warehouse Implementation** - PostgreSQL-ით შემუშავებული ETL Pipeline.

პროექტი ანალიზირებს ლოკალურ და საერთაშორისო გაყიდვების მონაცემებს CSV ფაილებიდან Kimball-ის dimensional modeling მეთოდოლოგიით.

## არქიტექტურა

```
CSV Files → External Tables → Source Layer → Clean Layer → 3NF Layer → Data Mart
```

### Layers:
| Layer | Schema | მიზანი |
|-------|--------|---------|
| **Source** | `sa_local`, `sa_global` | Raw მონაცემების იმპორტი |
| **Clean** | `BL_CL` | მონაცემების სტანდარტიზაცია |
| **3NF** | `bl_3nf` | Dimensional model SCD support-ით |
| **Data Mart** | `bl_dm` | რეპორტინგისთვის ოპტიმიზებული ცხრილები |
| **Logging** | `bl_log` | ETL მონიტორინგი |

## Features

- **Incremental Loading** - მხოლოდ ახალი მონაცემების ჩატვირთვა
- **SCD Type 2** - პროდუქტის dimension-ში historical tracking
- **Table Partitioning** - Fact tables კვარტალურად დაჰყოფა
- **ETL Logging** - Full execution tracking
- **Materialized Views** - სწრაფი წვდომა მონაცემებზე

## Setup

### პრერეკვიზიტები
- PostgreSQL 14+
- pgAdmin ან psql

### ნაბიჯები

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

### CSV ფაილები

მოათავსე `C:\temp\` ფოლდერში:
- `local_Wardrobe_sales.csv` - ლოკალური გაყიდვები
- `international_Wardrobe_sales.csv` - საერთაშორისო გაყიდვები

## სტრუქტურა

```
DWH Project/
├── README.md
├── TECHNICAL_DOCUMENTATION.md
├── TESTING_GUIDE.md
├── GITHUB_UPLOAD_GUIDE.md
├── .gitignore
├── BL_Master/           # ETL Orchestration
├── BL_3NF/              # Core Enterprise Layer
│   ├── Tables/
│   └── Procedures/
├── BL_CL/               # Clean Layer
│   ├── Tables/
│   └── Procedures/
├── BL_DM/               # Data Mart Layer
│   ├── Tables/
│   └── Procedures/
├── BL_LOG/              # Logging
├── SA_LOCAL/            # Local Source
├── SA_GLOBAL/           # International Source
├── External_Tables/     # CSV Connections
└── Check_Script/        # Validation
```

## Full ETL Run

```sql
CALL bl_master.execute_full_dwh_load();
```

## Monitoring

```sql
SELECT * FROM bl_log.incremental_load_log;
SELECT * FROM bl_log.procedure_execution_log;
```

## დოკუმენტაცია

- [TESTING_GUIDE.md](TESTING_GUIDE.md) - ტესტირების ინსტრუქცია
- [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md) - ტექნიკური დოკუმენტაცია
- [GITHUB_UPLOAD_GUIDE.md](GITHUB_UPLOAD_GUIDE.md) - GitHub-ზე ატვირთვის ინსტრუქცია