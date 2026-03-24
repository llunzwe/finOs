-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 16 - Industry Packs Insurance
-- TABLE: dynamic.reinsurance_rules
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - IAIS
--   - POPIA
-- ============================================================================


CREATE TABLE dynamic.reinsurance_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Treaty Reference
    treaty_id UUID REFERENCES dynamic.reinsurance_treaty(treaty_id),
    
    -- Cession Type
    cession_type VARCHAR(50) NOT NULL 
        CHECK (cession_type IN ('QUOTA_SHARE', 'SURPLUS', 'EXCESS_OF_LOSS', 'STOP_LOSS', 'FACULTATIVE', 'AGGREGATE_EXCESS')),
    
    -- Applicability
    applicable_products UUID[],
    applicable_sum_assured_min DECIMAL(28,8),
    applicable_sum_assured_max DECIMAL(28,8),
    applicable_geographies VARCHAR(10)[],
    
    -- Cession Logic
    cession_percentage DECIMAL(5,4), -- For quota share
    retention_limit DECIMAL(28,8), -- For surplus
    cession_limit DECIMAL(28,8), -- Maximum to cede
    
    -- Layer Structure (for XoL)
    layer_structure JSONB, -- [{attachment: 1000000, limit: 5000000, premium_share: 0.3}, ...]
    
    -- Premium
    reinsurance_premium_basis VARCHAR(50) DEFAULT 'PROPORTIONAL' 
        CHECK (reinsurance_premium_basis IN ('PROPORTIONAL', 'FIXED', 'EXPERIENCE_RATED', 'LOSS_CORRIDOR')),
    reinsurance_premium_percentage DECIMAL(10,6),
    
    -- Commission
    ceding_commission_percentage DECIMAL(10,6),
    profit_commission_structure JSONB, -- [{loss_ratio_threshold: 70, commission: 0.2}, ...]
    
    -- Claims
    claims_notification_period_days INTEGER DEFAULT 30,
    claims_settlement_terms VARCHAR(50) DEFAULT 'PROPORTIONAL',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_reinsurance_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reinsurance_rules_default PARTITION OF dynamic.reinsurance_rules DEFAULT;

-- Indexes
CREATE INDEX idx_reinsurance_rules_tenant ON dynamic.reinsurance_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_reinsurance_rules_treaty ON dynamic.reinsurance_rules(tenant_id, treaty_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.reinsurance_rules IS 'Reinsurance cession and premium calculation rules';

-- Triggers
CREATE TRIGGER trg_reinsurance_rules_audit
    BEFORE UPDATE ON dynamic.reinsurance_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.reinsurance_rules TO finos_app;