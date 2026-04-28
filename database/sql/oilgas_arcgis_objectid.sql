-- ============================================================
-- ARCGIS PRO COMPATIBILITY — OBJECTID & GLOBALID
-- oilgas schema — all 9 spatial feature class tables
-- ============================================================
-- What this script does:
--   1. Adds objectid  SERIAL  — required by ArcGIS Pro as the
--      unique integer row identifier (ObjectID field).
--   2. Adds globalid  UUID    — required for Sync, Field Maps,
--      Replica, and versioned editing workflows.
--   3. Seeds globalid with gen_random_uuid() for all existing rows.
--   4. Creates a trigger to auto-populate globalid on INSERT.
--   5. Registers the geometry columns with the Esri sde schema
--      metadata view (optional — only needed for Enterprise GDB).
--   6. Adds unique constraints so ArcGIS recognises them as
--      ObjectID and GlobalID field types on registration.
--
-- Your existing TEXT primary keys (well_id, lease_id, etc.)
-- are NOT modified — they continue to work as before.
-- objectid is a PARALLEL key used only by ArcGIS Pro.
--
-- Run order: execute this AFTER the core schema and both
-- extension files have been applied.
-- ============================================================

SET search_path TO oilgas, public;


-- ============================================================
-- HELPER: reusable function to auto-fill globalid on INSERT
-- ============================================================
CREATE OR REPLACE FUNCTION oilgas.set_globalid()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.globalid IS NULL THEN
        NEW.globalid := gen_random_uuid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION oilgas.set_globalid() IS
    'Populates globalid with a UUID on INSERT if not supplied. '
    'Shared trigger function used by all ArcGIS-registered feature classes.';


-- ============================================================
-- 1. WELLS  — Point (NAD83)
-- ============================================================
ALTER TABLE oilgas.wells
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.wells
    ADD CONSTRAINT wells_objectid_uq  UNIQUE (objectid);

ALTER TABLE oilgas.wells
    ADD CONSTRAINT wells_globalid_uq  UNIQUE (globalid);

-- Seed globalid for any existing rows that got NULL (edge case)
UPDATE oilgas.wells
SET globalid = gen_random_uuid()
WHERE globalid IS NULL;

CREATE TRIGGER wells_globalid_trg
    BEFORE INSERT ON oilgas.wells
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.wells.objectid IS
    'ArcGIS Pro ObjectID — unique integer row identifier. '
    'Do not use as application FK; use well_id instead.';
COMMENT ON COLUMN oilgas.wells.globalid IS
    'ArcGIS GlobalID — UUID for sync, replica, and Field Maps workflows.';


-- ============================================================
-- 2. LEASEHOLDS  — MultiPolygon (NAD83)
-- ============================================================
ALTER TABLE oilgas.leaseholds
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.leaseholds
    ADD CONSTRAINT leaseholds_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.leaseholds
    ADD CONSTRAINT leaseholds_globalid_uq UNIQUE (globalid);

UPDATE oilgas.leaseholds SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER leaseholds_globalid_trg
    BEFORE INSERT ON oilgas.leaseholds
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.leaseholds.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.leaseholds.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 3. PADS  — Point (NAD83)  +  pad_boundary Polygon (NAD83)
-- ============================================================
-- Note: ArcGIS Pro will use the first registered geometry column
-- (geom / Point) as the primary Shape field. pad_boundary is a
-- secondary geometry — register pads twice if you need both as
-- separate feature classes, or promote pad_boundary to its own
-- feature class via Feature Class to Feature Class tool.
-- ============================================================
ALTER TABLE oilgas.pads
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.pads
    ADD CONSTRAINT pads_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.pads
    ADD CONSTRAINT pads_globalid_uq UNIQUE (globalid);

UPDATE oilgas.pads SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER pads_globalid_trg
    BEFORE INSERT ON oilgas.pads
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.pads.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.pads.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 4. FACILITIES  — Point (NAD83)
-- ============================================================
ALTER TABLE oilgas.facilities
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.facilities
    ADD CONSTRAINT facilities_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.facilities
    ADD CONSTRAINT facilities_globalid_uq UNIQUE (globalid);

UPDATE oilgas.facilities SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER facilities_globalid_trg
    BEFORE INSERT ON oilgas.facilities
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.facilities.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.facilities.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 5. PIPELINES  — MultiLineString (NAD83)
-- ============================================================
ALTER TABLE oilgas.pipelines
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.pipelines
    ADD CONSTRAINT pipelines_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.pipelines
    ADD CONSTRAINT pipelines_globalid_uq UNIQUE (globalid);

UPDATE oilgas.pipelines SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER pipelines_globalid_trg
    BEFORE INSERT ON oilgas.pipelines
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.pipelines.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.pipelines.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 6. DIRECTIONAL_SURVEY  — PointZ (NAD83, 3-D)
-- ============================================================
-- This is a 3-D geometry (PointZ). In ArcGIS Pro it will appear
-- in a Scene (3-D view), not a standard 2-D map. Make sure to
-- enable Z values when you register this feature class:
--   Right-click in Catalog → Properties → check "Has Z"
-- ============================================================
ALTER TABLE oilgas.directional_survey
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.directional_survey
    ADD CONSTRAINT dir_survey_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.directional_survey
    ADD CONSTRAINT dir_survey_globalid_uq UNIQUE (globalid);

UPDATE oilgas.directional_survey SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER dir_survey_globalid_trg
    BEFORE INSERT ON oilgas.directional_survey
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.directional_survey.objectid IS
    'ArcGIS Pro ObjectID. PointZ geometry — use in Scene view.';
COMMENT ON COLUMN oilgas.directional_survey.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 7. RESERVOIR  — MultiPolygon (NAD83)
-- ============================================================
ALTER TABLE oilgas.reservoir
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.reservoir
    ADD CONSTRAINT reservoir_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.reservoir
    ADD CONSTRAINT reservoir_globalid_uq UNIQUE (globalid);

UPDATE oilgas.reservoir SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER reservoir_globalid_trg
    BEFORE INSERT ON oilgas.reservoir
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.reservoir.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.reservoir.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 8. SPILL_INCIDENT  — Point (NAD83)
-- ============================================================
ALTER TABLE oilgas.spill_incident
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.spill_incident
    ADD CONSTRAINT spill_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.spill_incident
    ADD CONSTRAINT spill_globalid_uq UNIQUE (globalid);

UPDATE oilgas.spill_incident SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER spill_globalid_trg
    BEFORE INSERT ON oilgas.spill_incident
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.spill_incident.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.spill_incident.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- 9. RIGHT_OF_WAY  — MultiLineString (NAD83)
-- ============================================================
ALTER TABLE oilgas.right_of_way
    ADD COLUMN IF NOT EXISTS objectid  SERIAL,
    ADD COLUMN IF NOT EXISTS globalid  UUID   DEFAULT gen_random_uuid();

ALTER TABLE oilgas.right_of_way
    ADD CONSTRAINT row_objectid_uq UNIQUE (objectid);

ALTER TABLE oilgas.right_of_way
    ADD CONSTRAINT row_globalid_uq UNIQUE (globalid);

UPDATE oilgas.right_of_way SET globalid = gen_random_uuid() WHERE globalid IS NULL;

CREATE TRIGGER row_globalid_trg
    BEFORE INSERT ON oilgas.right_of_way
    FOR EACH ROW EXECUTE FUNCTION oilgas.set_globalid();

COMMENT ON COLUMN oilgas.right_of_way.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.right_of_way.globalid IS 'ArcGIS GlobalID.';


-- ============================================================
-- VERIFICATION QUERY
-- Run this after applying the script to confirm all 9 tables
-- have objectid and globalid columns in place.
-- ============================================================
SELECT
    t.table_name                                    AS feature_class,
    MAX(CASE WHEN c.column_name = 'objectid'
             THEN c.data_type END)                  AS objectid_type,
    MAX(CASE WHEN c.column_name = 'globalid'
             THEN c.data_type END)                  AS globalid_type,
    f.type                                          AS geometry_type,
    f.srid                                          AS srid
FROM information_schema.tables t
JOIN information_schema.columns c
    ON c.table_schema = t.table_schema
    AND c.table_name  = t.table_name
LEFT JOIN geometry_columns f
    ON f.f_table_schema = t.table_schema
    AND f.f_table_name  = t.table_name
WHERE t.table_schema = 'oilgas'
  AND t.table_name IN (
      'wells','leaseholds','pads','facilities','pipelines',
      'directional_survey','reservoir','spill_incident','right_of_way'
  )
  AND c.column_name IN ('objectid','globalid')
GROUP BY t.table_name, f.type, f.srid
ORDER BY t.table_name;


-- ============================================================
-- WHAT TO DO NEXT IN ARCGIS PRO
-- ============================================================
--
-- 1. Open ArcGIS Pro → Catalog pane → Databases
--    → New Database Connection → PostgreSQL
--    Fill in: host, port (5432), database (oilgas),
--    username, password.
--
-- 2. Expand the connection. Each of the 9 tables above will
--    show a feature class icon (they have geometry columns).
--
-- 3. To enable full editing on a table:
--    Right-click the feature class → "Register with Geodatabase"
--    ArcGIS will ask which column to use as ObjectID —
--    select "objectid" from the dropdown.
--    It will also register "globalid" as the GlobalID field.
--
-- 4. Drag any feature class onto a Map or Scene to display it.
--    For directional_survey — drag it onto a Scene (3-D view)
--    to see the PointZ elevation dimension.
--
-- 5. To start editing: Edit tab → Start (pencil icon).
--    Click a feature to select it, use the Edit Vertices tool
--    to move geometry. All changes write directly to PostgreSQL.
--
-- 6. Non-spatial tables (production_monthly, inspections, etc.)
--    appear with a table icon. Open them via right-click →
--    Open to view/edit attributes in a grid.
--
-- 7. To map your views (v_well_summary, v_open_violations, etc.):
--    Map tab → Add Data → Query Layer
--    Paste the view name: SELECT * FROM oilgas.v_well_summary
--    Set the unique identifier field to "well_id".
--    These are read-only but fully symbology-capable.
-- ============================================================
