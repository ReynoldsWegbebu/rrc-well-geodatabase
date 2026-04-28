-- ============================================================
-- OIL & GAS GEODATABASE — EXTENSION DDL
-- Adds: LEASEHOLDS, PADS, FACILITIES, PIPELINES,
--       INSPECTIONS, VIOLATIONS
-- Extends: RRC District 04 | Killam Oil Co., Ltd.
-- Compatible with: PostgreSQL 14+ with PostGIS 3.3+
-- Coordinate System: NAD83 (EPSG:4269)
-- Depends on: oilgas core schema (operator, wells tables)
-- ============================================================

SET search_path TO oilgas, public;


-- ============================================================
-- 17. LEASEHOLDS
-- ============================================================
-- A leasehold is the legal/administrative unit that groups one or
-- more wells. Inspections and violations reference lease_no from
-- the RRC source data, so lease_no is exposed here as a natural key.
-- ============================================================
CREATE TABLE oilgas.leaseholds (
    lease_id              TEXT        PRIMARY KEY,
    lease_no              TEXT        UNIQUE NOT NULL,   -- RRC lease/facility no.
    lease_name            TEXT        NOT NULL,
    opr_id                TEXT        REFERENCES oilgas.operator(opr_id),
    field_name            TEXT,
    field_no              TEXT,
    rrc_district          TEXT,
    county                TEXT        NOT NULL,
    state                 CHAR(2)     DEFAULT 'TX',

    -- Legal description
    section_block_survey  TEXT,
    abstract_no           TEXT,
    survey_name           TEXT,
    total_acres           NUMERIC(10,3),

    -- Status
    lease_status          TEXT        DEFAULT 'ACTIVE',  -- ACTIVE, INACTIVE, EXPIRED
    effective_date        DATE,
    expiry_date           DATE,

    -- Geometry (polygon boundary of the leasehold)
    geom                  geometry(MultiPolygon, 4269),

    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX leaseholds_geom_idx    ON oilgas.leaseholds USING GIST (geom);
CREATE INDEX leaseholds_lease_no_idx ON oilgas.leaseholds (lease_no);
CREATE INDEX leaseholds_county_idx  ON oilgas.leaseholds (county);
CREATE INDEX leaseholds_opr_idx     ON oilgas.leaseholds (opr_id);

COMMENT ON TABLE oilgas.leaseholds IS
    'RRC leasehold records. lease_no matches Lease No field on inspection '
    'and violation reports. One leasehold may contain multiple wells and pads. '
    'Source: RRC lease assignments and Form G-1 Lease No fields.';

-- Back-link wells → leaseholds
ALTER TABLE oilgas.wells
    ADD COLUMN IF NOT EXISTS lease_id TEXT REFERENCES oilgas.leaseholds(lease_id);

CREATE INDEX wells_lease_id_idx ON oilgas.wells (lease_id);


-- ============================================================
-- 18. PADS
-- ============================================================
-- A well pad is the physical surface location where one or more
-- wellheads are drilled. Multiple wells share a pad on multi-well
-- pad developments. Pads belong to a leasehold.
-- ============================================================
CREATE TABLE oilgas.pads (
    pad_id                TEXT        PRIMARY KEY,
    pad_name              TEXT,
    lease_id              TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id                TEXT        REFERENCES oilgas.operator(opr_id),
    county                TEXT        NOT NULL,
    rrc_district          TEXT,

    -- Surface location
    latitude              DOUBLE PRECISION,
    longitude             DOUBLE PRECISION,
    datum                 TEXT        DEFAULT 'NAD83',
    elevation_ft          NUMERIC(8,2),
    geom                  geometry(Point, 4269),

    -- Pad footprint (optional polygon)
    pad_boundary          geometry(Polygon, 4269),

    -- Characteristics
    pad_status            TEXT        DEFAULT 'ACTIVE',  -- ACTIVE, RECLAIMED, INTERIM_RECLAIMED
    well_count            INTEGER     DEFAULT 0,          -- denormalized convenience count
    pad_area_acres        NUMERIC(8,3),
    surface_owner         TEXT,
    road_access           BOOLEAN     DEFAULT TRUE,
    nearest_town          TEXT,
    distance_mi           NUMERIC(6,2),
    direction             TEXT,

    -- Dates
    construction_date     DATE,
    reclamation_date      DATE,

    notes                 TEXT,
    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX pads_geom_idx     ON oilgas.pads USING GIST (geom);
CREATE INDEX pads_boundary_idx ON oilgas.pads USING GIST (pad_boundary);
CREATE INDEX pads_lease_id_idx ON oilgas.pads (lease_id);
CREATE INDEX pads_county_idx   ON oilgas.pads (county);

COMMENT ON TABLE oilgas.pads IS
    'Physical well pad locations. One pad may host multiple wellheads. '
    'Geometry stored as PostGIS Point (centroid) in NAD83 (EPSG:4269). '
    'Optional pad_boundary polygon captures the disturbed surface footprint.';

-- Trigger: auto-populate point geometry from lat/lon
CREATE OR REPLACE FUNCTION oilgas.pads_update_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4269);
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pads_geom_trigger
    BEFORE INSERT OR UPDATE ON oilgas.pads
    FOR EACH ROW EXECUTE FUNCTION oilgas.pads_update_geom();

-- Back-link wells → pads
ALTER TABLE oilgas.wells
    ADD COLUMN IF NOT EXISTS pad_id TEXT REFERENCES oilgas.pads(pad_id);

CREATE INDEX wells_pad_id_idx ON oilgas.wells (pad_id);


-- ============================================================
-- 19. FACILITIES
-- ============================================================
-- Surface facilities on a leasehold: tank batteries, separators,
-- SWD systems, compression stations, metering points, etc.
-- A facility lives on a pad (or standalone) and belongs to a lease.
-- ============================================================
CREATE TABLE oilgas.facilities (
    facility_id           TEXT        PRIMARY KEY,
    facility_name         TEXT        NOT NULL,
    facility_type         TEXT        NOT NULL,
        -- TANK_BATTERY, SEPARATOR, TREATER, SWD_SYSTEM, COMPRESSOR,
        -- METER_STATION, FLARE, WATER_DISPOSAL, HEATER_TREATER, OTHER
    lease_id              TEXT        REFERENCES oilgas.leaseholds(lease_id),
    pad_id                TEXT        REFERENCES oilgas.pads(pad_id),
    opr_id                TEXT        REFERENCES oilgas.operator(opr_id),
    rrc_gas_id            TEXT,       -- RRC gas identifier (links to wells.rrc_gas_id)
    county                TEXT        NOT NULL,
    rrc_district          TEXT,
    field_name            TEXT,

    -- Location
    latitude              DOUBLE PRECISION,
    longitude             DOUBLE PRECISION,
    datum                 TEXT        DEFAULT 'NAD83',
    elevation_ft          NUMERIC(8,2),
    geom                  geometry(Point, 4269),

    -- Status
    facility_status       TEXT        DEFAULT 'ACTIVE',
        -- ACTIVE, INACTIVE, DECOMMISSIONED, PLUGGED_ABANDONED
    install_date          DATE,
    decommission_date     DATE,

    -- Capacity / specs
    oil_capacity_bbl      NUMERIC(10,1),
    water_capacity_bbl    NUMERIC(10,1),
    gas_capacity_mcfd     NUMERIC(10,1),
    tank_count            INTEGER,

    -- Regulatory
    permit_no             TEXT,
    permit_date           DATE,
    h2s_present           BOOLEAN     DEFAULT FALSE,
    secondary_containment BOOLEAN     DEFAULT FALSE,

    notes                 TEXT,
    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX facilities_geom_idx     ON oilgas.facilities USING GIST (geom);
CREATE INDEX facilities_lease_id_idx ON oilgas.facilities (lease_id);
CREATE INDEX facilities_pad_id_idx   ON oilgas.facilities (pad_id);
CREATE INDEX facilities_type_idx     ON oilgas.facilities (facility_type);
CREATE INDEX facilities_status_idx   ON oilgas.facilities (facility_status);

COMMENT ON TABLE oilgas.facilities IS
    'Surface production facilities (tank batteries, separators, SWD, compressors, etc.). '
    'Links to both leaseholds and pads. Inspection and violation records may target '
    'a facility rather than a specific well. '
    'Source: RRC facility registrations and Form G-1 references.';

-- Trigger: auto-populate geometry
CREATE OR REPLACE FUNCTION oilgas.facilities_update_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4269);
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER facilities_geom_trigger
    BEFORE INSERT OR UPDATE ON oilgas.facilities
    FOR EACH ROW EXECUTE FUNCTION oilgas.facilities_update_geom();


-- Junction: wells served by a facility (many-to-many)
CREATE TABLE oilgas.well_facility (
    well_id       TEXT  NOT NULL REFERENCES oilgas.wells(well_id)      ON DELETE CASCADE,
    facility_id   TEXT  NOT NULL REFERENCES oilgas.facilities(facility_id) ON DELETE CASCADE,
    role          TEXT,   -- PRODUCTION, DISPOSAL, INJECTION, METERING
    effective_date DATE,
    end_date       DATE,
    PRIMARY KEY (well_id, facility_id)
);

COMMENT ON TABLE oilgas.well_facility IS
    'Many-to-many: which wells flow to / through which facilities.';


-- ============================================================
-- 20. PIPELINES
-- ============================================================
-- Gathering, flowline, and transmission pipeline segments on
-- the leasehold. Each segment is a spatial LineString connecting
-- two endpoints (well, facility, or external tie-in).
-- ============================================================
CREATE TABLE oilgas.pipelines (
    pipeline_id           TEXT        PRIMARY KEY,
    pipeline_name         TEXT,
    pipeline_type         TEXT        NOT NULL,
        -- FLOWLINE, GATHERING, SALES_LINE, INJECTION_LINE,
        --  WATER_DISPOSAL, GAS_LIFT, OTHER
    lease_id              TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id                TEXT        REFERENCES oilgas.operator(opr_id),
    rrc_district          TEXT,
    county                TEXT,

    -- Endpoints (nullable — may terminate off-lease)
    from_well_id          TEXT        REFERENCES oilgas.wells(well_id),
    to_facility_id        TEXT        REFERENCES oilgas.facilities(facility_id),
    from_facility_id      TEXT        REFERENCES oilgas.facilities(facility_id),
    to_well_id            TEXT        REFERENCES oilgas.wells(well_id),

    -- Geometry (line in NAD83)
    geom                  geometry(MultiLineString, 4269),

    -- Physical characteristics
    pipe_material         TEXT,       -- STEEL, HDPE, FIBERGLASS, FLEX
    nominal_diameter_in   NUMERIC(5,2),
    wall_thickness_in     NUMERIC(5,4),
    max_op_pressure_psia  NUMERIC(8,1),
    length_ft             NUMERIC(10,1),
    length_mi             NUMERIC(8,4),
    depth_of_cover_in     NUMERIC(6,1),
    coating_type          TEXT,

    -- Fluid / service
    commodity             TEXT,       -- OIL, GAS, WATER, CONDENSATE, MIXED
    h2s_service           BOOLEAN     DEFAULT FALSE,
    co2_service           BOOLEAN     DEFAULT FALSE,
    insulated             BOOLEAN     DEFAULT FALSE,

    -- Status & regulatory
    pipeline_status       TEXT        DEFAULT 'ACTIVE',
    install_date          DATE,
    abandon_date          DATE,
    rrc_permit_no         TEXT,
    pressure_test_date    DATE,
    pressure_test_psia    NUMERIC(8,1),

    notes                 TEXT,
    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX pipelines_geom_idx     ON oilgas.pipelines USING GIST (geom);
CREATE INDEX pipelines_lease_id_idx ON oilgas.pipelines (lease_id);
CREATE INDEX pipelines_type_idx     ON oilgas.pipelines (pipeline_type);
CREATE INDEX pipelines_from_well_idx ON oilgas.pipelines (from_well_id);
CREATE INDEX pipelines_to_fac_idx   ON oilgas.pipelines (to_facility_id);

COMMENT ON TABLE oilgas.pipelines IS
    'Pipeline and flowline segments. Geometry stored as MultiLineString in NAD83 (EPSG:4269). '
    'Endpoints reference wells and/or facilities. '
    'Source: RRC pipeline permits, plat maps, and as-built surveys.';


-- ============================================================
-- 21. INSPECTIONS
-- ============================================================
-- Sourced from InspectionList__2_.xls (iceQueryTable).
-- 7,942 records. Links to leaseholds via lease_no and to wells
-- via api_number. May target a facility rather than a single well.
-- ============================================================
CREATE TABLE oilgas.inspections (
    inspection_id             TEXT        PRIMARY KEY,
    opr_id                    TEXT        REFERENCES oilgas.operator(opr_id),
    lease_id                  TEXT        REFERENCES oilgas.leaseholds(lease_id),
    well_id                   TEXT        REFERENCES oilgas.wells(well_id),
    facility_id               TEXT        REFERENCES oilgas.facilities(facility_id),

    -- Source columns (preserved verbatim for ETL traceability)
    lease_no                  TEXT,       -- raw RRC lease no. (join key to leaseholds.lease_no)
    lease_facility_name       TEXT,
    api_number                TEXT,       -- raw; resolve to well_id post-load
    well_no                   TEXT,
    drilling_permit_no        TEXT,

    -- Where
    rrc_district              INTEGER,
    district_performing       TEXT,       -- Corpus Christi, San Antonio, etc.
    county                    TEXT        NOT NULL,
    field_name                TEXT,

    -- When & outcome
    inspection_date           DATE        NOT NULL,
    complaint_no              TEXT,       -- populated only for complaint-driven inspections
    compliance                TEXT        NOT NULL CHECK (compliance IN ('Yes','No')),
        -- 'Yes' = in compliance at time of inspection
        -- 'No'  = violation(s) found (see violations table)

    -- Inspector / source metadata
    inspector_name            TEXT,
    inspection_type           TEXT,       -- ROUTINE, COMPLAINT, FOLLOW_UP, INITIAL
    notes                     TEXT,

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX inspections_lease_id_idx   ON oilgas.inspections (lease_id);
CREATE INDEX inspections_well_id_idx    ON oilgas.inspections (well_id);
CREATE INDEX inspections_facility_idx   ON oilgas.inspections (facility_id);
CREATE INDEX inspections_date_idx       ON oilgas.inspections (inspection_date);
CREATE INDEX inspections_compliance_idx ON oilgas.inspections (compliance);
CREATE INDEX inspections_county_idx     ON oilgas.inspections (county);
CREATE INDEX inspections_lease_no_idx   ON oilgas.inspections (lease_no);
CREATE INDEX inspections_api_idx        ON oilgas.inspections (api_number);

COMMENT ON TABLE oilgas.inspections IS
    '7,942 RRC field inspection records (iceQueryTable). '
    'compliance = Yes means the site was in compliance at inspection. '
    'compliance = No triggers one or more rows in the violations table. '
    'FK to wells resolves via api_number; FK to leaseholds via lease_no. '
    'Source: RRC Inspector Activity Report (InspectionList).';


-- ============================================================
-- 22. VIOLATIONS
-- ============================================================
-- Sourced from ViolationList.xls (vQueryTable).
-- 108 records. Each row is a specific rule violation discovered
-- during (or linked to) an inspection. Links to inspections,
-- leaseholds, and wells.
-- ============================================================
CREATE TABLE oilgas.violations (
    violation_id                  TEXT        PRIMARY KEY,
    inspection_id                 TEXT        REFERENCES oilgas.inspections(inspection_id),
    opr_id                        TEXT        REFERENCES oilgas.operator(opr_id),
    lease_id                      TEXT        REFERENCES oilgas.leaseholds(lease_id),
    well_id                       TEXT        REFERENCES oilgas.wells(well_id),
    facility_id                   TEXT        REFERENCES oilgas.facilities(facility_id),

    -- Source columns
    lease_no                      TEXT,
    lease_facility_name           TEXT,
    api_number                    TEXT,
    well_no                       TEXT,
    drilling_permit_no            TEXT,

    -- Location context
    rrc_district                  INTEGER,
    county                        TEXT        NOT NULL,
    field_name                    TEXT,

    -- Discovery
    discovery_date                DATE        NOT NULL,

    -- Rule violated
    violated_rule                 TEXT        NOT NULL,
        -- e.g. '16 TAC § 3.13(a)(6)(A) [SWR 13(a)(6)(A)]'
    violated_rule_description     TEXT        NOT NULL,
        -- e.g. 'Surface Control of Well'
    violated_rule_category        TEXT,
        -- Populated by ETL / lookup: WELL_CONTROL, ENVIRONMENTAL,
        -- ADMINISTRATIVE, EQUIPMENT, SAFETY, REPORTING
    major_violation               BOOLEAN     NOT NULL DEFAULT FALSE,
        -- Source: 'Major Violation Indicator' (Y/N)

    -- Compliance resolution
    compliant_on_reinspection     TEXT,
        -- '--' (pending), 'Y' (resolved), 'N' (still non-compliant)
    reinspection_date             DATE,
    reinspection_id               TEXT        REFERENCES oilgas.inspections(inspection_id),

    -- Enforcement
    last_enforcement_action       TEXT,
        -- 'Notice of Violation', 'Referred to State-Managed Plugging', etc.
    enforcement_action_date       DATE,
    penalty_amount                NUMERIC(12,2),
    penalty_paid_date             DATE,

    notes                         TEXT,
    created_at                    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX violations_inspection_idx  ON oilgas.violations (inspection_id);
CREATE INDEX violations_lease_id_idx    ON oilgas.violations (lease_id);
CREATE INDEX violations_well_id_idx     ON oilgas.violations (well_id);
CREATE INDEX violations_facility_idx    ON oilgas.violations (facility_id);
CREATE INDEX violations_date_idx        ON oilgas.violations (discovery_date);
CREATE INDEX violations_rule_idx        ON oilgas.violations (violated_rule);
CREATE INDEX violations_category_idx    ON oilgas.violations (violated_rule_category);
CREATE INDEX violations_major_idx       ON oilgas.violations (major_violation);
CREATE INDEX violations_enforcement_idx ON oilgas.violations (last_enforcement_action);
CREATE INDEX violations_lease_no_idx    ON oilgas.violations (lease_no);
CREATE INDEX violations_api_idx         ON oilgas.violations (api_number);

COMMENT ON TABLE oilgas.violations IS
    '108 RRC violation records (vQueryTable). Each row = one violated rule. '
    'A single inspection may produce multiple violation rows. '
    'inspection_id links back to the parent inspection; '
    'reinspection_id links to the follow-up inspection that resolved the issue. '
    'Source: RRC Violation List.';


-- ============================================================
-- LOOKUP TABLE: VIOLATION RULE CATEGORIES
-- ============================================================
CREATE TABLE oilgas.violation_rule_ref (
    violated_rule             TEXT        PRIMARY KEY,
    violated_rule_description TEXT        NOT NULL,
    rule_category             TEXT        NOT NULL,
        -- WELL_CONTROL, ENVIRONMENTAL, ADMINISTRATIVE,
        -- EQUIPMENT, SAFETY, REPORTING
    rrc_chapter               TEXT,       -- '3', '4', etc.
    active                    BOOLEAN     DEFAULT TRUE
);

COMMENT ON TABLE oilgas.violation_rule_ref IS
    'Reference table for RRC violated rule codes, descriptions, and categories. '
    'Seeded from distinct values in ViolationList.xls.';

-- Seed from the 16 distinct rules observed in the source data
INSERT INTO oilgas.violation_rule_ref (violated_rule, violated_rule_description, rule_category, rrc_chapter) VALUES
  ('16 TAC § 3.3(1) [SWR 3(1)]',                     'Entrance Sign',                                      'ADMINISTRATIVE', '3'),
  ('16 TAC § 3.3(2) [SWR 3(2)]',                     'Battery Sign; Commingling Permit',                   'ADMINISTRATIVE', '3'),
  ('16 TAC § 3.3(3) [SWR 3(3)]',                     'Well Sign',                                          'ADMINISTRATIVE', '3'),
  ('16 TAC § 3.8(d)(1) [SWR 8(d)(1)]',               'Dike or Fire Wall Requirements',                     'EQUIPMENT',      '3'),
  ('16 TAC § 3.8(d)(4)(H)(i) [SWR 8(d)(4)(H)(i)]',  'Pit Backfill Requirements',                          'ENVIRONMENTAL',  '3'),
  ('16 TAC § 3.9(1) [SWR 9(1)]',                     'BOPS or Control Head Requirement',                   'WELL_CONTROL',   '3'),
  ('16 TAC § 3.13(a)(6)(A) [SWR 13(a)(6)(A)]',       'Surface Control of Well',                            'WELL_CONTROL',   '3'),
  ('16 TAC § 3.13(a)(6)(B) [SWR 13(a)(6)(B)]',       'Surface Control of Well',                            'WELL_CONTROL',   '3'),
  ('16 TAC § 3.14(b)(2) [SWR 14(b)(2)]',             'Notice of Fire, Leak, Spill',                        'REPORTING',      '3'),
  ('16 TAC § 3.14(d)(12) [SWR 14(d)(12)]',           'Bird Protection',                                    'ENVIRONMENTAL',  '3'),
  ('16 TAC § 3.20(a)(1) [SWR 20(a)(1)]',             'Inactive Unplugged Well',                            'EQUIPMENT',      '3'),
  ('16 TAC § 3.21(i) [SWR 21(i)]',                   'Rubbish or Debris Might Constitute a Fire Hazard',   'SAFETY',         '3'),
  ('16 TAC § 3.21(j) [SWR 21(j)]',                   'Empty and Remove tanks, vessels, flowlines, junk, close pits.', 'EQUIPMENT', '3'),
  ('16 TAC § 3.22(b) [SWR 22(b)]',                   'Permit Required for Injection Well',                 'ADMINISTRATIVE', '3'),
  ('16 TAC § 3.46(a) [SWR 46(a)]',                   'Permit Required for Disposal Well',                  'ADMINISTRATIVE', '3'),
  ('16 TAC § 4.103(a) [4.103(a)]',                   'Unpermitted Disposal of Oil and Gas Wastes',         'ENVIRONMENTAL',  '4');


-- ============================================================
-- VIEWS — Analytical views for the new tables
-- ============================================================

-- Compliance summary per lease
CREATE OR REPLACE VIEW oilgas.v_lease_compliance AS
SELECT
    l.lease_id,
    l.lease_no,
    l.lease_name,
    l.county,
    l.field_name,
    op.operator_name,
    COUNT(DISTINCT i.inspection_id)                         AS total_inspections,
    SUM(CASE WHEN i.compliance = 'Yes' THEN 1 ELSE 0 END)  AS inspections_compliant,
    SUM(CASE WHEN i.compliance = 'No'  THEN 1 ELSE 0 END)  AS inspections_non_compliant,
    ROUND(
        100.0 * SUM(CASE WHEN i.compliance = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(i.inspection_id), 0), 1
    )                                                       AS compliance_rate_pct,
    COUNT(DISTINCT v.violation_id)                          AS total_violations,
    MAX(i.inspection_date)                                  AS last_inspection_date
FROM oilgas.leaseholds l
LEFT JOIN oilgas.operator    op ON l.opr_id       = op.opr_id
LEFT JOIN oilgas.inspections i  ON l.lease_id     = i.lease_id
LEFT JOIN oilgas.violations  v  ON l.lease_id     = v.lease_id
GROUP BY l.lease_id, l.lease_no, l.lease_name, l.county, l.field_name, op.operator_name;

COMMENT ON VIEW oilgas.v_lease_compliance IS
    'Compliance rate and violation count per leasehold.';


-- Open (unresolved) violations
CREATE OR REPLACE VIEW oilgas.v_open_violations AS
SELECT
    v.violation_id,
    v.discovery_date,
    l.lease_no,
    l.lease_name,
    l.county,
    w.api_number,
    w.well_no,
    v.violated_rule,
    v.violated_rule_description,
    r.rule_category,
    v.major_violation,
    v.last_enforcement_action,
    v.enforcement_action_date,
    v.compliant_on_reinspection,
    CURRENT_DATE - v.discovery_date                         AS days_open
FROM oilgas.violations v
LEFT JOIN oilgas.leaseholds         l  ON v.lease_id      = l.lease_id
LEFT JOIN oilgas.wells              w  ON v.well_id       = w.well_id
LEFT JOIN oilgas.violation_rule_ref r  ON v.violated_rule = r.violated_rule
WHERE v.compliant_on_reinspection IN ('--', 'N')
  OR v.compliant_on_reinspection IS NULL
ORDER BY v.discovery_date;

COMMENT ON VIEW oilgas.v_open_violations IS
    'Violations not yet resolved (compliant_on_reinspection is pending or N).';


-- Full well context — extends v_well_summary with spatial hierarchy
CREATE OR REPLACE VIEW oilgas.v_well_full AS
SELECT
    w.well_id,
    w.api_number,
    w.well_no,
    w.well_status,
    w.well_type,
    w.county,
    w.field_name,
    w.latitude,
    w.longitude,
    w.permit_no,
    -- Leasehold
    l.lease_no,
    l.lease_name,
    l.lease_status,
    -- Pad
    p.pad_id,
    p.pad_name,
    p.pad_status,
    -- Operator
    op.operator_name,
    op.operator_p5_no,
    -- Completion
    c.spud_date,
    c.first_prod_date,
    c.total_depth_tvd,
    -- Production
    gs.gas_produced_mcfd    AS ip_gas_mcfd,
    gs.siwh_pressure_psia,
    -- Compliance snapshot
    latest_i.last_inspection_date,
    latest_i.last_compliance
FROM oilgas.wells w
LEFT JOIN oilgas.leaseholds  l  ON w.lease_id  = l.lease_id
LEFT JOIN oilgas.pads        p  ON w.pad_id    = p.pad_id
LEFT JOIN oilgas.operator    op ON w.opr_id    = op.opr_id
LEFT JOIN oilgas.completion  c  ON w.well_id   = c.well_id
LEFT JOIN oilgas.gas_status  gs ON w.well_id   = gs.well_id
LEFT JOIN LATERAL (
    SELECT inspection_date AS last_inspection_date,
           compliance      AS last_compliance
    FROM oilgas.inspections
    WHERE well_id = w.well_id
    ORDER BY inspection_date DESC
    LIMIT 1
) latest_i ON TRUE;

COMMENT ON VIEW oilgas.v_well_full IS
    'Full well context: spatial hierarchy (leasehold → pad → well), '
    'operator, completion, production, and latest inspection compliance.';


-- Violation frequency by rule category (for dashboards / reporting)
CREATE OR REPLACE VIEW oilgas.v_violation_summary AS
SELECT
    r.rule_category,
    r.violated_rule,
    r.violated_rule_description,
    COUNT(v.violation_id)                                        AS total_violations,
    SUM(CASE WHEN v.major_violation THEN 1 ELSE 0 END)          AS major_violations,
    SUM(CASE WHEN v.compliant_on_reinspection = 'Y' THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN v.compliant_on_reinspection IN ('--','N') OR v.compliant_on_reinspection IS NULL THEN 1 ELSE 0 END) AS open,
    MIN(v.discovery_date)                                        AS first_seen,
    MAX(v.discovery_date)                                        AS last_seen
FROM oilgas.violation_rule_ref r
LEFT JOIN oilgas.violations    v ON r.violated_rule = v.violated_rule
GROUP BY r.rule_category, r.violated_rule, r.violated_rule_description
ORDER BY total_violations DESC;

COMMENT ON VIEW oilgas.v_violation_summary IS
    'Violation frequency and resolution status by rule, grouped by category.';
