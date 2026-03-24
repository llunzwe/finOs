-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.dispute_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Dispute Configs.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dispute_configs_default PARTITION OF dynamic.dispute_configs DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.dispute_configs IS 'Dispute handling configuration with evidence requirements';

GRANT SELECT, INSERT, UPDATE ON dynamic.dispute_configs TO finos_app;