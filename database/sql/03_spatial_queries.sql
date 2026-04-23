-- ============================================================
-- SPATIAL ANALYSIS QUERIES
-- Demonstrates PostGIS and petroleum data analysis skills
-- ============================================================

SET search_path TO oilgas, public;


-- ── QUERY 1: Well Summary with Spatial Attributes ────────────
-- Returns all wells with key production and spatial info
SELECT
    w.well_id,
    w.api_number,
    w.lease_name,
    w.county,
    w.well_status,
    w.latitude,
    w.longitude,
    ST_AsGeoJSON(w.geom)::json      AS geometry,
    gs.gas_produced_mcfd            AS ip_gas_mcfd,
    gs.siwh_pressure_psia,
    c.total_depth_tvd,
    c.comp_type
FROM oilgas.wells w
LEFT JOIN oilgas.gas_status gs ON w.well_id = gs.well_id
LEFT JOIN oilgas.completion c  ON w.well_id = c.well_id
ORDER BY gs.gas_produced_mcfd DESC NULLS LAST;


-- ── QUERY 2: Formation Depth Profile (Cross-Section Data) ────
-- Shows all encountered formation tops ordered by well and depth
SELECT
    w.lease_name,
    w.api_number,
    f.formation_name,
    f.depth_tvd_ft,
    f.depth_md_ft,
    f.is_isolated,
    f.geopressured,
    f.inj_disposal_zone,
    f.h2s_present
FROM oilgas.formations f
JOIN oilgas.wells w ON f.well_id = w.well_id
WHERE f.encountered = TRUE
ORDER BY w.well_id, f.depth_tvd_ft NULLS LAST;


-- ── QUERY 3: Wells Within 50km of Laredo (Spatial Query) ─────
-- Demonstrates PostGIS proximity analysis using NAD83
SELECT
    w.well_id,
    w.lease_name,
    w.county,
    ROUND(
        ST_Distance(
            w.geom::geography,
            ST_SetSRID(ST_MakePoint(-99.5067, 27.5064), 4269)::geography
        ) / 1000.0
    , 1) AS distance_km_from_laredo
FROM oilgas.wells w
WHERE w.geom IS NOT NULL
  AND ST_DWithin(
    w.geom::geography,
    ST_SetSRID(ST_MakePoint(-99.5067, 27.5064), 4269)::geography,
    50000  -- 50 km
  )
ORDER BY distance_km_from_laredo;


-- ── QUERY 4: Cementing Summary per Well ──────────────────────
-- How many plugs set, total cement used per well
SELECT
    w.lease_name,
    w.api_number,
    COUNT(cem.cem_id)               AS total_plugs,
    SUM(cem.sacks_cement)           AS total_cement_sacks,
    SUM(cem.slurry_volume_cu_ft)    AS total_slurry_cuft,
    MIN(cem.cibp_setting_depth_ft)  AS shallowest_plug_ft,
    MAX(cem.cibp_setting_depth_ft)  AS deepest_plug_ft
FROM oilgas.cementing cem
JOIN oilgas.wells w ON cem.well_id = w.well_id
GROUP BY w.lease_name, w.api_number
ORDER BY total_plugs DESC;


-- ── QUERY 5: Production Comparison (IP Gas vs Pressure) ──────
-- Compares initial potential gas rates with wellhead pressures
SELECT
    w.lease_name,
    w.county,
    gs.test_date,
    gs.gas_produced_mcfd            AS ip_gas_mcfd,
    gs.siwh_pressure_psia,
    gs.flowing_pressure_psia,
    ROUND(
        (gs.siwh_pressure_psia - gs.flowing_pressure_psia)
        / NULLIF(gs.siwh_pressure_psia, 0) * 100
    , 1)                            AS drawdown_pct,
    cl.choke_size,
    cl.gas_specific_gravity,
    c.total_depth_tvd,
    c.comp_type
FROM oilgas.gas_status gs
JOIN oilgas.wells       w  ON gs.well_id = w.well_id
JOIN oilgas.completion  c  ON gs.well_id = c.well_id
LEFT JOIN oilgas.classification cl ON gs.well_id = cl.well_id
WHERE gs.gas_produced_mcfd > 0
ORDER BY gs.gas_produced_mcfd DESC;


-- ── QUERY 6: Casing Integrity Summary ────────────────────────
-- All casing strings per well with cement coverage
SELECT
    w.lease_name,
    cas.string_no,
    cas.casing_type,
    cas.casing_size_in,
    cas.setting_depth_ft,
    cas.cement_class,
    cas.cement_amount_sacks,
    cas.top_of_cement_ft,
    ROUND(cas.setting_depth_ft - cas.top_of_cement_ft, 0)
                                    AS cemented_interval_ft,
    cas.toc_determined_by
FROM oilgas.casing cas
JOIN oilgas.wells w ON cas.well_id = w.well_id
ORDER BY w.lease_name, cas.string_no;


-- ── QUERY 7: Regulatory Compliance Checklist ─────────────────
-- Shows filing completeness per well across all key forms
SELECT
    w.well_id,
    w.lease_name,
    w.api_number,
    w.well_status,
    CASE WHEN COUNT(DISTINCT c.comp_id)  > 0 THEN '✓' ELSE '✗' END AS g1_completion,
    CASE WHEN COUNT(DISTINCT gm.meas_id) > 0 THEN '✓' ELSE '✗' END AS g1_gas_meas,
    CASE WHEN COUNT(DISTINCT cl.class_id)> 0 THEN '✓' ELSE '✗' END AS g5_classification,
    CASE WHEN COUNT(DISTINCT gs.stat_id) > 0 THEN '✓' ELSE '✗' END AS g10_status,
    CASE WHEN COUNT(DISTINCT pl.plug_id) > 0 THEN '✓' ELSE '✗' END AS w3_plugging,
    CASE WHEN COUNT(DISTINCT ta.auth_id) > 0 THEN '✓' ELSE '✗' END AS p4_transport,
    CASE WHEN COUNT(DISTINCT gw.gw_id)   > 0 THEN '✓' ELSE '✗' END AS gw_protection
FROM oilgas.wells w
LEFT JOIN oilgas.completion      c  ON w.well_id = c.well_id
LEFT JOIN oilgas.gas_measurement gm ON w.well_id = gm.well_id
LEFT JOIN oilgas.classification  cl ON w.well_id = cl.well_id
LEFT JOIN oilgas.gas_status      gs ON w.well_id = gs.well_id
LEFT JOIN oilgas.plugging        pl ON w.well_id = pl.well_id
LEFT JOIN oilgas.transport_auth  ta ON w.well_id = ta.well_id
LEFT JOIN oilgas.groundwater     gw ON w.well_id = gw.well_id
GROUP BY w.well_id, w.lease_name, w.api_number, w.well_status
ORDER BY w.well_id;


-- ── QUERY 8: GeoJSON Feature Collection Export ───────────────
-- Exports wells as a valid GeoJSON FeatureCollection
-- Use with: psql -t -A -f 03_spatial_queries.sql > wells.geojson
SELECT json_build_object(
    'type', 'FeatureCollection',
    'crs',  json_build_object(
                'type', 'name',
                'properties', json_build_object('name','urn:ogc:def:crs:EPSG::4269')
            ),
    'features', json_agg(
        json_build_object(
            'type',       'Feature',
            'geometry',   ST_AsGeoJSON(w.geom)::json,
            'properties', json_build_object(
                'well_id',          w.well_id,
                'api_number',       w.api_number,
                'lease_name',       w.lease_name,
                'county',           w.county,
                'well_status',      w.well_status,
                'field_name',       w.field_name,
                'total_depth_tvd',  c.total_depth_tvd,
                'ip_gas_mcfd',      gs.gas_produced_mcfd,
                'siwh_psia',        gs.siwh_pressure_psia,
                'comp_type',        c.comp_type
            )
        )
    )
)
FROM oilgas.wells w
LEFT JOIN oilgas.completion c  ON w.well_id = c.well_id
LEFT JOIN oilgas.gas_status gs ON w.well_id = gs.well_id
WHERE w.geom IS NOT NULL;
