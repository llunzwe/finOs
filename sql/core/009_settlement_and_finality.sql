-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 9: SETTLEMENT & FINALITY
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Settlement Finality, DvP, Bilateral/Netting, RTGS
-- Standards: ISO 20022, CSDR, Dodd-Frank, PvP, DvP
-- =============================================================================

-- =============================================================================
-- SETTLEMENT INSTRUCTIONS
-- =============================================================================
CREATE TABLE core.settlement_instructions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Linked Movement
    movement_id UUID NOT NULL REFERENCES core.value_movements(id),
    
    -- Settlement Details
    instruction_reference VARCHAR(100) NOT NULL,
    settlement_method VARCHAR(20) NOT NULL 
        CHECK (settlement_method IN ('RTGS', 'DNS', 'BILATERAL', 'DFSNOSTRO', 'CASH', 'DELIVERY', 'INTERNAL')),
    settlement_type VARCHAR(20) CHECK (settlement_type IN ('single', 'batch', 'net')),
    
    -- Dates
    instruction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settlement_date DATE NOT NULL,
    settlement_cycle VARCHAR(10), -- 'T+0', 'T+1', 'T+2', 'T+3'
    
    -- Counterparties (ISO 20022 pacs.008/009)
    payer_agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    payee_agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    
    -- Correspondent Banking
    payer_correspondent_id UUID REFERENCES core.economic_agents(id),
    payee_correspondent_id UUID REFERENCES core.economic_agents(id),
    intermediary_agent_id UUID REFERENCES core.economic_agents(id),
    
    -- Amount
    settlement_amount DECIMAL(28,8) NOT NULL,
    settlement_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    instructed_amount DECIMAL(28,8),
    instructed_currency CHAR(3),
    exchange_rate DECIMAL(28,12),
    
    -- Finality Tracking (Universal Settlement States)
    provisional_at TIMESTAMPTZ,
    final_at TIMESTAMPTZ,
    revocable_until TIMESTAMPTZ,
    
    -- DvP (Delivery vs Payment) Linkage
    linked_delivery_instruction_id UUID REFERENCES core.settlement_instructions(id),
    linked_delivery_type VARCHAR(20), -- 'security', 'commodity', 'document', 'none'
    dvp_model VARCHAR(10) CHECK (dvp_model IN ('DvP', 'PvP', 'FoP')), -- Delivery vs Payment, Payment vs Payment, Free of Payment
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'provisional', 'matched', 'final', 'failed', 'reversed', 'cancelled')),
    status_reason VARCHAR(100),
    
    -- Failure Handling
    failure_reason VARCHAR(200),
    failure_code VARCHAR(50),
    retry_count INTEGER DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    
    -- Blockchain Anchoring (for DLT settlements)
    finalized_in_block VARCHAR(256),
    finalized_in_tx VARCHAR(256),
    settlement_proof BYTEA,
    
    -- ISO 20022 References
    end_to_end_id VARCHAR(100),
    transaction_id VARCHAR(100),
    uetr UUID, -- Unique End-to-End Transaction Reference
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version INTEGER DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    CONSTRAINT unique_instruction_ref UNIQUE (tenant_id, instruction_reference),
    CONSTRAINT unique_settlement_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key)
);

-- Critical indexes (-3.2)
CREATE INDEX idx_settlement_movement ON core.settlement_instructions(movement_id);
CREATE INDEX idx_settlement_date ON core.settlement_instructions(tenant_id, settlement_date) WHERE status IN ('pending', 'provisional') AND is_deleted = FALSE;
CREATE INDEX idx_settlement_status ON core.settlement_instructions(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_settlement_payer ON core.settlement_instructions(payer_agent_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_settlement_payee ON core.settlement_instructions(payee_agent_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_settlement_dvp ON core.settlement_instructions(linked_delivery_instruction_id) WHERE linked_delivery_instruction_id IS NOT NULL;
CREATE INDEX idx_settlement_uetr ON core.settlement_instructions(uetr) WHERE uetr IS NOT NULL;
CREATE INDEX idx_settlement_correlation ON core.settlement_instructions(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_settlement_active_composite ON core.settlement_instructions(tenant_id, status, settlement_date) 
    WHERE is_deleted = FALSE;

COMMENT ON TABLE core.settlement_instructions IS 'Settlement instructions with finality tracking per CSDR/Dodd-Frank';
COMMENT ON COLUMN core.settlement_instructions.final_at IS 'Timestamp when settlement achieved finality (irreversible)';

-- Trigger for finality tracking
CREATE OR REPLACE FUNCTION core.track_settlement_finality()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'final' AND OLD.status != 'final' THEN
        NEW.final_at := NOW();
    END IF;
    
    IF NEW.status = 'provisional' AND OLD.status = 'pending' THEN
        NEW.provisional_at := NOW();
    END IF;
    
    NEW.updated_at := NOW();
    NEW.version := OLD.version + 1;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_settlement_finality
    BEFORE UPDATE ON core.settlement_instructions
    FOR EACH ROW EXECUTE FUNCTION core.track_settlement_finality();

-- =============================================================================
-- SETTLEMENT BATCHES
-- =============================================================================
CREATE TABLE core.settlement_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Batch Identification
    batch_reference VARCHAR(100) NOT NULL,
    batch_type VARCHAR(20) NOT NULL CHECK (batch_type IN ('netting', 'bilateral', 'multilateral', 'dns')),
    settlement_cycle VARCHAR(20) NOT NULL CHECK (settlement_cycle IN ('eod', 'peak', 'intraday', 'overnight')),
    
    -- Dates
    batch_date DATE NOT NULL,
    cutoff_time TIMESTAMPTZ NOT NULL,
    settlement_time TIMESTAMPTZ,
    
    -- Participants
    participant_count INTEGER NOT NULL DEFAULT 0,
    participant_ids UUID[] NOT NULL DEFAULT '{}',
    
    -- Positions (Netting)
    net_positions JSONB NOT NULL DEFAULT '{}', -- {currency: {agent_id: amount}}
    gross_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    gross_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    net_position DECIMAL(28,8) GENERATED ALWAYS AS (gross_credits - gross_debits) STORED,
    
    -- Control
    control_total DECIMAL(28,8) NOT NULL DEFAULT 0,
    variance DECIMAL(28,8) GENERATED ALWAYS AS (control_total - ABS(net_position)) STORED,
    is_balanced BOOLEAN GENERATED ALWAYS AS (gross_debits = gross_credits) STORED,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'calculating', 'awaiting_settlement', 'settled', 'failed', 'cancelled')),
    
    -- Settlement Details
    settled_at TIMESTAMPTZ,
    settlement_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    settled_by VARCHAR(100),
    
    CONSTRAINT unique_batch_ref UNIQUE (tenant_id, batch_reference)
);

CREATE INDEX idx_settlement_batches_date ON core.settlement_batches(tenant_id, batch_date, status);
CREATE INDEX idx_settlement_batches_status ON core.settlement_batches(tenant_id, status) WHERE status IN ('open', 'awaiting_settlement');

COMMENT ON TABLE core.settlement_batches IS 'Settlement batches for DNS and netting settlement';

-- =============================================================================
-- BATCH INSTRUCTIONS LINK
-- =============================================================================
CREATE TABLE core.batch_instructions (
    batch_id UUID NOT NULL REFERENCES core.settlement_batches(id) ON DELETE CASCADE,
    instruction_id UUID NOT NULL REFERENCES core.settlement_instructions(id) ON DELETE CASCADE,
    
    -- Netting Details
    original_amount DECIMAL(28,8) NOT NULL,
    netted_amount DECIMAL(28,8) NOT NULL,
    netting_factor DECIMAL(5,4) DEFAULT 1.0,
    
    -- Status
    included_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settlement_sequence INTEGER,
    
    PRIMARY KEY (batch_id, instruction_id)
);

CREATE INDEX idx_batch_instructions_batch ON core.batch_instructions(batch_id);
CREATE INDEX idx_batch_instructions_instruction ON core.batch_instructions(instruction_id);

-- =============================================================================
-- SETTLEMENT QUEUE
-- =============================================================================
CREATE TABLE core.settlement_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    instruction_id UUID NOT NULL REFERENCES core.settlement_instructions(id),
    
    -- Queue Management
    queue_position INTEGER NOT NULL,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    queue_type VARCHAR(20) NOT NULL CHECK (queue_type IN ('rtgs', 'dns', 'bilateral')),
    
    -- Processing
    enqueued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processing_started_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'queued' 
        CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'deferred')),
    deferral_reason VARCHAR(100),
    deferral_count INTEGER DEFAULT 0,
    
    -- Constraints
    error_message TEXT,
    retry_after TIMESTAMPTZ
);

CREATE INDEX idx_settlement_queue_position ON core.settlement_queue(tenant_id, queue_type, priority DESC, queue_position);
CREATE INDEX idx_settlement_queue_status ON core.settlement_queue(status, retry_after) WHERE status IN ('queued', 'deferred');

COMMENT ON TABLE core.settlement_queue IS 'Settlement processing queue with priority management';

-- =============================================================================
-- SETTLEMENT FINALITY LOG
-- =============================================================================
CREATE TABLE core_history.settlement_finality_log (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    instruction_id UUID NOT NULL,
    movement_id UUID,
    
    previous_status VARCHAR(20) NOT NULL,
    new_status VARCHAR(20) NOT NULL,
    
    finality_timestamp TIMESTAMPTZ,
    finality_block_number BIGINT,
    finality_transaction_hash VARCHAR(256),
    
    settlement_method VARCHAR(20),
    settlement_amount DECIMAL(28,8),
    settlement_currency CHAR(3),
    
    PRIMARY KEY (time, instruction_id)
);

SELECT create_hypertable('core_history.settlement_finality_log', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_finality_log_instruction ON core_history.settlement_finality_log(instruction_id, time DESC);

COMMENT ON TABLE core_history.settlement_finality_log IS 'Audit trail of settlement finality events';

-- =============================================================================
-- LIQUIDITY MANAGEMENT
-- =============================================================================
CREATE TABLE core.liquidity_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    
    -- Liquidity Bucket
    currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    time_bucket TIMESTAMPTZ NOT NULL,
    
    -- Positions
    opening_liquidity DECIMAL(28,8) NOT NULL DEFAULT 0,
    incoming_payments DECIMAL(28,8) NOT NULL DEFAULT 0,
    outgoing_payments DECIMAL(28,8) NOT NULL DEFAULT 0,
    queued_payments DECIMAL(28,8) NOT NULL DEFAULT 0,
    available_liquidity DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Limits
    liquidity_limit DECIMAL(28,8),
    warning_threshold DECIMAL(28,8),
    
    -- Status
    status VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN available_liquidity < 0 THEN 'deficit'
            WHEN warning_threshold IS NOT NULL AND available_liquidity < warning_threshold THEN 'warning'
            ELSE 'adequate'
        END
    ) STORED,
    
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_liquidity_positions_agent ON core.liquidity_positions(tenant_id, agent_id, currency, time_bucket DESC);
CREATE INDEX idx_liquidity_positions_status ON core.liquidity_positions(tenant_id, status) WHERE status != 'adequate';

COMMENT ON TABLE core.liquidity_positions IS 'Real-time liquidity positions for settlement risk management';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.settlement_instructions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.settlement_batches TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.batch_instructions TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.settlement_queue TO finos_app;
GRANT SELECT, INSERT ON core_history.settlement_finality_log TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.liquidity_positions TO finos_app;
