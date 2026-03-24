-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 2: VALUE CONTAINER
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: TimescaleDB, LTREE Hierarchy, Bitemporal, Encryption, Partitioning
-- Standards: IFRS Conceptual Framework, ISO 4217
-- =============================================================================

-- =============================================================================
-- CURRENCIES (ISO 4217 Standard)
-- =============================================================================
CREATE TABLE core.currencies (
    code CHAR(3) PRIMARY KEY,
    numeric_code INTEGER UNIQUE,
    
    -- Naming
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10),
    
    -- Mathematical Properties
    decimal_places INTEGER NOT NULL DEFAULT 2 CHECK (decimal_places BETWEEN 0 AND 18),
    rounding_mode VARCHAR(20) DEFAULT 'HALF_EVEN' 
        CHECK (rounding_mode IN ('UP', 'DOWN', 'CEILING', 'FLOOR', 'HALF_UP', 'HALF_EVEN', 'HALF_DOWN')),
    
    -- Classification
    currency_type VARCHAR(20) NOT NULL DEFAULT 'fiat'
        CHECK (currency_type IN ('fiat', 'crypto', 'commodity', 'internal', 'basket')),
    
    -- Issuer
    issuer_country_code CHAR(2),
    issuer_central_bank VARCHAR(100),
    
    -- Crypto-specific
    blockchain_network VARCHAR(50),
    token_contract_address VARCHAR(100),
    
    -- SWIFT/Banking
    swift_code CHAR(3),
    minor_unit_name VARCHAR(20),
    
    -- Temporal
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT chk_currency_valid_dates CHECK (valid_from < valid_to)
);

CREATE INDEX idx_currencies_type ON core.currencies(currency_type) WHERE is_active = TRUE;
CREATE INDEX idx_currencies_country ON core.currencies(issuer_country_code) WHERE issuer_country_code IS NOT NULL;

COMMENT ON TABLE core.currencies IS 'ISO 4217 currency standard with crypto and commodity extensions';

-- =============================================================================
-- COUNTRY CODES (ISO 3166)
-- =============================================================================
CREATE TABLE core.country_codes (
    iso_code CHAR(2) PRIMARY KEY,
    iso3_code CHAR(3) UNIQUE,
    numeric_code INTEGER UNIQUE,
    
    country_name VARCHAR(100) NOT NULL,
    official_name VARCHAR(200),
    
    -- Region Classification
    region_code VARCHAR(10),
    sub_region VARCHAR(50),
    intermediate_region VARCHAR(50),
    
    -- FATF/Regulatory
    fatf_status VARCHAR(20) DEFAULT 'compliant' 
        CHECK (fatf_status IN ('compliant', 'grey_list', 'black_list')),
    eu_member BOOLEAN DEFAULT FALSE,
    oecd_member BOOLEAN DEFAULT FALSE,
    
    -- Address Formatting
    address_format VARCHAR(20),
    postal_code_regex VARCHAR(100),
    phone_country_code VARCHAR(5),
    
    -- Temporal
    valid_from DATE DEFAULT '1900-01-01',
    valid_to DATE DEFAULT '9999-12-31',
    
    -- Metadata
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_country_fatf ON core.country_codes(fatf_status);

COMMENT ON TABLE core.country_codes IS 'ISO 3166-1 country codes with FATF status for compliance';

-- =============================================================================
-- VALUE CONTAINERS (The Universal Account)
-- =============================================================================
CREATE TABLE core.value_containers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Classification (IFRS 7 Classes)
    class VARCHAR(20) NOT NULL 
        CHECK (class IN ('LIABILITY', 'ASSET', 'EQUITY', 'INCOME', 'EXPENSE', 'SUSPENSE', 'OFF_BALANCE')),
    
    -- Naming
    code VARCHAR(100) NOT NULL,
    name VARCHAR(255),
    description TEXT,
    
    -- Unit of Measure
    unit JSONB NOT NULL DEFAULT '{"code": "USD", "decimals": 2, "is_monetary": true}',
    currency_code CHAR(3) REFERENCES core.currencies(code),
    
    -- Hierarchy (LTREE)
    parent_id UUID REFERENCES core.value_containers(id),
    path LTREE,
    depth INTEGER GENERATED ALWAYS AS (nlevel(path)) STORED,
    
    -- State Machine
    state VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (state IN ('active', 'frozen', 'dormant', 'closed', 'pending_open', 'suspended')),
    state_since TIMESTAMPTZ DEFAULT NOW(),
    state_reason TEXT,
    
    -- Balances (High Precision)
    balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    pending_balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    held_balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    available_balance DECIMAL(28,8) GENERATED ALWAYS AS (balance - held_balance) STORED,
    
    -- Constraints (Universal Limits)
    min_balance DECIMAL(28,8),
    max_balance DECIMAL(28,8),
    max_single_debit DECIMAL(28,8),
    max_single_credit DECIMAL(28,8),
    
    -- Velocity Limits
    daily_debit_limit DECIMAL(28,8),
    daily_credit_limit DECIMAL(28,8),
    monthly_debit_limit DECIMAL(28,8),
    monthly_credit_limit DECIMAL(28,8),
    
    -- Chart of Accounts Linkage
    coa_code VARCHAR(50),
    
    -- Ownership
    primary_owner_id UUID,
    beneficial_owner_id UUID,
    
    -- Anchoring
    last_movement_id UUID,
    last_movement_at TIMESTAMPTZ,
    
    -- Compliance
    risk_classification VARCHAR(20) DEFAULT 'standard' 
        CHECK (risk_classification IN ('low', 'standard', 'high', 'restricted', 'prohibited')),
    requires_approval BOOLEAN DEFAULT FALSE,
    aml_monitoring BOOLEAN DEFAULT TRUE,
    
    -- Temporal (Bitemporal)
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    closed_reason VARCHAR(100),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    attributes JSONB NOT NULL DEFAULT '{}',
    tags TEXT[],
    
    -- Audit & Event Tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    
    -- Idempotency + Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Immutable Hash
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Constraints
    CONSTRAINT unique_container_code UNIQUE (tenant_id, code),
    CONSTRAINT chk_container_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent CHECK (parent_id IS NULL OR parent_id != id),
    CONSTRAINT chk_balance_precision CHECK (balance = round(balance, 8))
) PARTITION BY LIST (tenant_id);

-- Create default partition
CREATE TABLE core.value_containers_default PARTITION OF core.value_containers DEFAULT;

-- Critical indexes (-3.2)
CREATE INDEX idx_containers_tenant_lookup ON core.value_containers(tenant_id, code);
CREATE INDEX idx_containers_class ON core.value_containers(tenant_id, class) WHERE state = 'active';
CREATE INDEX idx_containers_hierarchy ON core.value_containers USING GIST(path);
CREATE INDEX idx_containers_parent ON core.value_containers(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_containers_temporal ON core.value_containers(valid_from, valid_to) WHERE is_current = TRUE;
CREATE INDEX idx_containers_owner ON core.value_containers(primary_owner_id) WHERE primary_owner_id IS NOT NULL;
CREATE INDEX idx_containers_attributes ON core.value_containers USING GIN(attributes);
CREATE INDEX idx_containers_tags ON core.value_containers USING GIN(tags);
CREATE INDEX idx_containers_correlation ON core.value_containers(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_containers_active_composite ON core.value_containers(tenant_id, valid_from, valid_to) 
    WHERE is_current = TRUE;

-- Currency consistency constraint trigger
CREATE OR REPLACE FUNCTION core.check_container_currency_consistency()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.balance != 0 AND NEW.currency_code IS NULL THEN
        RAISE EXCEPTION 'Currency required for non-zero balance in container %', NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_container_currency_check
    BEFORE INSERT OR UPDATE ON core.value_containers
    FOR EACH ROW EXECUTE FUNCTION core.check_container_currency_consistency();

COMMENT ON TABLE core.value_containers IS 'Universal value container supporting all IFRS account classes';
COMMENT ON COLUMN core.value_containers.balance IS 'Current balance in container currency (28,8 precision)';
COMMENT ON COLUMN core.value_containers.path IS 'LTREE materialized path for hierarchical queries';

-- Trigger to auto-update path on insert/update
CREATE OR REPLACE FUNCTION core.update_container_path()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_id IS NULL THEN
        NEW.path = NEW.id::text::ltree;
    ELSE
        SELECT path || NEW.id::text::ltree INTO NEW.path 
        FROM core.value_containers 
        WHERE id = NEW.parent_id;
        
        IF NEW.path IS NULL THEN
            RAISE EXCEPTION 'Parent container % not found', NEW.parent_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_container_path 
    BEFORE INSERT ON core.value_containers
    FOR EACH ROW EXECUTE FUNCTION core.update_container_path();

-- Trigger for audit updates
CREATE OR REPLACE FUNCTION core.update_container_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    NEW.immutable_hash = encode(digest(
        NEW.id::text || NEW.balance::text || NEW.state || NEW.version::text, 'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_containers_audit
    BEFORE UPDATE ON core.value_containers
    FOR EACH ROW EXECUTE FUNCTION core.update_container_audit();

-- =============================================================================
-- CONTAINER CONSTRAINTS (Extended Limits)
-- =============================================================================
CREATE TABLE core.container_constraints (
    container_id UUID PRIMARY KEY REFERENCES core.value_containers(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    -- Balance Constraints
    min_balance DECIMAL(28,8),
    max_balance DECIMAL(28,8),
    min_balance_warning DECIMAL(28,8),
    max_balance_warning DECIMAL(28,8),
    
    -- Transaction Limits
    max_single_debit DECIMAL(28,8),
    max_single_credit DECIMAL(28,8),
    max_daily_debits DECIMAL(28,8),
    max_daily_credits DECIMAL(28,8),
    max_monthly_debits DECIMAL(28,8),
    max_monthly_credits DECIMAL(28,8),
    
    -- Counterparty Constraints
    allowed_counterparty_ids UUID[],
    blocked_counterparty_ids UUID[],
    allowed_countries CHAR(2)[],
    blocked_countries CHAR(2)[],
    
    -- Time Constraints
    allowed_hours_start TIME,
    allowed_hours_end TIME,
    allowed_days INTEGER[], -- 0=Sunday, 6=Saturday
    
    -- Velocity JSON
    velocity_limits JSONB DEFAULT '[]',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100)
);

CREATE INDEX idx_container_constraints_tenant ON core.container_constraints(tenant_id);

COMMENT ON TABLE core.container_constraints IS 'Extended constraints for value containers beyond core limits';

-- =============================================================================
-- VELOCITY LIMITS (Detailed Table)
-- =============================================================================
CREATE TABLE core.velocity_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    container_id UUID NOT NULL REFERENCES core.value_containers(id) ON DELETE CASCADE,
    
    -- Time Window
    window_type VARCHAR(20) NOT NULL 
        CHECK (window_type IN ('minute', 'hour', 'day', 'week', 'month', 'quarter', 'year')),
    window_duration INTEGER NOT NULL DEFAULT 1,
    
    -- Limits
    max_debit_count INTEGER,
    max_credit_count INTEGER,
    max_debit_amount DECIMAL(28,8),
    max_credit_amount DECIMAL(28,8),
    max_net_flow DECIMAL(28,8),
    
    -- Current Period Tracking (denormalized for performance)
    current_period_start TIMESTAMPTZ,
    current_debit_count INTEGER DEFAULT 0,
    current_credit_count INTEGER DEFAULT 0,
    current_debit_amount DECIMAL(28,8) DEFAULT 0,
    current_credit_amount DECIMAL(28,8) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
);

CREATE INDEX idx_velocity_limits_container ON core.velocity_limits(container_id) WHERE is_active = TRUE;
CREATE INDEX idx_velocity_limits_tenant ON core.velocity_limits(tenant_id);

COMMENT ON TABLE core.velocity_limits IS 'Granular velocity limits for fraud prevention and compliance';

-- =============================================================================
-- CONTAINER BALANCE HISTORY (TimescaleDB Hypertable)
-- =============================================================================
CREATE TABLE core_history.container_balances (
    time TIMESTAMPTZ NOT NULL,
    container_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    
    -- Balance Snapshot
    balance DECIMAL(28,8) NOT NULL,
    available_balance DECIMAL(28,8) NOT NULL,
    pending_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    held_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Movement Counts in Period
    debit_count INTEGER DEFAULT 0,
    credit_count INTEGER DEFAULT 0,
    debit_volume DECIMAL(28,8) DEFAULT 0,
    credit_volume DECIMAL(28,8) DEFAULT 0,
    
    -- Anchoring
    merkle_hash VARCHAR(64),
    movement_ids UUID[],
    
    -- Metadata
    snapshot_reason VARCHAR(50),
    
    PRIMARY KEY (time, container_id)
);

-- Convert to hypertable
SELECT create_hypertable('core_history.container_balances', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

-- Indexes for hypertable
CREATE INDEX idx_balances_container_time ON core_history.container_balances(container_id, time DESC);
CREATE INDEX idx_balances_tenant_time ON core_history.container_balances(tenant_id, time DESC);

COMMENT ON TABLE core_history.container_balances IS 'Time-series balance snapshots using TimescaleDB';

-- =============================================================================
-- CONTAINER STATE TRANSITIONS
-- =============================================================================
CREATE TABLE core_history.container_state_transitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    container_id UUID NOT NULL REFERENCES core.value_containers(id) ON DELETE CASCADE,
    
    from_state VARCHAR(20) NOT NULL,
    to_state VARCHAR(20) NOT NULL,
    reason TEXT,
    
    triggered_by UUID,
    approved_by UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('core_history.container_state_transitions', 'created_at', 
                         chunk_time_interval => INTERVAL '1 week',
                         if_not_exists => TRUE);

CREATE INDEX idx_state_transitions_container ON core_history.container_state_transitions(container_id, created_at DESC);

COMMENT ON TABLE core_history.container_state_transitions IS 'Audit trail of container state changes';

-- =============================================================================
-- SEED DATA
-- =============================================================================
INSERT INTO core.currencies (code, numeric_code, name, decimal_places, currency_type) VALUES
('USD', 840, 'US Dollar', 2, 'fiat'),
('EUR', 978, 'Euro', 2, 'fiat'),
('GBP', 826, 'Pound Sterling', 2, 'fiat'),
('JPY', 392, 'Japanese Yen', 0, 'fiat'),
('BTC', NULL, 'Bitcoin', 8, 'crypto'),
('ETH', NULL, 'Ethereum', 18, 'crypto'),
('POINTS', NULL, 'Loyalty Points', 0, 'internal'),
('GOLD', NULL, 'Gold Gram', 4, 'commodity')
ON CONFLICT (code) DO NOTHING;

INSERT INTO core.country_codes (iso_code, iso3_code, numeric_code, country_name, fatf_status) VALUES
('US', 'USA', 840, 'United States', 'compliant'),
('GB', 'GBR', 826, 'United Kingdom', 'compliant'),
('DE', 'DEU', 276, 'Germany', 'compliant'),
('JP', 'JPN', 392, 'Japan', 'compliant'),
('ZW', 'ZWE', 716, 'Zimbabwe', 'compliant')
ON CONFLICT (iso_code) DO NOTHING;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.currencies TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.country_codes TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.value_containers TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.container_constraints TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.velocity_limits TO finos_app;
GRANT SELECT, INSERT ON core_history.container_balances TO finos_app;
GRANT SELECT, INSERT ON core_history.container_state_transitions TO finos_app;
