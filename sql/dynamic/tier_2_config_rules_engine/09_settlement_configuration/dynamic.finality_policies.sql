-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Settlement Configuration
-- TABLE: dynamic.finality_policies
--
-- DESCRIPTION:
--   Settlement finality policies per CSDR Article 5.
--   Configures finality thresholds and timing for provisional → final transitions.
--   Maps to core.settlement_instructions.final_at, provisional_at.
--
-- CORE DEPENDENCY: 009_settlement_and_finality.sql
--
-- COMPLIANCE:
--   - CSDR Article 5 (Settlement Finality)
--   - Dodd-Frank Title VII/VIII
--   - EMIR (European Market Infrastructure Regulation)
--
-- ============================================================================

CREATE TABLE dynamic.finality_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Applicability
    applicable_settlement_method dynamic.settlement_method,
    applicable_counterparty_types VARCHAR(50)[], -- 'BANK', 'CCP', 'CSD', 'INVESTOR', etc.
    applicable_instruments VARCHAR(50)[], -- 'EQUITY', 'BOND', 'DERIVATIVE', etc.
    
    -- Finality Timing
    provisional_period_seconds INTEGER DEFAULT 0, -- 0 = no provisional state
    finality_achieved_on VARCHAR(50) DEFAULT 'BOOKING', -- BOOKING, CONFIRMATION, MATCHING, CUSTOM
    custom_finality_trigger VARCHAR(200), -- JSON path or event name
    
    -- Revocability
    is_revocable BOOLEAN DEFAULT FALSE,
    revocation_window_seconds INTEGER DEFAULT 0,
    revocation_conditions JSONB, -- JSON logic for when revocation is allowed
    
    -- Finality Linked Events
    on_finality_achieved VARCHAR(50) DEFAULT 'NOTIFY', -- NOTIFY, TRIGGER_WORKFLOW, UPDATE_LEDGER
    on_finality_failed VARCHAR(50) DEFAULT 'ROLLBACK', -- ROLLBACK, HOLD, NOTIFY
    
    -- Blockchain Anchoring (for DLT settlements)
    anchor_on_finality BOOLEAN DEFAULT FALSE,
    anchor_chain dynamic.anchor_chain,
    anchor_confirmation_threshold INTEGER DEFAULT 6, -- Bitcoin blocks, etc.
    
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
    CONSTRAINT unique_finality_policy_code UNIQUE (tenant_id, policy_code),
    CONSTRAINT chk_finality_valid_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.finality_policies_default PARTITION OF dynamic.finality_policies DEFAULT;

-- Indexes
CREATE INDEX idx_finality_policy_method ON dynamic.finality_policies(tenant_id, applicable_settlement_method) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_finality_policy_default ON dynamic.finality_policies(tenant_id) WHERE is_default = TRUE;

-- Comments
COMMENT ON TABLE dynamic.finality_policies IS 'Settlement finality policies per CSDR Article 5 - configures provisional to final transitions. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.finality_policies.provisional_period_seconds IS 'Time settlement remains provisional before becoming final (CSDR compliance)';
COMMENT ON COLUMN dynamic.finality_policies.is_revocable IS 'Whether settlement can be revoked during provisional period';

-- Trigger
CREATE TRIGGER trg_finality_policies_audit
    BEFORE UPDATE ON dynamic.finality_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.finality_policies TO finos_app;
