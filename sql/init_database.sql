-- =============================================================================
-- FINOS CORE KERNEL - DATABASE INITIALIZATION (PostgreSQL Compatible)
-- =============================================================================
-- This script creates a working version without TimescaleDB/PostGIS dependencies
-- =============================================================================

-- =============================================================================
-- SECTION 1: CREATE EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =============================================================================
-- SECTION 2: CREATE SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS core_history;
CREATE SCHEMA IF NOT EXISTS core_crypto;
CREATE SCHEMA IF NOT EXISTS core_audit;
CREATE SCHEMA IF NOT EXISTS core_reporting;

COMMENT ON SCHEMA core IS 'FinOS Core Kernel - Immutable financial primitives';
COMMENT ON SCHEMA core_history IS 'FinOS Core - Temporal/historical data';
COMMENT ON SCHEMA core_crypto IS 'FinOS Core - Cryptographic anchoring and immutable event store';
COMMENT ON SCHEMA core_audit IS 'FinOS Core - Audit trails, logging, and compliance';
COMMENT ON SCHEMA core_reporting IS 'FinOS Core - Materialized views and reporting snapshots';

-- =============================================================================
-- SECTION 3: CREATE ROLES
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_app') THEN
        CREATE ROLE finos_app WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_readonly') THEN
        CREATE ROLE finos_readonly WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_admin') THEN
        CREATE ROLE finos_admin WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
END
$$;

-- =============================================================================
-- SECTION 4: UTILITY FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_environment()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(current_setting('app.environment', TRUE), 'development');
EXCEPTION WHEN OTHERS THEN
    RETURN 'development';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.current_tenant_id()
RETURNS UUID AS $$
BEGIN
    RETURN COALESCE(
        current_setting('app.current_tenant', TRUE)::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
EXCEPTION WHEN OTHERS THEN
    RETURN '00000000-0000-0000-0000-000000000000'::UUID;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.generate_secure_token(p_length INTEGER DEFAULT 32)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(gen_random_bytes(p_length), 'hex');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.util_uuid_v7()
RETURNS UUID AS $$
BEGIN
    RETURN uuid_generate_v4();
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SECTION 5: CURRENCIES AND COUNTRY CODES
-- =============================================================================

CREATE TABLE core.currencies (
    code CHAR(3) PRIMARY KEY,
    numeric_code INTEGER UNIQUE,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10),
    decimal_places INTEGER NOT NULL DEFAULT 2 CHECK (decimal_places BETWEEN 0 AND 18),
    rounding_mode VARCHAR(20) DEFAULT 'HALF_EVEN',
    currency_type VARCHAR(20) NOT NULL DEFAULT 'fiat',
    issuer_country_code CHAR(2),
    issuer_central_bank VARCHAR(100),
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    CONSTRAINT chk_currency_valid_dates CHECK (valid_from < valid_to)
);

CREATE INDEX idx_currencies_type ON core.currencies(currency_type) WHERE is_active = TRUE;

CREATE TABLE core.country_codes (
    iso_code CHAR(2) PRIMARY KEY,
    iso3_code CHAR(3) UNIQUE,
    numeric_code INTEGER UNIQUE,
    country_name VARCHAR(100) NOT NULL,
    official_name VARCHAR(200),
    region_code VARCHAR(10),
    sub_region VARCHAR(50),
    fatf_status VARCHAR(20) DEFAULT 'compliant',
    eu_member BOOLEAN DEFAULT FALSE,
    oecd_member BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_country_fatf ON core.country_codes(fatf_status);

-- Insert seed data
INSERT INTO core.currencies (code, numeric_code, name, decimal_places, currency_type) VALUES
('USD', 840, 'US Dollar', 2, 'fiat'),
('EUR', 978, 'Euro', 2, 'fiat'),
('GBP', 826, 'Pound Sterling', 2, 'fiat'),
('JPY', 392, 'Japanese Yen', 0, 'fiat'),
('BTC', NULL, 'Bitcoin', 8, 'crypto'),
('ETH', NULL, 'Ethereum', 18, 'crypto'),
('POINTS', NULL, 'Loyalty Points', 0, 'internal'),
('GOLD', NULL, 'Gold Gram', 4, 'commodity'),
('ZIG', 716, 'Zimbabwe Gold', 2, 'fiat')
ON CONFLICT (code) DO NOTHING;

INSERT INTO core.country_codes (iso_code, iso3_code, numeric_code, country_name, fatf_status) VALUES
('US', 'USA', 840, 'United States', 'compliant'),
('GB', 'GBR', 826, 'United Kingdom', 'compliant'),
('DE', 'DEU', 276, 'Germany', 'compliant'),
('JP', 'JPN', 392, 'Japan', 'compliant'),
('ZW', 'ZWE', 716, 'Zimbabwe', 'compliant')
ON CONFLICT (iso_code) DO NOTHING;

-- =============================================================================
-- SECTION 6: TENANTS TABLE
-- =============================================================================

CREATE TABLE core.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    legal_name VARCHAR(255) NOT NULL,
    lei_code VARCHAR(20) UNIQUE,
    bic_code VARCHAR(11),
    config JSONB NOT NULL DEFAULT '{}',
    config_encrypted BYTEA,
    base_currency CHAR(3) NOT NULL DEFAULT 'USD',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    decimal_separator CHAR(1) DEFAULT '.',
    thousands_separator CHAR(1) DEFAULT ',',
    license_number VARCHAR(100),
    regulatory_authority VARCHAR(100),
    tax_id VARCHAR(100),
    tax_id_encrypted BYTEA,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    status_reason TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    restored_at TIMESTAMPTZ,
    restored_by UUID,
    merkle_root VARCHAR(64),
    last_anchor_time TIMESTAMPTZ,
    anchor_chain VARCHAR(50) DEFAULT 'none',
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_tenant_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_tenant_code_format CHECK (code ~ '^[a-zA-Z][a-zA-Z0-9_-]+$')
);

CREATE INDEX idx_tenants_status ON core.tenants(status) WHERE status = 'active';
CREATE INDEX idx_tenants_lei ON core.tenants(lei_code) WHERE lei_code IS NOT NULL;
CREATE INDEX idx_tenants_temporal ON core.tenants(valid_from, valid_to);

-- Insert system tenant
INSERT INTO core.tenants (id, name, code, legal_name, base_currency, timezone, status)
VALUES ('00000000-0000-0000-0000-000000000000'::UUID, 'System Tenant', 'system', 'FinOS System Tenant', 'USD', 'UTC', 'active')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- SECTION 7: ENTITIES TABLE
-- =============================================================================

CREATE TABLE core.entities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL,
    entity_code VARCHAR(100) NOT NULL,
    global_reference VARCHAR(200) GENERATED ALWAYS AS (tenant_id::text || ':' || entity_type || ':' || entity_code) STORED,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    deletion_reason TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    idempotency_key VARCHAR(100),
    CONSTRAINT unique_entity_per_tenant UNIQUE (tenant_id, entity_type, entity_code),
    CONSTRAINT chk_entity_valid_dates CHECK (valid_from <= valid_to)
);

CREATE INDEX idx_entities_tenant_lookup ON core.entities(tenant_id, entity_type, entity_code) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_global_ref ON core.entities(global_reference);
CREATE INDEX idx_entities_temporal ON core.entities(valid_from, valid_to) WHERE is_current = TRUE AND is_deleted = FALSE;

-- =============================================================================
-- SECTION 8: VALUE CONTAINERS
-- =============================================================================

CREATE TABLE core.value_containers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    class VARCHAR(20) NOT NULL CHECK (class IN ('LIABILITY', 'ASSET', 'EQUITY', 'INCOME', 'EXPENSE', 'SUSPENSE', 'OFF_BALANCE')),
    code VARCHAR(100) NOT NULL,
    name VARCHAR(255),
    description TEXT,
    unit JSONB NOT NULL DEFAULT '{"code": "USD", "decimals": 2, "is_monetary": true}',
    currency_code CHAR(3) REFERENCES core.currencies(code),
    parent_id UUID,
    path LTREE,
    depth INTEGER,
    state VARCHAR(20) NOT NULL DEFAULT 'active',
    state_since TIMESTAMPTZ DEFAULT NOW(),
    state_reason TEXT,
    balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    pending_balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    held_balance DECIMAL(28,8) NOT NULL DEFAULT 0.00,
    available_balance DECIMAL(28,8) GENERATED ALWAYS AS (balance - held_balance) STORED,
    min_balance DECIMAL(28,8),
    max_balance DECIMAL(28,8),
    max_single_debit DECIMAL(28,8),
    max_single_credit DECIMAL(28,8),
    daily_debit_limit DECIMAL(28,8),
    daily_credit_limit DECIMAL(28,8),
    monthly_debit_limit DECIMAL(28,8),
    monthly_credit_limit DECIMAL(28,8),
    coa_code VARCHAR(50),
    primary_owner_id UUID,
    beneficial_owner_id UUID,
    last_movement_id UUID,
    last_movement_at TIMESTAMPTZ,
    risk_classification VARCHAR(20) DEFAULT 'standard',
    requires_approval BOOLEAN DEFAULT FALSE,
    aml_monitoring BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    closed_reason VARCHAR(100),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    attributes JSONB NOT NULL DEFAULT '{}',
    tags TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    CONSTRAINT unique_container_code UNIQUE (tenant_id, code),
    CONSTRAINT chk_container_valid_dates CHECK (valid_from < valid_to)
);

CREATE INDEX idx_containers_tenant_lookup ON core.value_containers(tenant_id, code);
CREATE INDEX idx_containers_class ON core.value_containers(tenant_id, class) WHERE state = 'active';
CREATE INDEX idx_containers_hierarchy ON core.value_containers USING GIST(path);

-- =============================================================================
-- SECTION 9: VALUE MOVEMENTS
-- =============================================================================

CREATE TABLE core.value_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    entry_date DATE NOT NULL,
    value_date DATE NOT NULL,
    posted_at TIMESTAMPTZ,
    reversed_at TIMESTAMPTZ,
    reversal_movement_id UUID,
    total_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    entry_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    functional_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    exchange_rate DECIMAL(28,12) NOT NULL DEFAULT 1.0,
    exchange_rate_source VARCHAR(50),
    control_hash VARCHAR(64),
    batch_id UUID,
    batch_sequence INTEGER,
    product_family VARCHAR(50),
    product_type VARCHAR(50),
    trigger_event VARCHAR(50),
    cohort_id VARCHAR(100),
    channel VARCHAR(50),
    context JSONB NOT NULL DEFAULT '{}',
    session_id UUID,
    authorized_by UUID,
    authorization_method VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    immutable_event_id BIGINT,
    merkle_leaf VARCHAR(64),
    anchor_status VARCHAR(20) DEFAULT 'pending',
    reconciliation_status VARCHAR(20) DEFAULT 'unreconciled',
    reconciliation_run_id UUID,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    CONSTRAINT unique_movement_reference UNIQUE (tenant_id, reference),
    CONSTRAINT chk_conservation CHECK (total_debits = total_credits),
    CONSTRAINT chk_value_date CHECK (value_date >= entry_date),
    CONSTRAINT chk_positive_totals CHECK (total_debits >= 0 AND total_credits >= 0)
);

CREATE INDEX idx_movements_tenant_ref ON core.value_movements(tenant_id, reference);
CREATE INDEX idx_movements_status ON core.value_movements(tenant_id, status) WHERE status IN ('pending', 'posted');
CREATE INDEX idx_movements_entry_date ON core.value_movements(tenant_id, entry_date);

-- =============================================================================
-- SECTION 10: MOVEMENT LEGS
-- =============================================================================

CREATE TABLE core.movement_legs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    movement_id UUID NOT NULL REFERENCES core.value_movements(id) ON DELETE CASCADE,
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('debit', 'credit')),
    amount DECIMAL(28,8) NOT NULL,
    amount_in_functional_currency DECIMAL(28,8),
    exchange_rate DECIMAL(28,12) DEFAULT 1.0,
    account_code VARCHAR(50),
    account_name VARCHAR(200),
    sequence_number INTEGER NOT NULL DEFAULT 1,
    leg_status VARCHAR(20) DEFAULT 'posted',
    failure_reason VARCHAR(200),
    cost_center VARCHAR(50),
    project_code VARCHAR(50),
    department VARCHAR(50),
    geography VARCHAR(50),
    product_line VARCHAR(50),
    custom_dimensions JSONB DEFAULT '{}',
    obligation_id UUID,
    document_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    CONSTRAINT unique_leg_sequence UNIQUE (movement_id, sequence_number),
    CONSTRAINT chk_non_zero_amount CHECK (amount != 0)
);

CREATE INDEX idx_legs_movement ON core.movement_legs(movement_id);
CREATE INDEX idx_legs_container ON core.movement_legs(container_id);

-- =============================================================================
-- SECTION 11: ECONOMIC AGENTS
-- =============================================================================

CREATE TABLE core.economic_agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    display_name VARCHAR(500) NOT NULL,
    legal_name VARCHAR(500),
    lei_code VARCHAR(20),
    national_id VARCHAR(100),
    tax_id VARCHAR(100),
    tax_id_encrypted BYTEA,
    risk_category VARCHAR(20) DEFAULT 'medium',
    risk_score DECIMAL(5,2) CHECK (risk_score BETWEEN 0 AND 100),
    kyc_status VARCHAR(20) DEFAULT 'pending',
    kyc_verified_at TIMESTAMPTZ,
    kyc_level VARCHAR(20) DEFAULT 'basic',
    pep_status BOOLEAN DEFAULT FALSE,
    sanctions_status VARCHAR(20) DEFAULT 'clear',
    country_of_residence CHAR(2),
    incorporation_date DATE,
    annual_revenue DECIMAL(28,8),
    employee_count INTEGER,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    attributes JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    correlation_id UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT unique_agent_display_per_tenant UNIQUE (tenant_id, display_name, type)
);

CREATE INDEX idx_agents_tenant_lookup ON core.economic_agents(tenant_id, display_name) WHERE is_deleted = FALSE;
CREATE INDEX idx_agents_type ON core.economic_agents(tenant_id, type) WHERE is_deleted = FALSE;
CREATE INDEX idx_agents_kyc ON core.economic_agents(kyc_status) WHERE kyc_status != 'verified';

-- =============================================================================
-- SECTION 12: AUDIT LOG
-- =============================================================================

CREATE TABLE core_audit.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    row_id UUID,
    old_data JSONB,
    new_data JSONB,
    changed_fields JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(100),
    tenant_id UUID,
    session_id UUID,
    ip_address INET,
    transaction_id BIGINT,
    correlation_id UUID
);

CREATE INDEX idx_audit_table ON core_audit.audit_log(table_name, changed_at DESC);
CREATE INDEX idx_audit_tenant ON core_audit.audit_log(tenant_id, changed_at DESC);

-- =============================================================================
-- SECTION 13: GRANTS
-- =============================================================================

GRANT USAGE ON SCHEMA core TO finos_app, finos_readonly, finos_admin;
GRANT USAGE ON SCHEMA core_history TO finos_app, finos_readonly, finos_admin;
GRANT USAGE ON SCHEMA core_crypto TO finos_app, finos_admin;
GRANT USAGE ON SCHEMA core_audit TO finos_app, finos_admin;
GRANT USAGE ON SCHEMA core_reporting TO finos_app, finos_readonly, finos_admin;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO finos_app;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA core_history TO finos_app;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA core_audit TO finos_app;

GRANT SELECT ON ALL TABLES IN SCHEMA core TO finos_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA core_history TO finos_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA core_audit TO finos_readonly;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_history TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_audit TO finos_app;

-- =============================================================================
-- SECTION 14: HEALTH CHECK FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.health_check_full()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_table_count INTEGER;
    v_rls_count INTEGER;
    v_index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_table_count
    FROM pg_tables WHERE schemaname = 'core';
    
    SELECT COUNT(*) INTO v_rls_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'core' AND c.relrowsecurity = true;
    
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit');
    
    v_result := jsonb_build_object(
        'timestamp', NOW(),
        'environment', COALESCE(current_setting('app.environment', TRUE), 'development'),
        'tables', jsonb_build_object(
            'total_core_tables', v_table_count,
            'rls_enabled', v_rls_count
        ),
        'indexes', jsonb_build_object(
            'total_indexes', v_index_count
        ),
        'status', 'HEALTHY'
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMPLETION
-- =============================================================================

SELECT 'FinOS Core Kernel initialized successfully!' AS status;
SELECT * FROM core.health_check_full();
