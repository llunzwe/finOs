-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 41: Transaction Event Sourcing (CQRS Pattern)
-- Table: saga_orchestration_config
-- Description: Saga pattern configuration - defines distributed transaction workflows
--              Choreography vs Orchestration patterns, step definitions, timeouts
-- Compliance: Distributed Systems Best Practices
-- ================================================================================

CREATE TABLE dynamic.saga_orchestration_config (
    -- Primary Identity
    saga_config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Saga Definition
    saga_code VARCHAR(100) NOT NULL,
    saga_name VARCHAR(200) NOT NULL,
    saga_description TEXT,
    
    -- Pattern Type
    saga_pattern VARCHAR(50) NOT NULL CHECK (saga_pattern IN ('ORCHESTRATION', 'CHOREOGRAPHY', 'HYBRID')),
    
    -- Business Context
    business_domain VARCHAR(100) NOT NULL CHECK (business_domain IN (
        'PAYMENTS', 'LENDING', 'TRADING', 'SETTLEMENT', 'TRANSFERS',
        'FOREX', 'DERIVATIVES', 'CLEARING', 'CORPORATE_ACTIONS'
    )),
    transaction_type VARCHAR(100) NOT NULL,
    
    -- Saga Steps Configuration (JSONB for flexibility)
    steps_configuration JSONB NOT NULL,
    -- Example structure:
    -- {
    --   "steps": [
    --     {"step_number": 1, "service": "account-service", "action": "debit", "compensate_action": "credit"},
    --     {"step_number": 2, "service": "payment-service", "action": "process", "compensate_action": "reverse"}
    --   ]
    -- }
    
    -- Timeout Configuration
    step_timeout_seconds INTEGER NOT NULL DEFAULT 30,
    saga_timeout_seconds INTEGER NOT NULL DEFAULT 300,
    compensation_timeout_seconds INTEGER NOT NULL DEFAULT 60,
    
    -- Retry Policy
    max_retries INTEGER DEFAULT 3,
    retry_backoff_ms INTEGER DEFAULT 1000,
    retry_backoff_multiplier DECIMAL(3,2) DEFAULT 2.00,
    max_retry_backoff_ms INTEGER DEFAULT 30000,
    
    -- Failure Handling
    on_failure_action VARCHAR(50) DEFAULT 'COMPENSATE' CHECK (on_failure_action IN ('COMPENSATE', 'ABORT', 'MANUAL_INTERVENTION', 'ESCALATE')),
    escalation_contact VARCHAR(255),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_saga_code_per_tenant UNIQUE (tenant_id, saga_code),
    CONSTRAINT valid_saga_dates CHECK (effective_from < effective_to),
    CONSTRAINT valid_timeout CHECK (step_timeout_seconds > 0 AND saga_timeout_seconds > 0)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.saga_orchestration_config_default PARTITION OF dynamic.saga_orchestration_config
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_saga_config_active ON dynamic.saga_orchestration_config (tenant_id, saga_code) 
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_saga_config_domain ON dynamic.saga_orchestration_config (tenant_id, business_domain, transaction_type);
CREATE INDEX idx_saga_config_steps ON dynamic.saga_orchestration_config USING GIN (steps_configuration jsonb_path_ops);

-- Comments
COMMENT ON TABLE dynamic.saga_orchestration_config IS 'Saga pattern configuration for distributed transaction workflows';
COMMENT ON COLUMN dynamic.saga_orchestration_config.steps_configuration IS 'JSON configuration of saga steps with services, actions, and compensations';

-- RLS
ALTER TABLE dynamic.saga_orchestration_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY saga_orchestration_config_tenant_isolation ON dynamic.saga_orchestration_config
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.saga_orchestration_config TO finos_app_user;
GRANT SELECT ON dynamic.saga_orchestration_config TO finos_readonly_user;
