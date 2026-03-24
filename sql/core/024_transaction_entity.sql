-- =============================================================================
-- FINOS CORE KERNEL - TRANSACTION ENTITY (FIRST-CLASS CITIZEN)
-- =============================================================================
-- File: core/024_transaction_entity.sql
-- Description: Datomic-style transaction entities with complete metadata,
--              audit trail, and chain of custody tracking
-- Features: Transaction recording, event linking, status workflow, custody chain
-- Standards: ISO 27001, SOC2, Audit Requirements
-- =============================================================================

-- =============================================================================
-- TRANSACTIONS (First-Class Entity - The "Tx" in Datomic E-A-V-Tx-Op)
-- =============================================================================
CREATE TABLE core.transactions (
    tx_id BIGSERIAL,
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Transaction Classification
    tx_type VARCHAR(50) NOT NULL CHECK (tx_type IN ('financial', 'system', 'admin', 'migration', 'batch', 'reversal', 'adjustment')),
    tx_category VARCHAR(50) CHECK (tx_category IN ('movement', 'container', 'agent', 'configuration', 'security', 'maintenance')),
    
    -- Status Workflow
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'preparing', 'executing', 'committed', 'aborted', 'partially_committed', 'compensating', 'failed')),
    
    -- Actor Information (Chain of Custody)
    initiated_by VARCHAR(100) NOT NULL,  -- User or service ID
    initiated_by_type VARCHAR(20) CHECK (initiated_by_type IN ('user', 'service', 'system', 'batch_job', 'api')),
    authorized_by VARCHAR(100)[],  -- Multi-authorization support
    approval_required BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Session Context
    session_id UUID,
    correlation_id UUID,  -- For distributed tracing
    causation_id UUID,    -- What caused this transaction
    idempotency_key VARCHAR(100),
    
    -- Network Context
    ip_address INET,
    user_agent TEXT,
    device_fingerprint VARCHAR(256),
    geolocation JSONB,  -- {country, city, lat, lon}
    
    -- Transaction Timing (4D Time)
    prepared_at TIMESTAMPTZ,
    execution_started_at TIMESTAMPTZ,
    committed_at TIMESTAMPTZ,
    aborted_at TIMESTAMPTZ,
    valid_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Business time
    
    -- Performance Metrics
    preparation_time_ms INTEGER,  -- Time from pending to prepared
    execution_time_ms INTEGER,    -- Time from prepared to committed/aborted
    total_time_ms INTEGER,        -- Total transaction time
    
    -- Transaction Content
    description TEXT,
    reason_code VARCHAR(50),
    business_reason TEXT,
    reference_number VARCHAR(100),  -- External reference
    external_system VARCHAR(50),    -- Source system
    
    -- Financial Impact (if applicable)
    total_debit_amount DECIMAL(28,8),
    total_credit_amount DECIMAL(28,8),
    currency CHAR(3),
    
    -- Scope
    affected_entities UUID[],  -- Entities modified by this transaction
    affected_containers UUID[],
    event_count INTEGER DEFAULT 0,
    
    -- Transaction Metadata
    tx_metadata JSONB DEFAULT '{}',  -- Flexible metadata storage
    tags TEXT[],
    
    -- Compensation (for sagas/long-running transactions)
    parent_tx_id BIGINT REFERENCES core.transactions(tx_id),
    compensation_tx_id BIGINT REFERENCES core.transactions(tx_id),
    is_compensation BOOLEAN DEFAULT FALSE,
    
    -- Cryptographic Integrity
    tx_hash VARCHAR(64),  -- Hash of all transaction data
    signature BYTEA,      -- Digital signature of transaction
    
    -- Constraints
    CONSTRAINT transactions_pkey PRIMARY KEY (tx_id),
    CONSTRAINT unique_tx_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key),
    CONSTRAINT chk_commit_order CHECK (
        (status = 'committed' AND committed_at IS NOT NULL) OR
        (status != 'committed')
    ),
    CONSTRAINT chk_approval_order CHECK (
        (approved_by IS NULL) OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)
    )
);

-- Critical indexes
CREATE INDEX idx_transactions_tenant ON core.transactions(tenant_id, valid_time DESC);
CREATE INDEX idx_transactions_status ON core.transactions(tenant_id, status) WHERE status IN ('pending', 'executing', 'partially_committed');
CREATE INDEX idx_transactions_correlation ON core.transactions(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_transactions_initiator ON core.transactions(initiated_by, valid_time DESC);
CREATE INDEX idx_transactions_type ON core.transactions(tx_type, tx_category, valid_time DESC);
CREATE INDEX idx_transactions_reference ON core.transactions(tenant_id, reference_number) WHERE reference_number IS NOT NULL;
CREATE INDEX idx_transactions_parent ON core.transactions(parent_tx_id) WHERE parent_tx_id IS NOT NULL;
CREATE INDEX idx_transactions_idempotency ON core.transactions(tenant_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

COMMENT ON TABLE core.transactions IS 'First-class transaction entities - the Tx in Datomic E-A-V-Tx-Op model';
COMMENT ON COLUMN core.transactions.tx_id IS 'Globally unique, monotonically increasing transaction identifier';
COMMENT ON COLUMN core.transactions.committed_at IS 'System time when transaction was committed (serialization point)';
COMMENT ON COLUMN core.transactions.valid_time IS 'Business time when transaction is effective (bitemporal)';

-- =============================================================================
-- TRANSACTION EVENTS (Links transactions to immutable events)
-- =============================================================================
CREATE TABLE core.transaction_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tx_id BIGINT NOT NULL REFERENCES core.transactions(tx_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    -- Event Reference
    event_id BIGINT NOT NULL REFERENCES core_crypto.immutable_events(event_id),
    
    -- Event Role in Transaction
    event_role VARCHAR(20) DEFAULT 'primary' CHECK (event_role IN ('primary', 'compensation', 'audit', 'notification', 'side_effect')),
    sequence_number INTEGER,  -- Order within transaction
    
    -- Event Details (denormalized for query performance)
    event_type VARCHAR(100),
    entity_type VARCHAR(50),
    entity_id UUID,
    datom_attribute VARCHAR(200),
    
    -- Audit
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    linked_by VARCHAR(100),
    
    UNIQUE(tx_id, event_id)
);

CREATE INDEX idx_transaction_events_tx ON core.transaction_events(tx_id, sequence_number);
CREATE INDEX idx_transaction_events_event ON core.transaction_events(event_id);
CREATE INDEX idx_transaction_events_entity ON core.transaction_events(tenant_id, entity_type, entity_id);
CREATE INDEX idx_transaction_events_tenant ON core.transaction_events(tenant_id, tx_id);

COMMENT ON TABLE core.transaction_events IS 'Many-to-many link between transactions and immutable events';

-- =============================================================================
-- TRANSACTION LEGS (Links transactions to value movements)
-- =============================================================================
CREATE TABLE core.transaction_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tx_id BIGINT NOT NULL REFERENCES core.transactions(tx_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    -- Movement Reference
    movement_id UUID NOT NULL REFERENCES core.value_movements(id),
    
    -- Movement Role
    movement_role VARCHAR(20) DEFAULT 'primary' CHECK (movement_role IN ('primary', 'reversal', 'adjustment', 'correction')),
    sequence_number INTEGER,
    
    -- Financial Impact (denormalized)
    debit_amount DECIMAL(28,8),
    credit_amount DECIMAL(28,8),
    currency CHAR(3),
    
    -- Audit
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(tx_id, movement_id)
);

CREATE INDEX idx_transaction_movements_tx ON core.transaction_movements(tx_id);
CREATE INDEX idx_transaction_movements_movement ON core.transaction_movements(movement_id);
CREATE INDEX idx_transaction_movements_tenant ON core.transaction_movements(tenant_id, tx_id);

COMMENT ON TABLE core.transaction_movements IS 'Links transactions to value movements';

-- =============================================================================
-- TRANSACTION AUDIT LOG (Detailed step-by-step audit)
-- =============================================================================
CREATE TABLE core.transaction_audit_log (
    audit_id BIGSERIAL,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    tx_id BIGINT NOT NULL REFERENCES core.transactions(tx_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    -- Audit Entry
    audit_type VARCHAR(50) NOT NULL CHECK (audit_type IN ('created', 'prepared', 'execution_started', 'step_completed', 'committed', 'aborted', 'compensated', 'verified')),
    step_name VARCHAR(100),
    step_number INTEGER,
    
    -- Details
    description TEXT,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    metadata JSONB,
    
    -- Actor
    performed_by VARCHAR(100),
    performed_by_type VARCHAR(20),
    
    PRIMARY KEY (audit_id, event_time)
);

-- Convert to hypertable
SELECT create_hypertable('core.transaction_audit_log', 'event_time', 
                         chunk_time_interval => INTERVAL '1 week',
                         if_not_exists => TRUE);

CREATE INDEX idx_transaction_audit_tx ON core.transaction_audit_log(tx_id, event_time);
CREATE INDEX idx_transaction_audit_type ON core.transaction_audit_log(audit_type, event_time);

COMMENT ON TABLE core.transaction_audit_log IS 'Detailed step-by-step audit of transaction execution';

-- =============================================================================
-- TRANSACTION STATUS HISTORY (State machine transitions)
-- =============================================================================
CREATE TABLE core.transaction_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tx_id BIGINT NOT NULL REFERENCES core.transactions(tx_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    
    from_status VARCHAR(20) NOT NULL,
    to_status VARCHAR(20) NOT NULL,
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transitioned_by VARCHAR(100),
    
    reason TEXT,
    metadata JSONB
);

CREATE INDEX idx_transaction_status_tx ON core.transaction_status_history(tx_id, transitioned_at);

COMMENT ON TABLE core.transaction_status_history IS 'Records all status transitions for audit trail';

-- =============================================================================
-- TRANSACTION FUNCTIONS
-- =============================================================================

-- Function: Create a new transaction
CREATE OR REPLACE FUNCTION core.create_transaction(
    p_tenant_id UUID,
    p_tx_type VARCHAR,
    p_initiated_by VARCHAR,
    p_description TEXT DEFAULT NULL,
    p_reason_code VARCHAR DEFAULT NULL,
    p_correlation_id UUID DEFAULT NULL,
    p_causation_id UUID DEFAULT NULL,
    p_idempotency_key VARCHAR DEFAULT NULL,
    p_session_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_tx_metadata JSONB DEFAULT '{}',
    p_tags TEXT[] DEFAULT NULL,
    p_approval_required BOOLEAN DEFAULT FALSE
)
RETURNS BIGINT AS $$
DECLARE
    v_tx_id BIGINT;
BEGIN
    INSERT INTO core.transactions (
        tenant_id, tx_type, initiated_by, initiated_by_type,
        description, reason_code,
        correlation_id, causation_id, idempotency_key,
        session_id, ip_address, user_agent,
        tx_metadata, tags, approval_required,
        status, valid_time
    ) VALUES (
        p_tenant_id, p_tx_type, p_initiated_by, 
        CASE WHEN p_initiated_by LIKE 'svc.%' THEN 'service' ELSE 'user' END,
        p_description, p_reason_code,
        COALESCE(p_correlation_id, gen_random_uuid()),
        p_causation_id,
        p_idempotency_key,
        p_session_id,
        p_ip_address,
        p_user_agent,
        p_tx_metadata,
        p_tags,
        p_approval_required,
        CASE WHEN p_approval_required THEN 'pending' ELSE 'preparing' END,
        NOW()
    )
    RETURNING tx_id INTO v_tx_id;
    
    -- Log creation
    INSERT INTO core.transaction_audit_log (
        tx_id, tenant_id, audit_type, description, new_status, performed_by
    ) VALUES (
        v_tx_id, p_tenant_id, 'created', 
        format('Transaction %s created by %s', v_tx_id, p_initiated_by),
        CASE WHEN p_approval_required THEN 'pending' ELSE 'preparing' END,
        p_initiated_by
    );
    
    RETURN v_tx_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.create_transaction IS 'Creates a new transaction entity with full audit trail';

-- Function: Start transaction execution
CREATE OR REPLACE FUNCTION core.start_transaction_execution(
    p_tx_id BIGINT,
    p_performed_by VARCHAR DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_tx RECORD;
    v_old_status VARCHAR;
BEGIN
    SELECT * INTO v_tx FROM core.transactions WHERE tx_id = p_tx_id;
    
    IF v_tx IS NULL THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;
    
    IF v_tx.status NOT IN ('pending', 'preparing') THEN
        RAISE EXCEPTION 'Transaction % cannot be started from status %', p_tx_id, v_tx.status;
    END IF;
    
    IF v_tx.approval_required AND v_tx.approved_by IS NULL THEN
        RAISE EXCEPTION 'Transaction % requires approval before execution', p_tx_id;
    END IF;
    
    v_old_status := v_tx.status;
    
    UPDATE core.transactions
    SET 
        status = 'executing',
        execution_started_at = NOW(),
        preparation_time_ms = EXTRACT(EPOCH FROM (NOW() - created_at)) * 1000
    WHERE tx_id = p_tx_id;
    
    -- Log transition
    INSERT INTO core.transaction_status_history (tx_id, tenant_id, from_status, to_status, transitioned_by, reason)
    VALUES (p_tx_id, v_tx.tenant_id, v_old_status, 'executing', p_performed_by, 'Execution started');
    
    INSERT INTO core.transaction_audit_log (tx_id, tenant_id, audit_type, old_status, new_status, performed_by)
    VALUES (p_tx_id, v_tx.tenant_id, 'execution_started', v_old_status, 'executing', p_performed_by);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Commit a transaction
CREATE OR REPLACE FUNCTION core.commit_transaction(
    p_tx_id BIGINT,
    p_performed_by VARCHAR DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_tx RECORD;
    v_old_status VARCHAR;
BEGIN
    SELECT * INTO v_tx FROM core.transactions WHERE tx_id = p_tx_id;
    
    IF v_tx IS NULL THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;
    
    IF v_tx.status NOT IN ('executing', 'partially_committed') THEN
        RAISE EXCEPTION 'Transaction % cannot be committed from status %', p_tx_id, v_tx.status;
    END IF;
    
    v_old_status := v_tx.status;
    
    -- Calculate transaction hash
    UPDATE core.transactions
    SET 
        status = 'committed',
        committed_at = NOW(),
        total_time_ms = EXTRACT(EPOCH FROM (NOW() - created_at)) * 1000,
        execution_time_ms = EXTRACT(EPOCH FROM (NOW() - execution_started_at)) * 1000,
        tx_hash = encode(digest(
            tx_id::text || tenant_id::text || initiated_by || COALESCE(total_debit_amount::text, '0') || 
            COALESCE(total_credit_amount::text, '0') || event_count::text,
            'sha256'
        ), 'hex')
    WHERE tx_id = p_tx_id;
    
    -- Log transition
    INSERT INTO core.transaction_status_history (tx_id, tenant_id, from_status, to_status, transitioned_by, reason)
    VALUES (p_tx_id, v_tx.tenant_id, v_old_status, 'committed', p_performed_by, 'Transaction committed');
    
    INSERT INTO core.transaction_audit_log (tx_id, tenant_id, audit_type, old_status, new_status, performed_by, description)
    VALUES (p_tx_id, v_tx.tenant_id, 'committed', v_old_status, 'committed', p_performed_by, 
            format('Transaction committed with %s events', v_tx.event_count));
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Abort a transaction
CREATE OR REPLACE FUNCTION core.abort_transaction(
    p_tx_id BIGINT,
    p_reason TEXT DEFAULT 'Aborted by system',
    p_performed_by VARCHAR DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_tx RECORD;
    v_old_status VARCHAR;
BEGIN
    SELECT * INTO v_tx FROM core.transactions WHERE tx_id = p_tx_id;
    
    IF v_tx IS NULL THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;
    
    IF v_tx.status = 'committed' THEN
        RAISE EXCEPTION 'Cannot abort already committed transaction %', p_tx_id;
    END IF;
    
    v_old_status := v_tx.status;
    
    UPDATE core.transactions
    SET 
        status = 'aborted',
        aborted_at = NOW(),
        total_time_ms = EXTRACT(EPOCH FROM (NOW() - created_at)) * 1000
    WHERE tx_id = p_tx_id;
    
    -- Log transition
    INSERT INTO core.transaction_status_history (tx_id, tenant_id, from_status, to_status, transitioned_by, reason)
    VALUES (p_tx_id, v_tx.tenant_id, v_old_status, 'aborted', p_performed_by, p_reason);
    
    INSERT INTO core.transaction_audit_log (tx_id, tenant_id, audit_type, old_status, new_status, performed_by, description)
    VALUES (p_tx_id, v_tx.tenant_id, 'aborted', v_old_status, 'aborted', p_performed_by, p_reason);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Approve a transaction
CREATE OR REPLACE FUNCTION core.approve_transaction(
    p_tx_id BIGINT,
    p_approved_by VARCHAR,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_tx RECORD;
BEGIN
    SELECT * INTO v_tx FROM core.transactions WHERE tx_id = p_tx_id;
    
    IF v_tx IS NULL THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;
    
    IF NOT v_tx.approval_required THEN
        RAISE EXCEPTION 'Transaction % does not require approval', p_tx_id;
    END IF;
    
    IF v_tx.approved_by IS NOT NULL THEN
        RAISE EXCEPTION 'Transaction % already approved by %', p_tx_id, v_tx.approved_by;
    END IF;
    
    UPDATE core.transactions
    SET 
        approved_by = p_approved_by,
        approved_at = NOW(),
        status = 'preparing'
    WHERE tx_id = p_tx_id;
    
    INSERT INTO core.transaction_audit_log (tx_id, tenant_id, audit_type, performed_by, description)
    VALUES (p_tx_id, v_tx.tenant_id, 'verified', p_approved_by, 
            COALESCE(p_notes, format('Approved by %s', p_approved_by)));
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- EVENT/MOVEMENT LINKING
-- =============================================================================

-- Function: Link an event to a transaction
CREATE OR REPLACE FUNCTION core.link_event_to_transaction(
    p_tx_id BIGINT,
    p_event_id BIGINT,
    p_event_role VARCHAR DEFAULT 'primary',
    p_sequence_number INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_link_id UUID;
    v_event RECORD;
BEGIN
    -- Get event details
    SELECT * INTO v_event FROM core_crypto.immutable_events WHERE event_id = p_event_id;
    
    IF v_event IS NULL THEN
        RAISE EXCEPTION 'Event % not found', p_event_id;
    END IF;
    
    INSERT INTO core.transaction_events (
        tx_id, tenant_id, event_id, event_role, sequence_number,
        event_type, entity_type, entity_id, datom_attribute
    ) VALUES (
        p_tx_id, v_event.tenant_id, p_event_id, p_event_role, p_sequence_number,
        v_event.event_type, v_event.event_category, v_event.datom_entity_id, v_event.datom_attribute
    )
    RETURNING id INTO v_link_id;
    
    -- Update transaction event count
    UPDATE core.transactions
    SET 
        event_count = event_count + 1,
        affected_entities = array_append_unique(affected_entities, v_event.datom_entity_id),
        datom_entity_id = v_event.datom_entity_id
    WHERE tx_id = p_tx_id;
    
    RETURN v_link_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.link_event_to_transaction IS 'Links an immutable event to a transaction';

-- Function: Link a movement to a transaction
CREATE OR REPLACE FUNCTION core.link_movement_to_transaction(
    p_tx_id BIGINT,
    p_movement_id UUID,
    p_movement_role VARCHAR DEFAULT 'primary',
    p_sequence_number INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_link_id UUID;
    v_movement RECORD;
BEGIN
    SELECT * INTO v_movement FROM core.value_movements WHERE id = p_movement_id;
    
    IF v_movement IS NULL THEN
        RAISE EXCEPTION 'Movement % not found', p_movement_id;
    END IF;
    
    INSERT INTO core.transaction_movements (
        tx_id, tenant_id, movement_id, movement_role, sequence_number,
        debit_amount, credit_amount, currency
    ) VALUES (
        p_tx_id, v_movement.tenant_id, p_movement_id, p_movement_role, p_sequence_number,
        v_movement.total_debits, v_movement.total_credits, v_movement.entry_currency
    )
    RETURNING id INTO v_link_id;
    
    -- Update transaction financial totals
    UPDATE core.transactions
    SET 
        total_debit_amount = COALESCE(total_debit_amount, 0) + v_movement.total_debits,
        total_credit_amount = COALESCE(total_credit_amount, 0) + v_movement.total_credits,
        currency = v_movement.entry_currency
    WHERE tx_id = p_tx_id;
    
    RETURN v_link_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- QUERY FUNCTIONS
-- =============================================================================

-- Function: Get transaction with all related data
CREATE OR REPLACE FUNCTION core.get_transaction_details(
    p_tx_id BIGINT
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_tx RECORD;
BEGIN
    SELECT * INTO v_tx FROM core.transactions WHERE tx_id = p_tx_id;
    
    IF v_tx IS NULL THEN
        RETURN NULL;
    END IF;
    
    SELECT jsonb_build_object(
        'transaction', row_to_json(t),
        'events', (
            SELECT jsonb_agg(row_to_json(te))
            FROM core.transaction_events te
            WHERE te.tx_id = p_tx_id
            ORDER BY te.sequence_number
        ),
        'movements', (
            SELECT jsonb_agg(row_to_json(tm))
            FROM core.transaction_movements tm
            WHERE tm.tx_id = p_tx_id
        ),
        'audit_log', (
            SELECT jsonb_agg(row_to_json(tal))
            FROM core.transaction_audit_log tal
            WHERE tal.tx_id = p_tx_id
            ORDER BY tal.event_time
        ),
        'status_history', (
            SELECT jsonb_agg(row_to_json(tsh))
            FROM core.transaction_status_history tsh
            WHERE tsh.tx_id = p_tx_id
            ORDER BY tsh.transitioned_at
        )
    ) INTO v_result
    FROM core.transactions t
    WHERE t.tx_id = p_tx_id;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_transaction_details IS 'Returns complete transaction details with all related data';

-- Function: Get transactions by entity
CREATE OR REPLACE FUNCTION core.get_transactions_by_entity(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    tx_id BIGINT,
    tx_type VARCHAR,
    status VARCHAR,
    initiated_by VARCHAR,
    committed_at TIMESTAMPTZ,
    event_count INTEGER,
    total_amount DECIMAL(28,8)
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        t.tx_id,
        t.tx_type,
        t.status,
        t.initiated_by,
        t.committed_at,
        t.event_count,
        COALESCE(t.total_debit_amount, t.total_credit_amount, 0)
    FROM core.transactions t
    JOIN core.transaction_events te ON te.tx_id = t.tx_id
    WHERE t.tenant_id = p_tenant_id
      AND te.entity_id = p_entity_id
      AND (p_start_date IS NULL OR t.valid_time >= p_start_date)
      AND (p_end_date IS NULL OR t.valid_time <= p_end_date)
    ORDER BY t.committed_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get transaction chain (parent/child relationships)
CREATE OR REPLACE FUNCTION core.get_transaction_chain(
    p_tx_id BIGINT
)
RETURNS TABLE (
    level INTEGER,
    tx_id BIGINT,
    tx_type VARCHAR,
    status VARCHAR,
    is_compensation BOOLEAN,
    relationship VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE chain AS (
        -- Base: the starting transaction
        SELECT 
            0 AS lvl,
            t.tx_id,
            t.tx_type,
            t.status,
            t.is_compensation,
            'self'::VARCHAR AS rel,
            t.parent_tx_id,
            t.compensation_tx_id
        FROM core.transactions t
        WHERE t.tx_id = p_tx_id
        
        UNION ALL
        
        -- Parents
        SELECT 
            c.lvl - 1,
            t.tx_id,
            t.tx_type,
            t.status,
            t.is_compensation,
            'parent'::VARCHAR,
            t.parent_tx_id,
            t.compensation_tx_id
        FROM chain c
        JOIN core.transactions t ON t.tx_id = c.parent_tx_id
        WHERE c.lvl > -10  -- Limit depth
        
        UNION ALL
        
        -- Children
        SELECT 
            c.lvl + 1,
            t.tx_id,
            t.tx_type,
            t.status,
            t.is_compensation,
            CASE WHEN t.is_compensation THEN 'compensation' ELSE 'child' END::VARCHAR,
            t.parent_tx_id,
            t.compensation_tx_id
        FROM chain c
        JOIN core.transactions t ON t.parent_tx_id = c.tx_id
        WHERE c.lvl < 10  -- Limit depth
    )
    SELECT DISTINCT ON (c.tx_id)
        c.lvl,
        c.tx_id,
        c.tx_type,
        c.status,
        c.is_compensation,
        c.rel
    FROM chain c
    ORDER BY c.tx_id, c.lvl;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- STATISTICS AND MONITORING
-- =============================================================================

-- View: Transaction statistics by tenant
CREATE OR REPLACE VIEW core.transaction_statistics AS
SELECT 
    tenant_id,
    DATE_TRUNC('day', valid_time) AS day,
    tx_type,
    status,
    COUNT(*) AS transaction_count,
    COUNT(*) FILTER (WHERE status = 'committed') AS committed_count,
    COUNT(*) FILTER (WHERE status = 'aborted') AS aborted_count,
    AVG(total_time_ms) FILTER (WHERE status = 'committed') AS avg_execution_time_ms,
    SUM(total_debit_amount) FILTER (WHERE status = 'committed') AS total_debit_amount,
    SUM(total_credit_amount) FILTER (WHERE status = 'committed') AS total_credit_amount,
    SUM(event_count) AS total_events
FROM core.transactions
WHERE valid_time > NOW() - INTERVAL '30 days'
GROUP BY tenant_id, DATE_TRUNC('day', valid_time), tx_type, status;

COMMENT ON VIEW core.transaction_statistics IS 'Daily transaction statistics by tenant';

-- Function: Get transaction volume metrics
CREATE OR REPLACE FUNCTION core.get_transaction_metrics(
    p_tenant_id UUID,
    p_start_date TIMESTAMPTZ DEFAULT NOW() - INTERVAL '7 days',
    p_end_date TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    metric VARCHAR,
    value DECIMAL(28,8),
    unit VARCHAR
) AS $$
BEGIN
    -- Total transactions
    RETURN QUERY
    SELECT 
        'total_transactions'::VARCHAR,
        COUNT(*)::DECIMAL,
        'count'::VARCHAR
    FROM core.transactions
    WHERE tenant_id = p_tenant_id
      AND valid_time BETWEEN p_start_date AND p_end_date;
    
    -- Committed transactions
    RETURN QUERY
    SELECT 
        'committed_transactions'::VARCHAR,
        COUNT(*)::DECIMAL,
        'count'::VARCHAR
    FROM core.transactions
    WHERE tenant_id = p_tenant_id
      AND valid_time BETWEEN p_start_date AND p_end_date
      AND status = 'committed';
    
    -- Success rate
    RETURN QUERY
    SELECT 
        'commit_success_rate'::VARCHAR,
        ROUND(
            COUNT(*) FILTER (WHERE status = 'committed')::DECIMAL / 
            NULLIF(COUNT(*), 0) * 100, 2
        ),
        'percent'::VARCHAR
    FROM core.transactions
    WHERE tenant_id = p_tenant_id
      AND valid_time BETWEEN p_start_date AND p_end_date;
    
    -- Average execution time
    RETURN QUERY
    SELECT 
        'avg_execution_time_ms'::VARCHAR,
        AVG(total_time_ms)::DECIMAL,
        'milliseconds'::VARCHAR
    FROM core.transactions
    WHERE tenant_id = p_tenant_id
      AND valid_time BETWEEN p_start_date AND p_end_date
      AND status = 'committed';
    
    -- Total value moved
    RETURN QUERY
    SELECT 
        'total_value_moved'::VARCHAR,
        COALESCE(SUM(total_debit_amount), 0)::DECIMAL,
        'currency'::VARCHAR
    FROM core.transactions
    WHERE tenant_id = p_tenant_id
      AND valid_time BETWEEN p_start_date AND p_end_date
      AND status = 'committed';
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.transactions TO finos_app;
GRANT SELECT, INSERT ON core.transaction_events TO finos_app;
GRANT SELECT, INSERT ON core.transaction_movements TO finos_app;
GRANT SELECT, INSERT ON core.transaction_audit_log TO finos_app;
GRANT SELECT, INSERT ON core.transaction_status_history TO finos_app;

GRANT EXECUTE ON FUNCTION core.create_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.start_transaction_execution TO finos_app;
GRANT EXECUTE ON FUNCTION core.commit_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.abort_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.approve_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.link_event_to_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.link_movement_to_transaction TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_transaction_details TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.get_transactions_by_entity TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.get_transaction_chain TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.get_transaction_metrics TO finos_app, finos_readonly;

-- =============================================================================
