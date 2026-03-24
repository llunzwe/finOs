-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.compliance_override
--
-- DESCRIPTION:
--   Enterprise-grade compliance override and exception management.
--   Tracks approved deviations from standard compliance rules.
--
-- ============================================================================


CREATE TABLE dynamic.compliance_override (
    override_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Override Identification
    override_reference VARCHAR(100) NOT NULL,
    override_type VARCHAR(100) NOT NULL 
        CHECK (override_type IN ('AML_THRESHOLD', 'KYC_REQUIREMENT', 'LENDING_LIMIT', 'EXCHANGE_CONTROL', 'REGULATORY_REPORTING')),
    
    -- Affected Entity
    entity_type VARCHAR(50) NOT NULL, -- 'CUSTOMER', 'TRANSACTION', 'ACCOUNT'
    entity_id UUID NOT NULL,
    
    -- Override Details
    standard_rule_id UUID, -- Reference to the rule being overridden
    standard_value TEXT, -- Original required value
    override_value TEXT, -- Approved override value
    override_reason TEXT NOT NULL,
    
    -- Approval
    requested_by VARCHAR(100) NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    approval_level VARCHAR(20), -- 'MANAGER', 'DIRECTOR', 'COMPLIANCE_OFFICER'
    
    -- Time Bound
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Conditions
    conditions JSONB DEFAULT '{}', -- Any conditions attached to override
    review_required BOOLEAN DEFAULT TRUE,
    next_review_date DATE,
    
    -- Status
    override_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (override_status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'REVOKED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_override_reference UNIQUE (tenant_id, override_reference)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.compliance_override_default PARTITION OF dynamic.compliance_override DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_compliance_override_tenant ON dynamic.compliance_override(tenant_id);
CREATE INDEX idx_compliance_override_entity ON dynamic.compliance_override(tenant_id, entity_type, entity_id);
CREATE INDEX idx_compliance_override_status ON dynamic.compliance_override(tenant_id, override_status);
CREATE INDEX idx_compliance_override_dates ON dynamic.compliance_override(tenant_id, effective_from, effective_to);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.compliance_override IS 'Compliance override management - approved exceptions to standard rules. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.compliance_override TO finos_app;
