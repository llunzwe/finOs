-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 41: Transaction Event Sourcing (CQRS Pattern)
-- Table: transaction_compensation_log
-- Description: Saga compensation tracking - records compensating transactions for
--              distributed transaction rollback and eventual consistency
-- Compliance: ACID, Distributed Transaction Patterns (Saga)
-- ================================================================================

CREATE TABLE dynamic.transaction_compensation_log (
    -- Primary Identity
    compensation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Saga Context
    saga_id UUID NOT NULL,
    saga_step_number INTEGER NOT NULL,
    saga_name VARCHAR(200) NOT NULL,
    
    -- Original Transaction
    original_event_id UUID NOT NULL REFERENCES dynamic.transaction_event_journal(event_id),
    original_transaction_id UUID NOT NULL,
    original_event_type VARCHAR(100) NOT NULL,
    
    -- Compensation Action
    compensation_action VARCHAR(100) NOT NULL CHECK (compensation_action IN (
        'REVERSE_TRANSACTION', 'CREDIT_ADJUSTMENT', 'DEBIT_ADJUSTMENT',
        'CANCEL_PAYMENT', 'REFUND_PAYMENT', 'RELEASE_HOLD', 'REINSTATE_LIMIT',
        'REVERSE_FEE', 'ADJUST_INTEREST', 'RESTORE_BALANCE', 'NOTIFY_FAILURE'
    )),
    compensation_payload JSONB NOT NULL,
    
    -- Compensation Status
    compensation_status VARCHAR(50) DEFAULT 'PENDING' CHECK (compensation_status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'PARTIAL', 'MANUAL_INTERVENTION'
    )),
    
    -- Execution Tracking
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Error Handling
    failure_reason TEXT,
    failure_code VARCHAR(50),
    failure_details JSONB,
    manual_intervention_required BOOLEAN DEFAULT FALSE,
    manual_intervention_notes TEXT,
    
    -- Rollback Chain
    parent_compensation_id UUID REFERENCES dynamic.transaction_compensation_log(compensation_id),
    compensation_order INTEGER NOT NULL, -- Order in rollback sequence
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_saga_step_compensation UNIQUE (tenant_id, saga_id, saga_step_number),
    CONSTRAINT valid_compensation_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.transaction_compensation_log_default PARTITION OF dynamic.transaction_compensation_log
    DEFAULT;

-- Indexes
CREATE INDEX idx_transaction_compensation_saga ON dynamic.transaction_compensation_log (tenant_id, saga_id, compensation_order);
CREATE INDEX idx_transaction_compensation_status ON dynamic.transaction_compensation_log (tenant_id, compensation_status, initiated_at);
CREATE INDEX idx_transaction_compensation_original ON dynamic.transaction_compensation_log (tenant_id, original_transaction_id);
CREATE INDEX idx_transaction_compensation_manual ON dynamic.transaction_compensation_log (tenant_id, manual_intervention_required) WHERE manual_intervention_required = TRUE;

-- Comments
COMMENT ON TABLE dynamic.transaction_compensation_log IS 'Saga compensation tracking for distributed transaction rollback';
COMMENT ON COLUMN dynamic.transaction_compensation_log.compensation_order IS 'Execution order in rollback sequence (higher = execute first)';

-- RLS
ALTER TABLE dynamic.transaction_compensation_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY transaction_compensation_log_tenant_isolation ON dynamic.transaction_compensation_log
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.transaction_compensation_log TO finos_app_user;
GRANT SELECT ON dynamic.transaction_compensation_log TO finos_readonly_user;
