-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_segment_assignment
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
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
    
    CONSTRAINT unique_customer_current_segment UNIQUE (tenant_id, customer_id, is_current) WHERE is_current = TRUE

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_segment_assignment_default PARTITION OF dynamic.customer_segment_assignment DEFAULT;

-- Indexes
CREATE INDEX idx_segment_assign_customer ON dynamic.customer_segment_assignment(tenant_id, customer_id);
CREATE INDEX idx_segment_assign_segment ON dynamic.customer_segment_assignment(tenant_id, segment_id);

-- Comments
COMMENT ON TABLE dynamic.customer_segment_assignment IS 'Customer to segment assignments with history';

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_segment_assignment TO finos_app;