-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.velocity_controls
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.velocity_controls (

    control_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    
    -- Velocity Window
    velocity_window VARCHAR(20) NOT NULL 
        CHECK (velocity_window IN ('per_transaction', 'day', 'week', 'month', 'year')),
    
    -- Limits
    amount_limit DECIMAL(28,8),
    count_limit INTEGER,
    
    -- Currency
    currency CHAR(3),
    
    -- Usage Tracking (current window)
    current_amount DECIMAL(28,8) DEFAULT 0,
    current_count INTEGER DEFAULT 0,
    window_start_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Approval Override
    approval_threshold DECIMAL(28,8), -- Amount above which approval required
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.velocity_controls_default PARTITION OF dynamic.velocity_controls DEFAULT;

-- Indexes
CREATE INDEX idx_velocity_controls_target ON dynamic.velocity_controls(tenant_id, applies_to, target_id);

-- Comments
COMMENT ON TABLE dynamic.velocity_controls IS 'Dedicated velocity control tracking with sliding windows';

-- Triggers
CREATE TRIGGER trg_velocity_controls_update
    BEFORE UPDATE ON dynamic.velocity_controls
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.velocity_controls TO finos_app;