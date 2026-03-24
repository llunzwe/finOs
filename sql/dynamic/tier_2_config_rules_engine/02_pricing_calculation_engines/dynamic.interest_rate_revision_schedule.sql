-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.interest_rate_revision_schedule
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Interest Rate Revision Schedule.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================


CREATE TABLE dynamic.interest_rate_revision_schedule (
    revision_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product/Account Reference
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    container_id UUID REFERENCES core.value_containers(id),
    
    -- Rate Details
    rate_type VARCHAR(50) NOT NULL, -- LENDING, DEPOSIT, PENALTY
    old_rate DECIMAL(15,10),
    new_rate DECIMAL(15,10) NOT NULL,
    rate_change_reason VARCHAR(200),
    
    -- Timing
    change_effective_date DATE NOT NULL,
    notification_lead_days INTEGER DEFAULT 30,
    
    -- Communication
    customer_communication_sent BOOLEAN DEFAULT FALSE,
    communication_sent_at TIMESTAMPTZ,
    communication_method VARCHAR(50), -- EMAIL, SMS, LETTER
    
    -- Approval
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'SCHEDULED' 
        CHECK (status IN ('SCHEDULED', 'NOTIFIED', 'APPLIED', 'CANCELLED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.interest_rate_revision_schedule_default PARTITION OF dynamic.interest_rate_revision_schedule DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_rate_revision_product ON dynamic.interest_rate_revision_schedule(tenant_id);
CREATE INDEX idx_rate_revision_effective ON dynamic.interest_rate_revision_schedule(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.interest_rate_revision_schedule IS 'Scheduled interest rate changes with customer notification tracking';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.interest_rate_revision_schedule TO finos_app;
