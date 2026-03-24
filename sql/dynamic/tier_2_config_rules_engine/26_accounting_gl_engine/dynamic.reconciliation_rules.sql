-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Accounting & GL Engine
-- TABLE: dynamic.reconciliation_rules
--
-- DESCRIPTION:
--   Enterprise-grade reconciliation engine configuration.
--   Bank rec, intercompany, suspense, nostro/vostro matching rules.
--   Supports automated matching, exception handling, bitemporal tracking.
--
-- COMPLIANCE: SOX, IFRS, GAAP, Internal Controls
-- ============================================================================


CREATE TABLE dynamic.reconciliation_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    
    -- Reconciliation Type
    recon_type VARCHAR(50) NOT NULL 
        CHECK (recon_type IN ('BANK', 'INTERCOMPANY', 'SUSPENSE', 'NOSTRO_VOSTRO', 'SUB_LEDGER', 'SYSTEM', 'CUSTOM')),
    
    -- Data Sources
    source_system_1 VARCHAR(100) NOT NULL, -- e.g., 'CORE_BANKING'
    source_system_2 VARCHAR(100) NOT NULL, -- e.g., 'EXTERNAL_BANK'
    source_account_1_id UUID REFERENCES dynamic.gl_account_master(account_id),
    source_account_2_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Matching Criteria
    match_fields VARCHAR(100)[] DEFAULT ARRAY['amount', 'date', 'reference'],
    amount_tolerance DECIMAL(28,8) DEFAULT 0.01,
    date_tolerance_days INTEGER DEFAULT 0,
    reference_fuzzy_matching BOOLEAN DEFAULT FALSE,
    
    -- Auto-Matching Rules
    auto_match_enabled BOOLEAN DEFAULT TRUE,
    auto_match_threshold DECIMAL(5,4) DEFAULT 1.0, -- 100% match required
    
    -- Exception Handling
    exception_aging_buckets INTEGER[] DEFAULT ARRAY[1, 3, 7, 14, 30],
    auto_create_adjustment BOOLEAN DEFAULT FALSE,
    adjustment_approval_required BOOLEAN DEFAULT TRUE,
    
    -- Frequency
    recon_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (recon_frequency IN ('INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    
    -- Status
    rule_status VARCHAR(20) DEFAULT 'ACTIVE',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_recon_rule_code UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reconciliation_rules_default PARTITION OF dynamic.reconciliation_rules DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.reconciliation_rules IS 'Reconciliation engine rules - bank rec, intercompany, suspense matching. Tier 2 - Accounting & GL Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.reconciliation_rules TO finos_app;
