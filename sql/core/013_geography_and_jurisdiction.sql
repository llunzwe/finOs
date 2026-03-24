-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 14: GEOGRAPHY & JURISDICTION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Hierarchical Jurisdictions, FATF Status, Timezone Management
-- Standards: ISO 3166, UN/LOCODE, FATF, IANA Timezones
-- =============================================================================

-- =============================================================================
-- JURISDICTIONS (Hierarchical)
-- =============================================================================
CREATE TABLE core.jurisdictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    official_name VARCHAR(255),
    
    -- Classification
    type VARCHAR(20) NOT NULL 
        CHECK (type IN ('country', 'state', 'province', 'city', 'economic_zone', 'free_trade_zone', 'special_administrative')),
    
    -- Hierarchy
    parent_id UUID REFERENCES core.jurisdictions(id),
    path LTREE,
    level INTEGER NOT NULL DEFAULT 1,
    
    -- ISO Standards
    iso_country_code CHAR(2) REFERENCES core.country_codes(iso_code),
    iso_subdivision_code VARCHAR(6), -- ISO 3166-2
    un_locode VARCHAR(5), -- UN/LOCODE for cities
    
    -- Regulatory
    regulatory_bodies TEXT[], -- ['RBZ', 'SEC', 'FCA']
    license_required BOOLEAN DEFAULT TRUE,
    license_types JSONB DEFAULT '[]', -- ["banking", "payments", "lending", "securities"]
    regulatory_risk_level VARCHAR(20) CHECK (regulatory_risk_level IN ('low', 'medium', 'high', 'prohibited')),
    
    -- Tax
    tax_jurisdiction_code VARCHAR(50),
    vat_gst_rate DECIMAL(5,2),
    vat_gst_name VARCHAR(50), -- 'VAT', 'GST', 'Sales Tax'
    withholding_tax_rate DECIMAL(5,2),
    tax_treaties JSONB DEFAULT '{}',
    
    -- Timezone
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC', -- IANA timezone
    utc_offset_hours INTEGER,
    observes_dst BOOLEAN DEFAULT FALSE,
    dst_start_rule VARCHAR(100),
    dst_end_rule VARCHAR(100),
    
    -- FATF/AML
    fatf_status VARCHAR(20) DEFAULT 'compliant' 
        CHECK (fatf_status IN ('compliant', 'grey_list', 'black_list')),
    fatf_listed_at TIMESTAMPTZ,
    fatf_review_date DATE,
    eu_high_risk_third_country BOOLEAN DEFAULT FALSE,
    sanctions_programs TEXT[], -- ['OFAC', 'EU', 'UN', 'HMT']
    
    -- Financial Infrastructure
    central_bank VARCHAR(100),
    currency_code CHAR(3) REFERENCES core.currencies(code),
    payment_systems TEXT[], -- ['RTGS', 'ACH', 'FPS']
    swift_country_code CHAR(2),
    
    -- Correspondent Banking Risk
    correspondent_risk_level VARCHAR(20) CHECK (correspondent_risk_level IN ('low', 'medium', 'high', 'prohibited')),
    correspondent_restrictions JSONB DEFAULT '{}',
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_jurisdiction_code UNIQUE (code, valid_from),
    CONSTRAINT chk_jurisdiction_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent CHECK (parent_id IS NULL OR parent_id != id)
);

CREATE INDEX idx_jurisdictions_type ON core.jurisdictions(type);
CREATE INDEX idx_jurisdictions_country ON core.jurisdictions(iso_country_code);
CREATE INDEX idx_jurisdictions_fatf ON core.jurisdictions(fatf_status) WHERE fatf_status != 'compliant';
CREATE INDEX idx_jurisdictions_hierarchy ON core.jurisdictions USING GIST(path);
CREATE INDEX idx_jurisdictions_parent ON core.jurisdictions(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_jurisdictions_timezone ON core.jurisdictions(timezone);
CREATE INDEX idx_jurisdictions_correlation ON core.jurisdictions(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.jurisdictions IS 'Hierarchical jurisdiction data with FATF status and regulatory info';

-- Trigger for hierarchy management
CREATE OR REPLACE FUNCTION core.update_jurisdiction_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_id IS NULL THEN
        NEW.path = NEW.id::text::ltree;
        NEW.level = 1;
    ELSE
        SELECT path || NEW.id::text::ltree, level + 1
        INTO NEW.path, NEW.level
        FROM core.jurisdictions
        WHERE id = NEW.parent_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_jurisdiction_hierarchy
    BEFORE INSERT OR UPDATE ON core.jurisdictions
    FOR EACH ROW EXECUTE FUNCTION core.update_jurisdiction_hierarchy();

-- =============================================================================
-- ADDRESSES
-- =============================================================================
CREATE TABLE core.addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Ownership (Polymorphic)
    entity_type VARCHAR(50) NOT NULL 
        CHECK (entity_type IN ('economic_agent', 'value_container', 'instrument', 'legal_entity')),
    entity_id UUID NOT NULL,
    
    -- Address Type
    address_type VARCHAR(20) NOT NULL DEFAULT 'registered' 
        CHECK (address_type IN ('registered', 'mailing', 'operating', 'billing', 'tax', 'domicile', 'branch')),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Structured Address (International Format)
    street_lines TEXT[] NOT NULL DEFAULT '{}', -- ["123 Main Street", "Suite 400"]
    city VARCHAR(100) NOT NULL,
    subdivision VARCHAR(100), -- State/Province
    subdivision_code VARCHAR(10),
    postal_code VARCHAR(20),
    postal_code_extension VARCHAR(10),
    country_code CHAR(2) NOT NULL REFERENCES core.country_codes(iso_code),
    
    -- Local Language (if different)
    local_street_lines TEXT[],
    local_city VARCHAR(100),
    local_subdivision VARCHAR(100),
    
    -- Geocoding
    latitude DECIMAL(10,8) CHECK (latitude BETWEEN -90 AND 90),
    longitude DECIMAL(11,8) CHECK (longitude BETWEEN -180 AND 180),
    geohash VARCHAR(12),
    location GEOGRAPHY(POINT),
    location_accuracy DECIMAL(10,2), -- Meters
    
    -- Plus Codes / What3Words
    plus_code VARCHAR(20),
    what3words VARCHAR(100),
    
    -- Validation
    validation_status VARCHAR(20) DEFAULT 'unvalidated' 
        CHECK (validation_status IN ('unvalidated', 'validated', 'failed', 'pending')),
    validated_by VARCHAR(50), -- 'google_maps', 'postal_service', 'manual', 'loqate'
    validated_at TIMESTAMPTZ,
    validation_reference VARCHAR(100),
    
    -- Address Standardization
    standardized_format VARCHAR(50), -- 'local', 'international', 'latin'
    standardization_confidence DECIMAL(3,2),
    
    -- Jurisdiction Link (derived)
    jurisdiction_id UUID REFERENCES core.jurisdictions(id),
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_primary_address UNIQUE (entity_type, entity_id, address_type, is_primary),
    CONSTRAINT chk_valid_lat_long CHECK (
        (latitude IS NULL AND longitude IS NULL) OR 
        (latitude IS NOT NULL AND longitude IS NOT NULL)
    )
);

-- Critical indexes
CREATE INDEX idx_addresses_entity ON core.addresses(entity_type, entity_id);
CREATE INDEX idx_addresses_country ON core.addresses(country_code);
CREATE INDEX idx_addresses_validation ON core.addresses(validation_status) WHERE validation_status != 'validated';
CREATE INDEX idx_addresses_jurisdiction ON core.addresses(jurisdiction_id);
CREATE INDEX idx_addresses_location ON core.addresses USING GIST(location) WHERE location IS NOT NULL;
CREATE INDEX idx_addresses_geohash ON core.addresses(geohash) WHERE geohash IS NOT NULL;
CREATE INDEX idx_addresses_postal ON core.addresses(postal_code, country_code);

COMMENT ON TABLE core.addresses IS 'Structured address data with geocoding and validation';

-- =============================================================================
-- TIMEZONE RULES
-- =============================================================================
CREATE TABLE core.timezone_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID REFERENCES core.jurisdictions(id),
    
    timezone VARCHAR(50) NOT NULL,
    rule_name VARCHAR(100) NOT NULL,
    
    -- Effective Period
    year INTEGER NOT NULL,
    dst_start TIMESTAMP WITH TIME ZONE,
    dst_end TIMESTAMP WITH TIME ZONE,
    utc_offset_std INTERVAL,
    utc_offset_dst INTERVAL,
    
    -- Cutoff Times (for payments)
    payment_cutoff_weekday TIME,
    payment_cutoff_friday TIME,
    payment_cutoff_weekend TIME,
    
    -- Business Days
    weekend_days INTEGER[] DEFAULT '{0,6}', -- Sunday=0, Saturday=6
    holidays UUID[], -- References to holiday calendar
    
    PRIMARY KEY (timezone, year)
);

CREATE INDEX idx_timezone_rules_jurisdiction ON core.timezone_rules(jurisdiction_id);

COMMENT ON TABLE core.timezone_rules IS 'Timezone and cutoff time rules by jurisdiction';

-- =============================================================================
-- HOLIDAY CALENDARS
-- =============================================================================
CREATE TABLE core.holiday_calendars (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    calendar_name VARCHAR(100) NOT NULL,
    calendar_type VARCHAR(50) NOT NULL CHECK (calendar_type IN ('national', 'financial', 'settlement', 'trading')),
    jurisdiction_id UUID REFERENCES core.jurisdictions(id),
    
    -- Scope
    applies_to_currencies CHAR(3)[],
    applies_to_markets VARCHAR(50)[], -- MIC codes
    
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT unique_calendar_name UNIQUE (tenant_id, calendar_name)
);

CREATE TABLE core.holidays (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    calendar_id UUID NOT NULL REFERENCES core.holiday_calendars(id) ON DELETE CASCADE,
    
    holiday_date DATE NOT NULL,
    holiday_name VARCHAR(100) NOT NULL,
    holiday_type VARCHAR(50) CHECK (holiday_type IN ('public', 'bank', 'trading', 'settlement', 'religious', 'observance')),
    
    -- Timing
    start_time TIME DEFAULT '00:00:00',
    end_time TIME DEFAULT '23:59:59',
    is_full_day BOOLEAN DEFAULT TRUE,
    
    -- Recurrence
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule VARCHAR(100), -- iCal RRULE format
    
    UNIQUE(calendar_id, holiday_date, start_time)
);

CREATE INDEX idx_holidays_calendar ON core.holidays(calendar_id, holiday_date);
CREATE INDEX idx_holidays_date ON core.holidays(holiday_date);

COMMENT ON TABLE core.holiday_calendars IS 'Holiday calendar definitions';
COMMENT ON TABLE core.holidays IS 'Individual holiday entries';

-- =============================================================================
-- GEOGRAPHIC RISK ASSESSMENT
-- =============================================================================
CREATE TABLE core.geographic_risk_assessments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    jurisdiction_id UUID NOT NULL REFERENCES core.jurisdictions(id),
    
    -- Assessment
    assessment_date DATE NOT NULL,
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high', 'prohibited')),
    risk_score DECIMAL(5,2) CHECK (risk_score BETWEEN 0 AND 100),
    
    -- Factors
    fatf_factor DECIMAL(5,2),
    corruption_factor DECIMAL(5,2), -- Transparency International CPI
    sanctions_factor DECIMAL(5,2),
    regulatory_factor DECIMAL(5,2),
    political_factor DECIMAL(5,2),
    
    -- Details
    assessment_methodology VARCHAR(100),
    assessed_by VARCHAR(100),
    next_review_date DATE,
    
    -- Constraints
    restrictions JSONB DEFAULT '{}',
    requires_enhanced_due_diligence BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_geo_risk_jurisdiction ON core.geographic_risk_assessments(jurisdiction_id, assessment_date DESC);
CREATE INDEX idx_geo_risk_level ON core.geographic_risk_assessments(tenant_id, risk_level) WHERE risk_level IN ('high', 'prohibited');

COMMENT ON TABLE core.geographic_risk_assessments IS 'Geographic risk assessments for AML';

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function: Check if date is business day
CREATE OR REPLACE FUNCTION core.is_business_day_by_jurisdiction(
    p_date DATE,
    p_jurisdiction_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_calendar_id UUID;
    v_is_weekend BOOLEAN;
    v_is_holiday BOOLEAN;
    v_weekend_days INTEGER[];
BEGIN
    -- Get calendar for jurisdiction
    SELECT id INTO v_calendar_id
    FROM core.holiday_calendars
    WHERE jurisdiction_id = p_jurisdiction_id
      AND is_active = TRUE
    ORDER BY is_default DESC
    LIMIT 1;
    
    -- Check weekend
    SELECT weekend_days INTO v_weekend_days
    FROM core.timezone_rules
    WHERE jurisdiction_id = p_jurisdiction_id
    ORDER BY year DESC
    LIMIT 1;
    
    v_is_weekend := EXTRACT(DOW FROM p_date) = ANY(COALESCE(v_weekend_days, ARRAY[0,6]));
    
    -- Check holiday
    SELECT EXISTS(
        SELECT 1 FROM core.holidays 
        WHERE calendar_id = v_calendar_id 
          AND holiday_date = p_date
          AND is_full_day = TRUE
    ) INTO v_is_holiday;
    
    RETURN NOT (v_is_weekend OR v_is_holiday);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get next business day
CREATE OR REPLACE FUNCTION core.next_business_day_by_jurisdiction(
    p_date DATE,
    p_jurisdiction_id UUID,
    p_offset INTEGER DEFAULT 1
) RETURNS DATE AS $$
DECLARE
    v_result DATE := p_date;
    v_count INTEGER := 0;
BEGIN
    WHILE v_count < p_offset LOOP
        v_result := v_result + 1;
        IF core.is_business_day_by_jurisdiction(v_result, p_jurisdiction_id) THEN
            v_count := v_count + 1;
        END IF;
    END LOOP;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.is_business_day_by_jurisdiction IS 'Checks if a date is a business day in a jurisdiction';
COMMENT ON FUNCTION core.next_business_day_by_jurisdiction IS 'Returns the nth next business day by jurisdiction';

-- Function: Get next business day (simple version)
CREATE OR REPLACE FUNCTION core.get_next_business_day(
    p_date DATE,
    p_jurisdiction_id UUID
)
RETURNS DATE AS $$
DECLARE
    v_result DATE := p_date;
BEGIN
    LOOP
        v_result := v_result + 1;
        IF core.is_business_day_by_jurisdiction(v_result, p_jurisdiction_id) THEN
            RETURN v_result;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_next_business_day IS 'Returns next business day for jurisdiction';

-- =============================================================================
-- SEED DATA
-- =============================================================================
INSERT INTO core.jurisdictions (id, code, name, type, iso_country_code, timezone, fatf_status, currency_code) VALUES
('11111111-1111-1111-1111-111111111111', 'US', 'United States', 'country', 'US', 'America/New_York', 'compliant', 'USD'),
('22222222-2222-2222-2222-222222222222', 'GB', 'United Kingdom', 'country', 'GB', 'Europe/London', 'compliant', 'GBP'),
('33333333-3333-3333-3333-333333333333', 'DE', 'Germany', 'country', 'DE', 'Europe/Berlin', 'compliant', 'EUR'),
('44444444-4444-4444-4444-444444444444', 'ZW', 'Zimbabwe', 'country', 'ZW', 'Africa/Harare', 'compliant', 'ZIG')
ON CONFLICT (code, valid_from) DO NOTHING;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.jurisdictions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.addresses TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.timezone_rules TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.holiday_calendars TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.holidays TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.geographic_risk_assessments TO finos_app;
GRANT EXECUTE ON FUNCTION core.is_business_day_by_jurisdiction TO finos_app;
GRANT EXECUTE ON FUNCTION core.next_business_day_by_jurisdiction TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_next_business_day TO finos_app;
