-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.account_holder_transitions
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.account_holder_transitions (

    transition_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    holder_id UUID NOT NULL REFERENCES dynamic.account_holders(holder_id),
    
    -- Transition
    from_status VARCHAR(20) NOT NULL,
    to_status VARCHAR(20) NOT NULL,
    transition_reason VARCHAR(100),
    transition_notes TEXT,
    
    -- Actor
    triggered_by VARCHAR(100),
    triggered_by_type VARCHAR(20) CHECK (triggered_by_type IN ('user', 'system', 'api', 'webhook')),
    
    -- Timing
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Linked to Core
    transition_event_id BIGINT REFERENCES core.transactions(tx_id)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.account_holder_transitions_default PARTITION OF dynamic.account_holder_transitions DEFAULT;

-- Indexes
CREATE INDEX idx_holder_transitions ON dynamic.account_holder_transitions(tenant_id, holder_id, transitioned_at DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.account_holder_transitions TO finos_app;