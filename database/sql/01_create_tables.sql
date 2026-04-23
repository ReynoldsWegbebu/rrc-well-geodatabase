-- ============================================================
-- OIL & GAS WELL GEODATABASE — DDL SCHEMA
-- RRC District 04 | Killam Oil Co., Ltd. | Operator #460054
-- Compatible with: PostgreSQL 14+ with PostGIS 3.3+
-- Coordinate System: NAD83 (EPSG:4269)
-- ============================================================

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ── SCHEMA ──────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS oilgas;
SET search_path TO oilgas, public;


-- ============================================================
-- 1. OPERATOR  (master lookup — no FK dependency)
-- ============================================================
CREATE TABLE oilgas.operator (
    opr_id            TEXT        PRIMARY KEY,
    operator_name     TEXT        NOT NULL,
    operator_p5_no    TEXT        NOT NULL,
    mailing_address   TEXT,
    city              TEXT,
    state             CHAR(2),
    zip               TEXT,
    contact_name      TEXT,
    contact_title     TEXT,
    phone             TEXT,
    email             TEXT,
    cert_date         DATE,
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE oilgas.operator IS
    'Master operator record. Source: operator information block on all RRC forms.';


-- ============================================================
-- 2. WELLS  (spatial feature class — central table)
-- ============================================================
CREATE TABLE oilgas.wells (
    well_id               TEXT        PRIMARY KEY,
    api_number            TEXT        UNIQUE NOT NULL,
    well_no               TEXT,
    lease_name            TEXT        NOT NULL,
    opr_id                TEXT        REFERENCES oilgas.operator(opr_id),
    county                TEXT        NOT NULL,
    rrc_district          TEXT,
    field_name            TEXT,
    field_no              TEXT,
    rrc_gas_id            TEXT,

    -- Spatial
    latitude              DOUBLE PRECISION,
    longitude             DOUBLE PRECISION,
    datum                 TEXT        DEFAULT 'NAD83',
    elevation_ft          NUMERIC(8,2),
    elev_datum            TEXT        DEFAULT 'GL',
    geom                  geometry(Point, 4269),  -- NAD83

    -- Well characteristics
    well_type             TEXT,
    well_status           TEXT,       -- PRODUCING, PLUGGED & ABANDONED, etc.
    filing_purpose        TEXT,
    well_class            TEXT,

    -- Location description
    nearest_town          TEXT,
    distance_mi           NUMERIC(6,2),
    direction             TEXT,
    total_acres           NUMERIC(10,3),
    nearest_well_ft       NUMERIC(8,1),
    off_lease             BOOLEAN     DEFAULT FALSE,
    section_block_survey  TEXT,

    -- Permit / filing
    permit_no             TEXT,
    permit_date           DATE,
    submission_date       DATE,
    tracking_no           TEXT,

    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now()
);

-- Spatial index
CREATE INDEX wells_geom_idx ON oilgas.wells USING GIST (geom);
CREATE INDEX wells_api_idx  ON oilgas.wells (api_number);
CREATE INDEX wells_county_idx ON oilgas.wells (county);
CREATE INDEX wells_status_idx ON oilgas.wells (well_status);

COMMENT ON TABLE oilgas.wells IS
    'Master spatial feature class. One record per well. PK=WELL_ID. '
    'Geometry stored as PostGIS Point in NAD83 (EPSG:4269). '
    'Source: Form G-1 header + well information sections.';

COMMENT ON COLUMN oilgas.wells.geom IS
    'Point geometry in NAD83 decimal degrees (EPSG:4269). '
    'Populated from LATITUDE/LONGITUDE columns via trigger.';


-- Trigger: auto-populate geometry from lat/lon
CREATE OR REPLACE FUNCTION oilgas.wells_update_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4269);
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wells_geom_trigger
    BEFORE INSERT OR UPDATE ON oilgas.wells
    FOR EACH ROW EXECUTE FUNCTION oilgas.wells_update_geom();


-- ============================================================
-- 3. COMPLETION
-- ============================================================
CREATE TABLE oilgas.completion (
    comp_id                   TEXT        PRIMARY KEY,
    well_id                   TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number                TEXT,
    comp_type                 TEXT,       -- NEW WELL, RECOMPLETION, DEEPENING, etc.
    recompletion              BOOLEAN     DEFAULT FALSE,

    -- Dates
    spud_date                 DATE,
    drill_op_end_date         DATE,
    first_prod_date           DATE,
    plug_back_date            DATE,

    -- Depths
    total_depth_tvd           NUMERIC(8,1),
    total_depth_md            NUMERIC(8,1),
    plug_back_tvd             NUMERIC(8,1),
    plug_back_md              NUMERIC(8,1),

    -- Lease info
    producing_wells_lease     INTEGER,
    distance_nearest_well_ft  NUMERIC(8,1),

    -- Logs
    log_types                 TEXT,
    directional_survey        BOOLEAN     DEFAULT FALSE,
    cementing_affidavit       BOOLEAN     DEFAULT FALSE,
    multiple_completion       BOOLEAN     DEFAULT FALSE,
    downhole_commingled       BOOLEAN     DEFAULT FALSE,

    -- Location footage
    loc_ft_from_line1         NUMERIC(8,1),
    line1_desc                TEXT,
    loc_ft_from_line2         NUMERIC(8,1),
    line2_desc                TEXT,
    lease_name_ref            TEXT,

    -- Well mechanics
    rotation_time_hrs         NUMERIC(6,1),
    notes                     TEXT,

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX completion_well_id_idx ON oilgas.completion (well_id);

COMMENT ON TABLE oilgas.completion IS
    'Completion and recompletion data. Source: Form G-1 Completion Information section.';


-- ============================================================
-- 4. GAS_MEASUREMENT
-- ============================================================
CREATE TABLE oilgas.gas_measurement (
    meas_id                   TEXT        PRIMARY KEY,
    well_id                   TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number                TEXT,
    test_date                 DATE        NOT NULL,
    meas_method               TEXT,       -- ORIFICE METER, etc.

    -- Test conditions
    gas_prod_during_test_mcf  NUMERIC(10,1),
    preflowed_48hr            BOOLEAN,
    run_no                    INTEGER,
    line_size                 NUMERIC(5,3),
    orifice_choke_in          NUMERIC(5,4),
    coeff_24hr                NUMERIC(10,2),
    static_pm_in              NUMERIC(8,2),
    diff_hw                   NUMERIC(8,2),
    flow_temp_f               NUMERIC(6,1),

    -- Results
    gravity_fg                NUMERIC(6,4),
    compressibility_fpv       NUMERIC(7,4),
    volume_mcfd               NUMERIC(10,1),

    -- Fluid properties
    gravity_dry               NUMERIC(6,4),
    gas_liq_ratio_cf_bbl      NUMERIC(10,0),
    avg_shutin_temp_f         NUMERIC(6,1),
    bh_temp_f                 NUMERIC(6,1),
    bh_temp_depth_ft          NUMERIC(8,1),
    gas_gravity_liquid_deg    NUMERIC(6,1),
    gravity_mixture           NUMERIC(6,4),

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX gas_meas_well_id_idx  ON oilgas.gas_measurement (well_id);
CREATE INDEX gas_meas_date_idx     ON oilgas.gas_measurement (test_date);

COMMENT ON TABLE oilgas.gas_measurement IS
    'Initial potential orifice meter test data. Source: Form G-1 Gas Measurement Data section.';


-- ============================================================
-- 5. PRESSURE_TEST
-- ============================================================
CREATE TABLE oilgas.pressure_test (
    test_id                   TEXT        PRIMARY KEY,
    well_id                   TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number                TEXT,
    run_type                  TEXT,       -- SHUT-IN, RUN 1, RUN 2, etc.
    time_of_run_min           INTEGER,

    -- Pressures (psia)
    choke_size                TEXT,
    wh_pressure_psia          NUMERIC(8,1),
    wh_flow_temp_f            NUMERIC(6,1),
    siwh_psia                 NUMERIC(8,1),
    flowing_tubing_psia       NUMERIC(8,1),
    casing_pressure_psia      NUMERIC(8,1),
    sep_operating_psia        NUMERIC(8,1),

    -- Fluids
    condensate_bbl            NUMERIC(8,2),
    condensate_gravity_api    NUMERIC(5,1),
    water_prod_bbl_day        NUMERIC(8,2),
    x_bh_pressure_psia        NUMERIC(8,1),

    -- Volumes
    oil_condensate_vol_bbl    NUMERIC(8,2),
    water_volume_bbl          NUMERIC(8,2),

    -- Liquid sample (distillation)
    stock_tank_color          TEXT,
    gravity_sep_liquid_api    NUMERIC(5,1),
    gravity_stock_tank_api    NUMERIC(5,1),
    gas_specific_gravity      NUMERIC(6,4),
    total_recovery_pct        NUMERIC(5,1),
    residue_pct               NUMERIC(5,1),
    loss_pct                  NUMERIC(5,1),
    distillation_date         DATE,
    distillation_source       TEXT,

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX pressure_test_well_id_idx ON oilgas.pressure_test (well_id);

COMMENT ON TABLE oilgas.pressure_test IS
    'Wellhead pressure and flow test data. Source: Form G-1 Field Data and Pressure Calculations, G-5, G-10.';


-- ============================================================
-- 6. CASING
-- ============================================================
CREATE TABLE oilgas.casing (
    casing_id             TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    string_no             INTEGER,
    casing_type           TEXT,       -- SURFACE, INTERMEDIATE, PRODUCTION, LINER
    casing_size_in        TEXT,
    hole_size_in          TEXT,
    setting_depth_ft      NUMERIC(8,1),
    multi_stage_tool      BOOLEAN,
    multi_stage_shoe      BOOLEAN,
    cement_class          TEXT,
    cement_amount_sacks   INTEGER,
    slurry_volume_cu_ft   NUMERIC(8,1),
    top_of_cement_ft      NUMERIC(8,1),
    toc_determined_by     TEXT,
    cementing_date        DATE,
    cementer_name         TEXT,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX casing_well_id_idx ON oilgas.casing (well_id);

COMMENT ON TABLE oilgas.casing IS
    'Casing string records. Source: Form G-1 Casing Record section and Form W-15.';


-- ============================================================
-- 7. CEMENTING
-- ============================================================
CREATE TABLE oilgas.cementing (
    cem_id                TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    plug_no               INTEGER,
    cementing_date        DATE,
    hole_size_in          TEXT,
    cibp_setting_depth_ft NUMERIC(8,1),
    cement_on_top_ft      NUMERIC(6,1),
    sacks_cement          NUMERIC(6,2),
    slurry_volume_cu_ft   NUMERIC(6,2),
    calculated_top_ft     NUMERIC(8,1),
    measured_top_ft       NUMERIC(8,1),
    slurry_weight_lbs_gal TEXT,
    cement_class          TEXT,
    perforate_squeeze     BOOLEAN,
    cementer_company      TEXT,
    cementer_rep          TEXT,
    operator_rep          TEXT,
    remarks               TEXT,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX cementing_well_id_idx ON oilgas.cementing (well_id);

COMMENT ON TABLE oilgas.cementing IS
    'Plug-back and squeeze cementing records. Source: Form W-15.';


-- ============================================================
-- 8. TUBING
-- ============================================================
CREATE TABLE oilgas.tubing (
    tube_id           TEXT        PRIMARY KEY,
    well_id           TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number        TEXT,
    string_no         INTEGER,
    tubing_size_in    TEXT,
    depth_ft          NUMERIC(8,1),
    packer_depth_ft   NUMERIC(8,1),
    packer_type       TEXT,

    created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX tubing_well_id_idx ON oilgas.tubing (well_id);

COMMENT ON TABLE oilgas.tubing IS 'Tubing and packer records. Source: Form G-1 Tubing Record section.';


-- ============================================================
-- 9. PERFORATIONS
-- ============================================================
CREATE TABLE oilgas.perforations (
    perf_id           TEXT        PRIMARY KEY,
    well_id           TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number        TEXT,
    interval_no       INTEGER,
    open_hole         BOOLEAN     DEFAULT FALSE,
    from_ft           NUMERIC(8,1),
    from_type         TEXT,       -- TVD or MD
    to_ft             NUMERIC(8,1),
    interval_type     TEXT,       -- PRODUCING, INJECTION, DISPOSAL
    perf_gun          TEXT,
    shots_per_ft      INTEGER,
    operation_type    TEXT,
    material_used     TEXT,
    depth_from        NUMERIC(8,1),
    depth_to          NUMERIC(8,1),

    created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX perforations_well_id_idx ON oilgas.perforations (well_id);

COMMENT ON TABLE oilgas.perforations IS
    'Producing and injection intervals. Source: Form G-1 Producing/Injection/Disposal Interval section.';


-- ============================================================
-- 10. FRAC_TREATMENT
-- ============================================================
CREATE TABLE oilgas.frac_treatment (
    frac_id                   TEXT        PRIMARY KEY,
    well_id                   TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number                TEXT,
    frac_performed            BOOLEAN     DEFAULT FALSE,
    downhole_sleeve           BOOLEAN     DEFAULT FALSE,
    actuation_pressure_psia   NUMERIC(8,1),
    prod_casing_test_psia     NUMERIC(8,1),
    max_pressure_frac_psia    NUMERIC(8,1),
    fluid_disclosure_filed    BOOLEAN     DEFAULT FALSE,
    frac_date                 DATE,
    frac_from_ft              NUMERIC(8,1),
    frac_to_ft                NUMERIC(8,1),
    frac_stages_ref           TEXT,

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX frac_well_id_idx ON oilgas.frac_treatment (well_id);

COMMENT ON TABLE oilgas.frac_treatment IS
    'Hydraulic fracture treatment data. Source: Form G-1 Acid/Fracture section.';


-- ============================================================
-- 11. FORMATIONS
-- ============================================================
CREATE TABLE oilgas.formations (
    form_id               TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    formation_name        TEXT        NOT NULL,
    formation_group       TEXT,
    encountered           BOOLEAN     DEFAULT FALSE,
    depth_tvd_ft          NUMERIC(8,1),
    depth_md_ft           NUMERIC(8,1),
    is_isolated           BOOLEAN     DEFAULT FALSE,
    inj_disposal_zone     BOOLEAN     DEFAULT FALSE,
    geopressured          BOOLEAN     DEFAULT FALSE,
    h2s_present           BOOLEAN     DEFAULT FALSE,
    remarks               TEXT,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX formations_well_id_idx   ON oilgas.formations (well_id);
CREATE INDEX formations_name_idx      ON oilgas.formations (formation_name);
CREATE INDEX formations_depth_idx     ON oilgas.formations (depth_tvd_ft);

COMMENT ON TABLE oilgas.formations IS
    '12 formation top records across 3 wells. Source: Form G-1 Formation Record section.';


-- ============================================================
-- 12. GAS_STATUS
-- ============================================================
CREATE TABLE oilgas.gas_status (
    stat_id               TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    rrc_ident_no          TEXT,
    well_no               TEXT,
    test_date             DATE        NOT NULL,
    gas_produced_mcfd     NUMERIC(10,1),
    gas_spec_gravity      NUMERIC(6,4),
    condensate_bbl        NUMERIC(8,2),
    condensate_gravity_api NUMERIC(5,1),
    water_prod_bbl_day    NUMERIC(8,2),
    x_bh_pressure_psia    NUMERIC(8,1),
    siwh_pressure_psia    NUMERIC(8,1),
    flowing_pressure_psia NUMERIC(8,1),
    reason_for_filing     TEXT,
    survey_flag           BOOLEAN,
    initial_test          BOOLEAN,
    correction            BOOLEAN,
    field_name            TEXT,
    lease_name            TEXT,
    certifier             TEXT,
    cert_date             DATE,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX gas_status_well_id_idx ON oilgas.gas_status (well_id);
CREATE INDEX gas_status_date_idx    ON oilgas.gas_status (test_date);

COMMENT ON TABLE oilgas.gas_status IS
    'G-10 Gas Well Status Report data. Source: Form G-10.';


-- ============================================================
-- 13. PLUGGING
-- ============================================================
CREATE TABLE oilgas.plugging (
    plug_id               TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    date_well_plugged     DATE,
    total_depth_ft        NUMERIC(8,1),

    -- Mud
    mud_laden             BOOLEAN,
    mud_application       TEXT,
    mud_weight_lbs_gal    NUMERIC(5,2),

    -- Fresh water zones (from GAU)
    fw_depth_top_ft       NUMERIC(8,1),
    fw_depth_bottom_ft    NUMERIC(8,1),
    fw_zone_name          TEXT,

    -- Plugs (up to 4 for this dataset)
    plug1_date            DATE,
    plug1_hole_size       TEXT,
    plug1_depth_bottom_ft NUMERIC(8,1),
    plug1_cement_sacks    NUMERIC(6,2),
    plug1_slurry_vol_cuft NUMERIC(6,2),
    plug1_top_ft          NUMERIC(8,1),
    plug1_weight          TEXT,
    plug1_cement_type     TEXT,

    plug2_date            DATE,
    plug2_depth_bottom_ft NUMERIC(8,1),
    plug2_cement_sacks    NUMERIC(6,2),
    plug2_slurry_vol_cuft NUMERIC(6,2),
    plug2_top_ft          NUMERIC(8,1),

    plug3_date            DATE,
    plug3_depth_bottom_ft NUMERIC(8,1),
    plug3_cement_sacks    NUMERIC(6,2),
    plug3_slurry_vol_cuft NUMERIC(6,2),
    plug3_top_ft          NUMERIC(8,1),

    plug4_date            DATE,
    plug4_depth_bottom_ft NUMERIC(8,1),
    plug4_cement_sacks    NUMERIC(6,2),
    plug4_slurry_vol_cuft NUMERIC(6,2),
    plug4_top_ft          NUMERIC(8,1),

    open_intervals        TEXT,
    cementing_company     TEXT,
    date_rrc_notified     DATE,
    form_p13_filed        BOOLEAN,
    remarks               TEXT,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX plugging_well_id_idx ON oilgas.plugging (well_id);

COMMENT ON TABLE oilgas.plugging IS
    'W-3 Plugging Record. Source: Form W-3 and W-15 cementing attachments.';


-- ============================================================
-- 14. TRANSPORT_AUTH
-- ============================================================
CREATE TABLE oilgas.transport_auth (
    auth_id               TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    field_name            TEXT,
    lease_name            TEXT,
    classification        TEXT,       -- GAS, OIL/CONDENSATE
    effective_date        DATE,
    purpose_of_filing     TEXT,
    entity_type           TEXT,       -- GATHERER, PURCHASER, OIL GATHERER
    entity_name           TEXT,
    rrc_system_code       TEXT,
    percent_take          NUMERIC(5,1),
    full_well_stream      BOOLEAN,
    current_operator      TEXT,
    operator_p5           TEXT,
    certified_by          TEXT,
    cert_title            TEXT,
    cert_date             DATE,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX transport_well_id_idx ON oilgas.transport_auth (well_id);

COMMENT ON TABLE oilgas.transport_auth IS
    'P-4 Certificate of Compliance and Transportation Authority. Source: Form P-4.';


-- ============================================================
-- 15. GROUNDWATER
-- ============================================================
CREATE TABLE oilgas.groundwater (
    gw_id                     TEXT        PRIMARY KEY,
    well_id                   TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number                TEXT,
    form_type                 TEXT,       -- GW-2, P-13, GAU DETERMINATION
    gau_number                TEXT,
    date_issued               DATE,
    purpose                   TEXT,
    survey_location           TEXT,

    -- Protection depths
    protection_depth_ft       NUMERIC(8,1),
    fw_surface_to_ft          NUMERIC(8,1),
    fw_zone_from_ft           NUMERIC(8,1),
    fw_zone_to_ft             NUMERIC(8,1),
    carrizo_from_ft           NUMERIC(8,1),
    carrizo_to_ft             NUMERIC(8,1),
    superior_quality_notes    TEXT,

    -- Water well conversion (P-13)
    proposed_plugback_ft      NUMERIC(8,1),
    base_usable_quality_ft    NUMERIC(8,1),

    tceq_file_no              TEXT,
    tceq_date                 DATE,
    gw_conservation_district  TEXT,
    approved_by               TEXT,
    approval_date             DATE,
    remarks                   TEXT,

    created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX groundwater_well_id_idx ON oilgas.groundwater (well_id);

COMMENT ON TABLE oilgas.groundwater IS
    'Groundwater protection determinations (GW-2) and water well conversions (P-13).';


-- ============================================================
-- 16. CLASSIFICATION
-- ============================================================
CREATE TABLE oilgas.classification (
    class_id              TEXT        PRIMARY KEY,
    well_id               TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number            TEXT,
    test_date             DATE        NOT NULL,
    gas_volume_mcf        NUMERIC(10,1),
    oil_condensate_bbl    NUMERIC(8,2),
    water_volume_bbl      NUMERIC(8,2),
    gas_liq_ratio_cf_bbl  NUMERIC(10,0),
    flowing_tubing_psia   NUMERIC(8,1),
    choke_size            TEXT,
    casing_pressure_psia  NUMERIC(8,1),
    shutin_wh_psia        NUMERIC(8,1),
    sep_operating_psia    NUMERIC(8,1),
    stock_tank_color      TEXT,
    gravity_sep_api       NUMERIC(5,1),
    gravity_stock_api     NUMERIC(5,1),
    gas_specific_gravity  NUMERIC(6,4),
    pipeline_connection   TEXT,
    liquid_sample_date    DATE,
    sample_source         TEXT,
    total_recovery_pct    NUMERIC(5,1),
    residue_pct           NUMERIC(5,1),
    loss_pct              NUMERIC(5,1),
    certified_by          TEXT,
    cert_title            TEXT,
    cert_date             DATE,

    created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX classification_well_id_idx ON oilgas.classification (well_id);

COMMENT ON TABLE oilgas.classification IS
    'G-5 Gas Well Classification Report data. Source: Form G-5.';


-- ============================================================
-- VIEWS — Common analytical queries as reusable views
-- ============================================================

-- Well summary view (joins key fields from multiple tables)
CREATE OR REPLACE VIEW oilgas.v_well_summary AS
SELECT
    w.well_id,
    w.api_number,
    w.well_no,
    w.lease_name,
    w.county,
    w.well_status,
    w.field_name,
    w.latitude,
    w.longitude,
    w.elevation_ft,
    c.spud_date,
    c.first_prod_date,
    c.total_depth_tvd,
    c.total_depth_md,
    c.comp_type,
    gs.gas_produced_mcfd        AS ip_gas_mcfd,
    gs.siwh_pressure_psia,
    gs.flowing_pressure_psia,
    gs.test_date                AS status_test_date,
    cl.gas_specific_gravity,
    cl.gravity_sep_api,
    cl.choke_size,
    op.operator_name,
    op.contact_name             AS operator_contact
FROM oilgas.wells w
LEFT JOIN oilgas.completion    c  ON w.well_id = c.well_id
LEFT JOIN oilgas.gas_status    gs ON w.well_id = gs.well_id
LEFT JOIN oilgas.classification cl ON w.well_id = cl.well_id
LEFT JOIN oilgas.operator      op ON w.opr_id  = op.opr_id;

COMMENT ON VIEW oilgas.v_well_summary IS
    'Denormalized well summary joining core tables for quick analysis.';


-- Formation depth profile view
CREATE OR REPLACE VIEW oilgas.v_formation_profile AS
SELECT
    w.well_id,
    w.api_number,
    w.lease_name,
    w.county,
    f.formation_name,
    f.formation_group,
    f.encountered,
    f.depth_tvd_ft,
    f.depth_md_ft,
    f.is_isolated,
    f.inj_disposal_zone,
    f.geopressured,
    f.h2s_present,
    f.remarks
FROM oilgas.formations f
JOIN oilgas.wells w ON f.well_id = w.well_id
ORDER BY w.well_id, f.depth_tvd_ft NULLS LAST;

COMMENT ON VIEW oilgas.v_formation_profile IS
    'Formation tops ordered by depth per well. Useful for cross-section analysis.';
