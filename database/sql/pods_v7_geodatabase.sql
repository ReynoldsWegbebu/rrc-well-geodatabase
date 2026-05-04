-- =============================================================================
-- PODS (Pipeline Open Data Standard) v7 - PostgreSQL/PostGIS Geodatabase
-- Generated from PODS Conceptual Model 7 Diagram
-- Requires: PostgreSQL 13+ with PostGIS 3.x extension
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- SCHEMA ORGANIZATION
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS pods;
SET search_path TO pods, public;

-- =============================================================================
-- SECTION 1: ABSTRACT / SHARED TABLES
-- These are referenced throughout the model
-- =============================================================================

-- Abstract Feature (base for all spatial features)
CREATE TABLE abstract_feature (
    feature_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_type        VARCHAR(100),
    created_date        TIMESTAMP,
    created_user        VARCHAR(100),
    last_edited_date    TIMESTAMP,
    last_edited_user    VARCHAR(100)
);

-- Abstract Network Feature (base for network elements)
CREATE TABLE abstract_network_feature (
    feature_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network_feature_type VARCHAR(100),
    created_date        TIMESTAMP,
    created_user        VARCHAR(100),
    last_edited_date    TIMESTAMP,
    last_edited_user    VARCHAR(100)
);

-- =============================================================================
-- SECTION 2: PIPELINE HIERARCHY
-- =============================================================================

-- Asset (top-level abstract)
CREATE TABLE asset (
    asset_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_type          VARCHAR(100),
    asset_name          VARCHAR(255),
    asset_status        VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipeline
CREATE TABLE pipeline (
    pipeline_id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_name               VARCHAR(255) NOT NULL,
    pipeline_type               VARCHAR(100),
    pipeline_status             VARCHAR(50),
    pipeline_product            VARCHAR(100),
    nominal_diameter_m          NUMERIC(10,4),
    max_allowable_op_pressure   NUMERIC(10,4),
    operator_name               VARCHAR(255),
    regulatory_identifier       VARCHAR(100),
    state_code                  VARCHAR(10),
    county                      VARCHAR(100),
    created_date                TIMESTAMP,
    last_edited_date            TIMESTAMP
);

-- Pipeline Company
CREATE TABLE pipeline_company (
    company_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name        VARCHAR(255) NOT NULL,
    company_type        VARCHAR(100),
    address             VARCHAR(500),
    phone               VARCHAR(50),
    email               VARCHAR(255),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipeline Product
CREATE TABLE pipeline_product (
    product_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    product_name        VARCHAR(255),
    product_type        VARCHAR(100),
    product_code        VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipeline Location (inline location along pipeline)
CREATE TABLE pipeline_inline_location (
    location_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    location_name       VARCHAR(255),
    station             NUMERIC(12,4),
    offset_dist         NUMERIC(12,4),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Site
CREATE TABLE site (
    site_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    site_name           VARCHAR(255),
    site_type           VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Site Containment
CREATE TABLE site_containment (
    containment_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id             UUID REFERENCES site(site_id),
    containment_type    VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Site Boundary (polygon)
CREATE TABLE site_boundary (
    boundary_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    site_id             UUID REFERENCES site(site_id),
    boundary_name       VARCHAR(255),
    geom                GEOMETRY(POLYGON, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Network Polyline (pipeline route as line geometry)
CREATE TABLE network_polyline (
    polyline_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    polyline_name       VARCHAR(255),
    from_measure        NUMERIC(12,4),
    to_measure          NUMERIC(12,4),
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Network Point (point on network)
CREATE TABLE network_point (
    point_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    point_name          VARCHAR(255),
    measure             NUMERIC(12,4),
    geom                GEOMETRY(POINT, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 3: LINEAR REFERENCING (APR)
-- =============================================================================

-- Centerline
CREATE TABLE centerline (
    centerline_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    centerline_name     VARCHAR(255),
    from_date           DATE,
    to_date             DATE,
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Centerline Sequence
CREATE TABLE centerline_sequence (
    sequence_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    centerline_id       UUID REFERENCES centerline(centerline_id),
    sequence_order      INTEGER,
    network_id          UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Route
CREATE TABLE route (
    route_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    route_name          VARCHAR(255),
    route_identifier    VARCHAR(100),
    from_date           DATE,
    to_date             DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Calibration Point
CREATE TABLE calibration_point (
    cal_point_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id            UUID REFERENCES route(route_id),
    measure             NUMERIC(12,4),
    description         VARCHAR(500),
    geom                GEOMETRY(POINT, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Engineering Station Network
CREATE TABLE engineering_sta_network (
    network_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    network_name        VARCHAR(255),
    network_id_code     VARCHAR(100),
    from_date           DATE,
    to_date             DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Contractor Area Network
CREATE TABLE contractor_area_network (
    contractor_network_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    network_name        VARCHAR(255),
    contractor_name     VARCHAR(255),
    from_date           DATE,
    to_date             DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 4: ASSETS - POLYLINE FEATURES
-- =============================================================================

-- Assets Polyline (base)
CREATE TABLE assets_polyline (
    asset_polyline_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    feature_type        VARCHAR(100),
    from_measure        NUMERIC(12,4),
    to_measure          NUMERIC(12,4),
    from_date           DATE,
    to_date             DATE,
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Casing
CREATE TABLE casing (
    casing_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_polyline_id   UUID REFERENCES assets_polyline(asset_polyline_id),
    casing_name         VARCHAR(255),
    casing_type         VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    wall_thickness_m    NUMERIC(10,6),
    material            VARCHAR(100),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Coating
CREATE TABLE coating (
    coating_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_polyline_id   UUID REFERENCES assets_polyline(asset_polyline_id),
    coating_company     VARCHAR(255),
    coating_type        VARCHAR(100),
    coating_layer       VARCHAR(100),
    applied_date        DATE,
    thickness_m         NUMERIC(10,6),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipe Lengths
CREATE TABLE pipe_lengths (
    pipe_length_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_polyline_id   UUID REFERENCES assets_polyline(asset_polyline_id),
    nominal_diameter_m  NUMERIC(10,4),
    wall_thickness_m    NUMERIC(10,6),
    material            VARCHAR(100),
    grade               VARCHAR(100),
    smys                NUMERIC(10,4),  -- Specified Minimum Yield Strength
    seam_type           VARCHAR(100),
    manufacturer        VARCHAR(255),
    heat_number         VARCHAR(100),
    length_m            NUMERIC(12,4),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipe Segment
CREATE TABLE pipe_segment (
    segment_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_polyline_id   UUID REFERENCES assets_polyline(asset_polyline_id),
    segment_type        VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    wall_thickness_m    NUMERIC(10,6),
    material            VARCHAR(100),
    grade               VARCHAR(100),
    smys                NUMERIC(10,4),
    max_op_pressure     NUMERIC(10,4),
    design_factor       NUMERIC(6,4),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 5: ASSETS - POINT FEATURES
-- =============================================================================

-- Assets Point (base)
CREATE TABLE assets_point (
    asset_point_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    feature_type        VARCHAR(100),
    measure             NUMERIC(12,4),
    from_date           DATE,
    to_date             DATE,
    geom                GEOMETRY(POINT, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Launcher Receiver
CREATE TABLE launcher_receiver (
    launcher_receiver_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    launcher_type       VARCHAR(100),  -- LAUNCHER or RECEIVER
    nominal_diameter_m  NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    model               VARCHAR(100),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Valve
CREATE TABLE valve (
    valve_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    valve_type          VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    model               VARCHAR(100),
    actuator_type       VARCHAR(100),
    normal_position     VARCHAR(50),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Branch Connect
CREATE TABLE branch_connect (
    branch_connect_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    branch_connect_type VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    connected_pipeline_id UUID REFERENCES pipeline(pipeline_id),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Tee
CREATE TABLE tee (
    tee_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    tee_type            VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    branch_diameter_m   NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Reducer
CREATE TABLE reducer (
    reducer_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    inlet_diameter_m    NUMERIC(10,4),
    outlet_diameter_m   NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Elbow
CREATE TABLE elbow (
    elbow_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    elbow_type          VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    angle_deg           NUMERIC(6,2),
    manufacturer        VARCHAR(255),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Earth Whip (anode/cathodic protection)
CREATE TABLE earth_whip (
    earth_whip_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    whip_type           VARCHAR(100),
    material            VARCHAR(100),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Vent
CREATE TABLE vent (
    vent_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    vent_type           VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Meter
CREATE TABLE meter (
    meter_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    meter_type          VARCHAR(100),
    meter_size          NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    serial_number       VARCHAR(100),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Flange
CREATE TABLE flange (
    flange_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    flange_type         VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    pressure_class      VARCHAR(50),
    material            VARCHAR(100),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipe Bend
CREATE TABLE pipe_bend (
    bend_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    bend_type           VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    bend_angle_deg      NUMERIC(6,2),
    bend_radius_m       NUMERIC(10,4),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Misc Fittings
CREATE TABLE misc_fittings (
    fitting_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    fitting_type        VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Customs (custom point features)
CREATE TABLE custom (
    custom_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    custom_type         VARCHAR(100),
    description         VARCHAR(500),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Mechanical Joint
CREATE TABLE mechanical_joint (
    joint_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    joint_type          VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    manufacturer        VARCHAR(255),
    installation_date   DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Repair Device
CREATE TABLE repair_device (
    repair_device_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_point_id      UUID REFERENCES assets_point(asset_point_id),
    cl_date             DATE,
    cl_type             VARCHAR(100),
    s_begins_to_ppl     NUMERIC(10,4),
    cl_device_manufacturer VARCHAR(255),
    cl_device_material  VARCHAR(100),
    cl_device_type      VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Repair Sleeve
CREATE TABLE repair_sleeve (
    repair_sleeve_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_polyline_id   UUID REFERENCES assets_polyline(asset_polyline_id),
    cl_type             VARCHAR(100),
    sleeve_length_m     NUMERIC(10,4),
    cl_begins_to_ppl    NUMERIC(10,4),
    cl_device_manufacturer VARCHAR(255),
    cl_device_material  VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 6: LOCATIONS
-- =============================================================================

-- Locations Point
CREATE TABLE locations_point (
    loc_point_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    network_point_id    UUID REFERENCES network_point(point_id),
    location_type       VARCHAR(100),
    measure             NUMERIC(12,4),
    geom                GEOMETRY(POINT, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Marker
CREATE TABLE marker (
    marker_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loc_point_id        UUID REFERENCES locations_point(loc_point_id),
    marker_install_date DATE,
    marker_type         VARCHAR(100),
    marker_number       VARCHAR(100),
    survey_coord_1      NUMERIC(14,8),
    survey_coord_2      NUMERIC(14,8),
    survey_crs_unit_1   VARCHAR(50),
    survey_crs_unit_2   VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Crossing Transportation
CREATE TABLE crossing_transportation (
    crossing_trans_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loc_point_id        UUID REFERENCES locations_point(loc_point_id),
    h_heavy_area_rd     VARCHAR(100),
    h_petroleum_road    VARCHAR(100),
    h_public_road       VARCHAR(100),
    b_railroad_road     VARCHAR(100),
    survey_coord_1      NUMERIC(14,8),
    survey_coord_2      NUMERIC(14,8),
    survey_crs_unit_1   VARCHAR(50),
    survey_crs_unit_2   VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Crossing Pipeline
CREATE TABLE crossing_pipeline (
    crossing_pipeline_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loc_point_id        UUID REFERENCES locations_point(loc_point_id),
    crossing_type       VARCHAR(100),
    nominal_diameter_m  NUMERIC(10,4),
    pipeline_type       VARCHAR(100),
    survey_coord_1      NUMERIC(14,8),
    survey_coord_2      NUMERIC(14,8),
    survey_crs_unit_1   VARCHAR(50),
    survey_crs_unit_2   VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Crossing Hydrology
CREATE TABLE crossing_hydrology (
    crossing_hydro_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loc_point_id        UUID REFERENCES locations_point(loc_point_id),
    hydrology_type      VARCHAR(100),
    body_name           VARCHAR(255),
    survey_coord_1      NUMERIC(14,8),
    survey_coord_2      NUMERIC(14,8),
    survey_crs_unit_1   VARCHAR(50),
    survey_crs_unit_2   VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Crossing Utility
CREATE TABLE crossing_utility (
    crossing_utility_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loc_point_id        UUID REFERENCES locations_point(loc_point_id),
    utility_type        VARCHAR(100),
    utility_owner       VARCHAR(255),
    survey_coord_1      NUMERIC(14,8),
    survey_coord_2      NUMERIC(14,8),
    survey_crs_unit_1   VARCHAR(50),
    survey_crs_unit_2   VARCHAR(50),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 7: OPERATIONS
-- =============================================================================

-- Operations Polyline
CREATE TABLE operations_polyline (
    ops_polyline_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    network_polyline_id UUID REFERENCES network_polyline(polyline_id),
    feature_type        VARCHAR(100),
    from_measure        NUMERIC(12,4),
    to_measure          NUMERIC(12,4),
    from_date           DATE,
    to_date             DATE,
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Class Location
CREATE TABLE class_location (
    class_loc_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    class_number        INTEGER,
    determination_date  DATE,
    determination_authority VARCHAR(255),
    determination_method VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Consequence Document
CREATE TABLE consequence_document (
    consequence_doc_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    determination_date  DATE,
    determination_authority VARCHAR(255),
    determination_method VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipe Jurisdiction
CREATE TABLE pipe_jurisdiction (
    jurisdiction_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    country             VARCHAR(100),
    state_code          VARCHAR(10),
    county              VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Pipe Operating Condition
CREATE TABLE pipe_operating_condition (
    op_condition_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    p_above_meter       NUMERIC(10,4),
    determination_date  DATE,
    determination_authority VARCHAR(255),
    determination_method VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Operation Pressure (test pressures)
CREATE TABLE operation_pressure (
    op_pressure_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    test_pressure_at_max NUMERIC(10,4),
    test_date           DATE,
    test_medium         VARCHAR(100),
    test_duration_hrs   NUMERIC(8,2),
    test_pressure_duration NUMERIC(10,4),
    pressure_group      VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Test Pressure (point)
CREATE TABLE test_pressure (
    test_pressure_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ops_polyline_id     UUID REFERENCES operations_polyline(ops_polyline_id),
    test_pressure_at_max_elevation NUMERIC(10,4),
    test_pressure_at_min_elevation NUMERIC(10,4),
    test_pressure_at_mid_elevation NUMERIC(10,4),
    test_date           DATE,
    test_medium         VARCHAR(100),
    test_duration_hrs   NUMERIC(8,2),
    test_pressure_duration NUMERIC(10,4),
    pressure_group      VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 8: CONDITIONS
-- =============================================================================

-- Conditions Point or Polyline (base)
CREATE TABLE conditions_feature (
    condition_feature_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    network_id          UUID,  -- references network_point or network_polyline
    feature_geom_type   VARCHAR(20),  -- POINT or POLYLINE
    from_date           DATE,
    to_date             DATE,
    geom                GEOMETRY(GEOMETRY, 4326),  -- accepts point or line
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Exposure Span
CREATE TABLE exposure_span (
    exposure_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condition_feature_id UUID REFERENCES conditions_feature(condition_feature_id),
    exposure_type       VARCHAR(100),
    span_length_m       NUMERIC(10,4),
    span_height_m       NUMERIC(10,4),
    span_location_offset NUMERIC(10,4),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Inspection Range
CREATE TABLE inspection_range (
    range_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condition_feature_id UUID REFERENCES conditions_feature(condition_feature_id),
    inspection_begin_date DATE,
    inspection_end_date DATE,
    inspection_type     VARCHAR(100),
    inspection_range_type VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Elevation Point
CREATE TABLE elevation_point (
    elevation_point_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condition_feature_id UUID REFERENCES conditions_feature(condition_feature_id),
    depth_of_cover      NUMERIC(10,4),
    water_depth         NUMERIC(10,4),
    elevation_method    VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Inspection Point
CREATE TABLE inspection_point (
    insp_point_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condition_feature_id UUID REFERENCES conditions_feature(condition_feature_id),
    inspection_date     DATE,
    inspection_type     VARCHAR(100),
    inspection_method   VARCHAR(100),
    inspection_growth   NUMERIC(10,4),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Inspection Log Cross Ref
CREATE TABLE inspection_loc_cross_ref (
    cross_ref_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    insp_point_id       UUID REFERENCES inspection_point(insp_point_id),
    inspection_table_name VARCHAR(100),
    inspection_table_id UUID,
    inspection_point_id UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 9: INLINE INSPECTION (ILI)
-- =============================================================================

-- ILI Inspection (inline inspection run)
CREATE TABLE ili_inspection (
    ili_inspection_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    inspection_run_date DATE,
    tool_type           VARCHAR(100),
    tool_manufacturer   VARCHAR(255),
    tool_speed_mps      NUMERIC(8,4),
    collection_company  VARCHAR(255),
    analysis_company    VARCHAR(255),
    report_number       VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- ILI Data (inspection results per feature)
CREATE TABLE ili_data (
    ili_data_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ili_inspection_id   UUID REFERENCES ili_inspection(ili_inspection_id),
    pipeline_feature_id UUID REFERENCES network_polyline(polyline_id),
    -- AL data
    acdc_rof_class      VARCHAR(100),
    acdc_depth_pct      NUMERIC(6,2),
    acdc_length_m       NUMERIC(10,4),
    acdc_width_m        NUMERIC(10,4),
    -- Geometry
    bends_angle_deg     NUMERIC(8,4),
    bends_effective_area NUMERIC(12,4),
    -- Dents
    dents_depth_pct     NUMERIC(6,2),
    -- Corrosion
    corrosion_depth_pct NUMERIC(6,2),
    corrosion_length_m  NUMERIC(10,4),
    corrosion_width_m   NUMERIC(10,4),
    -- Crack
    crack_depth_pct     NUMERIC(6,2),
    crack_length_m      NUMERIC(10,4),
    -- Wall thickness
    wt_measured_m       NUMERIC(10,6),
    wt_nominal_m        NUMERIC(10,6),
    -- Identification
    feature_id_code     VARCHAR(100),
    clock_position      VARCHAR(10),
    orientation         NUMERIC(6,2),
    measure             NUMERIC(12,4),
    -- Geom
    geom                GEOMETRY(POINT, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- ILI Inspection Polyline (run extent)
CREATE TABLE ili_inspection_polyline (
    ili_polyline_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ili_inspection_id   UUID REFERENCES ili_inspection(ili_inspection_id),
    network_polyline_id UUID REFERENCES network_polyline(polyline_id),
    from_measure        NUMERIC(12,4),
    to_measure          NUMERIC(12,4),
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 10: DOCUMENTS & ACTIVITIES
-- =============================================================================

-- Document
CREATE TABLE document (
    document_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_type       VARCHAR(100),
    document_number     VARCHAR(100),
    document_name       VARCHAR(255),
    document_date       DATE,
    full_path_type      VARCHAR(100),
    url                 VARCHAR(1000),
    table_record_identifier UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Document Cross Ref
CREATE TABLE document_cross_ref (
    cross_ref_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id         UUID REFERENCES document(document_id),
    related_table_name  VARCHAR(100),
    related_record_id   UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Document Range
CREATE TABLE document_range (
    doc_range_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id         UUID REFERENCES document(document_id),
    pipeline_id         UUID REFERENCES pipeline(pipeline_id),
    from_measure        NUMERIC(12,4),
    to_measure          NUMERIC(12,4),
    geom                GEOMETRY(LINESTRING, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Note (freeform note attachment)
CREATE TABLE note (
    note_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    note_type           VARCHAR(100),
    note_text           TEXT,
    note_date           DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Note Point / Polyline / Polygon
CREATE TABLE document_point_polyline_polygon (
    doc_geom_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id         UUID REFERENCES document(document_id),
    geom_type           VARCHAR(20),
    geom                GEOMETRY(GEOMETRY, 4326),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Activity
CREATE TABLE activity (
    activity_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_type       VARCHAR(100),
    activity_date       DATE,
    expiry_date         DATE,
    activity_status     VARCHAR(50),
    activity_summary    TEXT,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Activity Cross Ref
CREATE TABLE activity_cross_ref (
    cross_ref_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id         UUID REFERENCES activity(activity_id),
    related_table_name  VARCHAR(100),
    related_record_id   UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Repair
CREATE TABLE repair (
    repair_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id         UUID REFERENCES activity(activity_id),
    repair_type         VARCHAR(100),
    repair_date         DATE,
    repair_table_name   VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Physical Inspection
CREATE TABLE physical_inspection (
    phys_insp_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id         UUID REFERENCES activity(activity_id),
    inspection_date     DATE,
    inspection_type     VARCHAR(100),
    inspector_name      VARCHAR(255),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Repair Cross Asset
CREATE TABLE repair_cross_asset (
    rca_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    repair_id           UUID REFERENCES repair(repair_id),
    repair_table_name   VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Comment
CREATE TABLE comment (
    comment_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    related_table_name  VARCHAR(100),
    related_record_id   UUID,
    comment_text        TEXT,
    comment_date        DATE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 11: METADATA TABLES
-- =============================================================================

-- Layer Metadata
CREATE TABLE layer_metadata (
    layer_metadata_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    layer_name          VARCHAR(255),
    layer_alias         VARCHAR(255),
    attribute_lookup_key VARCHAR(100),
    attribute_global_name VARCHAR(255),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Field Metadata
CREATE TABLE field_metadata (
    field_metadata_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    layer_metadata_id   UUID REFERENCES layer_metadata(layer_metadata_id),
    table_metadata_id   UUID,
    field_name          VARCHAR(255),
    field_alias         VARCHAR(255),
    field_geometry_type VARCHAR(50),
    field_type          VARCHAR(50),
    table_name          VARCHAR(255),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Module Metadata
CREATE TABLE module_metadata (
    module_metadata_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_name         VARCHAR(255),
    module_alias        VARCHAR(255),
    attribute_lookup_key VARCHAR(100),
    attribute_global_name VARCHAR(255),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Attribute Metadata
CREATE TABLE attribute_metadata (
    attribute_metadata_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_metadata_id  UUID REFERENCES module_metadata(module_metadata_id),
    attribute_name      VARCHAR(255),
    attribute_alias     VARCHAR(255),
    attribute_global_name VARCHAR(255),
    attribute_lookup_key VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Network Metadata Domain
CREATE TABLE network_metadata_domain (
    network_domain_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network_id          UUID,
    network_general_name VARCHAR(255),
    network_lookup_key  VARCHAR(100),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Table Metadata
CREATE TABLE table_metadata (
    table_metadata_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name          VARCHAR(255) NOT NULL,
    table_alias         VARCHAR(255),
    table_geometry_type VARCHAR(50),
    table_metadata_id_2 UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Table Metadata Cross Ref
CREATE TABLE table_metadata_cross_ref (
    cross_ref_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_metadata_id   UUID REFERENCES table_metadata(table_metadata_id),
    related_table_name  VARCHAR(100),
    related_record_id   UUID,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Item Lookup Value
CREATE TABLE item_lookup_value (
    lookup_value_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lookup_key          VARCHAR(100),
    lookup_value        VARCHAR(255),
    display_order       INTEGER,
    is_active           BOOLEAN DEFAULT TRUE,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Reference Name
CREATE TABLE reference_name (
    reference_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_type      VARCHAR(100),
    reference_name      VARCHAR(255),
    reference_value     VARCHAR(500),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Business Rule
CREATE TABLE business_rule (
    rule_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_name           VARCHAR(255),
    rule_description    TEXT,
    rule_table          VARCHAR(255),
    rule_field          VARCHAR(255),
    pods_condition      TEXT,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- Unit of Measure
CREATE TABLE unit_of_measure (
    uom_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uom_name            VARCHAR(100),
    uom_abbreviation    VARCHAR(20),
    uom_type            VARCHAR(50),  -- LENGTH, PRESSURE, VOLUME, etc.
    conversion_factor   NUMERIC(20,10),
    base_unit           VARCHAR(20),
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- PODS Version
CREATE TABLE pods_version (
    version_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version_number      VARCHAR(20),
    version_date        DATE,
    description         TEXT,
    created_date        TIMESTAMP,
    last_edited_date    TIMESTAMP
);

-- =============================================================================
-- SECTION 12: SPATIAL INDEXES
-- =============================================================================

CREATE INDEX idx_network_polyline_geom       ON network_polyline       USING GIST(geom);
CREATE INDEX idx_network_point_geom          ON network_point          USING GIST(geom);
CREATE INDEX idx_site_boundary_geom          ON site_boundary          USING GIST(geom);
CREATE INDEX idx_centerline_geom             ON centerline             USING GIST(geom);
CREATE INDEX idx_calibration_point_geom      ON calibration_point      USING GIST(geom);
CREATE INDEX idx_assets_polyline_geom        ON assets_polyline        USING GIST(geom);
CREATE INDEX idx_assets_point_geom           ON assets_point           USING GIST(geom);
CREATE INDEX idx_locations_point_geom        ON locations_point        USING GIST(geom);
CREATE INDEX idx_operations_polyline_geom    ON operations_polyline    USING GIST(geom);
CREATE INDEX idx_conditions_feature_geom     ON conditions_feature     USING GIST(geom);
CREATE INDEX idx_ili_data_geom               ON ili_data               USING GIST(geom);
CREATE INDEX idx_ili_inspection_polyline_geom ON ili_inspection_polyline USING GIST(geom);
CREATE INDEX idx_doc_range_geom              ON document_range         USING GIST(geom);
CREATE INDEX idx_doc_geom_geom               ON document_point_polyline_polygon USING GIST(geom);

-- =============================================================================
-- SECTION 13: STANDARD BTREE INDEXES ON FOREIGN KEYS
-- =============================================================================

CREATE INDEX idx_pipeline_product_pipeline   ON pipeline_product(pipeline_id);
CREATE INDEX idx_network_polyline_pipeline   ON network_polyline(pipeline_id);
CREATE INDEX idx_network_point_pipeline      ON network_point(pipeline_id);
CREATE INDEX idx_assets_polyline_pipeline    ON assets_polyline(pipeline_id);
CREATE INDEX idx_assets_point_pipeline       ON assets_point(pipeline_id);
CREATE INDEX idx_operations_polyline_pipeline ON operations_polyline(pipeline_id);
CREATE INDEX idx_conditions_feature_pipeline ON conditions_feature(pipeline_id);
CREATE INDEX idx_ili_inspection_pipeline     ON ili_inspection(pipeline_id);
CREATE INDEX idx_document_cross_ref_doc      ON document_cross_ref(document_id);
CREATE INDEX idx_activity_cross_ref_act      ON activity_cross_ref(activity_id);
CREATE INDEX idx_inspection_point_cond       ON inspection_point(condition_feature_id);
CREATE INDEX idx_ili_data_inspection         ON ili_data(ili_inspection_id);

-- =============================================================================
-- SECTION 14: SEED DATA - Units of Measure
-- =============================================================================

INSERT INTO unit_of_measure (uom_name, uom_abbreviation, uom_type, conversion_factor, base_unit) VALUES
('Meter',           'm',    'LENGTH',   1.0,        'm'),
('Kilometer',       'km',   'LENGTH',   1000.0,     'm'),
('Foot',            'ft',   'LENGTH',   0.3048,     'm'),
('Mile',            'mi',   'LENGTH',   1609.344,   'm'),
('Inch',            'in',   'LENGTH',   0.0254,     'm'),
('Millimeter',      'mm',   'LENGTH',   0.001,      'm'),
('Pascal',          'Pa',   'PRESSURE', 1.0,        'Pa'),
('Kilopascal',      'kPa',  'PRESSURE', 1000.0,     'Pa'),
('Megapascal',      'MPa',  'PRESSURE', 1000000.0,  'Pa'),
('Bar',             'bar',  'PRESSURE', 100000.0,   'Pa'),
('PSI',             'psi',  'PRESSURE', 6894.757,   'Pa'),
('Cubic Meter',     'm3',   'VOLUME',   1.0,        'm3'),
('Liter',           'L',    'VOLUME',   0.001,      'm3'),
('Gallon (US)',     'gal',  'VOLUME',   0.003785,   'm3'),
('Barrel (Oil)',    'bbl',  'VOLUME',   0.158987,   'm3');

-- =============================================================================
-- SECTION 15: PODS VERSION
-- =============================================================================

INSERT INTO pods_version (version_number, version_date, description)
VALUES ('7.0', '2023-01-01', 'PODS Pipeline Open Data Standard Version 7');

-- =============================================================================
-- END OF PODS v7 GEODATABASE SCRIPT
-- =============================================================================

-- Usage notes:
-- 1. Run as a superuser or user with CREATE EXTENSION privilege.
-- 2. All geometry columns use EPSG:4326 (WGS84). Adjust SRID as needed for your project.
-- 3. Measures (stationing) are stored in meters by default. Adjust per your pipeline convention.
-- 4. UUID primary keys are auto-generated. Alternatively, use SERIAL/BIGSERIAL for integer PKs.
-- 5. To verify PostGIS installation: SELECT PostGIS_Full_Version();
