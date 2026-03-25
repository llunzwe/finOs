-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 18 - Capital & Liquidity
-- TABLE: dynamic.capital_buffer_rules
--
-- DESCRIPTION:
--   Capital buffer calculation rules per Basel III/IV.
--   Configures CCyB, CCB, and systemic risk buffers.
--
-- CORE DEPENDENCY: 018_capital_and_liquidity_position_tracking.sql
--
-- COMPLIANCE:
--   - Basel III (Capital Buffers)
--   - Basel IV (Output Floor)
--
-- ============================================================================

CREATE TABLE dynamic.capital_buffer_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Buffer Type
    buffer_type VARCHAR(50) NOT NULL, -- 'CCB', 'CCyB', 'G-SII', 'O-SII', 'SYRB'
    buffer_percentage DECIMAL(5,4) NOT NULL, -- 0.00 to 1.00 (0% to 100%)
    
    -- Applicability
    applicable_entity_types VARCHAR(50)[], -- 'BANK', 'HOLDING_COMPANY', 'SUBSIDIARY'
    applicable_jurisdictions CHAR(2)[], -- Country codes where buffer applies
    
    -- CCyB Specific
    ccyb_countercyclical BOOLEAN DEFAULT FALSE,
    ccyb_reference_jurisdiction CHAR(2),
    ccyb_notification_date DATE,
    ccyb_effective_date DATE,
    
    -- Systemic Risk Specific
    g_sii_bucket INTEGER, -- 1-5 for Global Systemically Important Institutions
    o_sii_score_threshold DECIMAL(10,2), -- Score threshold for O-SII
    
    -- Calculation Method
    calculation_base VARCHAR(50) DEFAULT 'RWA', -- RWA, TOTAL_EXPOSURE, LEVERAGE
    min_buffer_requirement DECIMAL(5,4) DEFAULT 0.0000,
    max_buffer_requirement DECIMAL(5,4) DEFAULT 0.0500, -- 5% cap for CCyB
    
    -- Restrictions
    restricts_distributions BOOLEAN DEFAULT TRUE, -- Limits dividends/bonuses if buffer breached
    restrictions JSONB, -- Details on distribution restrictions
    
    -- Reporting
    report_frequency VARCHAR(20) DEFAULT 'QUARTERLY',
    report_to_regulator BOOLEAN DEFAULT TRUE,
    regulator_authority VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_mandatory BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_capital_buffer_rule UNIQUE (tenant_id, buffer_type, rule_code),
    CONSTRAINT chk_buffer_percentage CHECK (buffer_percentage BETWEEN 0 AND 1)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.capital_buffer_rules_default PARTITION OF dynamic.capital_buffer_rules DEFAULT;

CREATE INDEX idx_capital_buffer_type ON dynamic.capital_buffer_rules(tenant_id, buffer_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.capital_buffer_rules IS 'Capital buffer calculation rules per Basel III/IV (CCB, CCyB, G-SII, O-SII). Tier 2 Low-Code';

CREATE TRIGGER trg_capital_buffer_rules_audit
    BEFORE UPDATE ON dynamic.capital_buffer_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.capital_buffer_rules TO finos_app;
