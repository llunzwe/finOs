-- =============================================================================
-- FINOS CORE KERNEL - AUDIT FOUNDATION
-- =============================================================================
-- File: 001_audit.sql
-- Description: Audit logging, triggers, and temporal vault patterns
-- Standards: ISO 27001, SOC2, GDPR
-- =============================================================================

-- SECTION 7: AUDIT FOUNDATION
-- =============================================================================

-- Generic audit table
CREATE TABLE core_audit.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    row_id UUID,
    old_data JSONB,
    new_data JSONB,
    changed_fields JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(100),
    tenant_id UUID,
    session_id UUID,
    ip_address INET,
    transaction_id BIGINT,
    correlation_id UUID
);

SELECT create_hypertable('core_audit.audit_log', 'changed_at', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_audit_table ON core_audit.audit_log(table_name, changed_at DESC);
CREATE INDEX idx_audit_row ON core_audit.audit_log(row_id, changed_at DESC);
CREATE INDEX idx_audit_tenant ON core_audit.audit_log(tenant_id, changed_at DESC);
CREATE INDEX idx_audit_correlation ON core_audit.audit_log(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core_audit.audit_log IS 'Generic audit log for all table changes with hypertable partitioning';

-- Function to capture audit data
CREATE OR REPLACE FUNCTION core_audit.capture_audit()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_changed_fields JSONB;
    v_row_id UUID;
    v_correlation_id UUID;
BEGIN
    -- Extract correlation ID from session if available
    BEGIN
        v_correlation_id := current_setting('app.correlation_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_correlation_id := NULL;
    END;
    
    IF TG_OP = 'DELETE' THEN
        v_row_id := OLD.id;
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
        v_changed_fields := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        v_row_id := NEW.id;
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
        v_changed_fields := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_row_id := NEW.id;
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        v_changed_fields := (
            SELECT jsonb_object_agg(key, value)
            FROM jsonb_each(to_jsonb(NEW))
            WHERE to_jsonb(OLD) -> key IS DISTINCT FROM value
        );
    END IF;
    
    INSERT INTO core_audit.audit_log (
        table_name, operation, row_id, old_data, new_data, changed_fields,
        changed_by, tenant_id, session_id, ip_address, transaction_id, correlation_id
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        v_row_id,
        v_old_data,
        v_new_data,
        v_changed_fields,
        current_setting('app.current_user', TRUE),
        core.current_tenant_id(),
        current_setting('app.session_id', TRUE)::UUID,
        current_setting('app.client_ip', TRUE)::INET,
        txid_current(),
        v_correlation_id
    );
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION core_audit.capture_audit IS 'Captures audit data for table changes including correlation tracking';

-- =============================================================================

-- SECTION 13: VAULT PATTERNS - BITEMPORAL & AUDIT
-- =============================================================================

-- Bitemporal "As-Of" Query Helper
CREATE OR REPLACE FUNCTION core.as_of(
    p_table_name TEXT,
    p_entity_id UUID,
    p_as_of_time TIMESTAMPTZ,
    p_system_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_query TEXT;
BEGIN
    v_query := format(
        'SELECT to_jsonb(t.*) FROM %I t 
         WHERE t.id = %L 
           AND t.valid_from <= %L 
           AND t.valid_to > %L
           AND t.system_time <= %L
         ORDER BY t.system_time DESC 
         LIMIT 1',
        p_table_name, p_entity_id, p_as_of_time, p_as_of_time, p_system_time
    );
    
    EXECUTE v_query INTO v_result;
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.as_of IS 'Vault Pattern: Returns exact state of any primitive at any point in time (system + valid time)';

-- Conservation Enforcement Trigger (Double-Entry Guarantee)
CREATE OR REPLACE FUNCTION core.enforce_conservation()
RETURNS TRIGGER AS $$
DECLARE
    v_total_debits DECIMAL(28,8);
    v_total_credits DECIMAL(28,8);
BEGIN
    -- Check conservation law: sum of all legs must equal zero
    IF NEW.total_debits IS NOT NULL AND NEW.total_credits IS NOT NULL THEN
        IF NEW.total_debits != NEW.total_credits THEN
            RAISE EXCEPTION 'Conservation violation: total_debits (%) must equal total_credits (%)',
                NEW.total_debits, NEW.total_credits
                USING ERRCODE = 'integrity_constraint_violation';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.enforce_conservation IS 'Vault Pattern: Enforces double-entry conservation on value movements';

-- Regulatory Snapshot Logging
CREATE TABLE core.regulatory_snapshot_log (
    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    primitive_name TEXT NOT NULL,
    as_of_date DATE NOT NULL,
    snapshot_hash TEXT NOT NULL,
    record_count INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
);

CREATE INDEX idx_regulatory_snapshot_tenant ON core.regulatory_snapshot_log(tenant_id, primitive_name, as_of_date DESC);
CREATE INDEX idx_regulatory_snapshot_hash ON core.regulatory_snapshot_log(snapshot_hash);

COMMENT ON TABLE core.regulatory_snapshot_log IS 'Vault Pattern: Immutable snapshot versioning for regulatory positions';

-- Function to capture regulatory snapshot
CREATE OR REPLACE FUNCTION core.capture_regulatory_snapshot(
    p_primitive_name TEXT,
    p_as_of_date DATE
)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_hash TEXT;
    v_count INTEGER;
BEGIN
    -- Calculate aggregate hash (simplified - would use actual data)
    v_hash := encode(digest(
        format('%s:%s:%s', p_primitive_name, p_as_of_date, core.current_tenant_id()),
        'sha256'
    ), 'hex');
    
    INSERT INTO core.regulatory_snapshot_log (
        tenant_id, primitive_name, as_of_date, snapshot_hash, record_count, created_by
    ) VALUES (
        core.current_tenant_id(), p_primitive_name, p_as_of_date, v_hash, v_count,
        current_setting('app.current_user', TRUE)
    )
    RETURNING snapshot_id INTO v_snapshot_id;
    
    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Idempotent Posting Guard (Vault duplicate prevention)
CREATE OR REPLACE FUNCTION core.enforce_idempotency(
    p_idempotency_key TEXT,
    p_movement_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_existing UUID;
BEGIN
    -- Check for existing movement with same idempotency key
    SELECT id INTO v_existing
    FROM core.value_movements
    WHERE idempotency_key = p_idempotency_key
      AND tenant_id = core.current_tenant_id()
    LIMIT 1;
    
    IF v_existing IS NOT NULL THEN
        IF p_movement_id IS NOT NULL AND v_existing = p_movement_id THEN
            -- Same movement, allow (idempotent retry)
            RETURN TRUE;
        ELSE
            -- Different movement, reject as duplicate
            RAISE EXCEPTION 'Duplicate idempotency key: %', p_idempotency_key
                USING ERRCODE = 'unique_violation',
                      HINT = 'This movement has already been processed';
        END IF;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.enforce_idempotency IS 'Vault Pattern: Prevents duplicate movements within the same tenant';

-- =============================================================================
