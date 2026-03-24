-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.dispute_configs
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.dispute_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_name VARCHAR(200) NOT NULL,
    
    -- Dispute Types
    dispute_types TEXT[], -- ['fraud', 'authorization', 'processing_error', 'consumer_dispute']
    
    -- Rules
    time_limit_days INTEGER DEFAULT 60,
    provisional_credit_days INTEGER DEFAULT 10,
    
    -- Evidence Fields Required
    evidence_fields JSONB DEFAULT '[]',
    -- Example: ['transaction_receipt', 'merchant_communication', 'police_report']
    
    -- Workflow
    workflow_stages JSONB DEFAULT '[]',
    -- Example: [
    --   {stage: 'submitted', auto_action: 'provisional_credit'},
    --   {stage: 'investigation', sla_hours: 72},
    --   {stage: 'resolved', auto_action: 'notify_customer'}
    -- ]
    
    -- Notifications
    notification_templates JSONB DEFAULT '{}',
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dispute_configs_default PARTITION OF dynamic.dispute_configs DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.dispute_configs IS 'Dispute handling configuration with evidence requirements';

GRANT SELECT, INSERT, UPDATE ON dynamic.dispute_configs TO finos_app;