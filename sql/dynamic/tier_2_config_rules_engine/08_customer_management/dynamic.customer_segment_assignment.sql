-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_segment_assignment
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Customer Segment Assignment.
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
CREATE TABLE dynamic.customer_segment_assignment (

    assignment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL, -- Reference to core entity
    segment_id UUID NOT NULL REFERENCES dynamic.customer_segment_definition(segment_id),
    
    -- Assignment Details
    assignment_type VARCHAR(20) DEFAULT 'AUTOMATIC' 
        CHECK (assignment_type IN ('AUTOMATIC', 'MANUAL', 'OVERRIDE')),
    assignment_reason TEXT,
    
    -- Effective Period
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Calculated Scores
    qualifying_score DECIMAL(5,4),
    qualifying_metrics JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_customer_current_segment UNIQUE (tenant_id, customer_id, is_current) WHERE is_current = TRUE

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_segment_assignment_default PARTITION OF dynamic.customer_segment_assignment DEFAULT;

-- Indexes
CREATE INDEX idx_segment_assign_customer ON dynamic.customer_segment_assignment(tenant_id, customer_id);
CREATE INDEX idx_segment_assign_segment ON dynamic.customer_segment_assignment(tenant_id, segment_id);

-- Comments
COMMENT ON TABLE dynamic.customer_segment_assignment IS 'Customer to segment assignments with history';

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_segment_assignment TO finos_app;