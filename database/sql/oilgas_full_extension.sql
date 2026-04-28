-- ============================================================
-- OIL & GAS GEODATABASE — FULL DOMAIN EXTENSION DDL
-- Tables 23 – 62
-- Domains covered:
--   A. Drilling & wellbore (23–26)
--   B. Production & allocation (27–31)
--   C. Reservoir & geoscience (32–36)
--   D. HSE & environmental (37–41)
--   E. Surface, land & commercial (42–48)
--   F. Infrastructure & equipment (49–54)
--   G. Economics & financial (55–62)
-- Compatible: PostgreSQL 14+ / PostGIS 3.3+
-- Depends on: oilgas core schema (tables 1–16)
--             oilgas_extensions.sql  (tables 17–22)
-- ============================================================

SET search_path TO oilgas, public;


-- ============================================================
-- A. DRILLING & WELLBORE
-- ============================================================

-- ------------------------------------------------------------
-- 23. DIRECTIONAL_SURVEY
-- Trajectory stations for deviated / horizontal wells.
-- The geom on wells is surface location only; this table
-- provides the full 3-D wellbore path.
-- ------------------------------------------------------------
CREATE TABLE oilgas.directional_survey (
    survey_id           TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    survey_date         DATE,
    survey_company      TEXT,
    survey_type         TEXT,       -- MWD, GYRO, SINGLE_SHOT, MULTI_SHOT

    -- Station data
    station_no          INTEGER     NOT NULL,
    md_ft               NUMERIC(10,2) NOT NULL,   -- measured depth
    tvd_ft              NUMERIC(10,2),             -- true vertical depth
    inclination_deg     NUMERIC(7,3),
    azimuth_deg         NUMERIC(7,3),
    dls_deg_per_100ft   NUMERIC(7,3),             -- dogleg severity
    northing_ft         NUMERIC(12,3),
    easting_ft          NUMERIC(12,3),
    vertical_section_ft NUMERIC(10,2),
    latitude            DOUBLE PRECISION,
    longitude           DOUBLE PRECISION,
    geom                geometry(PointZ, 4269),   -- 3-D point at station

    -- Tie-in reference
    is_tie_in           BOOLEAN     DEFAULT FALSE,
    kop_md_ft           NUMERIC(10,2),            -- kick-off point depth
    target_formation    TEXT,

    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX dir_survey_well_id_idx ON oilgas.directional_survey (well_id);
CREATE INDEX dir_survey_md_idx      ON oilgas.directional_survey (well_id, md_ft);
CREATE INDEX dir_survey_geom_idx    ON oilgas.directional_survey USING GIST (geom);

COMMENT ON TABLE oilgas.directional_survey IS
    'Wellbore trajectory stations (MD/TVD/azimuth/inclination). '
    'One row per survey station. Geometry is 3-D PointZ in NAD83. '
    'wells.geom is surface location only; this table gives the full path.';


-- ------------------------------------------------------------
-- 24. MUD_PROGRAM
-- Drilling fluid design and actual mud properties by depth
-- interval / hole section.
-- ------------------------------------------------------------
CREATE TABLE oilgas.mud_program (
    mud_id              TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    hole_section        TEXT,       -- SURFACE, INTERMEDIATE, PRODUCTION, LATERAL
    from_md_ft          NUMERIC(10,2),
    to_md_ft            NUMERIC(10,2),
    mud_type            TEXT,       -- WBM, OBM, SBM, BRINE, FRESHWATER
    mud_company         TEXT,

    -- Properties
    mud_weight_ppg      NUMERIC(6,3),
    viscosity_fann600   NUMERIC(6,1),
    viscosity_fann300   NUMERIC(6,1),
    plastic_viscosity   NUMERIC(6,1),
    yield_point         NUMERIC(6,1),
    gel_10sec           NUMERIC(6,1),
    gel_10min           NUMERIC(6,1),
    api_fluid_loss_cc   NUMERIC(6,2),
    ph                  NUMERIC(4,1),
    chlorides_ppm       NUMERIC(10,1),
    calcium_ppm         NUMERIC(10,1),
    solids_pct          NUMERIC(5,1),
    oil_water_ratio     TEXT,

    -- Volumes
    total_volume_bbls   NUMERIC(10,1),
    lost_circulation_bbls NUMERIC(8,1),
    lco_material        TEXT,       -- lost circulation material used

    sample_date         DATE,
    sampled_at_md_ft    NUMERIC(10,2),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX mud_program_well_id_idx ON oilgas.mud_program (well_id);

COMMENT ON TABLE oilgas.mud_program IS
    'Drilling fluid (mud) program per hole section. '
    'Stores both planned and actual mud properties.';


-- ------------------------------------------------------------
-- 25. BIT_RECORD
-- Drill bit inventory and performance by depth interval.
-- ------------------------------------------------------------
CREATE TABLE oilgas.bit_record (
    bit_id              TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    bit_run_no          INTEGER     NOT NULL,
    bit_size_in         NUMERIC(6,3),
    bit_type            TEXT,       -- PDC, TCI, DIAMOND, MILL_TOOTH, HYBRID
    bit_manufacturer    TEXT,       -- Baker Hughes, Halliburton, NOV, Smith, etc.
    bit_serial_no       TEXT,
    iadc_code           TEXT,

    -- Depth interval
    depth_in_md_ft      NUMERIC(10,2),
    depth_out_md_ft     NUMERIC(10,2),
    footage_drilled_ft  NUMERIC(10,2),

    -- Performance
    rop_avg_ft_hr       NUMERIC(8,2),
    wob_klbs            NUMERIC(8,1),   -- weight on bit
    rpm                 NUMERIC(6,1),
    flow_rate_gpm       NUMERIC(8,1),
    hours_on_bit        NUMERIC(7,2),

    -- Dull grade (IADC)
    inner_dull          TEXT,
    outer_dull          TEXT,
    dull_location       TEXT,
    bearings_seals      TEXT,
    gauge               TEXT,
    other_dull          TEXT,
    pull_reason         TEXT,

    bit_run_date        DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX bit_record_well_id_idx ON oilgas.bit_record (well_id);

COMMENT ON TABLE oilgas.bit_record IS
    'Drill bit run record per depth interval. IADC dull grading included. '
    'Enables ROP analysis and bit selection optimization.';


-- ------------------------------------------------------------
-- 26. DAILY_DRILLING_REPORT  (DDR)
-- One row per rig-day. Operational summary for cost tracking
-- and non-productive time (NPT) analysis.
-- ------------------------------------------------------------
CREATE TABLE oilgas.daily_drilling_report (
    ddr_id              TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    report_date         DATE        NOT NULL,
    report_day_no       INTEGER,    -- day 1 from spud

    -- Depth progress
    depth_start_md_ft   NUMERIC(10,2),
    depth_end_md_ft     NUMERIC(10,2),
    footage_drilled_ft  NUMERIC(10,2),
    tvd_end_ft          NUMERIC(10,2),

    -- Rig activity (hours, must sum to 24)
    hrs_drilling        NUMERIC(5,2),
    hrs_tripping        NUMERIC(5,2),
    hrs_casing          NUMERIC(5,2),
    hrs_cementing       NUMERIC(5,2),
    hrs_logging         NUMERIC(5,2),
    hrs_npt             NUMERIC(5,2),  -- non-productive time
    hrs_waiting         NUMERIC(5,2),
    hrs_other           NUMERIC(5,2),

    -- NPT detail
    npt_category        TEXT,       -- EQUIPMENT, WEATHER, WELLBORE, LOGISTICS, OTHER
    npt_description     TEXT,

    -- Costs (USD)
    daily_rig_cost      NUMERIC(12,2),
    daily_mud_cost      NUMERIC(12,2),
    daily_other_cost    NUMERIC(12,2),
    cumulative_cost     NUMERIC(14,2),

    -- Mud on hand
    mud_weight_ppg      NUMERIC(6,3),
    active_volume_bbls  NUMERIC(8,1),

    -- Personnel
    rig_name            TEXT,
    rig_contractor      TEXT,
    tool_pusher         TEXT,
    company_man         TEXT,

    operations_summary  TEXT,
    safety_incidents    INTEGER     DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ddr_well_id_idx  ON oilgas.daily_drilling_report (well_id);
CREATE INDEX ddr_date_idx     ON oilgas.daily_drilling_report (report_date);

COMMENT ON TABLE oilgas.daily_drilling_report IS
    'Daily drilling report (DDR). One row per rig-day. '
    'Enables NPT analysis, AFE cost tracking, and rig performance benchmarking.';


-- ============================================================
-- B. PRODUCTION & ALLOCATION
-- ============================================================

-- ------------------------------------------------------------
-- 27. PRODUCTION_MONTHLY
-- Core production table — oil / gas / water volumes by well
-- by calendar month. The single most-queried table in any
-- upstream system; all decline curves and reserves flow from it.
-- ------------------------------------------------------------
CREATE TABLE oilgas.production_monthly (
    prod_id             TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    api_number          TEXT,
    prod_month          DATE        NOT NULL,  -- first day of month (e.g. 2025-01-01)

    -- Volumes (allocated to this well)
    oil_bbl             NUMERIC(12,3)  DEFAULT 0,
    gas_mcf             NUMERIC(12,3)  DEFAULT 0,
    water_bbl           NUMERIC(12,3)  DEFAULT 0,
    condensate_bbl      NUMERIC(12,3)  DEFAULT 0,
    ngl_bbl             NUMERIC(12,3)  DEFAULT 0,

    -- Days / status
    days_on_prod        INTEGER,
    days_in_month       INTEGER,
    prod_status         TEXT,       -- PRODUCING, SHUT_IN, OFFLINE, INJECTION, ABANDONED

    -- Rates (calculated)
    oil_bopd            NUMERIC(10,3)  GENERATED ALWAYS AS
                            (CASE WHEN days_on_prod > 0
                             THEN oil_bbl / days_on_prod ELSE 0 END) STORED,
    gas_mcfd            NUMERIC(10,3)  GENERATED ALWAYS AS
                            (CASE WHEN days_on_prod > 0
                             THEN gas_mcf / days_on_prod ELSE 0 END) STORED,
    water_bwpd          NUMERIC(10,3)  GENERATED ALWAYS AS
                            (CASE WHEN days_on_prod > 0
                             THEN water_bbl / days_on_prod ELSE 0 END) STORED,
    wor                 NUMERIC(10,4)  GENERATED ALWAYS AS
                            (CASE WHEN oil_bbl > 0
                             THEN water_bbl / oil_bbl ELSE NULL END) STORED,
    gor_cf_bbl          NUMERIC(12,2)  GENERATED ALWAYS AS
                            (CASE WHEN oil_bbl > 0
                             THEN (gas_mcf * 1000) / oil_bbl ELSE NULL END) STORED,

    -- Source / reporting
    data_source         TEXT        DEFAULT 'OPERATOR',  -- OPERATOR, RRC, ESTIMATED
    rrc_reported        BOOLEAN     DEFAULT FALSE,
    amended             BOOLEAN     DEFAULT FALSE,
    amendment_date      DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),

    UNIQUE (well_id, prod_month)
);

CREATE INDEX prod_monthly_well_month_idx ON oilgas.production_monthly (well_id, prod_month DESC);
CREATE INDEX prod_monthly_lease_idx      ON oilgas.production_monthly (lease_id, prod_month DESC);
CREATE INDEX prod_monthly_month_idx      ON oilgas.production_monthly (prod_month DESC);
CREATE INDEX prod_monthly_status_idx     ON oilgas.production_monthly (prod_status);

COMMENT ON TABLE oilgas.production_monthly IS
    'Monthly allocated production volumes per well. '
    'oil_bopd / gas_mcfd / wor / gor are generated columns — computed automatically. '
    'prod_month is always the 1st of the month. '
    'Source: RRC Form PR, operator SCADA/metering systems.';


-- ------------------------------------------------------------
-- 28. WELL_TEST
-- Individual well potential tests and allocation tests.
-- Distinct from initial potential (gas_measurement) —
-- these are periodic tests throughout the producing life.
-- ------------------------------------------------------------
CREATE TABLE oilgas.well_test (
    test_id             TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    api_number          TEXT,
    test_date           DATE        NOT NULL,
    test_type           TEXT,       -- POTENTIAL, ALLOCATION, PRODUCTIVITY, DELIVERABILITY
    test_duration_hrs   NUMERIC(7,2),
    choke_size_in       NUMERIC(5,4),

    -- Oil / condensate
    oil_rate_bopd       NUMERIC(10,3),
    oil_gravity_api     NUMERIC(5,2),
    oil_bs_w_pct        NUMERIC(5,2),

    -- Gas
    gas_rate_mcfd       NUMERIC(10,3),
    gas_gravity         NUMERIC(6,4),
    gas_hhv_btu         NUMERIC(8,1),   -- higher heating value
    h2s_ppm             NUMERIC(8,1),
    co2_pct             NUMERIC(5,2),
    n2_pct              NUMERIC(5,2),

    -- Water
    water_rate_bwpd     NUMERIC(10,3),
    water_salinity_ppm  NUMERIC(10,1),

    -- Pressures
    ftp_psia            NUMERIC(8,1),   -- flowing tubing pressure
    sithp_psia          NUMERIC(8,1),   -- shut-in tubing head pressure
    fbhp_psia           NUMERIC(8,1),   -- flowing bottomhole pressure
    sbhp_psia           NUMERIC(8,1),   -- static bottomhole pressure
    bhp_depth_ft        NUMERIC(8,1),

    -- Allocation result
    allocation_factor   NUMERIC(8,6),   -- fraction assigned to this well
    tested_by           TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX well_test_well_id_idx ON oilgas.well_test (well_id);
CREATE INDEX well_test_date_idx    ON oilgas.well_test (test_date);

COMMENT ON TABLE oilgas.well_test IS
    'Periodic well test and allocation test results. '
    'allocation_factor drives volume splits in production_monthly '
    'when a facility meters commingled production.';


-- ------------------------------------------------------------
-- 29. PRODUCED_WATER_DISPOSITION
-- Tracks where produced water goes after leaving the wellhead:
-- disposal well, recycle/reuse, evaporation pond, hauling.
-- ------------------------------------------------------------
CREATE TABLE oilgas.produced_water_disposition (
    disp_id             TEXT        PRIMARY KEY,
    source_well_id      TEXT        REFERENCES oilgas.wells(well_id),
    source_facility_id  TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    disp_month          DATE        NOT NULL,

    -- Volume
    total_water_bbl     NUMERIC(12,3),

    -- Disposition split (should sum to total_water_bbl)
    disposal_well_bbl   NUMERIC(12,3)  DEFAULT 0,
    recycle_reuse_bbl   NUMERIC(12,3)  DEFAULT 0,
    evap_pond_bbl       NUMERIC(12,3)  DEFAULT 0,
    hauled_off_bbl      NUMERIC(12,3)  DEFAULT 0,
    other_bbl           NUMERIC(12,3)  DEFAULT 0,

    -- Disposal well destination
    disposal_well_id    TEXT        REFERENCES oilgas.wells(well_id),
    disposal_api        TEXT,
    disposal_permit_no  TEXT,

    -- Water quality
    tds_ppm             NUMERIC(10,1),
    chlorides_ppm       NUMERIC(10,1),
    toc_ppm             NUMERIC(8,1),
    radium_pci_l        NUMERIC(8,3),   -- NORM indicator

    hauler_company      TEXT,
    manifest_no         TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX pw_disp_source_well_idx ON oilgas.produced_water_disposition (source_well_id);
CREATE INDEX pw_disp_month_idx       ON oilgas.produced_water_disposition (disp_month);
CREATE INDEX pw_disp_disposal_idx    ON oilgas.produced_water_disposition (disposal_well_id);

COMMENT ON TABLE oilgas.produced_water_disposition IS
    'Monthly produced water volume tracking and disposition. '
    'Tracks recycling, disposal, hauling. Supports RRC Form H-10 reporting '
    'and environmental compliance.';


-- ------------------------------------------------------------
-- 30. FLARING_VENTING
-- Gas flaring and venting events by well/facility.
-- Required for TCEQ/EPA GHG reporting and RRC flaring permits.
-- ------------------------------------------------------------
CREATE TABLE oilgas.flaring_venting (
    flare_id            TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    event_type          TEXT        NOT NULL CHECK (event_type IN ('FLARE','VENT','RELEASE')),
    event_category      TEXT,       -- ROUTINE, EMERGENCY, UPSET, STARTUP_SHUTDOWN
    start_datetime      TIMESTAMPTZ NOT NULL,
    end_datetime        TIMESTAMPTZ,
    duration_hrs        NUMERIC(8,2),
    volume_mcf          NUMERIC(12,3),
    co2_equiv_tonnes    NUMERIC(10,3),  -- calculated GHG equivalent
    methane_tonnes      NUMERIC(10,3),
    reason              TEXT,
    rrc_flare_permit_no TEXT,
    reported_to_rrc     BOOLEAN     DEFAULT FALSE,
    reported_to_tceq    BOOLEAN     DEFAULT FALSE,
    report_date         DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX flaring_well_id_idx    ON oilgas.flaring_venting (well_id);
CREATE INDEX flaring_facility_idx   ON oilgas.flaring_venting (facility_id);
CREATE INDEX flaring_start_idx      ON oilgas.flaring_venting (start_datetime);
CREATE INDEX flaring_type_idx       ON oilgas.flaring_venting (event_type, event_category);

COMMENT ON TABLE oilgas.flaring_venting IS
    'Gas flaring, venting, and unplanned release events. '
    'Supports RRC flaring permit tracking and EPA/TCEQ GHG inventory reporting.';


-- ------------------------------------------------------------
-- 31. METER_CALIBRATION
-- Custody transfer and allocation meter calibration records.
-- Ensures measurement accuracy and regulatory compliance.
-- ------------------------------------------------------------
CREATE TABLE oilgas.meter_calibration (
    cal_id              TEXT        PRIMARY KEY,
    facility_id         TEXT        NOT NULL REFERENCES oilgas.facilities(facility_id),
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    meter_tag           TEXT        NOT NULL,  -- equipment tag / ID
    meter_type          TEXT,       -- ORIFICE, TURBINE, CORIOLIS, ULTRASONIC, LACT
    meter_service       TEXT,       -- OIL, GAS, WATER, GAS_LIFT
    calibration_date    DATE        NOT NULL,
    next_cal_due        DATE,
    calibrated_by       TEXT,
    calibration_co      TEXT,

    -- As-found
    as_found_error_pct  NUMERIC(7,4),
    as_found_pass       BOOLEAN,

    -- As-left
    as_left_error_pct   NUMERIC(7,4),
    as_left_pass        BOOLEAN,

    -- Conditions at calibration
    fluid_temp_f        NUMERIC(6,1),
    fluid_press_psia    NUMERIC(8,1),
    flow_rate           NUMERIC(10,3),
    flow_rate_unit      TEXT,

    cert_no             TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX meter_cal_facility_idx ON oilgas.meter_calibration (facility_id);
CREATE INDEX meter_cal_date_idx     ON oilgas.meter_calibration (calibration_date);
CREATE INDEX meter_cal_due_idx      ON oilgas.meter_calibration (next_cal_due);

COMMENT ON TABLE oilgas.meter_calibration IS
    'Meter calibration records for custody transfer and allocation meters. '
    'next_cal_due supports maintenance scheduling queries.';


-- ============================================================
-- C. RESERVOIR & GEOSCIENCE
-- ============================================================

-- ------------------------------------------------------------
-- 32. RESERVOIR
-- Named reservoir / pool definitions. Groups wells producing
-- from the same geologic interval. Required for RRC commingling
-- permits and pool-level reserve reporting.
-- ------------------------------------------------------------
CREATE TABLE oilgas.reservoir (
    reservoir_id        TEXT        PRIMARY KEY,
    reservoir_name      TEXT        NOT NULL,
    reservoir_code      TEXT        UNIQUE,     -- RRC pool code if assigned
    formation_name      TEXT,
    geologic_age        TEXT,       -- CRETACEOUS, EOCENE, PERMIAN, etc.
    rrc_district        TEXT,
    county              TEXT,
    field_name          TEXT,
    field_no            TEXT,

    -- Drive mechanism
    drive_mechanism     TEXT,       -- SOLUTION_GAS, WATER, GAS_CAP, GRAVITY, COMBINATION
    fluid_type          TEXT,       -- OIL, GAS, CONDENSATE, DRY_GAS

    -- Reservoir properties (average / initial)
    avg_depth_tvd_ft    NUMERIC(10,2),
    avg_thickness_ft    NUMERIC(8,2),
    avg_porosity_pct    NUMERIC(6,3),
    avg_permeability_md NUMERIC(10,3),
    avg_water_sat_pct   NUMERIC(6,3),
    initial_pressure_psia NUMERIC(8,1),
    reservoir_temp_f    NUMERIC(6,1),
    bubble_point_psia   NUMERIC(8,1),
    dew_point_psia      NUMERIC(8,1),

    -- Contacts
    oil_water_contact_ft NUMERIC(10,2),
    gas_oil_contact_ft  NUMERIC(10,2),
    gas_water_contact_ft NUMERIC(10,2),

    -- Area / volume
    drainage_area_acres NUMERIC(10,2),
    gross_rock_vol_acre_ft NUMERIC(14,2),
    net_pay_ft          NUMERIC(8,2),

    -- Spatial
    geom                geometry(MultiPolygon, 4269),

    discovery_date      DATE,
    status              TEXT        DEFAULT 'ACTIVE',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX reservoir_geom_idx  ON oilgas.reservoir USING GIST (geom);
CREATE INDEX reservoir_name_idx  ON oilgas.reservoir (reservoir_name);
CREATE INDEX reservoir_field_idx ON oilgas.reservoir (field_name);

COMMENT ON TABLE oilgas.reservoir IS
    'Named reservoir / pool definitions. Provides the geologic unit '
    'above which individual well completions are grouped. '
    'Boundary polygon supports spatial containment queries.';


-- Junction: wells producing from a reservoir (many-to-many)
CREATE TABLE oilgas.well_reservoir (
    well_id         TEXT  NOT NULL REFERENCES oilgas.wells(well_id)       ON DELETE CASCADE,
    reservoir_id    TEXT  NOT NULL REFERENCES oilgas.reservoir(reservoir_id) ON DELETE CASCADE,
    perf_interval   TEXT,           -- which perforation interval targets this reservoir
    commingled      BOOLEAN DEFAULT FALSE,
    commingling_permit_no TEXT,
    on_production_date DATE,
    abandoned_date  DATE,
    PRIMARY KEY (well_id, reservoir_id)
);

COMMENT ON TABLE oilgas.well_reservoir IS
    'Many-to-many: which wells produce from which reservoirs. '
    'A commingled well may target multiple reservoirs under one permit.';


-- ------------------------------------------------------------
-- 33. CORE_ANALYSIS
-- Conventional and sidewall core sample petrophysical data.
-- ------------------------------------------------------------
CREATE TABLE oilgas.core_analysis (
    core_id             TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    core_run_no         INTEGER,
    core_type           TEXT,       -- CONVENTIONAL, SIDEWALL_ROTARY, SIDEWALL_PERCUSSION, WHOLE
    sample_no           INTEGER,
    depth_top_ft        NUMERIC(10,2),
    depth_bottom_ft     NUMERIC(10,2),
    formation_name      TEXT,
    lithology           TEXT,

    -- Basic petrophysics
    porosity_pct        NUMERIC(7,4),
    perm_air_md         NUMERIC(12,4),   -- air permeability (Klinkenberg uncorrected)
    perm_klinkenberg_md NUMERIC(12,4),   -- Klinkenberg-corrected
    perm_to_oil_md      NUMERIC(12,4),
    perm_to_water_md    NUMERIC(12,4),
    grain_density_g_cc  NUMERIC(7,4),
    bulk_density_g_cc   NUMERIC(7,4),

    -- Fluid saturations
    oil_sat_pct         NUMERIC(6,3),
    water_sat_pct       NUMERIC(6,3),
    gas_sat_pct         NUMERIC(6,3),
    residual_oil_sat_pct NUMERIC(6,3),

    -- Special core analysis (SCAL) flags
    has_rel_perm        BOOLEAN DEFAULT FALSE,
    has_cap_pressure    BOOLEAN DEFAULT FALSE,
    has_wettability     BOOLEAN DEFAULT FALSE,
    wettability_index   NUMERIC(5,3),

    analysis_lab        TEXT,
    analysis_date       DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX core_analysis_well_id_idx ON oilgas.core_analysis (well_id);
CREATE INDEX core_analysis_depth_idx   ON oilgas.core_analysis (well_id, depth_top_ft);

COMMENT ON TABLE oilgas.core_analysis IS
    'Conventional and sidewall core petrophysical analysis. '
    'Permeability and porosity measurements feed reservoir model calibration.';


-- ------------------------------------------------------------
-- 34. LOG_INTERPRETATION
-- Petrophysical log interpretation results by depth zone.
-- Derived from wireline / LWD logs run in the well.
-- ------------------------------------------------------------
CREATE TABLE oilgas.log_interpretation (
    interp_id           TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    api_number          TEXT,
    zone_name           TEXT,
    formation_name      TEXT,
    depth_top_tvd_ft    NUMERIC(10,2),
    depth_bot_tvd_ft    NUMERIC(10,2),
    depth_top_md_ft     NUMERIC(10,2),
    depth_bot_md_ft     NUMERIC(10,2),

    -- Petrophysical results
    gross_pay_ft        NUMERIC(8,2),
    net_pay_ft          NUMERIC(8,2),
    net_to_gross        NUMERIC(6,4),
    avg_porosity_pct    NUMERIC(6,3),
    avg_sw_pct          NUMERIC(6,3),   -- water saturation
    avg_vsh_pct         NUMERIC(6,3),   -- volume of shale
    avg_rt_ohmm         NUMERIC(10,3),  -- true resistivity
    avg_rhob_g_cc       NUMERIC(7,4),   -- bulk density
    avg_nphi_pct        NUMERIC(6,3),   -- neutron porosity
    avg_dt_us_ft        NUMERIC(8,3),   -- sonic travel time

    -- Fluid identification
    fluid_type          TEXT,       -- OIL, GAS, WATER, UNDETERMINED
    pay_flag            BOOLEAN,
    cutoff_phi          NUMERIC(6,3),
    cutoff_sw           NUMERIC(6,3),
    cutoff_vsh          NUMERIC(6,3),

    interpreter         TEXT,
    interp_date         DATE,
    log_suite           TEXT,
    software_used       TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX log_interp_well_id_idx ON oilgas.log_interpretation (well_id);
CREATE INDEX log_interp_depth_idx   ON oilgas.log_interpretation (well_id, depth_top_tvd_ft);

COMMENT ON TABLE oilgas.log_interpretation IS
    'Petrophysical log interpretation results by depth zone per well. '
    'Net pay and average properties feed volumetric reserve calculations.';


-- ------------------------------------------------------------
-- 35. DECLINE_CURVE
-- Arps decline curve parameters per well per producing phase.
-- Enables EUR (estimated ultimate recovery) calculation and
-- reserves classification.
-- ------------------------------------------------------------
CREATE TABLE oilgas.decline_curve (
    dc_id               TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    reservoir_id        TEXT        REFERENCES oilgas.reservoir(reservoir_id),
    phase               TEXT        NOT NULL CHECK (phase IN ('OIL','GAS','WATER','CONDENSATE')),
    decline_type        TEXT        NOT NULL CHECK (decline_type IN ('EXPONENTIAL','HYPERBOLIC','HARMONIC')),

    -- Arps parameters
    qi                  NUMERIC(14,4),  -- initial rate (bopd / mcfd)
    qi_unit             TEXT,           -- BOPD, MCFD, BWPD
    di_annual           NUMERIC(10,6),  -- initial nominal decline rate (fraction/year)
    di_effective        NUMERIC(10,6),  -- initial effective decline rate (fraction/year)
    b_factor            NUMERIC(8,4),   -- hyperbolic b-exponent (0=exp, 1=harmonic)

    -- Date range
    fit_start_date      DATE,
    fit_end_date        DATE,
    forecast_end_date   DATE,
    economic_limit_rate NUMERIC(10,4),  -- abandonment rate

    -- EUR
    eur                 NUMERIC(14,3),
    eur_unit            TEXT,           -- BBL, MCF
    cum_production      NUMERIC(14,3),  -- cumulative at fit start date
    remaining_eur       NUMERIC(14,3),  -- EUR - cum_production

    -- Reserves classification
    reserves_category   TEXT,           -- 1P (PROVED), 2P (PROBABLE), 3P (POSSIBLE)

    r_squared           NUMERIC(7,6),   -- goodness of fit
    prepared_by         TEXT,
    prep_date           DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX dc_well_id_idx      ON oilgas.decline_curve (well_id);
CREATE INDEX dc_phase_idx        ON oilgas.decline_curve (well_id, phase);
CREATE INDEX dc_reservoir_idx    ON oilgas.decline_curve (reservoir_id);
CREATE INDEX dc_reserves_idx     ON oilgas.decline_curve (reserves_category);

COMMENT ON TABLE oilgas.decline_curve IS
    'Arps decline curve parameters (Qi, Di, b) per well per phase. '
    'eur and remaining_eur support SEC reserves reporting. '
    'reserves_category: 1P=proved, 2P=probable, 3P=possible.';


-- ------------------------------------------------------------
-- 36. FLUID_ANALYSIS
-- PVT / compositional fluid sample analysis.
-- ------------------------------------------------------------
CREATE TABLE oilgas.fluid_analysis (
    fluid_id            TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    reservoir_id        TEXT        REFERENCES oilgas.reservoir(reservoir_id),
    sample_date         DATE        NOT NULL,
    sample_depth_ft     NUMERIC(10,2),
    sample_type         TEXT,       -- DST, WIRELINE_MDT, SURFACE_RECOMBINED
    fluid_type          TEXT,       -- BLACK_OIL, VOLATILE_OIL, GAS_CONDENSATE, DRY_GAS, WATER
    analysis_lab        TEXT,

    -- Oil PVT
    api_gravity         NUMERIC(6,2),
    oil_viscosity_cp    NUMERIC(10,4),
    bubble_point_psia   NUMERIC(8,1),
    fvf_oil_rb_stb      NUMERIC(8,5),   -- formation volume factor
    solution_gor_scf_stb NUMERIC(10,2),
    oil_compressibility NUMERIC(14,8),

    -- Gas PVT
    specific_gravity    NUMERIC(6,4),
    z_factor            NUMERIC(7,5),
    fvf_gas_rcf_scf     NUMERIC(12,8),
    gas_viscosity_cp    NUMERIC(10,6),
    dew_point_psia      NUMERIC(8,1),
    cgr_stb_mmscf       NUMERIC(10,2),  -- condensate-gas ratio

    -- Water
    water_salinity_ppm  NUMERIC(10,1),
    water_density_g_cc  NUMERIC(7,4),
    water_fvf           NUMERIC(8,5),

    -- Composition (mole fraction, key components)
    c1_mol_pct          NUMERIC(6,3),
    c2_mol_pct          NUMERIC(6,3),
    c3_mol_pct          NUMERIC(6,3),
    ic4_mol_pct         NUMERIC(6,3),
    nc4_mol_pct         NUMERIC(6,3),
    c5plus_mol_pct      NUMERIC(6,3),
    co2_mol_pct         NUMERIC(6,3),
    n2_mol_pct          NUMERIC(6,3),
    h2s_mol_pct         NUMERIC(6,3),

    reservoir_temp_f    NUMERIC(6,1),
    reservoir_press_psia NUMERIC(8,1),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX fluid_analysis_well_id_idx ON oilgas.fluid_analysis (well_id);
CREATE INDEX fluid_analysis_res_idx     ON oilgas.fluid_analysis (reservoir_id);

COMMENT ON TABLE oilgas.fluid_analysis IS
    'PVT and compositional fluid analysis per well. '
    'bubble_point, FVF, and GOR feed reservoir simulation and '
    'material balance calculations.';


-- ============================================================
-- D. HSE & ENVIRONMENTAL
-- ============================================================

-- ------------------------------------------------------------
-- 37. SPILL_INCIDENT
-- Spill, release, and fire/explosion events.
-- Closes the loop on violation TAC §3.14 entries.
-- ------------------------------------------------------------
CREATE TABLE oilgas.spill_incident (
    incident_id         TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    pipeline_id         TEXT        REFERENCES oilgas.pipelines(pipeline_id),
    violation_id        TEXT        REFERENCES oilgas.violations(violation_id),

    -- Event
    incident_type       TEXT        NOT NULL,
        -- SPILL, RELEASE, FIRE, EXPLOSION, BLOWOUT, LEAK
    incident_date       DATE        NOT NULL,
    incident_time       TIME,
    discovery_date      DATE,
    discovery_method    TEXT,       -- OPERATOR, AERIAL, THIRD_PARTY, RRC

    -- Location
    county              TEXT,
    latitude            DOUBLE PRECISION,
    longitude           DOUBLE PRECISION,
    geom                geometry(Point, 4269),
    on_lease            BOOLEAN     DEFAULT TRUE,
    waterbody_affected  TEXT,
    distance_to_water_ft NUMERIC(8,1),

    -- Material released
    substance           TEXT,       -- CRUDE_OIL, PRODUCED_WATER, CONDENSATE, GAS, DRILLING_MUD
    volume_released_bbl NUMERIC(12,3),
    volume_recovered_bbl NUMERIC(12,3),
    net_loss_bbl        NUMERIC(12,3)  GENERATED ALWAYS AS
                            (volume_released_bbl - COALESCE(volume_recovered_bbl,0)) STORED,
    cause               TEXT,       -- CORROSION, EQUIPMENT_FAILURE, OVERFILL, VANDALISM, WEATHER

    -- Media impacted
    soil_impacted       BOOLEAN     DEFAULT FALSE,
    surface_water_impacted BOOLEAN  DEFAULT FALSE,
    groundwater_impacted BOOLEAN    DEFAULT FALSE,
    soil_volume_cy      NUMERIC(10,2),

    -- Reporting
    reported_to_rrc     BOOLEAN     DEFAULT FALSE,
    rrc_report_date     DATE,
    reported_to_tceq    BOOLEAN     DEFAULT FALSE,
    tceq_report_date    DATE,
    nrc_report_no       TEXT,       -- National Response Center

    -- Remediation status
    remediation_status  TEXT        DEFAULT 'OPEN',
        -- OPEN, IN_PROGRESS, COMPLETED, CLOSED_NO_ACTION
    remediation_start   DATE,
    remediation_end     DATE,
    closure_letter_date DATE,

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX spill_well_id_idx     ON oilgas.spill_incident (well_id);
CREATE INDEX spill_facility_idx    ON oilgas.spill_incident (facility_id);
CREATE INDEX spill_date_idx        ON oilgas.spill_incident (incident_date);
CREATE INDEX spill_geom_idx        ON oilgas.spill_incident USING GIST (geom);
CREATE INDEX spill_status_idx      ON oilgas.spill_incident (remediation_status);

COMMENT ON TABLE oilgas.spill_incident IS
    'Spill, release, fire, and blowout incident records. '
    'Links to violations (TAC §3.14 notice of spill/fire/leak). '
    'net_loss_bbl is a generated column. '
    'Supports RRC, TCEQ, and EPA/NRC reporting.';

-- Trigger: auto-populate geometry
CREATE OR REPLACE FUNCTION oilgas.spill_update_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4269);
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER spill_geom_trigger
    BEFORE INSERT OR UPDATE ON oilgas.spill_incident
    FOR EACH ROW EXECUTE FUNCTION oilgas.spill_update_geom();


-- ------------------------------------------------------------
-- 38. REMEDIATION_ACTION
-- Individual remediation tasks and progress tracking for
-- each spill or contaminated site.
-- ------------------------------------------------------------
CREATE TABLE oilgas.remediation_action (
    action_id           TEXT        PRIMARY KEY,
    incident_id         TEXT        NOT NULL REFERENCES oilgas.spill_incident(incident_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    action_type         TEXT,
        -- EXCAVATION, BIOREMEDIATION, VACUUM_TRUCK, AIR_SPARGING,
        -- SOIL_WASHING, THERMAL, MONITORING_ONLY, NATURAL_ATTENUATION
    action_status       TEXT        DEFAULT 'PLANNED',
        -- PLANNED, IN_PROGRESS, COMPLETE, VERIFIED
    start_date          DATE,
    end_date            DATE,
    contractor          TEXT,
    supervisor          TEXT,

    -- Volumes / extent
    soil_removed_cy     NUMERIC(10,2),
    soil_disposed_cy    NUMERIC(10,2),
    disposal_facility   TEXT,
    water_treated_bbl   NUMERIC(12,3),

    -- Sampling / verification
    confirmation_samples INTEGER,
    tph_initial_ppm     NUMERIC(10,2),  -- total petroleum hydrocarbons
    tph_final_ppm       NUMERIC(10,2),
    benzene_initial_ppb NUMERIC(10,3),
    benzene_final_ppb   NUMERIC(10,3),
    cleanup_standard    TEXT,

    -- Cost
    actual_cost_usd     NUMERIC(14,2),

    tceq_tracking_no    TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX remediation_incident_idx ON oilgas.remediation_action (incident_id);

COMMENT ON TABLE oilgas.remediation_action IS
    'Individual remediation tasks under a spill incident. '
    'Tracks cleanup progress from excavation to confirmation sampling.';


-- ------------------------------------------------------------
-- 39. SAFETY_INCIDENT
-- OSHA-recordable and near-miss safety events.
-- ------------------------------------------------------------
CREATE TABLE oilgas.safety_incident (
    safety_id           TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    incident_date       DATE        NOT NULL,
    incident_time       TIME,
    incident_type       TEXT,
        -- FATALITY, LOST_TIME, RECORDABLE, FIRST_AID, NEAR_MISS, PROPERTY_DAMAGE
    osha_recordable     BOOLEAN     DEFAULT FALSE,
    osha_days_away      INTEGER     DEFAULT 0,
    osha_restricted_days INTEGER    DEFAULT 0,

    -- Event detail
    event_category      TEXT,
        -- STRUCK_BY, CAUGHT_IN, FALL, ELECTRICAL, FIRE_EXPLOSION,
        --  CHEMICAL_EXPOSURE, VEHICLE, ERGONOMIC, OTHER
    description         TEXT,
    body_part_injured   TEXT,
    nature_of_injury    TEXT,

    -- Personnel
    injured_party       TEXT,       -- EMPLOYEE, CONTRACTOR, VISITOR
    contractor_company  TEXT,
    experience_yrs      NUMERIC(4,1),

    -- Investigation
    root_cause          TEXT,
    corrective_actions  TEXT,
    investigation_complete BOOLEAN  DEFAULT FALSE,
    osha_300_logged     BOOLEAN     DEFAULT FALSE,

    -- Costs
    medical_cost_usd    NUMERIC(12,2),
    property_damage_usd NUMERIC(12,2),
    total_cost_usd      NUMERIC(12,2),

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX safety_well_id_idx  ON oilgas.safety_incident (well_id);
CREATE INDEX safety_date_idx     ON oilgas.safety_incident (incident_date);
CREATE INDEX safety_osha_idx     ON oilgas.safety_incident (osha_recordable);

COMMENT ON TABLE oilgas.safety_incident IS
    'OSHA-recordable and near-miss safety incidents. '
    'osha_days_away and osha_restricted_days feed TRIR/LTIR KPI calculations.';


-- ------------------------------------------------------------
-- 40. EMISSIONS_MONITORING
-- Facility-level atmospheric emissions measurements.
-- Supports EPA Subpart W / TCEQ Air Quality permits.
-- ------------------------------------------------------------
CREATE TABLE oilgas.emissions_monitoring (
    emis_id             TEXT        PRIMARY KEY,
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    monitor_date        DATE        NOT NULL,
    monitor_method      TEXT,
        -- OGI_CAMERA, METHOD_21, LDAR_SENSOR, CONTINUOUS_MONITOR, ESTIMATION
    emission_source     TEXT,       -- FLANGE, VALVE, PUMP_SEAL, TANK, COMPRESSOR, WELLHEAD

    -- Methane
    methane_ppm         NUMERIC(10,3),
    methane_kg_hr       NUMERIC(10,4),
    methane_tonne_yr    NUMERIC(10,3),

    -- VOC
    voc_ppm             NUMERIC(10,3),
    voc_kg_hr           NUMERIC(10,4),
    voc_tonne_yr        NUMERIC(10,3),

    -- H2S
    h2s_ppm             NUMERIC(10,3),

    -- GHG totals (CO2 equivalent)
    co2e_tonne_yr       NUMERIC(12,3),

    -- Leak detection and repair (LDAR)
    leak_detected       BOOLEAN     DEFAULT FALSE,
    leak_repaired       BOOLEAN,
    repair_date         DATE,
    repair_method       TEXT,
    delay_of_repair     BOOLEAN     DEFAULT FALSE,
    delay_reason        TEXT,

    operator_name       TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX emissions_facility_idx ON oilgas.emissions_monitoring (facility_id);
CREATE INDEX emissions_date_idx     ON oilgas.emissions_monitoring (monitor_date);
CREATE INDEX emissions_leak_idx     ON oilgas.emissions_monitoring (leak_detected, leak_repaired);

COMMENT ON TABLE oilgas.emissions_monitoring IS
    'Atmospheric emissions monitoring and LDAR records. '
    'Supports EPA 40 CFR Subpart W and TCEQ permit reporting. '
    'Leak-detection and repair (LDAR) workflow tracked in each row.';


-- ------------------------------------------------------------
-- 41. WASTE_MANIFEST
-- E&P waste tracking — exempt and non-exempt streams.
-- ------------------------------------------------------------
CREATE TABLE oilgas.waste_manifest (
    manifest_id         TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    manifest_no         TEXT        UNIQUE,
    manifest_date       DATE        NOT NULL,
    waste_type          TEXT,
        -- DRILLING_CUTTINGS, PRODUCED_WATER, SLUDGE, TANK_BOTTOMS,
        --  PIPEMILL_SCALE, FRACK_FLUID, AMINE, GLYCOL, OTHER
    ep_exempt           BOOLEAN,    -- E&P exempt under RCRA Subtitle C
    waste_volume        NUMERIC(12,3),
    waste_volume_unit   TEXT,       -- BBL, CY, TON, GAL
    waste_description   TEXT,
    origin_description  TEXT,

    -- Transporter
    transporter_co      TEXT,
    transporter_dot_no  TEXT,
    vehicle_no          TEXT,
    driver_name         TEXT,

    -- Disposal
    disposal_facility   TEXT,
    disposal_permit_no  TEXT,
    disposal_method     TEXT,       -- LAND_FARM, INJECT, LANDFILL, RECYCLE, INCINERATE
    disposal_date       DATE,
    receipt_confirmed   BOOLEAN     DEFAULT FALSE,

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX waste_manifest_well_idx    ON oilgas.waste_manifest (well_id);
CREATE INDEX waste_manifest_date_idx    ON oilgas.waste_manifest (manifest_date);
CREATE INDEX waste_manifest_type_idx    ON oilgas.waste_manifest (waste_type);

COMMENT ON TABLE oilgas.waste_manifest IS
    'E&P waste manifest tracking. Covers both RCRA-exempt and non-exempt '
    'waste streams from drilling, production, and facility operations.';


-- ============================================================
-- E. SURFACE, LAND & COMMERCIAL
-- ============================================================

-- ------------------------------------------------------------
-- 42. MINERAL_LEASE
-- Oil and gas mineral lease agreements (not the RRC leasehold
-- administrative unit — this is the legal document itself).
-- ------------------------------------------------------------
CREATE TABLE oilgas.mineral_lease (
    ml_id               TEXT        PRIMARY KEY,
    lease_name          TEXT        NOT NULL,
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id              TEXT        REFERENCES oilgas.operator(opr_id),

    -- Parties
    lessor_name         TEXT        NOT NULL,
    lessor_address      TEXT,
    lessee_name         TEXT        NOT NULL,

    -- Terms
    effective_date      DATE        NOT NULL,
    expiry_date         DATE,
    primary_term_yrs    NUMERIC(4,1),
    paid_up             BOOLEAN     DEFAULT FALSE,

    -- Lands
    gross_acres         NUMERIC(10,3),
    net_acres           NUMERIC(10,3),
    survey_name         TEXT,
    abstract_no         TEXT,
    county              TEXT,
    state               CHAR(2)     DEFAULT 'TX',
    legal_description   TEXT,

    -- Royalty
    royalty_fraction    NUMERIC(8,6),   -- e.g. 0.250000 = 25%
    overriding_ri_pct   NUMERIC(7,4),   -- ORRI retained by lessor
    shut_in_royalty_usd NUMERIC(10,2),
    shut_in_period_days INTEGER,

    -- Special clauses
    depth_limitation_ft NUMERIC(10,2),
    pugh_clause         BOOLEAN     DEFAULT FALSE,
    continuous_drilling BOOLEAN     DEFAULT FALSE,
    pooling_allowed     BOOLEAN     DEFAULT TRUE,
    surface_use_restrictions TEXT,

    -- Document
    instrument_no       TEXT,
    recording_vol_page  TEXT,
    county_clerk_date   DATE,

    lease_status        TEXT        DEFAULT 'ACTIVE',
        -- ACTIVE, EXPIRED, RELEASED, HBP (held by production), SURRENDERED
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX mineral_lease_lease_id_idx ON oilgas.mineral_lease (lease_id);
CREATE INDEX mineral_lease_county_idx   ON oilgas.mineral_lease (county);
CREATE INDEX mineral_lease_status_idx   ON oilgas.mineral_lease (lease_status);

COMMENT ON TABLE oilgas.mineral_lease IS
    'Oil and gas mineral lease agreements (legal instruments). '
    'Distinct from leaseholds (RRC admin unit). '
    'royalty_fraction drives royalty payment calculations in revenue_allocation.';


-- ------------------------------------------------------------
-- 43. INTEREST_OWNER
-- Working interest and royalty interest owners.
-- ------------------------------------------------------------
CREATE TABLE oilgas.interest_owner (
    owner_id            TEXT        PRIMARY KEY,
    owner_name          TEXT        NOT NULL,
    owner_type          TEXT,       -- INDIVIDUAL, CORPORATION, TRUST, ESTATE, PARTNERSHIP
    tax_id              TEXT,       -- TIN / EIN (store encrypted in production)
    mailing_address     TEXT,
    city                TEXT,
    state               CHAR(2),
    zip                 TEXT,
    phone               TEXT,
    email               TEXT,
    payment_method      TEXT,       -- CHECK, ACH, WIRE
    bank_account_ref    TEXT,       -- reference only — do not store account numbers
    is_1099_required       BOOLEAN     DEFAULT TRUE,
    active              BOOLEAN     DEFAULT TRUE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX interest_owner_name_idx ON oilgas.interest_owner (owner_name);

COMMENT ON TABLE oilgas.interest_owner IS
    'Working interest and royalty interest owners. '
    'Links to well_interest for decimal interest records per well. '
    'Do NOT store raw bank account numbers — use bank_account_ref only.';


-- ------------------------------------------------------------
-- 44. WELL_INTEREST
-- Decimal interest ownership per well per owner.
-- WI + NRI + ORRI breakdown for each party.
-- ------------------------------------------------------------
CREATE TABLE oilgas.well_interest (
    wi_id               TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id) ON DELETE CASCADE,
    ml_id               TEXT        REFERENCES oilgas.mineral_lease(ml_id),
    owner_id            TEXT        NOT NULL REFERENCES oilgas.interest_owner(owner_id),

    interest_type       TEXT        NOT NULL,
        -- WI (working interest), RI (royalty), ORRI (overriding royalty),
        --  NPI (net profits interest), CARRIED (carried interest)

    -- Decimal interests
    wi_decimal          NUMERIC(10,8),   -- working interest (cost burden)
    nri_decimal         NUMERIC(10,8),   -- net revenue interest (revenue share)
    ri_decimal          NUMERIC(10,8),   -- royalty interest
    orri_decimal        NUMERIC(10,8),   -- overriding royalty

    -- Phase applicability
    oil_nri             NUMERIC(10,8),
    gas_nri             NUMERIC(10,8),
    ngl_nri             NUMERIC(10,8),

    effective_date      DATE        NOT NULL,
    end_date            DATE,
    division_order_no   TEXT,
    title_opinion_date  DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX well_interest_well_id_idx  ON oilgas.well_interest (well_id);
CREATE INDEX well_interest_owner_idx    ON oilgas.well_interest (owner_id);
CREATE INDEX well_interest_ml_idx       ON oilgas.well_interest (ml_id);

COMMENT ON TABLE oilgas.well_interest IS
    'Decimal working interest and NRI per well per owner. '
    'Drives revenue_allocation calculations and JIB billing splits.';


-- ------------------------------------------------------------
-- 45. RIGHT_OF_WAY
-- Pipeline, road, and facility right-of-way and easement
-- agreements with surface owners.
-- ------------------------------------------------------------
CREATE TABLE oilgas.right_of_way (
    row_id              TEXT        PRIMARY KEY,
    row_type            TEXT        NOT NULL,
        -- PIPELINE_ROW, ROAD_ACCESS, FACILITY_SITE, POWERLINE, OTHER
    pipeline_id         TEXT        REFERENCES oilgas.pipelines(pipeline_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),

    -- Surface owner
    grantor_name        TEXT        NOT NULL,
    grantor_address     TEXT,
    grantee_name        TEXT,

    -- Location
    county              TEXT,
    abstract_no         TEXT,
    survey_name         TEXT,
    width_ft            NUMERIC(8,2),
    length_ft           NUMERIC(10,2),
    area_acres          NUMERIC(8,4),
    geom                geometry(MultiLineString, 4269),  -- centerline

    -- Terms
    effective_date      DATE,
    expiry_date         DATE,
    perpetual           BOOLEAN     DEFAULT FALSE,
    annual_payment_usd  NUMERIC(10,2),
    one_time_payment_usd NUMERIC(12,2),
    damage_payment_usd  NUMERIC(12,2),

    -- Recording
    instrument_no       TEXT,
    recording_vol_page  TEXT,
    county_clerk_date   DATE,

    row_status          TEXT        DEFAULT 'ACTIVE',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX row_geom_idx        ON oilgas.right_of_way USING GIST (geom);
CREATE INDEX row_pipeline_idx    ON oilgas.right_of_way (pipeline_id);
CREATE INDEX row_lease_idx       ON oilgas.right_of_way (lease_id);

COMMENT ON TABLE oilgas.right_of_way IS
    'Pipeline, road, and facility ROW and easement agreements. '
    'Geometry is the centerline of the corridor.';


-- ------------------------------------------------------------
-- 46. SURFACE_USE_AGREEMENT
-- SUA / damage agreements with surface owners covering
-- well pads and facility sites.
-- ------------------------------------------------------------
CREATE TABLE oilgas.surface_use_agreement (
    sua_id              TEXT        PRIMARY KEY,
    pad_id              TEXT        REFERENCES oilgas.pads(pad_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    surface_owner       TEXT        NOT NULL,
    surface_owner_address TEXT,
    county              TEXT,
    effective_date      DATE,
    expiry_date         DATE,
    annual_rental_usd   NUMERIC(10,2),
    damage_payment_usd  NUMERIC(12,2),
    reclamation_bond_usd NUMERIC(12,2),
    reclamation_requirements TEXT,
    access_restrictions TEXT,
    instrument_no       TEXT,
    recording_ref       TEXT,
    sua_status          TEXT        DEFAULT 'ACTIVE',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX sua_pad_idx    ON oilgas.surface_use_agreement (pad_id);
CREATE INDEX sua_lease_idx  ON oilgas.surface_use_agreement (lease_id);

COMMENT ON TABLE oilgas.surface_use_agreement IS
    'Surface use and damage agreements for pad sites and facility locations.';


-- ------------------------------------------------------------
-- 47. GAS_CONTRACT
-- Gas purchase / sales / gathering contracts.
-- ------------------------------------------------------------
CREATE TABLE oilgas.gas_contract (
    contract_id         TEXT        PRIMARY KEY,
    contract_name       TEXT        NOT NULL,
    contract_type       TEXT,       -- PURCHASE, GATHERING, PROCESSING, TRANSPORTATION, SALES
    opr_id              TEXT        REFERENCES oilgas.operator(opr_id),
    counterparty        TEXT        NOT NULL,
    counterparty_duns   TEXT,

    -- Coverage
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    pipeline_id         TEXT        REFERENCES oilgas.pipelines(pipeline_id),

    -- Term
    effective_date      DATE        NOT NULL,
    expiry_date         DATE,
    auto_renew          BOOLEAN     DEFAULT FALSE,

    -- Pricing
    price_basis         TEXT,       -- SPOT, FIXED, INDEX_PLUS, PERCENT_OF_INDEX
    index_reference     TEXT,       -- WAHA, HENRY_HUB, OPAL, etc.
    price_usd_mmbtu     NUMERIC(10,4),
    price_differential  NUMERIC(8,4),

    -- Deductions
    gathering_fee_usd_mmbtu   NUMERIC(8,4),
    compression_fee_usd_mmbtu NUMERIC(8,4),
    processing_fee_pct        NUMERIC(6,3),
    fuel_retention_pct        NUMERIC(6,3),

    -- Volumes
    min_dcq_mmbtu_day   NUMERIC(12,2),   -- daily contract quantity
    max_dcq_mmbtu_day   NUMERIC(12,2),
    take_or_pay_pct     NUMERIC(6,3),

    -- Specs
    min_btu_mmbtu       NUMERIC(8,2),
    max_h2s_ppm         NUMERIC(8,2),
    max_co2_pct         NUMERIC(6,3),
    max_water_lb_mmscf  NUMERIC(8,2),

    contract_status     TEXT        DEFAULT 'ACTIVE',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX gas_contract_lease_idx    ON oilgas.gas_contract (lease_id);
CREATE INDEX gas_contract_pipeline_idx ON oilgas.gas_contract (pipeline_id);

COMMENT ON TABLE oilgas.gas_contract IS
    'Gas purchase, gathering, and sales contracts. '
    'gathering_fee and fuel_retention_pct feed revenue_allocation deductions.';


-- ------------------------------------------------------------
-- 48. SEVERANCE_TAX
-- State severance / production tax filings per period.
-- Texas: Oil Production Tax (4.6%), Natural Gas Production Tax (7.5%).
-- ------------------------------------------------------------
CREATE TABLE oilgas.severance_tax (
    sev_id              TEXT        PRIMARY KEY,
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id              TEXT        REFERENCES oilgas.operator(opr_id),
    tax_period          DATE        NOT NULL,  -- first of month
    tax_type            TEXT        NOT NULL,  -- OIL, GAS, CONDENSATE, SULFUR
    tax_authority       TEXT        DEFAULT 'TX_COMPTROLLER',

    -- Volumes reported
    taxable_volume      NUMERIC(14,3),
    volume_unit         TEXT,       -- BBL, MCF

    -- Values
    taxable_value_usd   NUMERIC(14,2),
    wellhead_price      NUMERIC(10,4),
    tax_rate_pct        NUMERIC(7,5),
    tax_amount_usd      NUMERIC(14,2),

    -- Exemptions / credits
    high_cost_exempt    BOOLEAN     DEFAULT FALSE,
    enhanced_recovery   BOOLEAN     DEFAULT FALSE,
    exemption_amount_usd NUMERIC(14,2),
    net_tax_due_usd     NUMERIC(14,2),

    -- Filing
    due_date            DATE,
    filed_date          DATE,
    paid_date           DATE,
    confirmation_no     TEXT,
    amended             BOOLEAN     DEFAULT FALSE,
    penalty_usd         NUMERIC(12,2),
    interest_usd        NUMERIC(12,2),

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX severance_tax_lease_idx  ON oilgas.severance_tax (lease_id);
CREATE INDEX severance_tax_period_idx ON oilgas.severance_tax (tax_period DESC);
CREATE INDEX severance_tax_type_idx   ON oilgas.severance_tax (tax_type);

COMMENT ON TABLE oilgas.severance_tax IS
    'State severance / production tax filings. '
    'TX oil rate: 4.6%, gas rate: 7.5% of market value. '
    'Exemption flags support high-cost gas and EOR credit claims.';


-- ============================================================
-- F. INFRASTRUCTURE & EQUIPMENT
-- ============================================================

-- ------------------------------------------------------------
-- 49. EQUIPMENT
-- Individual asset-level equipment inventory.
-- Pump jacks, compressors, separators, generators, etc.
-- ------------------------------------------------------------
CREATE TABLE oilgas.equipment (
    equip_id            TEXT        PRIMARY KEY,
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    pad_id              TEXT        REFERENCES oilgas.pads(pad_id),
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),

    asset_tag           TEXT        UNIQUE,
    equipment_name      TEXT        NOT NULL,
    equipment_type      TEXT        NOT NULL,
        -- PUMP_JACK, ELECTRIC_SUBMERSIBLE_PUMP, PLUNGER_LIFT,
        --  GAS_LIFT_VALVE, COMPRESSOR, SEPARATOR, TREATER,
        --  HEATER_TREATER, DEHYDRATOR, AMINE_UNIT, FLARE_STACK,
        --  GENERATOR, TANK, VRU, LACT_UNIT, CHOKE, FLOWMETER, OTHER
    manufacturer        TEXT,
    model               TEXT,
    serial_no           TEXT,
    year_manufactured   INTEGER,

    -- Specs (type-dependent)
    rated_capacity      NUMERIC(12,3),
    capacity_unit       TEXT,       -- BOPD, MCFD, HP, PSIG, BBL
    operating_pressure_psia NUMERIC(8,1),
    design_pressure_psia    NUMERIC(8,1),
    horsepower          NUMERIC(8,1),
    voltage_v           INTEGER,

    -- Status
    equip_status        TEXT        DEFAULT 'IN_SERVICE',
        -- IN_SERVICE, STANDBY, OUT_OF_SERVICE, RETIRED, SOLD
    install_date        DATE,
    decommission_date   DATE,
    ownership           TEXT        DEFAULT 'OWNED',  -- OWNED, LEASED, RENTAL
    vendor              TEXT,
    lease_expiry        DATE,

    -- Maintenance
    last_pm_date        DATE,
    next_pm_due         DATE,
    pm_interval_days    INTEGER,

    replacement_cost_usd NUMERIC(14,2),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX equipment_facility_idx ON oilgas.equipment (facility_id);
CREATE INDEX equipment_type_idx     ON oilgas.equipment (equipment_type);
CREATE INDEX equipment_status_idx   ON oilgas.equipment (equip_status);
CREATE INDEX equipment_pm_due_idx   ON oilgas.equipment (next_pm_due);

COMMENT ON TABLE oilgas.equipment IS
    'Individual asset-level equipment inventory. '
    'next_pm_due supports preventive maintenance scheduling queries. '
    'One row per physical asset — not one per type.';


-- ------------------------------------------------------------
-- 50. MAINTENANCE_RECORD
-- Preventive and corrective maintenance events per equipment.
-- ------------------------------------------------------------
CREATE TABLE oilgas.maintenance_record (
    maint_id            TEXT        PRIMARY KEY,
    equip_id            TEXT        NOT NULL REFERENCES oilgas.equipment(equip_id),
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    work_order_no       TEXT,
    maint_type          TEXT        NOT NULL,
        -- PREVENTIVE, CORRECTIVE, PREDICTIVE, INSPECTION, OVERHAUL
    priority            TEXT        DEFAULT 'ROUTINE',
        -- EMERGENCY, HIGH, ROUTINE, LOW
    status              TEXT        DEFAULT 'OPEN',
        -- OPEN, IN_PROGRESS, COMPLETE, DEFERRED, CANCELLED
    description         TEXT        NOT NULL,
    failure_mode        TEXT,
    root_cause          TEXT,

    -- Scheduling
    requested_date      DATE,
    scheduled_date      DATE,
    actual_start        TIMESTAMPTZ,
    actual_end          TIMESTAMPTZ,
    downtime_hrs        NUMERIC(8,2),

    -- Execution
    performed_by        TEXT,
    vendor              TEXT,
    work_performed      TEXT,
    parts_used          TEXT,       -- JSON array stored as TEXT for flexibility
    labor_hrs           NUMERIC(8,2),

    -- Cost
    labor_cost_usd      NUMERIC(12,2),
    parts_cost_usd      NUMERIC(12,2),
    total_cost_usd      NUMERIC(12,2),

    -- Next service
    next_service_date   DATE,
    next_service_hrs    NUMERIC(8,1),

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX maint_equip_id_idx   ON oilgas.maintenance_record (equip_id);
CREATE INDEX maint_status_idx     ON oilgas.maintenance_record (status);
CREATE INDEX maint_type_idx       ON oilgas.maintenance_record (maint_type);
CREATE INDEX maint_sched_idx      ON oilgas.maintenance_record (scheduled_date);

COMMENT ON TABLE oilgas.maintenance_record IS
    'Preventive and corrective maintenance work orders per equipment asset. '
    'downtime_hrs feeds facility availability and production deferment calculations.';


-- ------------------------------------------------------------
-- 51. CORROSION_INSPECTION
-- Pipeline and vessel corrosion monitoring (ILI, UT, visual).
-- Required for pipeline integrity management programs.
-- ------------------------------------------------------------
CREATE TABLE oilgas.corrosion_inspection (
    ci_id               TEXT        PRIMARY KEY,
    pipeline_id         TEXT        REFERENCES oilgas.pipelines(pipeline_id),
    equip_id            TEXT        REFERENCES oilgas.equipment(equip_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    inspection_date     DATE        NOT NULL,
    inspection_method   TEXT,
        -- ILI (inline inspection / pigging), UT_SCAN, VISUAL,
        --  RADIOGRAPHY, SMART_PIG, COUPON, PROBE
    inspector           TEXT,
    inspection_co       TEXT,

    -- Location
    location_description TEXT,
    chainage_from_ft    NUMERIC(10,2),
    chainage_to_ft      NUMERIC(10,2),

    -- Findings
    nominal_wt_in       NUMERIC(6,4),   -- nominal wall thickness
    measured_wt_in      NUMERIC(6,4),   -- minimum measured
    metal_loss_pct      NUMERIC(6,2),
    max_pit_depth_in    NUMERIC(6,4),
    pit_length_in       NUMERIC(6,2),
    corrosion_type      TEXT,       -- INTERNAL, EXTERNAL, CREVICE, SCC
    corrosion_rate_mpy  NUMERIC(8,4),   -- mils per year

    -- Assessment
    remaining_life_yrs  NUMERIC(6,2),
    mop_psi             NUMERIC(8,1),   -- maximum allowable operating pressure
    safe_to_operate     BOOLEAN,
    repair_required     BOOLEAN     DEFAULT FALSE,
    repair_by_date      DATE,

    -- Chemical treatment
    inhibitor_applied   BOOLEAN     DEFAULT FALSE,
    inhibitor_type      TEXT,
    inhibitor_ppm       NUMERIC(8,2),

    next_inspection_date DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX corr_insp_pipeline_idx ON oilgas.corrosion_inspection (pipeline_id);
CREATE INDEX corr_insp_equip_idx    ON oilgas.corrosion_inspection (equip_id);
CREATE INDEX corr_insp_date_idx     ON oilgas.corrosion_inspection (inspection_date);
CREATE INDEX corr_insp_repair_idx   ON oilgas.corrosion_inspection (repair_required, repair_by_date);

COMMENT ON TABLE oilgas.corrosion_inspection IS
    'Pipeline and vessel corrosion inspection records. '
    'remaining_life_yrs and repair_by_date drive integrity management scheduling. '
    'Supports API 1160 / DOT 49 CFR Part 195 pipeline integrity programs.';


-- ------------------------------------------------------------
-- 52. CHEMICAL_INJECTION
-- Oilfield chemical treatment programs per well / facility.
-- Covers scale, corrosion, paraffin, H2S scavenger, etc.
-- ------------------------------------------------------------
CREATE TABLE oilgas.chemical_injection (
    chem_id             TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    chemical_type       TEXT        NOT NULL,
        -- SCALE_INHIBITOR, CORROSION_INHIBITOR, PARAFFIN_INHIBITOR,
        --  H2S_SCAVENGER, DEMULSIFIER, BIOCIDE, OXYGEN_SCAVENGER, OTHER
    chemical_name       TEXT,
    supplier            TEXT,
    product_no          TEXT,
    cas_no              TEXT,       -- Chemical Abstracts Service number

    -- Application
    injection_point     TEXT,
    application_method  TEXT,       -- CONTINUOUS, BATCH, SQUEEZE, COIL_TUBING
    treatment_start     DATE,
    treatment_end       DATE,

    -- Dosing
    design_rate_gal_day NUMERIC(10,4),
    actual_rate_gal_day NUMERIC(10,4),
    concentration_ppm   NUMERIC(10,2),

    -- Inventory / cost
    volume_on_hand_gal  NUMERIC(10,2),
    unit_cost_usd_gal   NUMERIC(10,4),
    monthly_cost_usd    NUMERIC(12,2),

    -- Effectiveness
    monitoring_freq     TEXT,       -- MONTHLY, QUARTERLY, AS_NEEDED
    last_review_date    DATE,
    treatment_effective BOOLEAN,

    sds_on_file         BOOLEAN     DEFAULT FALSE,  -- safety data sheet
    sara_title_iii      BOOLEAN     DEFAULT FALSE,  -- EPCRA reporting threshold
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX chem_inj_well_idx     ON oilgas.chemical_injection (well_id);
CREATE INDEX chem_inj_facility_idx ON oilgas.chemical_injection (facility_id);
CREATE INDEX chem_inj_type_idx     ON oilgas.chemical_injection (chemical_type);

COMMENT ON TABLE oilgas.chemical_injection IS
    'Chemical treatment programs per well / facility. '
    'sara_title_iii flag triggers EPCRA Tier II reporting obligations. '
    'sds_on_file supports OSHA HazCom compliance.';


-- ------------------------------------------------------------
-- 53. LACT_UNIT
-- Lease Automatic Custody Transfer unit records.
-- Measurement point where title transfers from operator to buyer.
-- ------------------------------------------------------------
CREATE TABLE oilgas.lact_unit (
    lact_id             TEXT        PRIMARY KEY,
    facility_id         TEXT        NOT NULL REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    unit_tag            TEXT        UNIQUE,
    manufacturer        TEXT,
    model               TEXT,
    serial_no           TEXT,
    install_date        DATE,

    -- Metering
    meter_type          TEXT,       -- CORIOLIS, TURBINE, POSITIVE_DISPLACEMENT
    meter_factor        NUMERIC(10,8),
    prover_size_bbl     NUMERIC(8,4),
    last_proven_date    DATE,
    next_proving_date   DATE,
    proving_freq_days   INTEGER     DEFAULT 90,

    -- Sampling
    composite_sampler   BOOLEAN     DEFAULT TRUE,
    sample_freq         TEXT,       -- DAILY, WEEKLY, MONTHLY
    last_sample_date    DATE,
    last_bs_w_pct       NUMERIC(5,3),   -- bottom sediment & water

    -- Throughput
    design_capacity_bopd NUMERIC(10,2),
    avg_monthly_bbl     NUMERIC(12,3),

    -- Purchaser connection
    purchaser_name      TEXT,
    pipeline_connection TEXT,
    rrc_meter_no        TEXT,

    equip_status        TEXT        DEFAULT 'IN_SERVICE',
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX lact_facility_idx   ON oilgas.lact_unit (facility_id);
CREATE INDEX lact_proving_idx    ON oilgas.lact_unit (next_proving_date);

COMMENT ON TABLE oilgas.lact_unit IS
    'LACT unit records for custody transfer metering. '
    'next_proving_date supports calibration scheduling. '
    'meter_factor applied to raw meter readings to get custody volumes.';


-- ------------------------------------------------------------
-- 54. PIPELINE_PIGGING
-- Pipeline pigging / ILI run log for integrity management.
-- ------------------------------------------------------------
CREATE TABLE oilgas.pipeline_pigging (
    pig_id              TEXT        PRIMARY KEY,
    pipeline_id         TEXT        NOT NULL REFERENCES oilgas.pipelines(pipeline_id),
    pig_date            DATE        NOT NULL,
    pig_type            TEXT,
        -- CLEANING, GAUGING, CALIPER, SMART_MFL, SMART_UT,
        --  GEOMETRY, FOAM, SCRAPER
    pig_contractor      TEXT,
    launcher_location   TEXT,
    receiver_location   TEXT,
    pig_speed_fps       NUMERIC(6,3),
    run_duration_hrs    NUMERIC(7,2),
    distance_run_ft     NUMERIC(10,1),

    -- Results
    debris_removed_lbs  NUMERIC(10,2),
    scale_type          TEXT,
    max_metal_loss_pct  NUMERIC(6,2),
    anomalies_found     INTEGER     DEFAULT 0,
    anomalies_critical  INTEGER     DEFAULT 0,

    -- Disposition
    defects_repaired    BOOLEAN     DEFAULT FALSE,
    next_pig_date       DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX pigging_pipeline_idx ON oilgas.pipeline_pigging (pipeline_id);
CREATE INDEX pigging_date_idx     ON oilgas.pipeline_pigging (pig_date);

COMMENT ON TABLE oilgas.pipeline_pigging IS
    'Pipeline pigging and inline inspection (ILI) run records. '
    'anomalies_critical triggers entries in corrosion_inspection.';


-- ============================================================
-- G. ECONOMICS & FINANCIAL
-- ============================================================

-- ------------------------------------------------------------
-- 55. AFE
-- Authorization for Expenditure — cost estimate and approval
-- for capital projects (wells, workovers, facilities).
-- ------------------------------------------------------------
CREATE TABLE oilgas.afe (
    afe_id              TEXT        PRIMARY KEY,
    afe_no              TEXT        UNIQUE NOT NULL,
    afe_type            TEXT        NOT NULL,
        -- NEW_WELL, WORKOVER, RECOMPLETION, FACILITY, PIPELINE,
        --  ABANDONMENT, ENVIRONMENTAL, OTHER
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id              TEXT        REFERENCES oilgas.operator(opr_id),

    -- Description
    afe_title           TEXT        NOT NULL,
    description         TEXT,
    justification       TEXT,

    -- Budget
    intangible_cost_usd     NUMERIC(14,2),   -- IDC (tax deductible)
    tangible_cost_usd       NUMERIC(14,2),   -- equipment / materials
    contingency_usd         NUMERIC(14,2),
    total_afe_usd           NUMERIC(14,2)    GENERATED ALWAYS AS
                                (COALESCE(intangible_cost_usd,0)
                                 + COALESCE(tangible_cost_usd,0)
                                 + COALESCE(contingency_usd,0)) STORED,
    -- Actuals (updated through AFE lifecycle)
    actual_cost_usd         NUMERIC(14,2),
    cost_variance_usd       NUMERIC(14,2)    GENERATED ALWAYS AS
                                (COALESCE(actual_cost_usd,0) - COALESCE(intangible_cost_usd,0)
                                 - COALESCE(tangible_cost_usd,0)
                                 - COALESCE(contingency_usd,0)) STORED,

    -- Approval workflow
    status              TEXT        DEFAULT 'DRAFT',
        -- DRAFT, SUBMITTED, APPROVED, REJECTED, CLOSED, CANCELLED
    submitted_date      DATE,
    approved_date       DATE,
    approved_by         TEXT,
    closed_date         DATE,

    -- Working interest split
    operator_wi_pct     NUMERIC(7,4),
    non_op_wi_pct       NUMERIC(7,4),

    -- Expected return
    expected_eur_boe    NUMERIC(14,3),
    expected_ip_boed    NUMERIC(10,2),
    npv10_usd           NUMERIC(14,2),
    irr_pct             NUMERIC(7,3),
    payout_months       NUMERIC(6,1),

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX afe_well_id_idx    ON oilgas.afe (well_id);
CREATE INDEX afe_lease_id_idx   ON oilgas.afe (lease_id);
CREATE INDEX afe_status_idx     ON oilgas.afe (status);
CREATE INDEX afe_type_idx       ON oilgas.afe (afe_type);

COMMENT ON TABLE oilgas.afe IS
    'Authorization for Expenditure. total_afe_usd and cost_variance_usd '
    'are generated columns. npv10_usd / irr_pct support economic screening. '
    'One AFE per project; may span multiple wells (use well_id for primary well).';


-- ------------------------------------------------------------
-- 56. AFE_COST_CODE
-- Line-item cost breakdown for each AFE.
-- ------------------------------------------------------------
CREATE TABLE oilgas.afe_cost_code (
    line_id             TEXT        PRIMARY KEY,
    afe_id              TEXT        NOT NULL REFERENCES oilgas.afe(afe_id) ON DELETE CASCADE,
    cost_code           TEXT        NOT NULL,   -- e.g. 'DRILL_BIT', 'MUD', 'CASING'
    cost_category       TEXT,                   -- DRILLING, COMPLETION, FACILITIES, G&A
    description         TEXT,
    is_tangible         BOOLEAN     DEFAULT FALSE,
    budgeted_usd        NUMERIC(14,2),
    committed_usd       NUMERIC(14,2),
    actual_usd          NUMERIC(14,2),
    variance_usd        NUMERIC(14,2)   GENERATED ALWAYS AS
                            (COALESCE(actual_usd,0) - COALESCE(budgeted_usd,0)) STORED,
    vendor              TEXT,
    invoice_no          TEXT,
    invoice_date        DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX afe_cost_afe_id_idx ON oilgas.afe_cost_code (afe_id);

COMMENT ON TABLE oilgas.afe_cost_code IS
    'Line-item cost codes within an AFE. variance_usd is a generated column.';


-- ------------------------------------------------------------
-- 57. JIB_BILLING
-- Joint Interest Billing — monthly cost statements sent to
-- non-operating working interest partners.
-- ------------------------------------------------------------
CREATE TABLE oilgas.jib_billing (
    jib_id              TEXT        PRIMARY KEY,
    afe_id              TEXT        REFERENCES oilgas.afe(afe_id),
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    owner_id            TEXT        NOT NULL REFERENCES oilgas.interest_owner(owner_id),
    billing_month       DATE        NOT NULL,   -- first of month
    billing_type        TEXT,       -- CAPITAL, LOE, OVERHEAD, ABANDONMENT

    -- Gross costs
    gross_drilling_usd  NUMERIC(14,2)  DEFAULT 0,
    gross_completion_usd NUMERIC(14,2) DEFAULT 0,
    gross_loe_usd       NUMERIC(14,2)  DEFAULT 0,
    gross_overhead_usd  NUMERIC(14,2)  DEFAULT 0,
    gross_total_usd     NUMERIC(14,2),

    -- Working interest
    wi_decimal          NUMERIC(10,8),
    net_billing_usd     NUMERIC(14,2),

    -- Settlement
    status              TEXT        DEFAULT 'ISSUED',
        -- ISSUED, PAID, DISPUTED, WRITTEN_OFF
    issued_date         DATE,
    due_date            DATE,
    paid_date           DATE,
    paid_amount_usd     NUMERIC(14,2),
    invoice_no          TEXT,

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX jib_owner_idx   ON oilgas.jib_billing (owner_id, billing_month);
CREATE INDEX jib_well_idx    ON oilgas.jib_billing (well_id, billing_month);
CREATE INDEX jib_status_idx  ON oilgas.jib_billing (status);

COMMENT ON TABLE oilgas.jib_billing IS
    'Joint interest billing statements to non-operating WI owners. '
    'net_billing_usd = gross_total_usd × wi_decimal.';


-- ------------------------------------------------------------
-- 58. REVENUE_ALLOCATION
-- Monthly revenue distribution per well per interest owner.
-- Drives royalty and working interest disbursements.
-- ------------------------------------------------------------
CREATE TABLE oilgas.revenue_allocation (
    rev_id              TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id),
    prod_id             TEXT        REFERENCES oilgas.production_monthly(prod_id),
    owner_id            TEXT        NOT NULL REFERENCES oilgas.interest_owner(owner_id),
    revenue_month       DATE        NOT NULL,
    phase               TEXT        NOT NULL CHECK (phase IN ('OIL','GAS','NGL','CONDENSATE')),

    -- Volumes
    gross_volume        NUMERIC(14,3),
    volume_unit         TEXT,       -- BBL, MCF
    owners_volume       NUMERIC(14,3),

    -- Pricing
    wellhead_price_usd  NUMERIC(10,4),
    price_deductions_usd NUMERIC(12,4),
    net_price_usd       NUMERIC(10,4),

    -- Revenue
    gross_revenue_usd   NUMERIC(14,2),
    gathering_deduct_usd NUMERIC(12,2),
    processing_deduct_usd NUMERIC(12,2),
    transportation_deduct_usd NUMERIC(12,2),
    severance_tax_usd   NUMERIC(12,2),
    net_revenue_usd     NUMERIC(14,2),

    -- Interest applied
    interest_type       TEXT,       -- WI, RI, ORRI, NPI
    nri_decimal         NUMERIC(10,8),
    owners_net_usd      NUMERIC(14,2),

    -- Disbursement
    check_no            TEXT,
    check_date          DATE,
    status              TEXT        DEFAULT 'PENDING',
        -- PENDING, ISSUED, CLEARED, ON_HOLD, ESCHEAT

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX rev_alloc_well_month_idx  ON oilgas.revenue_allocation (well_id, revenue_month);
CREATE INDEX rev_alloc_owner_idx       ON oilgas.revenue_allocation (owner_id, revenue_month);
CREATE INDEX rev_alloc_status_idx      ON oilgas.revenue_allocation (status);

COMMENT ON TABLE oilgas.revenue_allocation IS
    'Monthly revenue distribution per well per interest owner. '
    'owners_net_usd = net_revenue_usd × nri_decimal. '
    'Drives royalty checks and working interest disbursements.';


-- ------------------------------------------------------------
-- 59. LOE_TRACKING
-- Lease Operating Expense tracking per well per month.
-- Feeds per-BOE operating cost analysis.
-- ------------------------------------------------------------
CREATE TABLE oilgas.loe_tracking (
    loe_id              TEXT        PRIMARY KEY,
    well_id             TEXT        NOT NULL REFERENCES oilgas.wells(well_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    expense_month       DATE        NOT NULL,

    -- Cost categories (USD)
    labor_usd           NUMERIC(12,2)  DEFAULT 0,
    chemicals_usd       NUMERIC(12,2)  DEFAULT 0,
    fuel_usd            NUMERIC(12,2)  DEFAULT 0,
    water_disposal_usd  NUMERIC(12,2)  DEFAULT 0,
    repairs_maint_usd   NUMERIC(12,2)  DEFAULT 0,
    compression_usd     NUMERIC(12,2)  DEFAULT 0,
    gathering_transport_usd NUMERIC(12,2) DEFAULT 0,
    insurance_usd       NUMERIC(12,2)  DEFAULT 0,
    ad_valorem_usd      NUMERIC(12,2)  DEFAULT 0,
    other_usd           NUMERIC(12,2)  DEFAULT 0,
    total_loe_usd       NUMERIC(14,2),

    -- Unit costs
    prod_boe            NUMERIC(12,3),
    loe_per_boe         NUMERIC(10,4)  GENERATED ALWAYS AS
                            (CASE WHEN prod_boe > 0
                             THEN total_loe_usd / prod_boe ELSE NULL END) STORED,

    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE (well_id, expense_month)
);

CREATE INDEX loe_well_month_idx ON oilgas.loe_tracking (well_id, expense_month DESC);
CREATE INDEX loe_lease_idx      ON oilgas.loe_tracking (lease_id, expense_month DESC);

COMMENT ON TABLE oilgas.loe_tracking IS
    'Monthly lease operating expense by cost category per well. '
    'loe_per_boe is a generated column. '
    'Feeds well economics and production cost benchmarking.';


-- ------------------------------------------------------------
-- 60. RESERVE_ESTIMATE
-- Proved / probable / possible reserve bookings per well per
-- commodity. Supports SEC annual reserve report (Form 10-K).
-- ------------------------------------------------------------
CREATE TABLE oilgas.reserve_estimate (
    res_id              TEXT        PRIMARY KEY,
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    reservoir_id        TEXT        REFERENCES oilgas.reservoir(reservoir_id),
    dc_id               TEXT        REFERENCES oilgas.decline_curve(dc_id),
    as_of_date          DATE        NOT NULL,
    reserve_category    TEXT        NOT NULL,
        -- 1P_PROVED_PD (proved developed producing),
        --  1P_PROVED_PUD (proved undeveloped),
        --  2P_PROBABLE, 3P_POSSIBLE
    phase               TEXT        NOT NULL CHECK (phase IN ('OIL','GAS','NGL','CONDENSATE')),
    volume_unit         TEXT,       -- BBL, MCF, BOE

    -- Volumes
    gross_reserves      NUMERIC(14,3),
    net_reserves        NUMERIC(14,3),   -- × NRI
    cumulative_prod     NUMERIC(14,3),
    eur                 NUMERIC(14,3),

    -- Economics
    npv10_usd           NUMERIC(14,2),   -- 10% discount factor (SEC standard)
    npv0_usd            NUMERIC(14,2),
    price_assumption_usd NUMERIC(10,4),
    price_date_basis    TEXT,

    -- Preparer
    prepared_by         TEXT,
    prep_company        TEXT,
    independent_engineer BOOLEAN    DEFAULT FALSE,
    prep_date           DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX reserve_well_date_idx ON oilgas.reserve_estimate (well_id, as_of_date);
CREATE INDEX reserve_category_idx  ON oilgas.reserve_estimate (reserve_category);
CREATE INDEX reserve_res_idx       ON oilgas.reserve_estimate (reservoir_id);

COMMENT ON TABLE oilgas.reserve_estimate IS
    'Annual reserve estimates per well per category (1P/2P/3P). '
    'npv10_usd uses SEC 10% discount rate. '
    'Links to decline_curve for Arps parameter traceability.';


-- ------------------------------------------------------------
-- 61. PRICE_DECK
-- Forward commodity price assumptions used in economic models.
-- Stores both flat-price and strip-price scenarios.
-- ------------------------------------------------------------
CREATE TABLE oilgas.price_deck (
    price_id            TEXT        PRIMARY KEY,
    deck_name           TEXT        NOT NULL,
    deck_type           TEXT,       -- STRIP, FLAT, SCENARIO_LOW, SCENARIO_BASE, SCENARIO_HIGH
    as_of_date          DATE        NOT NULL,
    commodity           TEXT        NOT NULL CHECK (commodity IN ('OIL','GAS','NGL','CONDENSATE')),
    effective_month     DATE        NOT NULL,   -- price month
    price_usd           NUMERIC(10,4),
    price_unit          TEXT,       -- USD/BBL, USD/MMBTU, USD/MCF
    differential        NUMERIC(8,4),
    net_price_usd       NUMERIC(10,4),
    price_index         TEXT,       -- WTI, WAHA, HENRY_HUB, LLS, MIDLAND
    inflation_rate_pct  NUMERIC(6,3),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX price_deck_name_idx      ON oilgas.price_deck (deck_name, commodity, effective_month);
CREATE INDEX price_deck_asof_idx      ON oilgas.price_deck (as_of_date DESC);

COMMENT ON TABLE oilgas.price_deck IS
    'Forward commodity price assumptions for economic evaluations and reserve reports. '
    'SEC reserve reports use 12-month average trailing price.';


-- ------------------------------------------------------------
-- 62. PERMIT_LIFECYCLE
-- Full permit application and status tracking for any permit
-- type (drilling, injection, disposal, air, water, pipeline).
-- Extends the permit_no fields scattered across wells,
-- facilities, and pipelines into a managed workflow table.
-- ------------------------------------------------------------
CREATE TABLE oilgas.permit_lifecycle (
    permit_id           TEXT        PRIMARY KEY,
    permit_type         TEXT        NOT NULL,
        -- DRILLING, INJECTION, DISPOSAL, AIR_QUALITY, WATER_DISCHARGE,
        --  PIPELINE, SURFACE_WATER, FLARING, OTHER
    permit_no           TEXT,
    regulatory_body     TEXT,       -- RRC, TCEQ, EPA, USACE, RAILROAD_COMMISSION
    well_id             TEXT        REFERENCES oilgas.wells(well_id),
    facility_id         TEXT        REFERENCES oilgas.facilities(facility_id),
    pipeline_id         TEXT        REFERENCES oilgas.pipelines(pipeline_id),
    lease_id            TEXT        REFERENCES oilgas.leaseholds(lease_id),
    opr_id              TEXT        REFERENCES oilgas.operator(opr_id),

    -- Application
    application_date    DATE,
    application_no      TEXT,
    applicant_name      TEXT,

    -- Status workflow
    permit_status       TEXT        DEFAULT 'PENDING',
        -- PENDING, UNDER_REVIEW, APPROVED, DENIED, EXPIRED,
        --  REVOKED, SUSPENDED, WITHDRAWN
    issued_date         DATE,
    effective_date      DATE,
    expiry_date         DATE,
    renewal_due_date    DATE,
    renewal_submitted   BOOLEAN     DEFAULT FALSE,

    -- Conditions
    conditions_text     TEXT,
    monitoring_required BOOLEAN     DEFAULT FALSE,
    reporting_frequency TEXT,       -- MONTHLY, QUARTERLY, ANNUAL

    -- Bonds
    bond_required       BOOLEAN     DEFAULT FALSE,
    bond_amount_usd     NUMERIC(14,2),
    bond_no             TEXT,
    surety_company      TEXT,

    -- History
    last_modified_date  DATE,
    modified_by         TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX permit_well_idx       ON oilgas.permit_lifecycle (well_id);
CREATE INDEX permit_facility_idx   ON oilgas.permit_lifecycle (facility_id);
CREATE INDEX permit_type_idx       ON oilgas.permit_lifecycle (permit_type);
CREATE INDEX permit_status_idx     ON oilgas.permit_lifecycle (permit_status);
CREATE INDEX permit_expiry_idx     ON oilgas.permit_lifecycle (expiry_date);
CREATE INDEX permit_renewal_idx    ON oilgas.permit_lifecycle (renewal_due_date)
                                   WHERE permit_status = 'APPROVED';

COMMENT ON TABLE oilgas.permit_lifecycle IS
    'Full permit application and status lifecycle for all permit types. '
    'Partial index on renewal_due_date filters to active permits only. '
    'Consolidates permit_no fields from wells, facilities, and pipelines '
    'into a managed compliance workflow.';


-- ============================================================
-- CROSS-DOMAIN VIEWS
-- ============================================================

-- Production + economics dashboard per well (monthly)
CREATE OR REPLACE VIEW oilgas.v_well_economics AS
SELECT
    pm.well_id,
    pm.prod_month,
    w.api_number,
    w.lease_name,
    l.lease_no,
    op.operator_name,
    -- Production
    pm.oil_bbl,
    pm.gas_mcf,
    pm.water_bbl,
    pm.oil_bopd,
    pm.gas_mcfd,
    pm.wor,
    pm.gor_cf_bbl,
    pm.days_on_prod,
    -- LOE
    loe.total_loe_usd,
    loe.loe_per_boe,
    -- Revenue (aggregated across phases for this well/month)
    SUM(ra.owners_net_usd)              AS net_revenue_usd,
    -- Decline curve (most recent proved)
    dc.eur                              AS proved_eur,
    dc.remaining_eur,
    dc.di_effective                     AS decline_rate,
    -- Compliance snapshot
    (SELECT COUNT(*) FROM oilgas.violations v
     WHERE v.well_id = pm.well_id
       AND v.compliant_on_reinspection IN ('--','N')) AS open_violations
FROM oilgas.production_monthly     pm
LEFT JOIN oilgas.wells             w   ON pm.well_id   = w.well_id
LEFT JOIN oilgas.leaseholds        l   ON pm.lease_id  = l.lease_id
LEFT JOIN oilgas.operator          op  ON w.opr_id     = op.opr_id
LEFT JOIN oilgas.loe_tracking      loe ON pm.well_id   = loe.well_id
                                       AND pm.prod_month = loe.expense_month
LEFT JOIN oilgas.revenue_allocation ra  ON pm.well_id   = ra.well_id
                                       AND pm.prod_month = ra.revenue_month
LEFT JOIN LATERAL (
    SELECT eur, remaining_eur, di_effective
    FROM oilgas.decline_curve
    WHERE well_id = pm.well_id
      AND phase = 'OIL'
      AND reserves_category = '1P'
    ORDER BY prep_date DESC LIMIT 1
) dc ON TRUE
GROUP BY pm.well_id, pm.prod_month, w.api_number, w.lease_name,
         l.lease_no, op.operator_name,
         pm.oil_bbl, pm.gas_mcf, pm.water_bbl, pm.oil_bopd, pm.gas_mcfd,
         pm.wor, pm.gor_cf_bbl, pm.days_on_prod,
         loe.total_loe_usd, loe.loe_per_boe,
         dc.eur, dc.remaining_eur, dc.di_effective;

COMMENT ON VIEW oilgas.v_well_economics IS
    'Monthly well economics dashboard: production + LOE + net revenue + decline curve + compliance.';


-- HSE KPI summary per lease (rolling 12 months)
CREATE OR REPLACE VIEW oilgas.v_hse_summary AS
SELECT
    l.lease_id,
    l.lease_no,
    l.lease_name,
    l.county,
    op.operator_name,
    -- Spills
    COUNT(DISTINCT si.incident_id)                          AS spill_count_12mo,
    COALESCE(SUM(si.net_loss_bbl), 0)                       AS total_spill_bbl_12mo,
    COUNT(DISTINCT CASE WHEN si.remediation_status != 'CLOSED_NO_ACTION'
                        AND si.remediation_status != 'COMPLETED'
                        THEN si.incident_id END)            AS open_spills,
    -- Safety
    COUNT(DISTINCT sa.safety_id)                            AS recordable_incidents_12mo,
    COALESCE(SUM(sa.osha_days_away), 0)                     AS days_away_12mo,
    -- Emissions
    COUNT(DISTINCT em.emis_id)                              AS ldar_surveys_12mo,
    COUNT(DISTINCT CASE WHEN em.leak_detected THEN em.emis_id END) AS leaks_found_12mo,
    COUNT(DISTINCT CASE WHEN em.leak_detected
                        AND (em.leak_repaired IS FALSE OR em.leak_repaired IS NULL)
                        THEN em.emis_id END)                AS leaks_unrepaired,
    -- Violations
    COUNT(DISTINCT v.violation_id)                          AS violations_12mo,
    COUNT(DISTINCT CASE WHEN v.compliant_on_reinspection IN ('--','N')
                        THEN v.violation_id END)            AS open_violations
FROM oilgas.leaseholds         l
LEFT JOIN oilgas.operator      op ON l.opr_id       = op.opr_id
LEFT JOIN oilgas.spill_incident si ON l.lease_id    = si.lease_id
                                  AND si.incident_date >= CURRENT_DATE - INTERVAL '12 months'
LEFT JOIN oilgas.safety_incident sa ON l.lease_id   = sa.lease_id
                                   AND sa.incident_date >= CURRENT_DATE - INTERVAL '12 months'
                                   AND sa.osha_recordable = TRUE
LEFT JOIN oilgas.emissions_monitoring em ON l.lease_id = em.lease_id
                                        AND em.monitor_date >= CURRENT_DATE - INTERVAL '12 months'
LEFT JOIN oilgas.violations    v  ON l.lease_id     = v.lease_id
                                  AND v.discovery_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY l.lease_id, l.lease_no, l.lease_name, l.county, op.operator_name;

COMMENT ON VIEW oilgas.v_hse_summary IS
    'Rolling 12-month HSE KPIs per lease: spills, safety incidents, LDAR, violations.';


-- Equipment PM overdue list
CREATE OR REPLACE VIEW oilgas.v_pm_overdue AS
SELECT
    e.equip_id,
    e.asset_tag,
    e.equipment_name,
    e.equipment_type,
    f.facility_id,
    f.facility_name,
    w.well_id,
    w.api_number,
    e.last_pm_date,
    e.next_pm_due,
    CURRENT_DATE - e.next_pm_due           AS days_overdue,
    e.pm_interval_days,
    e.equip_status
FROM oilgas.equipment e
LEFT JOIN oilgas.facilities f ON e.facility_id = f.facility_id
LEFT JOIN oilgas.wells      w ON e.well_id     = w.well_id
WHERE e.next_pm_due < CURRENT_DATE
  AND e.equip_status = 'IN_SERVICE'
ORDER BY days_overdue DESC;

COMMENT ON VIEW oilgas.v_pm_overdue IS
    'Equipment with overdue preventive maintenance, ordered by days overdue.';


-- Reserve summary by category
CREATE OR REPLACE VIEW oilgas.v_reserve_summary AS
SELECT
    re.as_of_date,
    re.reserve_category,
    re.phase,
    re.volume_unit,
    COUNT(DISTINCT re.well_id)              AS well_count,
    SUM(re.gross_reserves)                  AS gross_reserves,
    SUM(re.net_reserves)                    AS net_reserves,
    SUM(re.eur)                             AS total_eur,
    SUM(re.npv10_usd)                       AS total_npv10_usd
FROM oilgas.reserve_estimate re
GROUP BY re.as_of_date, re.reserve_category, re.phase, re.volume_unit
ORDER BY re.as_of_date DESC, re.reserve_category, re.phase;

COMMENT ON VIEW oilgas.v_reserve_summary IS
    'Aggregated reserve volumes and NPV10 by category and phase.';


-- Permit expiry watchlist (next 90 days)
CREATE OR REPLACE VIEW oilgas.v_permit_expiry AS
SELECT
    p.permit_id,
    p.permit_type,
    p.permit_no,
    p.regulatory_body,
    p.expiry_date,
    p.renewal_due_date,
    p.renewal_submitted,
    p.expiry_date - CURRENT_DATE           AS days_to_expiry,
    w.api_number,
    f.facility_name,
    l.lease_no,
    l.lease_name
FROM oilgas.permit_lifecycle   p
LEFT JOIN oilgas.wells         w ON p.well_id     = w.well_id
LEFT JOIN oilgas.facilities    f ON p.facility_id = f.facility_id
LEFT JOIN oilgas.leaseholds    l ON p.lease_id    = l.lease_id
WHERE p.permit_status = 'APPROVED'
  AND p.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY p.expiry_date;

COMMENT ON VIEW oilgas.v_permit_expiry IS
    'Permits expiring within 90 days, ordered by expiry date. '
    'renewal_submitted flag highlights which ones still need action.';
