-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.program_reserve
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.program_reserve (

    reserve_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    reserve_name VARCHAR(200) NOT NULL,
    reserve_type VARCHAR(50) DEFAULT 'general' 
        CHECK (reserve_type IN ('general', 'escrow', 'settlement', 'chargeback', 'compliance')),
    
    -- Balance (derived from core movements, stored for caching)
    current_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    available_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    hold_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL,
    
    -- Limits
    min_balance_required DECIMAL(28,8) DEFAULT 0,
    max_balance_limit DECIMAL(28,8),
    
    -- Alerts
    low_balance_threshold DECIMAL(28,8),
    low_balance_alert_sent BOOLEAN DEFAULT FALSE,
    
    -- Core Links
    core_container_id UUID REFERENCES core.value_containers(id),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.program_reserve_default PARTITION OF dynamic.program_reserve DEFAULT;

-- Indexes
CREATE INDEX idx_program_reserve_tenant ON dynamic.program_reserve(tenant_id, reserve_type);

-- Comments
COMMENT ON TABLE dynamic.program_reserve IS 'Program-level reserve accounts for settlement/chargebacks';

-- Triggers
CREATE TRIGGER trg_program_reserve_update
    BEFORE UPDATE ON dynamic.program_reserve
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.program_reserve TO finos_app;