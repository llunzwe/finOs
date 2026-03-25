-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.legal_entity_consolidation_policies
--
-- DESCRIPTION:
--   Group consolidation policies per IFRS 10/11.
--   Configures consolidation methods for legal entity hierarchies.
--   Maps to core.legal_entities and core.group_consolidation_rules.
--
-- CORE DEPENDENCY: 017_legal_entity_hierarchy_and_group_consolidation.sql
--
-- COMPLIANCE:
--   - IFRS 10 (Consolidated Financial Statements)
--   - IFRS 11 (Joint Arrangements)
--   - IAS 28 (Investments in Associates)
--
-- ============================================================================

CREATE TABLE dynamic.legal_entity_consolidation_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Consolidation Method
    consolidation_method dynamic.consolidation_method NOT NULL,
    
    -- Control Assessment (IFRS 10)
    control_threshold_percentage DECIMAL(5,4), -- e.g., 0.50 for 50%
    de_facto_control_criteria JSONB, -- Additional control indicators
    
    -- Joint Arrangements (IFRS 11)
    joint_arrangement_type VARCHAR(50), -- JOINT_OPERATION or JOINT_VENTURE (NULL if not joint)
    contractual_sharing_terms JSONB,
    
    -- Significant Influence (IAS 28)
    significant_influence_range_min DECIMAL(5,4) DEFAULT 0.20, -- 20%
    significant_influence_range_max DECIMAL(5,4) DEFAULT 0.50, -- 50%
    
    -- Exclusions
    exclude_if_subsidiary_of_investment_entity BOOLEAN DEFAULT TRUE,
    exclude_if_different_reporting_date BOOLEAN DEFAULT FALSE,
    exclude_if_severe_restrictions BOOLEAN DEFAULT TRUE,
    
    -- Intercompany Eliminations
    auto_eliminate_intercompany_transactions BOOLEAN DEFAULT TRUE,
    auto_eliminate_intercompany_balances BOOLEAN DEFAULT TRUE,
    auto_eliminate_unrealized_profits BOOLEAN DEFAULT TRUE,
    
    -- Non-controlling Interests
    nci_measurement VARCHAR(50) DEFAULT 'PROPORTIONATE', -- PROPORTIONATE or FAIR_VALUE
    nci_present_in_equity BOOLEAN DEFAULT TRUE,
    
    -- Foreign Operations
    functional_currency_conversion_method VARCHAR(50) DEFAULT 'CURRENT_RATE', -- CURRENT_RATE or TEMPORAL
    exchange_difference_treatment VARCHAR(50) DEFAULT 'OCI', -- OCI or P&L
    
    -- Reporting
    consolidation_frequency VARCHAR(20) DEFAULT 'MONTHLY', -- DAILY, MONTHLY, QUARTERLY
    elimination_posting_level VARCHAR(50) DEFAULT 'ADJUSTMENT', -- JOURNAL or ADJUSTMENT
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    -- Constraints
    CONSTRAINT unique_consolidation_policy_code UNIQUE (tenant_id, policy_code),
    CONSTRAINT chk_consolidation_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_control_threshold CHECK (control_threshold_percentage IS NULL OR control_threshold_percentage BETWEEN 0 AND 1),
    CONSTRAINT chk_significant_influence_range CHECK (
        significant_influence_range_min IS NULL OR 
        significant_influence_range_max IS NULL OR
        significant_influence_range_min < significant_influence_range_max
    )
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.legal_entity_consolidation_policies_default PARTITION OF dynamic.legal_entity_consolidation_policies DEFAULT;

-- Indexes
CREATE INDEX idx_consolidation_policy_method ON dynamic.legal_entity_consolidation_policies(tenant_id, consolidation_method) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_consolidation_policy_default ON dynamic.legal_entity_consolidation_policies(tenant_id) WHERE is_default = TRUE;

-- Comments
COMMENT ON TABLE dynamic.legal_entity_consolidation_policies IS 'Group consolidation policies per IFRS 10/11 - configures consolidation methods. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.legal_entity_consolidation_policies.consolidation_method IS 'Consolidation method: FULL, PROPORTIONAL, EQUITY, JOINT_VENTURE';
COMMENT ON COLUMN dynamic.legal_entity_consolidation_policies.control_threshold_percentage IS 'Ownership percentage threshold for control (default 50%)';
COMMENT ON COLUMN dynamic.legal_entity_consolidation_policies.nci_measurement IS 'Non-controlling interest measurement: PROPORTIONATE or FAIR_VALUE';

-- Trigger
CREATE TRIGGER trg_legal_entity_consolidation_policies_audit
    BEFORE UPDATE ON dynamic.legal_entity_consolidation_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.legal_entity_consolidation_policies TO finos_app;
