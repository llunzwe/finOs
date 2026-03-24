-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 29 - AI & Embedded Finance
-- TABLE: dynamic.ai_agent_configuration
--
-- DESCRIPTION:
--   Enterprise-grade AI agent configuration for autonomous financial operations.
--   Agentic commerce, hyper-personalization, next-best-action engines.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: GDPR, SOC2, AI Ethics Standards, Financial Regulations
-- ============================================================================


CREATE TABLE dynamic.ai_agent_configuration (
    agent_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Agent Identity
    agent_code VARCHAR(100) NOT NULL,
    agent_name VARCHAR(200) NOT NULL,
    agent_description TEXT,
    agent_type VARCHAR(50) NOT NULL 
        CHECK (agent_type IN ('CHATBOT', 'TRADING', 'ADVISORY', 'COLLECTIONS', 'FRAUD_DETECTION', 'PERSONALIZATION', 'AUTONOMOUS_PAYMENT')),
    
    -- AI Model Configuration
    model_provider VARCHAR(50) NOT NULL 
        CHECK (model_provider IN ('OPENAI', 'ANTHROPIC', 'GOOGLE', 'MISTRAL', 'LOCAL', 'CUSTOM')),
    model_name VARCHAR(100) NOT NULL, -- e.g., 'gpt-4', 'claude-3-opus'
    model_version VARCHAR(20),
    model_endpoint_url TEXT,
    
    -- Prompt Engineering
    system_prompt TEXT NOT NULL,
    context_window INTEGER DEFAULT 4096,
    temperature DECIMAL(3,2) DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 1024,
    
    -- Capabilities
    allowed_actions VARCHAR(100)[], -- ['VIEW_BALANCE', 'MAKE_PAYMENT', 'APPLY_LOAN']
    restricted_actions VARCHAR(100)[], -- Actions explicitly blocked
    max_transaction_amount DECIMAL(28,8), -- Autonomous payment limit
    requires_human_approval BOOLEAN DEFAULT TRUE,
    
    -- Knowledge Base
    knowledge_base_ids UUID[], -- References to document stores
    product_catalog_access BOOLEAN DEFAULT TRUE,
    customer_data_access_level VARCHAR(20) DEFAULT 'BASIC' 
        CHECK (customer_data_access_level IN ('NONE', 'BASIC', 'FULL', 'SENSITIVE')),
    
    -- Orchestration
    workflow_integration VARCHAR(50), -- BPMN workflow to trigger
    webhook_endpoints JSONB, -- Callback URLs
    
    -- Safety & Guardrails
    content_filter_enabled BOOLEAN DEFAULT TRUE,
    pii_detection_enabled BOOLEAN DEFAULT TRUE,
    audit_logging_level VARCHAR(20) DEFAULT 'FULL' 
        CHECK (audit_logging_level IN ('MINIMAL', 'STANDARD', 'FULL')),
    
    -- Performance
    response_timeout_ms INTEGER DEFAULT 30000,
    retry_attempts INTEGER DEFAULT 3,
    fallback_agent_id UUID, -- Escalation target
    
    -- Usage Limits
    daily_quota INTEGER,
    monthly_quota INTEGER,
    cost_budget DECIMAL(28,8), -- Max spend per period
    
    -- Status
    agent_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (agent_status IN ('DRAFT', 'TESTING', 'ACTIVE', 'PAUSED', 'DEPRECATED')),
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_agent_code_per_tenant UNIQUE (tenant_id, agent_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ai_agent_configuration_default PARTITION OF dynamic.ai_agent_configuration DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_ai_agent_tenant ON dynamic.ai_agent_configuration(tenant_id);
CREATE INDEX idx_ai_agent_type ON dynamic.ai_agent_configuration(tenant_id, agent_type);
CREATE INDEX idx_ai_agent_status ON dynamic.ai_agent_configuration(tenant_id, agent_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.ai_agent_configuration IS 'AI agent configuration for autonomous banking operations and agentic commerce. Tier 2 - AI & Embedded Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.ai_agent_configuration TO finos_app;
