-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 12: CONTROL & BATCH PROCESSING
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Control Totals, Batch Balancing, Hash Totals, EOD Processing
-- Standards: ISO 20022, COBIT, ITIL
-- =============================================================================

-- =============================================================================
-- CONTROL BATCHES
-- =============================================================================
CREATE TABLE core.control_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    batch_reference VARCHAR(100) NOT NULL,
    batch_name VARCHAR(200),
    batch_type VARCHAR(50) NOT NULL 
        CHECK (batch_type IN ('intraday', 'eod', 'bulk_payment', 'payroll', 'dividend', 'interest_posting', 'statement', 'reporting')),
    
    -- Control Totals (Enterprise Pattern)
    hash_total VARCHAR(64), -- Hash of all reference numbers
    hash_algorithm VARCHAR(20) DEFAULT 'SHA256',
    
    amount_total DECIMAL(28,8) NOT NULL DEFAULT 0,
    amount_currency CHAR(3) DEFAULT 'USD',
    
    debit_total DECIMAL(28,8) NOT NULL DEFAULT 0,
    credit_total DECIMAL(28,8) NOT NULL DEFAULT 0,
    net_total DECIMAL(28,8) GENERATED ALWAYS AS (credit_total - debit_total) STORED,
    
    record_count INTEGER NOT NULL DEFAULT 0,
    expected_record_count INTEGER,
    
    expected_total DECIMAL(28,8) NOT NULL DEFAULT 0,
    variance DECIMAL(28,8) GENERATED ALWAYS AS (amount_total - expected_total) STORED,
    is_balanced BOOLEAN GENERATED ALWAYS AS (ABS(amount_total - expected_total) <= 0.01 AND debit_total = credit_total) STORED,
    
    -- Scope
    effective_date DATE NOT NULL,
    value_date DATE,
    accounting_period VARCHAR(20),
    
    -- EOD Link
    eod_run_id UUID,
    
    -- Status Workflow
    status VARCHAR(20) NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'validation_pending', 'validated', 'balanced', 'validation_failed', 'posting', 'posted', 'rejected', 'cancelled')),
    status_reason VARCHAR(200),
    
    -- Processing Stages
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    validation_started_at TIMESTAMPTZ,
    validated_at TIMESTAMPTZ,
    posting_started_at TIMESTAMPTZ,
    posted_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    
    -- Error Handling
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Operators (4-eyes)
    opened_by UUID NOT NULL REFERENCES core.economic_agents(id),
    validated_by UUID REFERENCES core.economic_agents(id),
    posted_by UUID REFERENCES core.economic_agents(id),
    approved_by UUID REFERENCES core.economic_agents(id),
    
    -- Metadata
    source_system VARCHAR(100),
    source_file_name VARCHAR(255),
    source_file_hash VARCHAR(64),
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    CONSTRAINT unique_batch_ref UNIQUE (tenant_id, batch_reference),
    CONSTRAINT unique_batch_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key)
);

CREATE INDEX idx_control_batches_date ON core.control_batches(tenant_id, effective_date, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_control_batches_status ON core.control_batches(tenant_id, status) WHERE status IN ('open', 'validation_pending', 'balanced') AND is_deleted = FALSE;
CREATE INDEX idx_control_batches_eod ON core.control_batches(eod_run_id) WHERE eod_run_id IS NOT NULL;
CREATE INDEX idx_control_batches_type ON core.control_batches(tenant_id, batch_type, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_control_batches_correlation ON core.control_batches(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_control_batches_active_composite ON core.control_batches(tenant_id, status, effective_date) 
    WHERE is_deleted = FALSE;

COMMENT ON TABLE core.control_batches IS 'Control batches with hash totals and balancing per ISO 20022';
COMMENT ON COLUMN core.control_batches.hash_total IS 'Cryptographic hash of all entry references for integrity';

-- =============================================================================
-- CONTROL ENTRIES
-- =============================================================================
CREATE TABLE core.control_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES core.control_batches(id) ON DELETE CASCADE,
    
    -- Sequence
    sequence_number INTEGER NOT NULL,
    
    -- Content
    reference VARCHAR(100) NOT NULL,
    external_reference VARCHAR(100),
    
    -- Amounts
    amount DECIMAL(28,8) NOT NULL,
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('debit', 'credit')),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Hash
    row_hash VARCHAR(64) NOT NULL,
    hash_input TEXT, -- What was hashed (for verification)
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'valid' 
        CHECK (status IN ('valid', 'warning', 'error', 'posted', 'failed', 'rejected')),
    error_code VARCHAR(50),
    error_message TEXT,
    warning_message TEXT,
    
    -- Validation Results
    validation_rules_passed JSONB DEFAULT '[]',
    validation_rules_failed JSONB DEFAULT '[]',
    
    -- Link to Movement
    movement_id UUID REFERENCES core.value_movements(id),
    
    -- Account Info
    account_number VARCHAR(100),
    account_type VARCHAR(50),
    
    -- Counterparty
    counterparty_reference VARCHAR(100),
    counterparty_name VARCHAR(200),
    
    -- Metadata
    narrative TEXT,
    value_date DATE,
    attributes JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_entry_sequence UNIQUE (batch_id, sequence_number)
);

CREATE INDEX idx_control_entries_batch ON core.control_entries(batch_id, sequence_number);
CREATE INDEX idx_control_entries_status ON core.control_entries(batch_id, status) WHERE status IN ('error', 'failed');
CREATE INDEX idx_control_entries_movement ON core.control_entries(movement_id) WHERE movement_id IS NOT NULL;
CREATE INDEX idx_control_entries_reference ON core.control_entries(reference);

COMMENT ON TABLE core.control_entries IS 'Individual entries within a control batch';

-- =============================================================================
-- EOD RUNS (End of Day Processing)
-- =============================================================================
CREATE TABLE core.eod_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Date
    business_date DATE NOT NULL,
    fiscal_year INTEGER,
    fiscal_period INTEGER,
    
    -- Phase
    phase VARCHAR(20) NOT NULL DEFAULT 'preliminary' 
        CHECK (phase IN ('preliminary', 'processing', 'final', 'complete', 'failed', 'rollover')),
    
    -- Processing Stages
    stage VARCHAR(50) DEFAULT 'initialization',
    stages_completed TEXT[] DEFAULT '{}',
    stages_pending TEXT[] DEFAULT '{}',
    current_stage_started_at TIMESTAMPTZ,
    
    -- Control Totals
    total_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_containers INTEGER NOT NULL DEFAULT 0,
    total_movements INTEGER NOT NULL DEFAULT 0,
    total_batches INTEGER NOT NULL DEFAULT 0,
    
    -- Cutoff Times
    cutoff_times JSONB DEFAULT '{}', -- {"payments": "16:00:00+02", "securities": "15:30:00+02"}
    cutoff_breaches JSONB DEFAULT '[]',
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'running' 
        CHECK (status IN ('running', 'completed', 'failed', 'rollback', 'manual_intervention')),
    
    -- Timing
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Error Handling
    error_details JSONB,
    rollback_initiated_at TIMESTAMPTZ,
    rollback_completed_at TIMESTAMPTZ,
    
    -- Operator
    initiated_by UUID NOT NULL REFERENCES core.economic_agents(id),
    supervised_by UUID REFERENCES core.economic_agents(id),
    
    -- Reconciliation
    reconciliation_status VARCHAR(20) DEFAULT 'pending' CHECK (reconciliation_status IN ('pending', 'in_progress', 'balanced', 'unbalanced')),
    reconciliation_run_id UUID,
    
    CONSTRAINT unique_eod_date UNIQUE (tenant_id, business_date)
);

CREATE INDEX idx_eod_runs_date ON core.eod_runs(tenant_id, business_date DESC);
CREATE INDEX idx_eod_runs_status ON core.eod_runs(tenant_id, status) WHERE status IN ('running', 'failed', 'manual_intervention');
CREATE INDEX idx_eod_runs_phase ON core.eod_runs(tenant_id, phase);

COMMENT ON TABLE core.eod_runs IS 'End-of-day processing runs with stage tracking';

-- =============================================================================
-- EOD STAGE DEFINITIONS
-- =============================================================================
CREATE TABLE core.eod_stages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    stage_name VARCHAR(50) NOT NULL,
    stage_order INTEGER NOT NULL,
    stage_type VARCHAR(50) CHECK (stage_type IN ('automatic', 'manual', 'approval')),
    
    -- Dependencies
    depends_on_stages TEXT[] DEFAULT '{}',
    
    -- Processing
    procedure_name VARCHAR(100),
    max_duration_minutes INTEGER,
    
    -- Control
    is_mandatory BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT unique_stage_order UNIQUE (tenant_id, stage_order)
);

COMMENT ON TABLE core.eod_stages IS 'Configurable EOD processing stages';

-- =============================================================================
-- BATCH HISTORY
-- =============================================================================
CREATE TABLE core_history.batch_processing_log (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    batch_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- 'created', 'validation_started', 'validation_completed', 'posting_started', 'posted', 'error'
    
    event_data JSONB,
    performed_by UUID,
    
    PRIMARY KEY (time, batch_id, event_type)
);

SELECT create_hypertable('core_history.batch_processing_log', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_batch_log_batch ON core_history.batch_processing_log(batch_id, time DESC);

COMMENT ON TABLE core_history.batch_processing_log IS 'Audit trail of batch processing events';

-- =============================================================================
-- BATCH VALIDATION RULES
-- =============================================================================
CREATE TABLE core.batch_validation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN ('format', 'balance', 'reference', 'duplicate', 'limit')),
    
    -- Applicability
    applies_to_batch_types VARCHAR(50)[],
    
    -- Validation Logic
    validation_sql TEXT,
    validation_function VARCHAR(100),
    
    -- Error Handling
    severity VARCHAR(20) DEFAULT 'error' CHECK (severity IN ('error', 'warning', 'info')),
    error_code VARCHAR(50),
    error_message_template VARCHAR(255),
    
    -- Action
    reject_on_failure BOOLEAN DEFAULT TRUE,
    auto_correct BOOLEAN DEFAULT FALSE,
    auto_correct_function VARCHAR(100),
    
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 100,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_batch_rules_active ON core.batch_validation_rules(tenant_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_batch_rules_correlation ON core.batch_validation_rules(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.batch_validation_rules IS 'Configurable validation rules for batches';

-- =============================================================================
-- CONTROL BATCH TRIGGERS
-- =============================================================================

-- Trigger to update batch totals on entry insert/update
CREATE OR REPLACE FUNCTION core.update_batch_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_batch_id UUID;
BEGIN
    -- Use OLD.batch_id for DELETE, NEW.batch_id for INSERT/UPDATE
    v_batch_id := COALESCE(NEW.batch_id, OLD.batch_id);
    
    UPDATE core.control_batches
    SET 
        record_count = (SELECT COUNT(*) FROM core.control_entries WHERE batch_id = v_batch_id),
        debit_total = COALESCE((SELECT SUM(amount) FROM core.control_entries WHERE batch_id = v_batch_id AND direction = 'debit'), 0),
        credit_total = COALESCE((SELECT SUM(amount) FROM core.control_entries WHERE batch_id = v_batch_id AND direction = 'credit'), 0),
        amount_total = COALESCE((SELECT SUM(amount) FROM core.control_entries WHERE batch_id = v_batch_id AND direction = 'debit'), 0),
        hash_total = encode(
            digest(
                (SELECT string_agg(reference, '' ORDER BY sequence_number) FROM core.control_entries WHERE batch_id = v_batch_id),
                'sha256'
            ),
            'hex'
        ),
        updated_at = NOW()
    WHERE id = v_batch_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_batch_totals
    AFTER INSERT OR UPDATE OR DELETE ON core.control_entries
    FOR EACH ROW EXECUTE FUNCTION core.update_batch_totals();

-- =============================================================================
-- BATCH PROCESSING FUNCTIONS
-- =============================================================================

-- Function: Validate batch
CREATE OR REPLACE FUNCTION core.validate_batch(p_batch_id UUID)
RETURNS TABLE (
    is_valid BOOLEAN,
    error_count INTEGER,
    warning_count INTEGER,
    errors JSONB
) AS $$
DECLARE
    v_errors JSONB := '[]'::JSONB;
    v_error_count INTEGER := 0;
    v_warning_count INTEGER := 0;
    v_batch RECORD;
    v_rule RECORD;
BEGIN
    -- Get batch details
    SELECT * INTO v_batch FROM core.control_batches WHERE id = p_batch_id;
    
    IF v_batch IS NULL THEN
        RETURN QUERY SELECT FALSE, 1, 0, '[{"message": "Batch not found"}]'::JSONB;
        RETURN;
    END IF;
    
    -- Check record count
    IF v_batch.expected_record_count IS NOT NULL AND v_batch.record_count != v_batch.expected_record_count THEN
        v_errors := v_errors || jsonb_build_object(
            'severity', 'error',
            'code', 'RECORD_COUNT_MISMATCH',
            'message', format('Expected %s records, found %s', v_batch.expected_record_count, v_batch.record_count)
        );
        v_error_count := v_error_count + 1;
    END IF;
    
    -- Check totals
    IF v_batch.expected_total != 0 AND ABS(v_batch.variance) > 0.01 THEN
        v_errors := v_errors || jsonb_build_object(
            'severity', 'error',
            'code', 'TOTAL_MISMATCH',
            'message', format('Expected total %s, actual %s (variance: %s)', v_batch.expected_total, v_batch.amount_total, v_batch.variance)
        );
        v_error_count := v_error_count + 1;
    END IF;
    
    -- Check balance
    IF v_batch.debit_total != v_batch.credit_total THEN
        v_errors := v_errors || jsonb_build_object(
            'severity', 'error',
            'code', 'UNBALANCED_BATCH',
            'message', format('Debits (%s) do not equal credits (%s)', v_batch.debit_total, v_batch.credit_total)
        );
        v_error_count := v_error_count + 1;
    END IF;
    
    -- Check for errors in entries
    SELECT COUNT(*) INTO v_error_count 
    FROM core.control_entries 
    WHERE batch_id = p_batch_id AND status = 'error';
    
    -- Update batch status
    IF v_error_count > 0 THEN
        UPDATE core.control_batches 
        SET status = 'validation_failed', 
            error_count = v_error_count,
            validated_at = NOW()
        WHERE id = p_batch_id;
        
        RETURN QUERY SELECT FALSE, v_error_count, v_warning_count, v_errors;
    ELSE
        UPDATE core.control_batches 
        SET status = 'validated', 
            error_count = 0,
            validated_at = NOW()
        WHERE id = p_batch_id;
        
        RETURN QUERY SELECT TRUE, 0, v_warning_count, v_errors;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.validate_batch IS 'Validates a control batch and returns validation results';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.control_batches TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.control_entries TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.eod_runs TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.eod_stages TO finos_app;
GRANT SELECT, INSERT ON core_history.batch_processing_log TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.batch_validation_rules TO finos_app;
GRANT EXECUTE ON FUNCTION core.validate_batch TO finos_app;
