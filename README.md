# 🛢️ Oil & Gas Well GIS Portfolio
### RRC District 04 — Geodatabase Project

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](https://python.org)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.3-336791?logo=postgresql&logoColor=white)](https://postgis.net)
[![GeoJSON](https://img.shields.io/badge/GeoJSON-RFC%207946-brightgreen)](https://geojson.org)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![RRC Texas](https://img.shields.io/badge/Source-RRC%20of%20Texas-red)](https://www.rrc.texas.gov)

---

## 📌 Project Overview

A production-grade **well geodatabase** built from Railroad Commission of Texas (RRC) regulatory filings for three random wells in **Starr and Webb Counties, Texas** (RRC District 04).

This project demonstrates end-to-end GIS data engineering for oil and gas — from raw RRC form extraction through to a normalized relational geodatabase, spatial GeoJSON feature classes, SQL schema, Python ETL pipeline, and an interactive map dashboard (I was inspired to design the project after taking online course on O&G Data Management. To design a single geodatabase of true form exploration, drilling , production, etc.)

> **Intended audience:** Oil & gas operators, E&P companies, geospatial firms, and energy data providers hiring for GIS Analyst, Geospatial Engineer, or Petroleum Data Analyst roles.

---

## 🗂️ Repository Structure

```
oil-gas-gis-portfolio/
│
├── README.md                        # This file
├── LICENSE
│
├── data/
│   ├── raw/                         # Source RRC PDFs (G-1, G-5, G-10, W-3, W-15, P-4, P-13, GW-2)
│   ├── processed/
│   │   └── GeoDatabase.xlsx   # Full 17-table geodatabase (Excel)
│   └── geojson/
│       ├── wells.geojson            # Point feature class (NAD83)
│       ├── formations.geojson       # Formation tops with well association
│       └── perforations.geojson     # Perforation intervals
│
├── database/
│   ├── schema/
│   │   └── geodatabase_erd.html     # Interactive ERD diagram
│   └── sql/
│       ├── 01_create_tables.sql     # Full DDL — all 17 tables
│       ├── 02_insert_data.sql       # Seed data from RRC filings
│       └── 03_spatial_queries.sql   # Example analysis queries
│
├── maps/
│   └── well_dashboard.html          # Interactive Leaflet.js well map
│
├── scripts/
│   ├── etl/
│   │   ├── parse_rrc_forms.py       # Extract fields from RRC PDF structure
│   │   ├── build_geodatabase.py     # Build normalized Excel geodatabase
│   │   └── export_geojson.py        # Export spatial tables to GeoJSON
│   └── analysis/
│       ├── production_analysis.py   # IP gas comparison, pressure analysis
│       └── formation_depths.py      # Formation top visualization
│
└── docs/
    ├── DATA_DICTIONARY.md           # All 17 tables, every field defined
    ├── METHODOLOGY.md               # How data was extracted and normalized
    └── RRC_FORMS_REFERENCE.md       # Guide to RRC regulatory forms used
```

---

## 🗃️ Geodatabase Schema

17 related tables organized into 6 thematic groups:

| Group | Tables | Records |
|-------|--------|---------|
| **Spatial Core** | WELLS | 3 wells |
| **Completion & Drilling** | COMPLETION, CASING, CEMENTING, TUBING | 3 / 7 / 5 / 3 |
| **Production & Testing** | GAS_MEASUREMENT, PRESSURE_TEST, CLASSIFICATION, GAS_STATUS | 2 / 4 / 2 / 2 |
| **Intervals & Treatment** | PERFORATIONS, FRAC_TREATMENT | 3 / 3 |
| **Geology** | FORMATIONS | 12 formation tops |
| **Regulatory & Compliance** | PLUGGING, TRANSPORT_AUTH, GROUNDWATER, OPERATOR | 1 / 5 / 2 / 1 |

**Primary key:** `WELL_ID` (W-001, W-002, W-003) — all tables relate back to the WELLS feature class via FK.

---

## 🗺️ Wells Covered

| Well ID | API | Lease | County | Status | Field | IP Gas (MCF/d) |
|---------|-----|-------|--------|--------|-------|----------------|
| W-001 | 42-479-00001 | LEASE A #3| Webb | Producing |(Austin Chalk) | **11,252** |
| W-002 | 42-427-00002 | LEASE C #49 | Starr | Producing | Sun North (Vicksburg) | **492** |
| W-003 | 42-479-00003 | LEASE D 17 | Webb | P&A | Del Mar (Lobo Cons.) |  |

---

## ⚙️ Technical Stack

| Layer | Technology |
|-------|-----------|
| Spatial database | PostGIS / PostgreSQL |
| Data processing | Python 3.11 (pandas, geopandas, openpyxl) |
| GIS format | GeoJSON (RFC 7946), ESRI Geodatabase-compatible schema |
| Coordinate system | NAD83 decimal degrees (EPSG:4269) |
| Web mapping | Leaflet.js |
| Visualization | HTML/CSS/JS, Chart.js |
| Source data | RRC of Texas — Forms G-1, G-5, G-10, W-3, W-15, P-4, P-13, GW-2 |

---

## 🚀 Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/oil-gas-gis-portfolio.git
cd oil-gas-gis-portfolio
```

### 2. Install Python dependencies
```bash
pip install -r requirements.txt
```

### 3. Set up the PostGIS database
```bash
psql -U postgres -c "CREATE DATABASE oilgas_gis;"
psql -U postgres -d oilgas_gis -c "CREATE EXTENSION postgis;"
psql -U postgres -d oilgas_gis -f database/sql/01_create_tables.sql
psql -U postgres -d oilgas_gis -f database/sql/02_insert_data.sql
```

### 4. Export GeoJSON
```bash
python scripts/etl/export_geojson.py
```

### 5. Open the interactive map
```bash
open maps/well_dashboard.html
```

---


---

## 📋 RRC Forms Reference

| Form | Purpose | Tables Populated |
|------|---------|-----------------|
| G-1 | Gas Well Back Pressure Test / Completion Report | WELLS, COMPLETION, GAS_MEASUREMENT, PRESSURE_TEST, CASING, TUBING, PERFORATIONS, FRAC_TREATMENT, FORMATIONS |
| G-5 | Gas Well Classification Report | CLASSIFICATION |
| G-10 | Gas Well Status Report | GAS_STATUS |
| W-3 | Plugging Record | PLUGGING |
| W-15 | Cementing Report | CEMENTING |
| P-4 | Certificate of Compliance & Transportation Authority | TRANSPORT_AUTH |
| P-13 | Application to Condition Abandoned Well for Fresh Water | GROUNDWATER |
| GW-2 | Groundwater Protection Determination | GROUNDWATER |

---

## 🧠 Skills Demonstrated

- **Regulatory data literacy** — RRC of Texas form structure, field definitions, and filing workflows
- **Geodatabase design** — normalized relational schema, PK/FK relationships, spatial feature classes
- **ETL pipeline** — structured extraction from semi-structured PDF regulatory documents
- **Spatial data** — GeoJSON feature classes, coordinate reference systems (NAD83/WGS84), geometry types
- **SQL** — DDL schema creation, spatial queries with PostGIS, analytical queries
- **Python** — pandas data manipulation, geopandas spatial operations, openpyxl automation
- **Data visualization** — interactive web maps (Leaflet.js), ERD diagrams, production charts
- **Domain knowledge** — completion types, formation evaluation, well testing (SIWH, IP, BHP), cementing, P&A

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🤝 Contact

Built by **REYNOLDS**  
📧 reybu20@gmail.com  
🔗 [LinkedIn](https://linkedin.com/in/yourprofile)  
📍 Available for GIS Analyst / Geospatial Engineer roles in oil & gas

---

*Data sourced from public Railroad Commission of Texas filings. All well information is publicly available regulatory data.*


📌 Project Overview
A production-grade well geodatabase built from Railroad Commission of Texas (RRC) regulatory filings for three random wells in Starr and Webb Counties, Texas (RRC District 04).
This project demonstrates end-to-end GIS data engineering for oil and gas — from raw RRC form extraction through to a normalized relational geodatabase, spatial GeoJSON feature classes, SQL schema, Python ETL pipeline, and an interactive map dashboard (I was inspired to design the project after taking online course on O&G Data Management. To design a single geodatabase of true form exploration, drilling , production, etc.)

Intended audience: Oil & gas operators, E&P companies, geospatial firms, and energy data providers hiring for GIS Analyst, Geospatial Engineer, or Petroleum Data Analyst roles.


🗂️ Repository Structure

```
oil-gas-gis-portfolio/
│
├── README.md                        # This file
├── LICENSE
│
├── data/
│   ├── raw/                         # Source RRC PDFs (G-1, G-5, G-10, W-3, W-15, P-4, P-13, GW-2)
│   ├── processed/
│   │   └── GeoDatabase.xlsx         # Full 17-table geodatabase (Excel)
│   └── geojson/
│       ├── wells.geojson            # Point feature class (NAD83)
│       ├── formations.geojson       # Formation tops with well association
│       └── perforations.geojson     # Perforation intervals
│
├── database/
│   ├── schema/
│   │   └── geodatabase_erd.html     # Interactive ERD diagram
│   └── sql/
│       ├── 01_create_tables.sql         # Full DDL — all 17 tables
│       ├── 02_insert_data.sql           # Seed data from RRC filings
│       ├── 03_spatial_queries.sql       # Example analysis queries
│       ├── oilgas_arcgis_objectid.sql   # ArcGIS-compatible OBJECTID/GLOBALID columns
│       ├── oilgas_extensions.sql        # RRC violation and inspection schema
│       ├── oilgas_full_extension.sql    # Full domain extension schema
│       └── pods_v7_geodatabase.sql      # PODS v7 industry-standard geodatabase schema
│
├── maps/
│   └── well_dashboard.html          # Interactive Leaflet.js well map
│
├── scripts/
│   ├── etl/
│   │   ├── parse_rrc_forms.py       # Extract fields from RRC PDF structure
│   │   ├── build_geodatabase.py     # Build normalized Excel geodatabase
│   │   └── export_geojson.py        # Export spatial tables to GeoJSON
│   └── analysis/
│       ├── production_analysis.py   # IP gas comparison, pressure analysis
│       └── formation_depths.py      # Formation top visualization
│
└── docs/
    ├── DATA_DICTIONARY.md           # All 17 tables, every field defined
    ├── METHODOLOGY.md               # How data was extracted and normalized
    └── RRC_FORMS_REFERENCE.md       # Guide to RRC regulatory forms used
```

---
🗃️ Geodatabase Schema
17 related tables organized into 6 thematic groups:
GroupTablesRecordsSpatial CoreWELLS3 wellsCompletion & DrillingCOMPLETION, CASING, CEMENTING, TUBING3 / 7 / 5 / 3Production & TestingGAS_MEASUREMENT, PRESSURE_TEST, CLASSIFICATION, GAS_STATUS2 / 4 / 2 / 2Intervals & TreatmentPERFORATIONS, FRAC_TREATMENT3 / 3GeologyFORMATIONS12 formation topsRegulatory & CompliancePLUGGING, TRANSPORT_AUTH, GROUNDWATER, OPERATOR1 / 5 / 2 / 1
Primary key: WELL_ID (W-001, W-002, W-003) — all tables relate back to the WELLS feature class via FK.
---

🗺️ Wells Covered
Well IDAPILeaseCountyStatusFieldIP Gas (MCF/d)W-00142-479-00001LEASE A #3WebbProducing(Austin Chalk)11,252W-00242-427-00002LEASE C #49StarrProducingSun North (Vicksburg)492W-00342-479-00003LEASE D 17WebbP&ADel Mar (Lobo Cons.)

⚙️ Technical Stack
LayerTechnologySpatial databasePostGIS / PostgreSQLData processingPython 3.11 (pandas, geopandas, openpyxl)GIS formatGeoJSON (RFC 7946), ESRI Geodatabase-compatible schemaCoordinate systemNAD83 decimal degrees (EPSG:4269)Web mappingLeaflet.jsVisualizationHTML/CSS/JS, Chart.jsSource dataRRC of Texas — Forms G-1, G-5, G-10, W-3, W-15, P-4, P-13, GW-2

🚀 Quick Start
1. Clone the repository
bashgit clone https://github.com/YOUR_USERNAME/oil-gas-gis-portfolio.git
cd oil-gas-gis-portfolio
2. Install Python dependencies
bashpip install -r requirements.txt
3. Set up the PostGIS database
bashpsql -U postgres -c "CREATE DATABASE oilgas_gis;"
psql -U postgres -d oilgas_gis -c "CREATE EXTENSION postgis;"
psql -U postgres -d oilgas_gis -f database/sql/01_create_tables.sql
psql -U postgres -d oilgas_gis -f database/sql/02_insert_data.sql
4. Export GeoJSON
bashpython scripts/etl/export_geojson.py
5. Open the interactive map
bashopen maps/well_dashboard.html


📋 RRC Forms Reference
FormPurposeTables PopulatedG-1Gas Well Back Pressure Test / Completion ReportWELLS, COMPLETION, GAS_MEASUREMENT, PRESSURE_TEST, CASING, TUBING, PERFORATIONS, FRAC_TREATMENT, FORMATIONSG-5Gas Well Classification ReportCLASSIFICATIONG-10Gas Well Status ReportGAS_STATUSW-3Plugging RecordPLUGGINGW-15Cementing ReportCEMENTINGP-4Certificate of Compliance & Transportation AuthorityTRANSPORT_AUTHP-13Application to Condition Abandoned Well for Fresh WaterGROUNDWATERGW-2Groundwater Protection DeterminationGROUNDWATER

🧠 Skills Demonstrated

Regulatory data literacy — RRC of Texas form structure, field definitions, and filing workflows
Geodatabase design — normalized relational schema, PK/FK relationships, spatial feature classes
ETL pipeline — structured extraction from semi-structured PDF regulatory documents
Spatial data — GeoJSON feature classes, coordinate reference systems (NAD83/WGS84), geometry types
SQL — DDL schema creation, spatial queries with PostGIS, analytical queries
Python — pandas data manipulation, geopandas spatial operations, openpyxl automation
Data visualization — interactive web maps (Leaflet.js), ERD diagrams, production charts
Domain knowledge — completion types, formation evaluation, well testing (SIWH, IP, BHP), cementing, P&A


📄 License
MIT License — see LICENSE for details.

🤝 Contact
Built by REYNOLDS
📧 reybu20@gmail.com
🔗 LinkedIn
📍 Available for GIS Analyst / Geospatial Engineer roles in oil & gas

Data sourced from public Railroad Commission of Texas filings. All well information is publicly available regulatory data.
