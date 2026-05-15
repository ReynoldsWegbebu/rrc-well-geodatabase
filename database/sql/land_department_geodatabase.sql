-- ============================================================
-- LAND DEPARTMENT GEODATABASE
-- Schema: land
-- Company: Killam Oil Company
-- Description: Upstream E&P Land Department geodatabase covering
--              leases, tracts, ownership, title, contracts, and permits
-- Author: Bismark Reynolds
-- Date: 2026
-- ============================================================

-- ============================================================
-- 1. CREATE SCHEMA
-- ============================================================
CREATE SCHEMA IF NOT EXISTS land;

-- ============================================================
-- 2. SHARED TRIGGER FUNCTION FOR GLOBALID
-- ============================================================
CREATE OR REPLACE FUNCTION land.set_globalid()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.globalid IS NULL THEN
        NEW.globalid = gen_random_uuid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3. SEQUENCES
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS land.leases_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.lease_tracts_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.prospect_areas_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.abstracts_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.surface_ownership_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.contracts_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.royalty_owners_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.ownership_interest_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.assignments_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.title_opinions_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.curative_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.check_requests_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.division_orders_objectid_seq;
CREATE SEQUENCE IF NOT EXISTS land.permits_objectid_seq;

-- ============================================================
-- SPATIAL TABLES
-- ============================================================

-- ============================================================
-- 4. LEASES
-- ============================================================
CREATE TABLE IF NOT EXISTS land.leases
(
    lease_id                text                        NOT NULL,
    lease_no                text                        NOT NULL,
    lease_name              text                        NOT NULL,
    lease_type              text                        DEFAULT 'OIL_GAS',
    lease_status            text                        DEFAULT 'ACTIVE',
    lessor                  text,
    lessee                  text,
    operator_name           text,
    county                  text                        NOT NULL,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    rrc_district            text,
    field_name              text,
    field_no                text,
    abstract_no             text,
    survey_name             text,
    section_block           text,
    legal_description       text,
    gross_acres             numeric(12,4),
    net_acres               numeric(12,4),
    working_interest        numeric(8,6),
    royalty_interest        numeric(8,6),
    net_revenue_interest    numeric(8,6),
    effective_date          date,
    expiry_date             date,
    primary_term_years      integer,
    paid_up                 boolean                     DEFAULT false,
    continuous_drilling     boolean                     DEFAULT false,
    delay_rental_amount     numeric(12,2),
    delay_rental_due_date   date,
    bonus_paid              numeric(12,2),
    recording_info          text,
    notes                   text,
    geom                    geometry(MultiPolygon,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.leases_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT leases_pkey PRIMARY KEY (lease_id),
    CONSTRAINT leases_lease_no_key UNIQUE (lease_no),
    CONSTRAINT leases_objectid_uq UNIQUE (objectid),
    CONSTRAINT leases_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.leases OWNER TO postgres;

COMMENT ON TABLE land.leases IS 'Oil and gas lease records with spatial boundary. Each lease represents a legal agreement granting rights to explore and produce hydrocarbons.';
COMMENT ON COLUMN land.leases.working_interest IS 'Working interest decimal (e.g. 0.750000 = 75%).';
COMMENT ON COLUMN land.leases.royalty_interest IS 'Landowner royalty decimal (e.g. 0.250000 = 25%).';
COMMENT ON COLUMN land.leases.net_revenue_interest IS 'NRI decimal = WI * (1 - RI).';
COMMENT ON COLUMN land.leases.geom IS 'Full lease boundary polygon. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.leases.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.leases.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS leases_geom_idx ON land.leases USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS leases_county_idx ON land.leases USING btree(county) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS leases_status_idx ON land.leases USING btree(lease_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS leases_lease_no_idx ON land.leases USING btree(lease_no) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS leases_expiry_idx ON land.leases USING btree(expiry_date) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER leases_globalid_trg
    BEFORE INSERT ON land.leases
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 5. LEASE TRACTS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.lease_tracts
(
    tract_id                text                        NOT NULL,
    lease_id                text                        NOT NULL,
    tract_no                text                        NOT NULL,
    tract_name              text,
    tract_type              text                        DEFAULT 'FEE',
    tract_status            text                        DEFAULT 'ACTIVE',
    county                  text                        NOT NULL,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    abstract_no             text,
    survey_name             text,
    section_block           text,
    legal_description       text,
    gross_acres             numeric(12,4),
    net_acres               numeric(12,4),
    working_interest        numeric(8,6),
    royalty_interest        numeric(8,6),
    net_revenue_interest    numeric(8,6),
    surface_owner           text,
    mineral_owner           text,
    depth_from_ft           numeric(10,2),
    depth_to_ft             numeric(10,2),
    formation_top           text,
    formation_base          text,
    notes                   text,
    geom                    geometry(MultiPolygon,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.lease_tracts_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT lease_tracts_pkey PRIMARY KEY (tract_id),
    CONSTRAINT lease_tracts_objectid_uq UNIQUE (objectid),
    CONSTRAINT lease_tracts_globalid_uq UNIQUE (globalid),
    CONSTRAINT lease_tracts_lease_id_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.lease_tracts OWNER TO postgres;

COMMENT ON TABLE land.lease_tracts IS 'Individual tract subdivisions within a lease. One lease may contain multiple tracts with different ownership, depth rights, and acreage.';
COMMENT ON COLUMN land.lease_tracts.tract_type IS 'FEE, MINERAL, SURFACE, ROYALTY, OVERRIDING_ROYALTY.';
COMMENT ON COLUMN land.lease_tracts.depth_from_ft IS 'Top of depth rights in feet (0 = surface).';
COMMENT ON COLUMN land.lease_tracts.depth_to_ft IS 'Base of depth rights in feet. NULL = no depth restriction.';
COMMENT ON COLUMN land.lease_tracts.geom IS 'Tract boundary polygon. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.lease_tracts.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.lease_tracts.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS lease_tracts_geom_idx ON land.lease_tracts USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS lease_tracts_lease_id_idx ON land.lease_tracts USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS lease_tracts_county_idx ON land.lease_tracts USING btree(county) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS lease_tracts_status_idx ON land.lease_tracts USING btree(tract_status) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER lease_tracts_globalid_trg
    BEFORE INSERT ON land.lease_tracts
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 6. PROSPECT AREAS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.prospect_areas
(
    prospect_id             text                        NOT NULL,
    prospect_name           text                        NOT NULL,
    prospect_status         text                        DEFAULT 'ACTIVE',
    play_type               text,
    formation_target        text,
    basin                   text,
    county                  text,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    rrc_district            text,
    total_acres             numeric(12,4),
    net_acres               numeric(12,4),
    prospect_lead           text,
    geologist               text,
    description             text,
    notes                   text,
    geom                    geometry(MultiPolygon,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.prospect_areas_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT prospect_areas_pkey PRIMARY KEY (prospect_id),
    CONSTRAINT prospect_areas_objectid_uq UNIQUE (objectid),
    CONSTRAINT prospect_areas_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.prospect_areas OWNER TO postgres;

COMMENT ON TABLE land.prospect_areas IS 'Prospect and project area polygons defining exploration or development targets.';
COMMENT ON COLUMN land.prospect_areas.geom IS 'Prospect area boundary polygon. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.prospect_areas.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.prospect_areas.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS prospect_areas_geom_idx ON land.prospect_areas USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS prospect_areas_status_idx ON land.prospect_areas USING btree(prospect_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS prospect_areas_county_idx ON land.prospect_areas USING btree(county) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER prospect_areas_globalid_trg
    BEFORE INSERT ON land.prospect_areas
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 7. ABSTRACTS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.abstracts
(
    abstract_id             text                        NOT NULL,
    abstract_no             text                        NOT NULL,
    survey_name             text,
    grantee                 text,
    county                  text                        NOT NULL,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    total_acres             numeric(12,4),
    certificate_no          text,
    file_no                 text,
    patent_date             date,
    notes                   text,
    geom                    geometry(MultiPolygon,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.abstracts_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT abstracts_pkey PRIMARY KEY (abstract_id),
    CONSTRAINT abstracts_abstract_no_key UNIQUE (abstract_no),
    CONSTRAINT abstracts_objectid_uq UNIQUE (objectid),
    CONSTRAINT abstracts_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.abstracts OWNER TO postgres;

COMMENT ON TABLE land.abstracts IS 'Texas General Land Office abstract and survey records. Abstracts define the original land grant boundaries used in legal descriptions.';
COMMENT ON COLUMN land.abstracts.geom IS 'Abstract boundary polygon. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.abstracts.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.abstracts.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS abstracts_geom_idx ON land.abstracts USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS abstracts_county_idx ON land.abstracts USING btree(county) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS abstracts_abstract_no_idx ON land.abstracts USING btree(abstract_no) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER abstracts_globalid_trg
    BEFORE INSERT ON land.abstracts
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 8. SURFACE OWNERSHIP
-- ============================================================
CREATE TABLE IF NOT EXISTS land.surface_ownership
(
    surface_id              text                        NOT NULL,
    owner_name              text                        NOT NULL,
    owner_type              text                        DEFAULT 'INDIVIDUAL',
    mailing_address         text,
    city                    text,
    state                   character(2),
    zip                     text,
    phone                   text,
    email                   text,
    county                  text                        NOT NULL,
    abstract_no             text,
    survey_name             text,
    legal_description       text,
    total_surface_acres     numeric(12,4),
    mineral_severance       boolean                     DEFAULT false,
    notes                   text,
    geom                    geometry(MultiPolygon,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.surface_ownership_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT surface_ownership_pkey PRIMARY KEY (surface_id),
    CONSTRAINT surface_ownership_objectid_uq UNIQUE (objectid),
    CONSTRAINT surface_ownership_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.surface_ownership OWNER TO postgres;

COMMENT ON TABLE land.surface_ownership IS 'Surface owner parcel records. Tracks who owns the surface rights separate from mineral rights.';
COMMENT ON COLUMN land.surface_ownership.mineral_severance IS 'TRUE if mineral rights have been severed from surface rights.';
COMMENT ON COLUMN land.surface_ownership.geom IS 'Surface parcel boundary polygon. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.surface_ownership.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.surface_ownership.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS surface_ownership_geom_idx ON land.surface_ownership USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS surface_ownership_county_idx ON land.surface_ownership USING btree(county) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS surface_ownership_owner_idx ON land.surface_ownership USING btree(owner_name) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER surface_ownership_globalid_trg
    BEFORE INSERT ON land.surface_ownership
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 9. CONTRACTS (ROW, EASEMENTS, Surface Use Agreements)
-- ============================================================
CREATE TABLE IF NOT EXISTS land.contracts
(
    contract_id             text                        NOT NULL,
    contract_no             text,
    contract_type           text                        NOT NULL,
    contract_status         text                        DEFAULT 'ACTIVE',
    counterparty            text                        NOT NULL,
    county                  text,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    description             text,
    effective_date          date,
    expiry_date             date,
    annual_payment          numeric(12,2),
    one_time_payment        numeric(12,2),
    width_ft                numeric(8,2),
    length_ft               numeric(8,2),
    recording_info          text,
    notes                   text,
    geom                    geometry(MultiLineString,4269),
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.contracts_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT contracts_pkey PRIMARY KEY (contract_id),
    CONSTRAINT contracts_objectid_uq UNIQUE (objectid),
    CONSTRAINT contracts_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.contracts OWNER TO postgres;

COMMENT ON TABLE land.contracts IS 'Surface use agreements, easements, and right-of-way contracts. contract_type: ROW, EASEMENT, SURFACE_USE, PIPELINE_CROSSING, ACCESS_ROAD.';
COMMENT ON COLUMN land.contracts.geom IS 'ROW or easement corridor line. NAD83 geographic coordinates EPSG:4269.';
COMMENT ON COLUMN land.contracts.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.contracts.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS contracts_geom_idx ON land.contracts USING gist(geom) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS contracts_type_idx ON land.contracts USING btree(contract_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS contracts_status_idx ON land.contracts USING btree(contract_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS contracts_expiry_idx ON land.contracts USING btree(expiry_date) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER contracts_globalid_trg
    BEFORE INSERT ON land.contracts
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- NON-SPATIAL TABLES
-- ============================================================

-- ============================================================
-- 10. ROYALTY OWNERS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.royalty_owners
(
    owner_id                text                        NOT NULL,
    owner_name              text                        NOT NULL,
    owner_type              text                        DEFAULT 'INDIVIDUAL',
    tax_id                  text,
    mailing_address         text,
    city                    text,
    state                   character(2),
    zip                     text,
    phone                   text,
    email                   text,
    bank_name               text,
    bank_routing            text,
    bank_account            text,
    payment_method          text                        DEFAULT 'CHECK',
    active                  boolean                     DEFAULT true,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.royalty_owners_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT royalty_owners_pkey PRIMARY KEY (owner_id),
    CONSTRAINT royalty_owners_objectid_uq UNIQUE (objectid),
    CONSTRAINT royalty_owners_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.royalty_owners OWNER TO postgres;

COMMENT ON TABLE land.royalty_owners IS 'Royalty and interest owners receiving payments. Includes mineral owners, ORRI holders, and working interest partners.';
COMMENT ON COLUMN land.royalty_owners.owner_type IS 'INDIVIDUAL, CORPORATION, TRUST, ESTATE, PARTNERSHIP.';
COMMENT ON COLUMN land.royalty_owners.payment_method IS 'CHECK, ACH, WIRE.';
COMMENT ON COLUMN land.royalty_owners.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.royalty_owners.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS royalty_owners_name_idx ON land.royalty_owners USING btree(owner_name) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS royalty_owners_active_idx ON land.royalty_owners USING btree(active) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER royalty_owners_globalid_trg
    BEFORE INSERT ON land.royalty_owners
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 11. OWNERSHIP INTEREST
-- ============================================================
CREATE TABLE IF NOT EXISTS land.ownership_interest
(
    interest_id             text                        NOT NULL,
    lease_id                text                        NOT NULL,
    tract_id                text,
    owner_id                text                        NOT NULL,
    interest_type           text                        NOT NULL,
    decimal_interest        numeric(10,8)               NOT NULL,
    effective_date          date,
    termination_date        date,
    conveyance_type         text,
    recording_info          text,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.ownership_interest_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT ownership_interest_pkey PRIMARY KEY (interest_id),
    CONSTRAINT ownership_interest_objectid_uq UNIQUE (objectid),
    CONSTRAINT ownership_interest_globalid_uq UNIQUE (globalid),
    CONSTRAINT ownership_interest_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ownership_interest_owner_fkey FOREIGN KEY (owner_id)
        REFERENCES land.royalty_owners (owner_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.ownership_interest OWNER TO postgres;

COMMENT ON TABLE land.ownership_interest IS 'Decimal interest ownership per owner per lease. interest_type: WI (Working Interest), RI (Royalty Interest), ORRI (Overriding Royalty), NPI (Net Profits Interest).';
COMMENT ON COLUMN land.ownership_interest.decimal_interest IS 'Decimal interest (e.g. 0.25000000 = 25%).';
COMMENT ON COLUMN land.ownership_interest.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.ownership_interest.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS ownership_interest_lease_idx ON land.ownership_interest USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS ownership_interest_owner_idx ON land.ownership_interest USING btree(owner_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS ownership_interest_type_idx ON land.ownership_interest USING btree(interest_type) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER ownership_interest_globalid_trg
    BEFORE INSERT ON land.ownership_interest
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 12. ASSIGNMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.assignments
(
    assignment_id           text                        NOT NULL,
    lease_id                text                        NOT NULL,
    assignment_type         text                        NOT NULL,
    assignor                text                        NOT NULL,
    assignee                text                        NOT NULL,
    assignment_date         date,
    recording_date          date,
    recording_info          text,
    instrument_no           text,
    county                  text,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    interest_assigned       numeric(10,8),
    consideration           numeric(12,2),
    description             text,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.assignments_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT assignments_pkey PRIMARY KEY (assignment_id),
    CONSTRAINT assignments_objectid_uq UNIQUE (objectid),
    CONSTRAINT assignments_globalid_uq UNIQUE (globalid),
    CONSTRAINT assignments_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.assignments OWNER TO postgres;

COMMENT ON TABLE land.assignments IS 'Lease assignment and transfer records. assignment_type: FULL, PARTIAL, FARMOUT, FARMOUT_BACK, SUBLEASE.';
COMMENT ON COLUMN land.assignments.interest_assigned IS 'Decimal interest assigned (e.g. 0.50000000 = 50%).';
COMMENT ON COLUMN land.assignments.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.assignments.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS assignments_lease_idx ON land.assignments USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS assignments_assignor_idx ON land.assignments USING btree(assignor) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS assignments_assignee_idx ON land.assignments USING btree(assignee) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS assignments_date_idx ON land.assignments USING btree(assignment_date) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER assignments_globalid_trg
    BEFORE INSERT ON land.assignments
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 13. TITLE OPINIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.title_opinions
(
    opinion_id              text                        NOT NULL,
    lease_id                text                        NOT NULL,
    opinion_type            text                        NOT NULL,
    opinion_status          text                        DEFAULT 'PENDING',
    attorney_name           text,
    law_firm                text,
    opinion_date            date,
    effective_date          date,
    county                  text,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    abstract_no             text,
    curative_required       boolean                     DEFAULT false,
    curative_complete       boolean                     DEFAULT false,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.title_opinions_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT title_opinions_pkey PRIMARY KEY (opinion_id),
    CONSTRAINT title_opinions_objectid_uq UNIQUE (objectid),
    CONSTRAINT title_opinions_globalid_uq UNIQUE (globalid),
    CONSTRAINT title_opinions_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.title_opinions OWNER TO postgres;

COMMENT ON TABLE land.title_opinions IS 'Title opinion records per lease. opinion_type: DRILLING, DIVISION_ORDER, RUNSHEET, SUPPLEMENTAL.';
COMMENT ON COLUMN land.title_opinions.opinion_status IS 'PENDING, IN_PROGRESS, COMPLETE, CURATIVE_REQUIRED.';
COMMENT ON COLUMN land.title_opinions.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.title_opinions.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS title_opinions_lease_idx ON land.title_opinions USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS title_opinions_status_idx ON land.title_opinions USING btree(opinion_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS title_opinions_date_idx ON land.title_opinions USING btree(opinion_date) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER title_opinions_globalid_trg
    BEFORE INSERT ON land.title_opinions
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 14. CURATIVE
-- ============================================================
CREATE TABLE IF NOT EXISTS land.curative
(
    curative_id             text                        NOT NULL,
    opinion_id              text,
    lease_id                text                        NOT NULL,
    curative_type           text                        NOT NULL,
    curative_status         text                        DEFAULT 'OPEN',
    description             text                        NOT NULL,
    assigned_to             text,
    priority                text                        DEFAULT 'NORMAL',
    due_date                date,
    completed_date          date,
    resolution              text,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.curative_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT curative_pkey PRIMARY KEY (curative_id),
    CONSTRAINT curative_objectid_uq UNIQUE (objectid),
    CONSTRAINT curative_globalid_uq UNIQUE (globalid),
    CONSTRAINT curative_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.curative OWNER TO postgres;

COMMENT ON TABLE land.curative IS 'Title curative action items. curative_type: MISSING_SIGNATURE, PROBATE, HEIRSHIP, GAP_IN_TITLE, MISSING_RELEASE, INCORRECT_DESCRIPTION, OTHER.';
COMMENT ON COLUMN land.curative.curative_status IS 'OPEN, IN_PROGRESS, COMPLETE, WAIVED.';
COMMENT ON COLUMN land.curative.priority IS 'LOW, NORMAL, HIGH, CRITICAL.';
COMMENT ON COLUMN land.curative.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.curative.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS curative_lease_idx ON land.curative USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS curative_status_idx ON land.curative USING btree(curative_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS curative_priority_idx ON land.curative USING btree(priority) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS curative_due_date_idx ON land.curative USING btree(due_date) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER curative_globalid_trg
    BEFORE INSERT ON land.curative
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 15. CHECK REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.check_requests
(
    check_request_id        text                        NOT NULL,
    check_no                text,
    request_date            date                        NOT NULL,
    requested_by            text                        NOT NULL,
    payable_to              text                        NOT NULL,
    payable_address         text,
    payable_city            text,
    payable_state           character(2),
    payable_zip             text,
    purpose                 text                        NOT NULL,
    lease_id                text,
    amount                  numeric(12,2)               NOT NULL,
    prospect_no             text,
    vendor                  text,
    voucher                 text,
    account                 text,
    charge_to               text,
    misc_info               text,
    approved_by             text,
    supporting_docs         boolean                     DEFAULT false,
    status                  text                        DEFAULT 'PENDING',
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.check_requests_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT check_requests_pkey PRIMARY KEY (check_request_id),
    CONSTRAINT check_requests_objectid_uq UNIQUE (objectid),
    CONSTRAINT check_requests_globalid_uq UNIQUE (globalid),
    CONSTRAINT check_requests_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE SET NULL
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.check_requests OWNER TO postgres;

COMMENT ON TABLE land.check_requests IS 'Land department check requests for recording fees, bonus payments, delay rentals, and other land expenses.';
COMMENT ON COLUMN land.check_requests.status IS 'PENDING, APPROVED, PAID, VOID.';
COMMENT ON COLUMN land.check_requests.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.check_requests.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS check_requests_date_idx ON land.check_requests USING btree(request_date) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS check_requests_status_idx ON land.check_requests USING btree(status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS check_requests_lease_idx ON land.check_requests USING btree(lease_id) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER check_requests_globalid_trg
    BEFORE INSERT ON land.check_requests
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 16. DIVISION ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.division_orders
(
    do_id                   text                        NOT NULL,
    lease_id                text                        NOT NULL,
    owner_id                text                        NOT NULL,
    well_api                text,
    do_type                 text                        DEFAULT 'OIL_GAS',
    do_status               text                        DEFAULT 'ACTIVE',
    decimal_interest        numeric(10,8)               NOT NULL,
    interest_type           text                        NOT NULL,
    effective_date          date,
    termination_date        date,
    sent_date               date,
    returned_date           date,
    signed                  boolean                     DEFAULT false,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.division_orders_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT division_orders_pkey PRIMARY KEY (do_id),
    CONSTRAINT division_orders_objectid_uq UNIQUE (objectid),
    CONSTRAINT division_orders_globalid_uq UNIQUE (globalid),
    CONSTRAINT division_orders_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT division_orders_owner_fkey FOREIGN KEY (owner_id)
        REFERENCES land.royalty_owners (owner_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.division_orders OWNER TO postgres;

COMMENT ON TABLE land.division_orders IS 'Division order records authorizing revenue distribution to interest owners. Links leases to owners with confirmed decimal interests.';
COMMENT ON COLUMN land.division_orders.decimal_interest IS 'Confirmed decimal interest for revenue distribution (e.g. 0.25000000 = 25%).';
COMMENT ON COLUMN land.division_orders.interest_type IS 'WI, RI, ORRI, NPI.';
COMMENT ON COLUMN land.division_orders.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.division_orders.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS division_orders_lease_idx ON land.division_orders USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS division_orders_owner_idx ON land.division_orders USING btree(owner_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS division_orders_status_idx ON land.division_orders USING btree(do_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS division_orders_signed_idx ON land.division_orders USING btree(signed) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER division_orders_globalid_trg
    BEFORE INSERT ON land.division_orders
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- 17. PERMITS
-- ============================================================
CREATE TABLE IF NOT EXISTS land.permits
(
    permit_id               text                        NOT NULL,
    lease_id                text,
    permit_no               text                        NOT NULL,
    permit_type             text                        NOT NULL,
    permit_status           text                        DEFAULT 'PENDING',
    regulatory_agency       text                        DEFAULT 'RRC',
    county                  text,
    state                   character(2)                DEFAULT 'TX'::bpchar,
    rrc_district            text,
    well_api                text,
    well_name               text,
    operator_name           text,
    submitted_date          date,
    approved_date           date,
    expiry_date             date,
    description             text,
    notes                   text,
    created_at              timestamp with time zone    DEFAULT now(),
    updated_at              timestamp with time zone    DEFAULT now(),
    objectid                integer                     NOT NULL DEFAULT nextval('land.permits_objectid_seq'::regclass),
    globalid                uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT permits_pkey PRIMARY KEY (permit_id),
    CONSTRAINT permits_permit_no_key UNIQUE (permit_no),
    CONSTRAINT permits_objectid_uq UNIQUE (objectid),
    CONSTRAINT permits_globalid_uq UNIQUE (globalid),
    CONSTRAINT permits_lease_fkey FOREIGN KEY (lease_id)
        REFERENCES land.leases (lease_id)
        ON UPDATE CASCADE ON DELETE SET NULL
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS land.permits OWNER TO postgres;

COMMENT ON TABLE land.permits IS 'Drilling and regulatory permit records. permit_type: DRILLING, PLUGGING, INJECTION, WATER_DISPOSAL, PIPELINE, SURFACE_DISTURBANCE.';
COMMENT ON COLUMN land.permits.permit_status IS 'PENDING, APPROVED, EXPIRED, REVOKED, CANCELLED.';
COMMENT ON COLUMN land.permits.objectid IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN land.permits.globalid IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS permits_lease_idx ON land.permits USING btree(lease_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS permits_status_idx ON land.permits USING btree(permit_status) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS permits_type_idx ON land.permits USING btree(permit_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS permits_expiry_idx ON land.permits USING btree(expiry_date) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS permits_county_idx ON land.permits USING btree(county) TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER permits_globalid_trg
    BEFORE INSERT ON land.permits
    FOR EACH ROW EXECUTE FUNCTION land.set_globalid();


-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- Active leases expiring within 90 days
CREATE OR REPLACE VIEW land.v_expiring_leases AS
SELECT
    lease_id, lease_name, lease_no, lessor, lessee,
    county, gross_acres, net_acres,
    expiry_date,
    (expiry_date - CURRENT_DATE) AS days_remaining
FROM land.leases
WHERE lease_status = 'ACTIVE'
  AND expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY expiry_date;

COMMENT ON VIEW land.v_expiring_leases IS 'Active leases expiring within 90 days. Used for lease management alerts.';

-- Division orders not yet signed
CREATE OR REPLACE VIEW land.v_unsigned_division_orders AS
SELECT
    d.do_id, d.lease_id, l.lease_name,
    r.owner_name, r.email, r.phone,
    d.interest_type, d.decimal_interest,
    d.sent_date,
    (CURRENT_DATE - d.sent_date) AS days_outstanding
FROM land.division_orders d
JOIN land.leases l ON d.lease_id = l.lease_id
JOIN land.royalty_owners r ON d.owner_id = r.owner_id
WHERE d.signed = false
  AND d.do_status = 'ACTIVE'
ORDER BY d.sent_date;

COMMENT ON VIEW land.v_unsigned_division_orders IS 'Division orders sent but not yet signed by owners.';

-- Open curative items by priority
CREATE OR REPLACE VIEW land.v_open_curative AS
SELECT
    c.curative_id, c.lease_id, l.lease_name,
    c.curative_type, c.description,
    c.priority, c.assigned_to,
    c.due_date,
    (c.due_date - CURRENT_DATE) AS days_until_due
FROM land.curative c
JOIN land.leases l ON c.lease_id = l.lease_id
WHERE c.curative_status IN ('OPEN', 'IN_PROGRESS')
ORDER BY
    CASE c.priority
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'NORMAL' THEN 3
        WHEN 'LOW' THEN 4
    END,
    c.due_date;

COMMENT ON VIEW land.v_open_curative IS 'Open and in-progress curative items sorted by priority and due date.';

-- Lease ownership summary
CREATE OR REPLACE VIEW land.v_lease_ownership AS
SELECT
    l.lease_id, l.lease_name, l.lease_no,
    l.county, l.gross_acres,
    r.owner_name,
    oi.interest_type,
    oi.decimal_interest,
    (l.gross_acres * oi.decimal_interest) AS net_acres_owned
FROM land.leases l
JOIN land.ownership_interest oi ON l.lease_id = oi.lease_id
JOIN land.royalty_owners r ON oi.owner_id = r.owner_id
ORDER BY l.lease_name, oi.interest_type;

COMMENT ON VIEW land.v_lease_ownership IS 'Full lease ownership breakdown showing all interest owners and their decimal interests per lease.';

-- ============================================================
-- END OF LAND DEPARTMENT GEODATABASE
-- ============================================================
