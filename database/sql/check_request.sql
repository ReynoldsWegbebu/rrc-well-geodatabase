-- Table: oilgas.check_requests
CREATE SEQUENCE IF NOT EXISTS oilgas.check_requests_objectid_seq;

CREATE TABLE IF NOT EXISTS oilgas.check_requests
(
    check_request_id    text                        NOT NULL,
    check_no            text,
    request_date        date                        NOT NULL,
    requested_by        text                        NOT NULL,
    payable_to          text                        NOT NULL,
    payable_address     text,
    payable_city        text,
    payable_state       character(2)                DEFAULT 'TX'::bpchar,
    payable_zip         text,
    purpose             text                        NOT NULL,
    amount              numeric(12,2)               NOT NULL,
    prospect_no         text,
    vendor              text,
    voucher             text,
    account             text,
    charge_to           text,
    misc_info           text,
    approved_by         text,
    supporting_docs     boolean                     DEFAULT false,
    status              text                        DEFAULT 'PENDING'::text,
    created_at          timestamp with time zone    DEFAULT now(),
    updated_at          timestamp with time zone    DEFAULT now(),
    objectid            integer                     NOT NULL DEFAULT nextval('oilgas.check_requests_objectid_seq'::regclass),
    globalid            uuid                        DEFAULT gen_random_uuid(),

    CONSTRAINT check_requests_pkey PRIMARY KEY (check_request_id),
    CONSTRAINT check_requests_objectid_uq UNIQUE (objectid),
    CONSTRAINT check_requests_globalid_uq UNIQUE (globalid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS oilgas.check_requests
    OWNER TO postgres;

-- Comments
COMMENT ON TABLE oilgas.check_requests
    IS 'Check request records for vendor payments, recording fees, and land department expenses.';
COMMENT ON COLUMN oilgas.check_requests.check_request_id
    IS 'Unique internal ID for each check request (e.g. CR-2014-001).';
COMMENT ON COLUMN oilgas.check_requests.objectid
    IS 'ArcGIS Pro ObjectID.';
COMMENT ON COLUMN oilgas.check_requests.globalid
    IS 'ArcGIS GlobalID.';

-- Indexes
CREATE INDEX IF NOT EXISTS check_requests_date_idx
    ON oilgas.check_requests USING btree (request_date ASC NULLS LAST)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS check_requests_requested_by_idx
    ON oilgas.check_requests USING btree (requested_by ASC NULLS LAST)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS check_requests_status_idx
    ON oilgas.check_requests USING btree (status ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger
CREATE OR REPLACE TRIGGER check_requests_globalid_trg
    BEFORE INSERT
    ON oilgas.check_requests
    FOR EACH ROW
    EXECUTE FUNCTION oilgas.set_globalid();
