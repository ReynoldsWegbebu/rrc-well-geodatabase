# Data Dictionary
## Killam Oil Co. Well Geodatabase — RRC District 04

All field definitions, data types, constraints, and source references for all 17 tables.

---

## Table: WELLS *(Spatial Feature Class)*

Primary key: `WELL_ID` | Geometry: Point (NAD83, EPSG:4269)

| Field | Type | Nullable | Description | Source |
|-------|------|----------|-------------|--------|
| WELL_ID | TEXT | NO | Surrogate primary key (W-001, W-002, W-003) | Generated |
| API_NUMBER | TEXT | NO | API well number (42-CCC-NNNNN format) | G-1 header |
| WELL_NO | TEXT | YES | Well number on lease (e.g., 18H, 49, 1701) | G-1 Well Info |
| LEASE_NAME | TEXT | NO | RRC lease name | G-1 Well Info |
| OPR_ID | TEXT | YES | FK → OPERATOR.OPR_ID | G-1 header |
| COUNTY | TEXT | NO | Texas county name | G-1 Well Info |
| RRC_DISTRICT | TEXT | YES | RRC Oil & Gas District number | G-1 Well Info |
| FIELD_NAME | TEXT | YES | RRC field name and reservoir | G-1 Well Info |
| FIELD_NO | TEXT | YES | RRC field number | G-1 Well Info |
| RRC_GAS_ID | TEXT | YES | RRC Gas ID / Lease ID | G-1 Well Info |
| LATITUDE | DOUBLE | YES | Decimal degrees (NAD83) | G-1 / RRC records |
| LONGITUDE | DOUBLE | YES | Decimal degrees (NAD83), negative = West | G-1 / RRC records |
| DATUM | TEXT | YES | Horizontal datum (NAD83 or NAD27) | G-1 / GW-2 |
| ELEVATION_FT | NUMERIC | YES | Ground level elevation in feet | G-1 Completion Info |
| ELEV_DATUM | TEXT | YES | Elevation datum (GL = Ground Level) | G-1 Completion Info |
| GEOM | GEOMETRY | YES | PostGIS Point geometry (EPSG:4269) | Derived from LAT/LON |
| WELL_TYPE | TEXT | YES | GAS, OIL, DUAL, etc. | G-1 Filing Info |
| WELL_STATUS | TEXT | YES | PRODUCING, PLUGGED & ABANDONED, SHUT-IN | G-1 Filing Info |
| FILING_PURPOSE | TEXT | YES | INITIAL POTENTIAL, RETEST, PLUGGING | G-1 Filing Info |
| WELL_CLASS | TEXT | YES | New Well, Recompletion, Abandoned Producer | G-1 Filing Info |
| NEAREST_TOWN | TEXT | YES | Nearest town name | G-1 Well Info |
| DISTANCE_MI | NUMERIC | YES | Distance in miles to nearest town | G-1 Well Info |
| DIRECTION | TEXT | YES | Compass direction to nearest town (SW, NW, etc.) | G-1 Well Info |
| TOTAL_ACRES | NUMERIC | YES | Total lease acres | G-1 Completion Info |
| NEAREST_WELL_FT | NUMERIC | YES | Distance to nearest well in same reservoir (ft) | G-1 Completion Info |
| OFF_LEASE | BOOLEAN | YES | Is well location off the lease? | G-1 Completion Info |
| SECTION_BLOCK_SURVEY | TEXT | YES | Section, block, and survey description | G-1 Location |
| PERMIT_NO | TEXT | YES | Drilling permit number | G-1 Filing Info |
| PERMIT_DATE | DATE | YES | Date of permit issuance | G-1 Filing Info |
| SUBMISSION_DATE | DATE | YES | Date form submitted to RRC | G-1 header |
| TRACKING_NO | TEXT | YES | RRC tracking number | G-1 header |

---

## Table: COMPLETION

Primary key: `COMP_ID` | FK: `WELL_ID → WELLS`

| Field | Type | Nullable | Description | Source |
|-------|------|----------|-------------|--------|
| COMP_ID | TEXT | NO | Surrogate PK (C-001, C-002, C-003) | Generated |
| WELL_ID | TEXT | NO | FK → WELLS.WELL_ID | — |
| COMP_TYPE | TEXT | YES | NEW WELL, OTHER/RECOMPLETION, ABANDONED PRODUCER | G-1 Filing Info |
| RECOMPLETION | BOOLEAN | YES | Is this a recompletion? | G-1 Completion Info |
| SPUD_DATE | DATE | YES | Date drilling commenced | G-1 Completion Info |
| DRILL_OP_END_DATE | DATE | YES | Date plug back / drilling operation ended | G-1 Completion Info |
| FIRST_PROD_DATE | DATE | YES | Date of first production after rig | G-1 Completion Info |
| PLUG_BACK_DATE | DATE | YES | Date plug-back operation completed | G-1 Completion Info |
| TOTAL_DEPTH_TVD | NUMERIC | YES | Total depth — true vertical depth (ft) | G-1 Completion Info |
| TOTAL_DEPTH_MD | NUMERIC | YES | Total depth — measured depth (ft) | G-1 Completion Info |
| PLUG_BACK_TVD | NUMERIC | YES | Plug-back depth TVD (ft) | G-1 Completion Info |
| PLUG_BACK_MD | NUMERIC | YES | Plug-back depth MD (ft) | G-1 Completion Info |
| PRODUCING_WELLS_LEASE | INTEGER | YES | Number of producing wells on lease including this one | G-1 Completion Info |
| DISTANCE_NEAREST_WELL_FT | NUMERIC | YES | Distance to nearest well in lease and reservoir (ft) | G-1 Completion Info |
| LOG_TYPES | TEXT | YES | Electric/other log types run | G-1 Completion Info |
| DIRECTIONAL_SURVEY | BOOLEAN | YES | Was directional survey made other than inclination? | G-1 Completion Info |
| CEMENTING_AFFIDAVIT | BOOLEAN | YES | Is cementing affidavit on file? | G-1 Completion Info |
| MULTIPLE_COMPLETION | BOOLEAN | YES | Is this a multiple completion? | G-1 Completion Info |
| DOWNHOLE_COMMINGLED | BOOLEAN | YES | Is completion downhole commingled (SWR)? | G-1 Completion Info |
| LOC_FT_FROM_LINE1 | NUMERIC | YES | Footage from first lease line | G-1 Completion Info |
| LINE1_DESC | TEXT | YES | Description of first line (East, North, etc.) | G-1 Completion Info |
| LOC_FT_FROM_LINE2 | NUMERIC | YES | Footage from second lease line | G-1 Completion Info |
| LINE2_DESC | TEXT | YES | Description of second line | G-1 Completion Info |
| ROTATION_TIME_HRS | NUMERIC | YES | Rotation time within surface casing (hrs) | G-1 Completion Info |

---

## Table: GAS_MEASUREMENT

Primary key: `MEAS_ID` | FK: `WELL_ID → WELLS`

| Field | Type | Nullable | Description | Source |
|-------|------|----------|-------------|--------|
| MEAS_ID | TEXT | NO | Surrogate PK (M-001, M-002) | Generated |
| WELL_ID | TEXT | NO | FK → WELLS.WELL_ID | — |
| TEST_DATE | DATE | NO | Date of gas measurement test | G-1 Gas Measurement Data |
| MEAS_METHOD | TEXT | YES | Measurement method (ORIFICE METER, etc.) | G-1 Gas Measurement Data |
| GAS_PROD_DURING_TEST_MCF | NUMERIC | YES | Gas production during test (MCF) | G-1 Gas Measurement Data |
| PREFLOWED_48HR | BOOLEAN | YES | Was well preflowed for 48 hours? | G-1 Gas Measurement Data |
| ORIFICE_CHOKE_IN | NUMERIC | YES | Orifice or choke size (inches) | G-1 Gas Measurement Data |
| COEFF_24HR | NUMERIC | YES | 24-hour orifice or choke coefficient | G-1 Gas Measurement Data |
| STATIC_PM_IN | NUMERIC | YES | Static Pm or choke (inches) | G-1 Gas Measurement Data |
| DIFF_HW | NUMERIC | YES | Differential (hw) | G-1 Gas Measurement Data |
| FLOW_TEMP_F | NUMERIC | YES | Flow temperature at orifice (°F) | G-1 Gas Measurement Data |
| GRAVITY_FG | NUMERIC | YES | Specific gravity (Fg) | G-1 Gas Measurement Data |
| COMPRESSIBILITY_FPV | NUMERIC | YES | Compressibility factor (Fpv) | G-1 Gas Measurement Data |
| VOLUME_MCFD | NUMERIC | YES | Calculated gas volume (MCF/day) | G-1 Gas Measurement Data |
| GRAVITY_DRY | NUMERIC | YES | Gravity — dry gas | G-1 Field Data |
| GAS_LIQ_RATIO_CF_BBL | NUMERIC | YES | Gas-liquid hydrocarbon ratio (CF/Bbl) | G-1 Field Data |
| AVG_SHUTIN_TEMP_F | NUMERIC | YES | Average shut-in temperature (°F) | G-1 Field Data |
| BH_TEMP_F | NUMERIC | YES | Bottom hole temperature (°F) | G-1 Field Data |
| BH_TEMP_DEPTH_FT | NUMERIC | YES | Depth at which BH temperature measured (ft) | G-1 Field Data |
| GAS_GRAVITY_LIQUID_DEG | NUMERIC | YES | Gravity of liquid hydrocarbons (°F) | G-1 Field Data |
| GRAVITY_MIXTURE | NUMERIC | YES | Gravity of gas-liquid mixture | G-1 Field Data |

---

## Table: FORMATIONS

Primary key: `FORM_ID` | FK: `WELL_ID → WELLS`

| Field | Type | Nullable | Description | Source |
|-------|------|----------|-------------|--------|
| FORM_ID | TEXT | NO | Surrogate PK (FM-001 through FM-012) | Generated |
| WELL_ID | TEXT | NO | FK → WELLS.WELL_ID | — |
| FORMATION_NAME | TEXT | NO | RRC formation name | G-1 Formation Record |
| FORMATION_GROUP | TEXT | YES | Broader stratigraphic group | G-1 Formation Record |
| ENCOUNTERED | BOOLEAN | YES | Was formation encountered while drilling? | G-1 Formation Record |
| DEPTH_TVD_FT | NUMERIC | YES | Formation top — true vertical depth (ft) | G-1 Formation Record |
| DEPTH_MD_FT | NUMERIC | YES | Formation top — measured depth (ft) | G-1 Formation Record |
| IS_ISOLATED | BOOLEAN | YES | Is formation isolated from injection/disposal? | G-1 Formation Record |
| INJ_DISPOSAL_ZONE | BOOLEAN | YES | Is formation an injection/disposal zone? | G-1 Formation Record |
| GEOPRESSURED | BOOLEAN | YES | Is formation geopressured? | G-1 Formation Record |
| H2S_PRESENT | BOOLEAN | YES | Does formation contain H2S? | G-1 Formation Record |
| REMARKS | TEXT | YES | Additional notes (NOT DEEP ENOUGH, BASE OF WILCOX, etc.) | G-1 Formation Record |

---

## Coordinate Reference Systems

| CRS | EPSG | Description | Used in |
|-----|------|-------------|---------|
| NAD83 | 4269 | North American Datum 1983 — primary CRS | WELLS geometry, G-1 filings |
| NAD27 | 4267 | North American Datum 1927 — legacy CRS | W-003 K&H Fee Porcion (GW-2) |
| WGS84 | 4326 | World Geodetic System 1984 | GeoJSON export standard |

> **Note:** When converting NAD27 coordinates to WGS84/NAD83, apply a datum transformation. In PostGIS: `ST_Transform(geom, 4326)`. Shift in South Texas is approximately 10–30 meters.

---

## RRC Form Reference

| Form | Full Name | Key Data | Tables |
|------|-----------|----------|--------|
| G-1 | Gas Well Back Pressure Test, Completion or Recompletion Report | Well info, completion, gas measurement, casing, tubing, perforations, fracturing, formations | WELLS, COMPLETION, GAS_MEASUREMENT, PRESSURE_TEST, CASING, TUBING, PERFORATIONS, FRAC_TREATMENT, FORMATIONS |
| G-5 | Gas Well Classification Report | Condensate gravity, distillation, pipeline connection | CLASSIFICATION |
| G-10 | Gas Well Status Report | IP gas, pressure, condensate, water | GAS_STATUS |
| W-3 | Plugging Record | Plug depths, cement, mud weight | PLUGGING |
| W-15 | Cementing Report | CIBP depth, cement class/volume, cementer | CEMENTING |
| P-4 | Certificate of Compliance and Transportation Authority | Gatherer, purchaser, system codes | TRANSPORT_AUTH |
| P-13 | Application to Condition Abandoned Well for Fresh Water | Water well conversion, landowner | GROUNDWATER |
| GW-2 | Groundwater Protection Determination | Protection depths, Carrizo zone | GROUNDWATER |
