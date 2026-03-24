-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic.report_instance
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.report_instance (

    instance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Template Reference
    template_id UUID NOT NULL REFERENCES dynamic.report_templates(template_id),
    
    -- Generation Details
    instance_name VARCHAR(200),
    parameters_used JSONB,
    
    -- Timing
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    generated_by VARCHAR(100),
    generation_duration_ms INTEGER,
    
    -- Output
    output_format VARCHAR(20),
    file_location VARCHAR(500),
    file_size_bytes BIGINT,
    checksum VARCHAR(64),
    
    -- Status
    generation_status VARCHAR(20) DEFAULT 'GENERATING' 
        CHECK (generation_status IN ('GENERATING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    error_message TEXT,
    
    -- Distribution
    distributed_to TEXT[],
    distributed_at TIMESTAMPTZ,
    
    -- Expiry
    retention_expiry_date DATE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.report_instance_default PARTITION OF dynamic.report_instance DEFAULT;

-- Indexes
CREATE INDEX idx_report_instance_template ON dynamic.report_instance(tenant_id, template_id);
CREATE INDEX idx_report_instance_date ON dynamic.report_instance(generated_at DESC);
CREATE INDEX idx_report_instance_status ON dynamic.report_instance(tenant_id, generation_status);

-- Comments
COMMENT ON TABLE dynamic.report_instance IS 'Generated report instances with output files';

GRANT SELECT, INSERT, UPDATE ON dynamic.report_instance TO finos_app;