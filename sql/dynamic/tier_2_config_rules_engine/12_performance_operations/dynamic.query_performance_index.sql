-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic.query_performance_index
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.query_performance_index (

    recommendation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Target Table
    table_schema VARCHAR(100) NOT NULL,
    table_name VARCHAR(200) NOT NULL,
    column_names TEXT[] NOT NULL,
    
    -- Index Properties
    index_type VARCHAR(20) DEFAULT 'BTREE' 
        CHECK (index_type IN ('BTREE', 'HASH', 'GIN', 'GIST', 'SPGIST', 'BRIN', 'PARTIAL')),
    index_name_suggested VARCHAR(200),
    
    -- Analysis
    estimated_improvement_percentage DECIMAL(5,2),
    estimated_query_benefit TEXT,
    supporting_queries JSONB, -- Sample queries that would benefit
    
    -- Statistics
    table_size_bytes BIGINT,
    current_index_count INTEGER,
    sequential_scans_per_hour INTEGER,
    
    -- Status
    recommendation_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (recommendation_status IN ('PENDING', 'APPROVED', 'APPLIED', 'REJECTED', 'DEPRECATED')),
    
    applied_at TIMESTAMPTZ,
    applied_by VARCHAR(100),
    applied_ddl TEXT,
    
    -- Review
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.query_performance_index_default PARTITION OF dynamic.query_performance_index DEFAULT;

-- Indexes
CREATE INDEX idx_query_perf_status ON dynamic.query_performance_index(tenant_id, recommendation_status) WHERE recommendation_status = 'PENDING';

-- Comments
COMMENT ON TABLE dynamic.query_performance_index IS 'Automated index recommendations';

GRANT SELECT, INSERT, UPDATE ON dynamic.query_performance_index TO finos_app;