# retail-sales-dwh
# Retail Sales Data Warehouse — ETL & Data Quality Validation

A production-style ETL pipeline built on Databricks SQL, AWS S3, and Python.  
Implements a full Medallion Architecture (Bronze → Silver → Gold) with automated testing gates, SCD Type 2 dimension handling, idempotent data ingestion, and an intelligent file archival mechanism.

---

## Table of Contents

- Architecture Overview
- Tech Stack
- Project Structure
- Pipeline Flow
- Data Model
- Archival Mechanism
- Testing Strategy
- How to Run

---

## Architecture Overview

Source CSVs (SFTP Landing in S3)
        │
        ▼
┌──────────────────┐
│ archive_files.py │  ← Evaluates timestamps; archives old files to keep landing zone clean
└──────────────────┘
        │
        ▼
┌──────────────────┐
│   Bronze Layer   │  ← Raw ingestion using COPY INTO (CSVs → Delta)
│ 01_bronze_layer  │    Safely handles schema variation by casting to STRING
└──────────────────┘
        │
        ▼
┌──────────────────┐
│   Silver Layer   │  ← Deduplication, strict typing, and Dimension builds
│ 02_silver_layer  │    SCD Type 2 tracking for DimCustomer
└──────────────────┘
        │
        ▼
┌──────────────────┐
│    Gold Layer    │  ← Final Fact presentation using MERGE INTO (Upsert)
│  03_gold_layer   │    Derives amounts and maps historical surrogate keys
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  Quality Gates   │  ← Validates uniqueness, mathematical accuracy, and nulls
│ 04_data_quality  │
└──────────────────┘

---

## Tech Stack

* ETL Engine: Databricks SQL
* Storage: AWS S3 (s3://retail-dwh-project-bucket)
* Format: Delta Lake (Parquet)
* Catalog: Unity Catalog (retail_project)
* Scripting: Python (dbutils.fs, re, datetime)
* Architecture: Medallion (Bronze / Silver / Gold)

---

## Project Structure

├── 00_setup_environment.sql       # Initializes Unity Catalog and Medallion schemas
├── archive_files.py               # Pre-processing script to archive older source files
├── 01_bronze_layer.sql            # Idempotent CSV ingestion via COPY INTO
├── 02_silver_layer_dimensions.sql # Deduplication (QUALIFY) & SCD2 Dimension logic
├── 03_gold_layer_facts.sql        # Daily Fact upserts using MERGE INTO
├── 04_data_quality_tests.sql      # Automated QA checks and assertions
└── test.sql                       # Ad-hoc table validation queries

---

## Pipeline Flow

### 1. Ingestion & Archival
* Source systems drop timestamped CSV files into s3://.../sftp/.
* archive_files.py scans the directory, parses dates from filenames, keeps the newest files for processing, and moves older iterations to archive/YYYY-MM-DD_HH-MM-SS/raw/.

### 2. Bronze (Raw Ingestion)
* 01_bronze_layer.sql uses COPY INTO to ingest files into Delta tables.
* Data is read natively as STRING to prevent upstream schema corruption.
* Null CustomerID rows are immediately purged.

### 3. Silver (Conformed Dimensions)
* 02_silver_layer_dimensions.sql removes exact duplicates using QUALIFY ROW_NUMBER() OVER (...) = 1.
* DimProduct & DimStore: Static dimensions, fully overwritten daily with clean types (BIGINT, DECIMAL).
* DimCustomer: Implements Slowly Changing Dimension (SCD Type 2). Triggers row expiration when City or Address changes, inserting the new record with IsActive = 1.

### 4. Gold (Reporting Facts)
* 03_gold_layer_facts.sql calculates total Amount (Quantity * UnitPrice).
* Resolves Surrogate Keys (SKs) by joining against Silver tables, respecting the SCD2 date boundaries (TxnDate BETWEEN StartDate AND EndDate).
* Uses MERGE INTO to ensure idempotency. If a TransactionID exists, it updates; if not, it inserts.

---

## Data Model

                    ┌─────────────────┐
                    │  DimCustomer    │
                    │  (SCD Type 2)   │
                    │  CustomerSK  PK │
                    │  CustomerID  NK │
                    │  StartDate      │
                    │  EndDate        │
                    │  IsActive       │
                    └────────┬────────┘
                             │
┌──────────────┐    ┌────────▼────────┐    ┌─────────────┐
│  DimProduct  │    │   FactSales     │    │  DimStore   │
│  ProductSK PK│───►│  CustomerSK  FK │◄───│  StoreSK PK │
│  ProductID NK│    │  ProductSK   FK │    │  StoreID  NK│
│  UnitPrice   │    │  StoreSK     FK │    │  StoreName  │
└──────────────┘    │  Quantity       │    │  Region     │
                    │  Amount         │    └─────────────┘
                    │  TxnDate        │
                    └─────────────────┘

---

## Archival Mechanism

Source files must follow the strict naming convention:
tablename_src_DDMMYYYYHHMMSS.csv (e.g., customers_src_15052026123000.csv).

The archival script (archive_files.py) utilizes Python regex (r'_src_(\d{8})\d{6}\.csv$') to extract the date. 
If multiple files for the same source are found:
1. It identifies the maximum (newest) date.
2. It leaves the newest file(s) in the sftp/ zone for Bronze COPY INTO processing.
3. It moves all older files to an archive/<run-timestamp>/raw/ directory.

---

## Testing Strategy

The 04_data_quality_tests.sql acts as an automated validation gate running at the end of the pipeline.

Core Assertions:
* Uniqueness: No duplicate active CustomerIDs in DimCustomer.
* Null Checks: Foreign keys (CustomerSK, ProductSK, StoreSK) in FactSales must never be NULL.
* Math Accuracy: Calculates f.Amount != (f.Quantity * p.UnitPrice) to catch pricing calculation errors.
* Historical Mapping: Ensures FactSales.TxnDate strictly falls between the StartDate and EndDate of the assigned CustomerSK.
* Completeness: Compares raw Bronze row counts to final Gold row counts.

---

## How to Run

### First Time Setup
1. Mount or establish access to your AWS S3 bucket (retail-dwh-project-bucket).
2. Run 00_setup_environment.sql once in a Databricks SQL warehouse to initialize the retail_project catalog and namespaces.

### Daily Execution
Configure a Databricks Workflow (Job) to run the scripts sequentially:
1. Python Task: archive_files.py
2. SQL Task: 01_bronze_layer.sql
3. SQL Task: 02_silver_layer_dimensions.sql
4. SQL Task: 03_gold_layer_facts.sql
5. SQL Task: 04_data_quality_tests.sql
