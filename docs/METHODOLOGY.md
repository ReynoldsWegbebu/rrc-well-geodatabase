# Methodology
## How This Geodatabase Was Built

### 1. Source Document Acquisition
Three well packets obtained from the **Railroad Commission of Texas (RRC)** public records portal (`rrc.texas.gov`). Each packet contains multiple regulatory forms filed by Killam Oil Co., Ltd. (Operator #460054) for wells in RRC District 04.

### 2. Form Identification & Parsing
Each PDF was analyzed to identify which RRC form it represented, then systematically parsed by section:

```
G-1  → Operator Info, Well Info, Filing Info, Completion Info,
        Gas Measurement Data, Field Data & Pressure Calculations,
        Casing Record, Liner Record, Tubing Record,
        Producing/Injection Interval, Acid/Fracture, Formation Record
G-5  → Production Test, A.S.T.M. Distillation Data
G-10 → Well Status Report (gas, condensate, water, pressures)
W-3  → Plugging Record (plugs 1–4, mud data, fresh water zones)
W-15 → Cementing Report (squeeze/plug-back section)
P-4  → Gatherer/Purchaser authorization, classification
P-13 → Landowner water well conversion application
GW-2 → Groundwater Advisory Unit protection depths
```

### 3. Schema Design
The geodatabase schema follows industry-standard petroleum data models:
- **WELLS** as the central spatial feature class (point geometry, NAD83)
- All detail tables relate back via `WELL_ID` foreign key
- Field names follow PPDM (Professional Petroleum Data Management) naming conventions where applicable
- Depth fields always distinguish **TVD** (True Vertical Depth) from **MD** (Measured Depth)
- Pressure fields always specify units in field names (e.g., `_PSIA`, `_PSIG`)

### 4. Coordinate Reference System
- Primary CRS: **NAD83 (EPSG:4269)** — standard for Texas O&G GIS
- W-003 coordinates sourced from GW-2 form which specifies NAD27 datum
- GeoJSON exports use WGS84 (EPSG:4326) per RFC 7946

### 5. Data Quality Notes
- W-001 (Nido Ranch 18H) latitude/longitude not present in filed G-1; coordinates estimated from survey description
- W-003 coordinates in NAD27 — flagged in WELLS table DATUM field
- Formation depth records for W-003 not extracted (P&A well, formation data in original W-1 filing not included in this packet)
- All pressure values are **psia** (pounds per square inch absolute) unless otherwise noted

### 6. Limitations
- This dataset represents **3 wells from a single operator packet** — not a complete field or basin dataset
- Production history (monthly volumes) is not included — this data comes from RRC Form PR filings
- No wellbore trajectory/deviation survey data included in these filings
- Seismic interpretation and structural mapping not in scope
