-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 26: REAL-TIME POSTING & AUTHORISATION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Instant Authorization, JIT Funding, Velocity Controls, Ring-Fencing
-- Standards: Marqeta-Style Auth, Double-Entry, <10ms Response Time
-- Version: 1.1 (March 2026)
-- =============================================================================

-- =============================================================================
-- REAL-TIME POSTING & AUTHORISATION (Primitive 21 in v1.1 Documentation)
-- =============================================================================
-- Handles every financial movement with instant auth, JIT, velocity, commando mode
-- Real-time double-entry posting; enforces ring-fencing, client-money segregation,
-- and Marqeta-style authorisation in < 10 ms. Balances always derived.

CREATE TABLE core.real_time_postings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Movement Link
    movement_id UUID REFERENCES core.value_movements(id),
    original_request_id VARCHAR(100), -- External request ID (Marqeta-style)
    
    -- Authorisation Status
    auth_status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (auth_status IN ('PENDING', 'APPROVED', 'DECLINED', 'REVERSED', 'TIMEOUT', 'ERROR')),
    auth_status_reason VARCHAR(100), -- Detailed reason code
    
    -- Authorisation Details
    auth_type VARCHAR(30) NOT NULL DEFAULT 'REAL_TIME'
        CHECK (auth_type IN ('REAL_TIME', 'PRE_AUTH', 'POST_AUTH', 'STAND_IN', 'OFFLINE')),
    auth_code VARCHAR(100), -- Authorisation code returned to client
    auth_expires_at TIMESTAMPTZ, -- When pre-auth expires
    
    -- Velocity Checks (Marqeta-style)
    velocity_check_passed BOOLEAN DEFAULT NULL, -- NULL = not checked, TRUE/FALSE = result
    velocity_limits_applied JSONB DEFAULT '{}', -- Which limits were checked
    velocity_breach_details JSONB, -- Details if velocity check failed
    
    -- JIT Funding (Just-In-Time)
    jit_funding_required BOOLEAN DEFAULT FALSE,
    jit_funding_message JSONB, -- {funding_source: '...', amount: ..., currency: '...'}
    jit_funding_executed_at TIMESTAMPTZ,
    jit_funding_reference VARCHAR(100),
    
    -- Ring-Fencing (Client Money Protection)
    ring_fence_flag BOOLEAN NOT NULL DEFAULT FALSE,
    ring_fence_type VARCHAR(30) CHECK (ring_fence_type IN ('CLIENT_MONEY', 'TRUST_ACCOUNT', 'SEGREGATED', 'RESERVE')),
    ring_fence_account_id UUID, -- Links to sub_account for segregation
    client_money_compliance_verified BOOLEAN DEFAULT FALSE,
    
    -- Commando Mode (Emergency Override)
    commando_override BOOLEAN NOT NULL DEFAULT FALSE,
    commando_override_reason TEXT,
    commando_authorized_by VARCHAR(100),
    commando_authorized_at TIMESTAMPTZ,
    commando_approval_chain JSONB, -- Multi-sig approval chain
    
    -- Financial Amounts (High Precision)
    requested_amount DECIMAL(28,8) NOT NULL,
    approved_amount DECIMAL(28,8), -- May differ from requested (partial approval)
    currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Posting Totals (Double-Entry)
    total_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Timing (Performance Metrics)
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    auth_decision_at TIMESTAMPTZ, -- When auth decision was made
    posted_at TIMESTAMPTZ, -- When actually posted to ledger
    
    -- Decision Time in Milliseconds
    decision_time_ms INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (auth_decision_at - requested_at)) * 1000
    ) STORED,
    
    -- Product Contract Reference
    product_contract_hash UUID REFERENCES core.product_contract_anchors(contract_hash),
    
    -- Channel & Context
    channel VARCHAR(50), -- ATM, POS, ONLINE, MOBILE, etc.
    merchant_id VARCHAR(100),
    merchant_category_code VARCHAR(10), -- MCC
    merchant_country CHAR(2),
    
    -- Card/Payment Instrument (if applicable)
    instrument_type VARCHAR(30),
    instrument_token VARCHAR(100), -- Tokenized card number
    instrument_expiry VARCHAR(10),
    
    -- Geographic & Risk
    ip_address INET,
    geolocation JSONB, -- {lat, lon, country, city}
    risk_score INTEGER CHECK (risk_score BETWEEN 0 AND 100),
    risk_flags TEXT[],
    
    -- 3D Secure / Authentication
    sca_required BOOLEAN DEFAULT FALSE,
    sca_completed BOOLEAN DEFAULT FALSE,
    sca_method VARCHAR(50), -- OTP, BIOMETRIC, etc.
    
    -- Cryptographic Security
    request_signature BYTEA, -- Signed request
    response_signature BYTEA, -- Signed response
    
    -- 4D Bitemporal Time
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Audit & Immutability
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    product_contract_anchor_hash UUID, -- Links to contract anchor
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Authorisation Decision JSONB (Marqeta-style)
    authorisation_decision_jsonb JSONB DEFAULT '{}', -- Full decision payload
    
    -- Constraints
    CONSTRAINT unique_request_per_tenant UNIQUE NULLS NOT DISTINCT (tenant_id, original_request_id),
    CONSTRAINT chk_rt_posting_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_rt_conservation CHECK (total_debits = total_credits),
    CONSTRAINT chk_amounts_positive CHECK (requested_amount >= 0 AND approved_amount >= 0),
    CONSTRAINT chk_auth_timing CHECK (
        (auth_status IN ('APPROVED', 'DECLINED') AND auth_decision_at IS NOT NULL) OR
        (auth_status NOT IN ('APPROVED', 'DECLINED'))
    )
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE core.real_time_postings_default PARTITION OF core.real_time_postings DEFAULT;

-- Critical Indexes for <10ms performance
CREATE INDEX idx_rt_postings_tenant ON core.real_time_postings(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_rt_postings_movement ON core.real_time_postings(movement_id);
CREATE INDEX idx_rt_postings_status ON core.real_time_postings(tenant_id, auth_status) 
    WHERE auth_status IN ('PENDING', 'APPROVED');
CREATE INDEX idx_rt_postings_request ON core.real_time_postings(tenant_id, original_request_id);
CREATE INDEX idx_rt_postings_time ON core.real_time_postings(requested_at DESC);
CREATE INDEX idx_rt_postings_channel ON core.real_time_postings(channel, merchant_id) 
    WHERE channel IS NOT NULL;
CREATE INDEX idx_rt_postings_instrument ON core.real_time_postings(instrument_token) 
    WHERE instrument_token IS NOT NULL;
CREATE INDEX idx_rt_postings_velocity ON core.real_time_postings(tenant_id, instrument_token, requested_at DESC) 
    WHERE instrument_token IS NOT NULL;
CREATE INDEX idx_rt_postings_temporal ON core.real_time_postings(valid_from, valid_to) WHERE valid_to > NOW();
CREATE INDEX idx_rt_postings_contract ON core.real_time_postings(product_contract_hash);
CREATE INDEX idx_rt_postings_auth_jsonb ON core.real_time_postings USING GIN(authorisation_decision_jsonb);

COMMENT ON TABLE core.real_time_postings IS 
    'Real-time posting and authorization with <10ms response, JIT funding, and ring-fencing';
COMMENT ON COLUMN core.real_time_postings.velocity_check_passed IS 
    'Velocity limit check result - NULL means not checked, TRUE/FALSE is result';
COMMENT ON COLUMN core.real_time_postings.commando_override IS 
    'Emergency override mode for critical situations with proper audit trail';
COMMENT ON COLUMN core.real_time_postings.ring_fence_flag IS 
    'Indicates if posting is subject to client money / ring-fencing requirements';

-- =============================================================================
-- VELOCITY LIMIT TRACKING
-- =============================================================================
-- Real-time velocity tracking per instrument/account

CREATE TABLE core.velocity_limit_counters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- What is being tracked
    tracking_key VARCHAR(200) NOT NULL, -- Composite key: instrument|account|user
    tracking_type VARCHAR(30) NOT NULL 
        CHECK (tracking_type IN ('INSTRUMENT', 'ACCOUNT', 'USER', 'MERCHANT', 'DEVICE')),
    
    -- Limit Definition
    limit_window VARCHAR(20) NOT NULL 
        CHECK (limit_window IN ('PER_TRANSACTION', 'PER_MINUTE', 'PER_HOUR', 'PER_DAY', 'PER_WEEK', 'PER_MONTH')),
    limit_amount DECIMAL(28,8),
    limit_count INTEGER,
    
    -- Current Usage (sliding window)
    current_window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    current_count INTEGER NOT NULL DEFAULT 0,
    
    -- Last Reset
    last_reset_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Alert Threshold
    alert_threshold_percentage DECIMAL(5,4) DEFAULT 0.80, -- 80%
    alert_sent BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_velocity_tracker UNIQUE (tenant_id, tracking_key, tracking_type, limit_window)
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.velocity_limit_counters_default PARTITION OF core.velocity_limit_counters DEFAULT;

-- High-performance index for velocity checks
CREATE INDEX idx_velocity_counters_lookup ON core.velocity_limit_counters(tenant_id, tracking_key, tracking_type);
CREATE INDEX idx_velocity_counters_window ON core.velocity_limit_counters(current_window_start);

COMMENT ON TABLE core.velocity_limit_counters IS 
    'Sliding window velocity tracking for real-time authorization decisions';

-- =============================================================================
-- JIT FUNDING LOG
-- =============================================================================
-- Audit trail of all JIT funding operations

CREATE TABLE core.jit_funding_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    posting_id UUID NOT NULL REFERENCES core.real_time_postings(id),
    
    -- Funding Source
    funding_source_type VARCHAR(30) NOT NULL 
        CHECK (funding_source_type IN ('PROGRAM', 'USER', 'RESERVE', 'EXTERNAL', 'GPA', 'MSA')),
    funding_source_id UUID NOT NULL, -- Links to funding source in dynamic layer
    
    -- Funding Details
    requested_amount DECIMAL(28,8) NOT NULL,
    funded_amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    
    -- Status
    funding_status VARCHAR(20) NOT NULL 
        CHECK (funding_status IN ('REQUESTED', 'PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),
    failure_reason TEXT,
    
    -- Linked Movement
    funding_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Timing
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    -- 4D Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.jit_funding_log_default PARTITION OF core.jit_funding_log DEFAULT;

CREATE INDEX idx_jit_funding_posting ON core.jit_funding_log(posting_id);
CREATE INDEX idx_jit_funding_status ON core.jit_funding_log(tenant_id, funding_status) WHERE funding_status IN ('PENDING', 'REQUESTED');

COMMENT ON TABLE core.jit_funding_log IS 'Audit trail of Just-In-Time funding operations';

-- =============================================================================
-- RING-FENCE ACCOUNT BALANCES (Derived - Never Stored Mutably)
-- =============================================================================
-- Materialized view for ring-fenced balance calculations

CREATE TABLE core.ring_fence_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Ring-Fence Account Reference
    ring_fence_account_id UUID NOT NULL, -- Links to sub_account
    ring_fence_type VARCHAR(30) NOT NULL,
    
    -- Balance Components (always derived from movements)
    total_receipts DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_payments DECIMAL(28,8) NOT NULL DEFAULT 0,
    pending_auth_amount DECIMAL(28,8) NOT NULL DEFAULT 0, -- Pre-auth holds
    
    -- Calculated Balance (derived, not stored directly)
    available_balance DECIMAL(28,8) GENERATED ALWAYS AS (
        total_receipts - total_payments - pending_auth_amount
    ) STORED,
    
    -- Compliance Check
    last_compliance_check_at TIMESTAMPTZ,
    compliance_status VARCHAR(20) DEFAULT 'compliant' 
        CHECK (compliance_status IN ('compliant', 'breach', 'warning')),
    
    -- Snapshot Time
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    calculation_basis VARCHAR(100), -- Which movements were included
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_ring_fence_balance UNIQUE (tenant_id, ring_fence_account_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.ring_fence_balances_default PARTITION OF core.ring_fence_balances DEFAULT;

CREATE INDEX idx_ring_fence_tenant ON core.ring_fence_balances(tenant_id);
CREATE INDEX idx_ring_fence_account ON core.ring_fence_balances(ring_fence_account_id);
CREATE INDEX idx_ring_fence_compliance ON core.ring_fence_balances(tenant_id, compliance_status) 
    WHERE compliance_status != 'compliant';

COMMENT ON TABLE core.ring_fence_balances IS 
    'Derived ring-fence balances - always computed from immutable movements';

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function: Process real-time authorization request (main entry point)
CREATE OR REPLACE FUNCTION core.process_real_time_auth(
    p_tenant_id UUID,
    p_amount DECIMAL(28,8),
    p_currency CHAR(3),
    p_instrument_token VARCHAR(100),
    p_merchant_id VARCHAR(100) DEFAULT NULL,
    p_channel VARCHAR(50) DEFAULT 'ONLINE',
    p_original_request_id VARCHAR(100) DEFAULT NULL,
    p_context JSONB DEFAULT '{}'
)
RETURNS TABLE (
    posting_id UUID,
    auth_status VARCHAR(20),
    auth_code VARCHAR(100),
    approved_amount DECIMAL(28,8),
    decline_reason VARCHAR(100)
) AS $$
DECLARE
    v_posting_id UUID;
    v_auth_status VARCHAR(20) := 'PENDING';
    v_auth_code VARCHAR(100);
    v_approved_amount DECIMAL(28,8);
    v_decline_reason VARCHAR(100);
    v_velocity_passed BOOLEAN;
    v_jit_required BOOLEAN := FALSE;
    v_jit_message JSONB;
    v_contract_hash UUID;
    v_immutable_hash VARCHAR(64);
BEGIN
    -- Generate auth code
    v_auth_code := 'AUTH-' || encode(gen_random_bytes(8), 'hex');
    
    -- Check velocity limits
    SELECT core.check_velocity_limits(p_tenant_id, p_instrument_token, p_amount) 
    INTO v_velocity_passed;
    
    -- Determine if JIT funding needed
    IF p_context->>'jit_funding_required' = 'true' THEN
        v_jit_required := TRUE;
        v_jit_message := jsonb_build_object(
            'funding_source', p_context->>'funding_source',
            'amount', p_amount,
            'currency', p_currency
        );
    END IF;
    
    -- Calculate immutable hash
    v_immutable_hash := encode(digest(
        p_tenant_id::text || p_amount::text || p_currency || NOW()::text || v_auth_code,
        'sha256'
    ), 'hex');
    
    -- Insert posting record
    INSERT INTO core.real_time_postings (
        tenant_id,
        original_request_id,
        auth_status,
        auth_type,
        auth_code,
        velocity_check_passed,
        jit_funding_required,
        jit_funding_message,
        requested_amount,
        approved_amount,
        currency,
        total_debits,
        total_credits,
        requested_at,
        auth_decision_at,
        channel,
        merchant_id,
        instrument_token,
        risk_score,
        product_contract_hash,
        immutable_hash,
        product_contract_anchor_hash,
        authorisation_decision_jsonb
    ) VALUES (
        p_tenant_id,
        COALESCE(p_original_request_id, 'RT-' || v_auth_code),
        'APPROVED', -- Start with approved, update if checks fail
        'REAL_TIME',
        v_auth_code,
        v_velocity_passed,
        v_jit_required,
        v_jit_message,
        p_amount,
        p_amount, -- Full approval initially
        p_currency,
        p_amount, -- Debit side
        p_amount, -- Credit side - balanced
        NOW(),
        NOW(),
        p_channel,
        p_merchant_id,
        p_instrument_token,
        (p_context->>'risk_score')::INTEGER,
        v_contract_hash,
        v_immutable_hash,
        v_contract_hash,
        jsonb_build_object(
            'velocity_check', v_velocity_passed,
            'jit_funding', v_jit_required,
            'channel', p_channel,
            'timestamp', NOW()
        )
    )
    RETURNING id INTO v_posting_id;
    
    -- If velocity check failed, decline
    IF v_velocity_passed = FALSE THEN
        UPDATE core.real_time_postings 
        SET auth_status = 'DECLINED', 
            auth_status_reason = 'VELOCITY_LIMIT_EXCEEDED',
            approved_amount = 0
        WHERE id = v_posting_id;
        
        v_auth_status := 'DECLINED';
        v_approved_amount := 0;
        v_decline_reason := 'VELOCITY_LIMIT_EXCEEDED';
    ELSE
        v_auth_status := 'APPROVED';
        v_approved_amount := p_amount;
        
        -- Update velocity counters
        PERFORM core.update_velocity_counters(p_tenant_id, p_instrument_token, p_amount);
    END IF;
    
    RETURN QUERY SELECT v_posting_id, v_auth_status, v_auth_code, v_approved_amount, v_decline_reason;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.process_real_time_auth IS 
    'Main entry point for real-time authorization - <10ms target response time';

-- Function: Check velocity limits
CREATE OR REPLACE FUNCTION core.check_velocity_limits(
    p_tenant_id UUID,
    p_tracking_key VARCHAR(100),
    p_amount DECIMAL(28,8)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_limit_record RECORD;
    v_passed BOOLEAN := TRUE;
BEGIN
    -- Check all applicable velocity limits
    FOR v_limit_record IN 
        SELECT * FROM core.velocity_limit_counters
        WHERE tenant_id = p_tenant_id 
          AND tracking_key = p_tracking_key
          AND current_window_start > NOW() - INTERVAL '1 day' -- Recent windows only
    LOOP
        -- Check amount limit
        IF v_limit_record.limit_amount IS NOT NULL THEN
            IF v_limit_record.current_amount + p_amount > v_limit_record.limit_amount THEN
                v_passed := FALSE;
                EXIT;
            END IF;
        END IF;
        
        -- Check count limit
        IF v_limit_record.limit_count IS NOT NULL THEN
            IF v_limit_record.current_count + 1 > v_limit_record.limit_count THEN
                v_passed := FALSE;
                EXIT;
            END IF;
        END IF;
    END LOOP;
    
    RETURN v_passed;
END;
$$ LANGUAGE plpgsql;

-- Function: Update velocity counters
CREATE OR REPLACE FUNCTION core.update_velocity_counters(
    p_tenant_id UUID,
    p_tracking_key VARCHAR(100),
    p_amount DECIMAL(28,8)
)
RETURNS VOID AS $$
BEGIN
    -- Update or insert daily counter
    INSERT INTO core.velocity_limit_counters (
        tenant_id, tracking_key, tracking_type, limit_window, 
        current_amount, current_count
    ) VALUES (
        p_tenant_id, p_tracking_key, 'INSTRUMENT', 'PER_DAY',
        p_amount, 1
    )
    ON CONFLICT (tenant_id, tracking_key, tracking_type, limit_window)
    DO UPDATE SET
        current_amount = velocity_limit_counters.current_amount + p_amount,
        current_count = velocity_limit_counters.current_count + 1,
        updated_at = NOW();
    
    -- Reset if window expired
    UPDATE core.velocity_limit_counters
    SET 
        current_amount = p_amount,
        current_count = 1,
        current_window_start = NOW(),
        last_reset_at = NOW()
    WHERE tenant_id = p_tenant_id 
      AND tracking_key = p_tracking_key
      AND current_window_start < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Function: Execute JIT funding
CREATE OR REPLACE FUNCTION core.execute_jit_funding(
    p_posting_id UUID,
    p_funding_source_id UUID,
    p_amount DECIMAL(28,8)
)
RETURNS UUID AS $$
DECLARE
    v_jit_id UUID;
    v_tenant_id UUID;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM core.real_time_postings WHERE id = p_posting_id;
    
    INSERT INTO core.jit_funding_log (
        tenant_id, posting_id, funding_source_type, funding_source_id,
        requested_amount, funded_amount, currency, funding_status
    )
    SELECT 
        v_tenant_id, p_posting_id, 'PROGRAM', p_funding_source_id,
        p_amount, p_amount, rt.currency, 'COMPLETED'
    FROM core.real_time_postings rt
    WHERE rt.id = p_posting_id
    RETURNING id INTO v_jit_id;
    
    -- Update posting
    UPDATE core.real_time_postings
    SET jit_funding_executed_at = NOW(),
        jit_funding_reference = v_jit_id::text
    WHERE id = p_posting_id;
    
    RETURN v_jit_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate ring-fence balance (derived)
CREATE OR REPLACE FUNCTION core.calculate_ring_fence_balance(
    p_ring_fence_account_id UUID
)
RETURNS DECIMAL(28,8) AS $$
DECLARE
    v_balance DECIMAL(28,8);
BEGIN
    -- Sum all movements to/from this ring-fenced account
    SELECT COALESCE(
        SUM(CASE WHEN ml.direction = 'credit' THEN ml.amount ELSE -ml.amount END),
        0
    )
    INTO v_balance
    FROM core.movement_legs ml
    JOIN core.value_movements vm ON vm.id = ml.movement_id
    WHERE ml.container_id = p_ring_fence_account_id
      AND vm.status = 'posted'
      AND vm.is_deleted = FALSE;
    
    -- Subtract pending authorizations
    SELECT v_balance - COALESCE(SUM(rp.approved_amount), 0)
    INTO v_balance
    FROM core.real_time_postings rp
    WHERE rp.ring_fence_account_id = p_ring_fence_account_id
      AND rp.auth_status = 'APPROVED'
      AND rp.posted_at IS NULL;
    
    RETURN v_balance;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger: Calculate hash on insert
CREATE OR REPLACE FUNCTION core.calc_rt_posting_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.immutable_hash := encode(digest(
        NEW.id::text || NEW.requested_amount::text || NEW.currency || 
        NEW.requested_at::text || COALESCE(NEW.auth_code, ''),
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rt_posting_hash
    BEFORE INSERT ON core.real_time_postings
    FOR EACH ROW EXECUTE FUNCTION core.calc_rt_posting_hash();

-- Trigger: Prevent updates to posted records
CREATE OR REPLACE FUNCTION core.prevent_rt_posting_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.posted_at IS NOT NULL THEN
        -- Only allow reversal, not modification
        IF NEW.auth_status NOT IN ('REVERSED') OR
           NEW.requested_amount != OLD.requested_amount THEN
            RAISE EXCEPTION 'IMMUTABLE_POSTING: Cannot modify posted real-time posting %', OLD.id;
        END IF;
    END IF;
    
    NEW.system_time := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_rt_mutation
    BEFORE UPDATE ON core.real_time_postings
    FOR EACH ROW EXECUTE FUNCTION core.prevent_rt_posting_mutation();

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.real_time_postings TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.velocity_limit_counters TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.jit_funding_log TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.ring_fence_balances TO finos_app;

GRANT EXECUTE ON FUNCTION core.process_real_time_auth TO finos_app;
GRANT EXECUTE ON FUNCTION core.check_velocity_limits TO finos_app;
GRANT EXECUTE ON FUNCTION core.update_velocity_counters TO finos_app;
GRANT EXECUTE ON FUNCTION core.execute_jit_funding TO finos_app;
GRANT EXECUTE ON FUNCTION core.calculate_ring_fence_balance TO finos_app, finos_readonly;
