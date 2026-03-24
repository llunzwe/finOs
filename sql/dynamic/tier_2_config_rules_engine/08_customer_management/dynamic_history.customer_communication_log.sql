-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic_history.customer_communication_log
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
-- ============================================================================


CREATE TABLE dynamic_history.customer_communication_log (

    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL,
    
    -- Communication Details
    communication_type VARCHAR(50) NOT NULL, -- EMAIL, SMS, PHONE, LETTER, PUSH
    communication_direction VARCHAR(20) NOT NULL CHECK (communication_direction IN ('INBOUND', 'OUTBOUND')),
    
    -- Content
    subject TEXT,
    content_summary TEXT,
    template_id UUID,
    
    -- Delivery
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    
    -- Status
    delivery_status VARCHAR(20) DEFAULT 'PENDING',
    bounce_reason TEXT,
    
    -- Related To
    related_entity_type VARCHAR(50),
    related_entity_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.customer_communication_log_default PARTITION OF dynamic_history.customer_communication_log DEFAULT;

-- Indexes
CREATE INDEX idx_comm_log_customer ON dynamic_history.customer_communication_log(tenant_id, customer_id);
CREATE INDEX idx_comm_log_date ON dynamic_history.customer_communication_log(sent_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.customer_communication_log IS 'Customer communication audit trail';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.customer_communication_log TO finos_app;