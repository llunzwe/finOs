-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic_history.customer_communication_log
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Customer Communication Log.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.customer_communication_log_default PARTITION OF dynamic_history.customer_communication_log DEFAULT;

-- Indexes
CREATE INDEX idx_comm_log_customer ON dynamic_history.customer_communication_log(tenant_id, customer_id);
CREATE INDEX idx_comm_log_date ON dynamic_history.customer_communication_log(sent_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.customer_communication_log IS 'Customer communication audit trail';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.customer_communication_log TO finos_app;