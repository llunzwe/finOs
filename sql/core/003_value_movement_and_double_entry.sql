-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 3: VALUE MOVEMENT & DOUBLE-ENTRY
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Immutable Ledger, Conservation Enforcement, Multi-currency, Bitemporal
-- Standards: ISO 20022, IFRS, Double-Entry Accounting
-- =============================================================================

-- =============================================================================
-- MOVEMENT TYPES (Reference Data)
-- =============================================================================
CREATE TABLE core.movement_types (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Accounting Impact
    requires_balancing BOOLEAN NOT NULL DEFAULT TRUE,
    default_coa_debit VARCHAR(50),
    default_coa_credit VARCHAR(50),
    
    -- Workflow
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    can_be_reversed BOOLEAN NOT NULL DEFAULT TRUE,
    reversal_type VARCHAR(20) CHECK (reversal_type IN ('contra', 'negative', 'replacement')),
    
    -- ISO 20022 Mapping
    iso20022_message_type VARCHAR(50),
    iso20022_business_area VARCHAR(50),
    
    -- Metadata
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    CONSTRAINT chk_movement_type_valid_dates CHECK (valid_from < valid_to)
);

COMMENT ON TABLE core.movement_types IS 'Universal movement type classification per ISO 20022';

-- Insert 9 Universal Movement Types
INSERT INTO core.movement_types (code, name, description, requires_balancing, reversal_type, iso20022_message_type) VALUES
('TRANSFER', 'Transfer', 'Value moves from A to B (same unit)', TRUE, 'contra', 'pacs.008'),
('EXCHANGE', 'Exchange', 'Currency conversion or barter', TRUE, 'contra', 'pacs.009'),
('ACCRUAL', 'Accrual', 'Recognition over time (interest, fees)', TRUE, 'contra', 'camt.052'),
('ALLOCATION', 'Allocation', 'One-to-many distribution (dividends)', TRUE, 'contra', 'semt.017'),
('AGGREGATION', 'Aggregation', 'Many-to-one collection (taxes)', TRUE, 'contra', 'pacs.003'),
('TRANSFORMATION', 'Transformation', 'Reclassification (cash to equity)', TRUE, 'contra', 'semt.018'),
('SETTLEMENT', 'Settlement', 'Finality of pending transaction', TRUE, 'contra', 'semt.002'),
('REVERSAL', 'Reversal', 'Correction of error', TRUE, 'negative', 'camt.056'),
('ADJUSTMENT', 'Adjustment', 'Revaluation without prior movement', TRUE, 'contra', 'camt.053')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- VALUE MOVEMENTS (Headers)
-- =============================================================================
CREATE TABLE core.value_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Classification
    type VARCHAR(50) NOT NULL REFERENCES core.movement_types(code),
    reference VARCHAR(100) NOT NULL,
    
    -- Status Workflow
    status VARCHAR(20) NOT NULL DEFAULT 'draft' 
        CHECK (status IN ('draft', 'pending', 'posted', 'reversing', 'reversed', 'failed', 'rejected')),
    
    -- Temporal (Axiom II - 4D Time)
    entry_date DATE NOT NULL,
    value_date DATE NOT NULL,
    posted_at TIMESTAMPTZ,
    reversed_at TIMESTAMPTZ,
    reversal_movement_id UUID,
    
    -- Monetary Totals (Conservation of Value)
    total_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Multi-currency
    entry_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    functional_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    exchange_rate DECIMAL(28,12) NOT NULL DEFAULT 1.0,
    exchange_rate_source VARCHAR(50),
    
    -- Control Totals (Batching)
    control_hash VARCHAR(64),
    batch_id UUID,
    batch_sequence INTEGER,
    
    -- Business Context
    product_family VARCHAR(50),
    product_type VARCHAR(50),
    trigger_event VARCHAR(50),
    cohort_id VARCHAR(100),
    channel VARCHAR(50),
    context JSONB NOT NULL DEFAULT '{}',
    
    -- Session/Authorization
    session_id UUID,
    authorized_by UUID,
    authorization_method VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    
    -- Anchoring (Event Sourcing)
    immutable_event_id BIGINT,
    merkle_leaf VARCHAR(64),
    anchor_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (anchor_status IN ('pending', 'anchored', 'confirmed', 'failed')),
    
    -- Reconciliation
    reconciliation_status VARCHAR(20) DEFAULT 'unreconciled'
        CHECK (reconciliation_status IN ('unreconciled', 'matched', 'exception', 'adjusted')),
    reconciliation_run_id UUID,
    
    -- Temporal (Bitemporal)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Idempotency + Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Constraints
    CONSTRAINT unique_movement_reference UNIQUE (tenant_id, reference),
    CONSTRAINT unique_movement_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key),
    CONSTRAINT chk_conservation CHECK (total_debits = total_credits),
    CONSTRAINT chk_value_date CHECK (value_date >= entry_date),
    CONSTRAINT chk_posted_immutable CHECK (
        (status = 'posted' AND posted_at IS NOT NULL) OR 
        (status != 'posted')
    ),
    CONSTRAINT chk_positive_totals CHECK (total_debits >= 0 AND total_credits >= 0)
) PARTITION BY LIST (tenant_id);

-- Create default partition
CREATE TABLE core.value_movements_default PARTITION OF core.value_movements DEFAULT;

-- Critical indexes (-3.2)
CREATE INDEX idx_movements_tenant_ref ON core.value_movements(tenant_id, reference);
CREATE INDEX idx_movements_status ON core.value_movements(tenant_id, status) 
    WHERE status IN ('pending', 'posted') AND is_deleted = FALSE;
CREATE INDEX idx_movements_entry_date ON core.value_movements(tenant_id, entry_date);
CREATE INDEX idx_movements_value_date ON core.value_movements(tenant_id, value_date);
CREATE INDEX idx_movements_batch ON core.value_movements(batch_id) WHERE batch_id IS NOT NULL;
CREATE INDEX idx_movements_temporal ON core.value_movements(valid_from, valid_to) WHERE valid_to > NOW();
CREATE INDEX idx_movements_context ON core.value_movements USING GIN(context);
CREATE INDEX idx_movements_posted_at ON core.value_movements(posted_at) WHERE posted_at IS NOT NULL;
CREATE INDEX idx_movements_correlation ON core.value_movements(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_movements_active_composite ON core.value_movements(tenant_id, valid_from, valid_to) 
    WHERE is_deleted = FALSE;

COMMENT ON TABLE core.value_movements IS 'Immutable double-entry movement headers with conservation enforcement';
COMMENT ON COLUMN core.value_movements.total_debits IS 'Sum of all debit legs (must equal total_credits)';

-- =============================================================================
-- MOVEMENT LEGS (Double-Entry Lines)
-- =============================================================================
CREATE TABLE core.movement_legs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    movement_id UUID NOT NULL REFERENCES core.value_movements(id) ON DELETE CASCADE,
    
    -- The Affected Container
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Direction (T-Account Entry)
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('debit', 'credit')),
    
    -- Amounts (High Precision)
    amount DECIMAL(28,8) NOT NULL,
    amount_in_functional_currency DECIMAL(28,8),
    exchange_rate DECIMAL(28,12) DEFAULT 1.0,
    
    -- Chart of Accounts
    account_code VARCHAR(50),
    account_name VARCHAR(200),
    
    -- Sequence for Presentation
    sequence_number INTEGER NOT NULL DEFAULT 1,
    
    -- Individual Leg Status
    leg_status VARCHAR(20) DEFAULT 'posted' 
        CHECK (leg_status IN ('draft', 'pending', 'posted', 'failed', 'reversed')),
    failure_reason VARCHAR(200),
    
    -- Dimensions (Analytics)
    cost_center VARCHAR(50),
    project_code VARCHAR(50),
    department VARCHAR(50),
    geography VARCHAR(50),
    product_line VARCHAR(50),
    custom_dimensions JSONB DEFAULT '{}',
    
    -- Links
    obligation_id UUID,
    document_id UUID,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Constraints
    CONSTRAINT unique_leg_sequence UNIQUE (movement_id, sequence_number),
    CONSTRAINT chk_non_zero_amount CHECK (amount != 0),
    CONSTRAINT chk_leg_precision CHECK (amount = round(amount, 8))
);

CREATE INDEX idx_legs_movement ON core.movement_legs(movement_id);
CREATE INDEX idx_legs_container ON core.movement_legs(container_id);
CREATE INDEX idx_legs_container_direction ON core.movement_legs(container_id, direction, created_at);
CREATE INDEX idx_legs_account ON core.movement_legs(account_code);
CREATE INDEX idx_legs_dimensions ON core.movement_legs USING GIN(custom_dimensions);
CREATE INDEX idx_legs_tenant ON core.movement_legs(tenant_id);
CREATE INDEX idx_legs_composite ON core.movement_legs(tenant_id, container_id, created_at);

COMMENT ON TABLE core.movement_legs IS 'Individual double-entry legs forming balanced movements';

-- =============================================================================
-- CONSERVATION OF VALUE TRIGGER
-- =============================================================================
CREATE OR REPLACE FUNCTION core.validate_conservation_of_value()
RETURNS TRIGGER AS $$
DECLARE
    v_sum_debits DECIMAL(28,8);
    v_sum_credits DECIMAL(28,8);
    v_total_debits DECIMAL(28,8);
    v_total_credits DECIMAL(28,8);
BEGIN
    -- Calculate sums from legs
    SELECT 
        COALESCE(SUM(CASE WHEN direction = 'debit' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0)
    INTO v_sum_debits, v_sum_credits
    FROM core.movement_legs
    WHERE movement_id = NEW.id;
    
    -- Get header totals
    v_total_debits := NEW.total_debits;
    v_total_credits := NEW.total_credits;
    
    -- Validate conservation
    IF v_sum_debits != v_sum_credits THEN
        RAISE EXCEPTION 'CONSERVATION_VIOLATION: Movement % has unbalanced legs: debits=%, credits=%', 
            NEW.id, v_sum_debits, v_sum_credits;
    END IF;
    
    IF v_sum_debits != v_total_debits OR v_sum_credits != v_total_credits THEN
        RAISE EXCEPTION 'CONSERVATION_VIOLATION: Movement % header totals mismatch: header(debits=%,credits=%) vs legs(debits=%,credits=%)',
            NEW.id, v_total_debits, v_total_credits, v_sum_debits, v_sum_credits;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply conservation check on status change to posted
CREATE OR REPLACE FUNCTION core.check_movement_posting()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'posted' AND OLD.status != 'posted' THEN
        -- Set posting timestamp
        NEW.posted_at := NOW();
        
        -- Calculate immutable hash
        NEW.immutable_hash := encode(digest(
            NEW.id::text || NEW.reference || NEW.total_debits::text || NEW.total_credits::text || NEW.version::text,
            'sha256'
        ), 'hex');
        
        -- Validate conservation (conservation enforced by chk_conservation constraint)
        IF NEW.total_debits != NEW.total_credits THEN
            RAISE EXCEPTION 'CONSERVATION_VIOLATION: total_debits != total_credits';
        END IF;
    END IF;
    
    -- Prevent updates to posted movements (Immutability)
    IF OLD.status = 'posted' AND NEW.status NOT IN ('reversing', 'reversed') THEN
        RAISE EXCEPTION 'IMMUTABLE_MUTATION: Posted movement % cannot be modified (Axiom V)', OLD.id;
    END IF;
    
    NEW.updated_at := NOW();
    NEW.version := OLD.version + 1;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_movement_posting
    BEFORE UPDATE ON core.value_movements
    FOR EACH ROW EXECUTE FUNCTION core.check_movement_posting();

-- =============================================================================
-- LEG AUDIT TRIGGER
-- =============================================================================
CREATE OR REPLACE FUNCTION core.update_leg_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.immutable_hash := encode(digest(
        NEW.id::text || NEW.movement_id::text || NEW.container_id::text || 
        NEW.direction || NEW.amount::text || NEW.sequence_number::text,
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leg_audit
    BEFORE INSERT OR UPDATE ON core.movement_legs
    FOR EACH ROW EXECUTE FUNCTION core.update_leg_audit();

-- =============================================================================
-- MOVEMENT HISTORY (TimescaleDB)
-- =============================================================================
CREATE TABLE core_history.movement_postings (
    time TIMESTAMPTZ NOT NULL,
    movement_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    
    container_id UUID NOT NULL,
    direction VARCHAR(6) NOT NULL,
    amount DECIMAL(28,8) NOT NULL,
    
    balance_before DECIMAL(28,8),
    balance_after DECIMAL(28,8),
    
    PRIMARY KEY (time, movement_id, container_id)
);

SELECT create_hypertable('core_history.movement_postings', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_postings_container ON core_history.movement_postings(container_id, time DESC);
CREATE INDEX idx_postings_movement ON core_history.movement_postings(movement_id);

COMMENT ON TABLE core_history.movement_postings IS 'Immutable posting history for balance reconstruction';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT ON core.movement_types TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.value_movements TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.movement_legs TO finos_app;
GRANT SELECT, INSERT ON core_history.movement_postings TO finos_app;
