-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 10: RECONCILIATION & SUSPENSE
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Reconciliation Matching, Suspense Management, Auto-matching Rules
-- Standards: ISO 20022 (camt), IFRS, SOX
-- =============================================================================

-- =============================================================================
-- RECONCILIATION RUNS
-- =============================================================================
CREATE TABLE core.reconciliation_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scope
    run_reference VARCHAR(100) NOT NULL,
    recon_date DATE NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Source
    container_id UUID REFERENCES core.value_containers(id),
    external_source VARCHAR(50) NOT NULL 
        CHECK (external_source IN ('bank_statement', 'card_network', 'swift', 'custodian', 'depository', 'internal')),
    external_reference VARCHAR(200) NOT NULL,
    external_system VARCHAR(100),
    
    -- Control Totals
    opening_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    closing_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    external_opening DECIMAL(28,8) NOT NULL DEFAULT 0,
    external_closing DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Discrepancy
    discrepancy DECIMAL(28,8) GENERATED ALWAYS AS (closing_balance - external_closing) STORED,
    discrepancy_percentage DECIMAL(10,6) GENERATED ALWAYS AS (
        CASE WHEN external_closing != 0 THEN ABS(closing_balance - external_closing) / ABS(external_closing) ELSE 0 END
    ) STORED,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' 
        CHECK (status IN ('in_progress', 'matched', 'unmatched', 'adjusted', 'approved', 'cancelled')),
    
    -- Matching Summary
    total_items INTEGER DEFAULT 0,
    matched_items INTEGER DEFAULT 0,
    unmatched_items INTEGER DEFAULT 0,
    partial_match_items INTEGER DEFAULT 0,
    auto_matched_items INTEGER DEFAULT 0,
    manual_matched_items INTEGER DEFAULT 0,
    
    -- Approver (4-eyes)
    prepared_by UUID REFERENCES core.economic_agents(id),
    reviewed_by UUID REFERENCES core.economic_agents(id),
    approved_by UUID REFERENCES core.economic_agents(id),
    approved_at TIMESTAMPTZ,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Anchoring
    statement_hash VARCHAR(64),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT unique_recon_run UNIQUE (tenant_id, run_reference)
);

CREATE INDEX idx_recon_runs_date ON core.reconciliation_runs(tenant_id, recon_date);
CREATE INDEX idx_recon_runs_status ON core.reconciliation_runs(tenant_id, status) WHERE status IN ('in_progress', 'unmatched') AND is_deleted = FALSE;
CREATE INDEX idx_recon_runs_container ON core.reconciliation_runs(container_id, recon_date);
CREATE INDEX idx_recon_runs_correlation ON core.reconciliation_runs(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.reconciliation_runs IS 'Reconciliation run headers with control totals';

-- =============================================================================
-- RECONCILIATION ITEMS
-- =============================================================================
CREATE TABLE core.reconciliation_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    run_id UUID NOT NULL REFERENCES core.reconciliation_runs(id) ON DELETE CASCADE,
    
    -- Internal Reference
    internal_movement_id UUID REFERENCES core.value_movements(id),
    internal_reference VARCHAR(100),
    internal_amount DECIMAL(28,8),
    internal_currency CHAR(3),
    internal_date DATE,
    
    -- External Reference
    external_reference VARCHAR(100),
    external_amount DECIMAL(28,8),
    external_currency CHAR(3),
    external_date DATE,
    external_description TEXT,
    external_metadata JSONB,
    
    -- Matching
    match_type VARCHAR(20) NOT NULL DEFAULT 'unmatched' 
        CHECK (match_type IN ('exact', 'fuzzy', 'many_to_one', 'one_to_many', 'unmatched', 'suspense')),
    match_confidence DECIMAL(5,2) CHECK (match_confidence BETWEEN 0 AND 100),
    matched_by VARCHAR(20) CHECK (matched_by IN ('auto', 'manual', 'rule', 'system')),
    matched_at TIMESTAMPTZ,
    matched_by_agent UUID REFERENCES core.economic_agents(id),
    
    -- Discrepancy Analysis
    amount_variance DECIMAL(28,8),
    timing_variance INTEGER, -- Days difference
    discrepancy_reason VARCHAR(50), -- 'timing', 'fee', 'duplicate', 'missing', 'error', 'fx'
    
    -- Resolution
    resolution_action VARCHAR(50), -- 'accept', 'adjust', 'investigate', 'write_off'
    resolution_notes TEXT,
    adjustment_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recon_items_run ON core.reconciliation_items(run_id);
CREATE INDEX idx_recon_items_match ON core.reconciliation_items(run_id, match_type);
CREATE INDEX idx_recon_items_internal ON core.reconciliation_items(internal_movement_id);
CREATE INDEX idx_recon_items_external ON core.reconciliation_items(external_reference);
CREATE INDEX idx_recon_items_unmatched ON core.reconciliation_items(tenant_id, match_type) WHERE match_type = 'unmatched';
CREATE INDEX idx_recon_items_correlation ON core.reconciliation_items(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.reconciliation_items IS 'Individual reconciliation items with matching status';

-- =============================================================================
-- MATCHING RULES
-- =============================================================================
CREATE TABLE core.reconciliation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Definition
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN ('exact', 'tolerance', 'fuzzy', 'pattern')),
    priority INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Match Criteria
    match_fields JSONB NOT NULL DEFAULT '["reference", "amount", "date"]', -- Fields to compare
    amount_tolerance DECIMAL(10,6), -- As percentage
    date_tolerance_days INTEGER DEFAULT 0,
    
    -- Reference Patterns (Regex)
    reference_pattern VARCHAR(200),
    external_pattern VARCHAR(200),
    
    -- Auto-resolution
    auto_resolve BOOLEAN DEFAULT FALSE,
    auto_resolve_action VARCHAR(50),
    requires_approval BOOLEAN DEFAULT TRUE,
    
    -- Applicability
    applicable_sources VARCHAR(50)[],
    applicable_currencies CHAR(3)[],
    min_amount DECIMAL(28,8),
    max_amount DECIMAL(28,8),
    
    -- Metadata
    match_count INTEGER DEFAULT 0,
    last_match_at TIMESTAMPTZ,
    success_rate DECIMAL(5,2),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recon_rules_active ON core.reconciliation_rules(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.reconciliation_rules IS 'Auto-matching rules for reconciliation';

-- =============================================================================
-- SUSPENSE ITEMS
-- =============================================================================
CREATE TABLE core.suspense_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Source
    recon_run_id UUID REFERENCES core.reconciliation_runs(id),
    source_type VARCHAR(50) NOT NULL 
        CHECK (source_type IN ('unmatched_debit', 'unmatched_credit', 'system_error', 'manual_entry', 'adjustment')),
    
    -- Amount
    amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Description
    description TEXT NOT NULL,
    reference VARCHAR(100),
    external_reference VARCHAR(100),
    
    -- Aging
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    age_days INTEGER GENERATED ALWAYS AS (EXTRACT(DAY FROM NOW() - created_at)::INTEGER) STORED,
    
    -- Auto-resolution Attempts
    auto_match_rules_attempted JSONB DEFAULT '[]',
    last_match_attempt_at TIMESTAMPTZ,
    match_attempt_count INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'under_review', 'matched', 'resolved', 'written_off', 'returned')),
    
    -- Assignment
    assigned_to UUID REFERENCES core.economic_agents(id),
    assigned_at TIMESTAMPTZ,
    
    -- Resolution
    resolved_by UUID REFERENCES core.economic_agents(id),
    resolved_at TIMESTAMPTZ,
    resolution_type VARCHAR(50), -- 'matched_to_movement', 'adjustment', 'refund', 'write_off', 'returned'
    resolution_movement_id UUID REFERENCES core.value_movements(id),
    resolution_notes TEXT,
    
    -- Write-off
    write_off_approved_by UUID REFERENCES core.economic_agents(id),
    write_off_approved_at TIMESTAMPTZ,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Constraints
    CONSTRAINT chk_amount_nonzero CHECK (amount != 0)
);

-- Aging indexes for suspense management
CREATE INDEX idx_suspense_status ON core.suspense_items(tenant_id, status) WHERE status IN ('open', 'under_review');
CREATE INDEX idx_suspense_aging ON core.suspense_items(tenant_id, age_days) WHERE status = 'open';
CREATE INDEX idx_suspense_assigned ON core.suspense_items(assigned_to, status) WHERE status IN ('open', 'under_review');
CREATE INDEX idx_suspense_created ON core.suspense_items(created_at) WHERE status = 'open';
CREATE INDEX idx_recon_rules_correlation ON core.reconciliation_rules(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_suspense_items_correlation ON core.suspense_items(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.suspense_items IS 'Unmatched/suspense items requiring manual resolution';

-- =============================================================================
-- SUSPENSE AGING VIEW
-- =============================================================================
CREATE OR REPLACE VIEW core.suspense_aging AS
SELECT 
    tenant_id,
    status,
    CASE 
        WHEN age_days <= 1 THEN '0-1 days'
        WHEN age_days <= 7 THEN '2-7 days'
        WHEN age_days <= 30 THEN '8-30 days'
        WHEN age_days <= 90 THEN '31-90 days'
        ELSE '90+ days'
    END AS aging_bucket,
    COUNT(*) AS item_count,
    SUM(ABS(amount)) AS total_amount,
    currency
FROM core.suspense_items
WHERE status IN ('open', 'under_review')
GROUP BY tenant_id, status, aging_bucket, currency;

COMMENT ON VIEW core.suspense_aging IS 'Aging analysis of open suspense items';

-- =============================================================================
-- RECONCILIATION HISTORY
-- =============================================================================
CREATE TABLE core_history.reconciliation_activity (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    activity_type VARCHAR(50) NOT NULL, -- 'run_created', 'item_matched', 'item_unmatched', 'suspense_created', 'suspense_resolved'
    
    run_id UUID,
    item_id UUID,
    suspense_id UUID,
    
    previous_status VARCHAR(50),
    new_status VARCHAR(50),
    
    performed_by UUID,
    details JSONB,
    
    PRIMARY KEY (time, tenant_id, activity_type)
);

SELECT create_hypertable('core_history.reconciliation_activity', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_recon_activity_type ON core_history.reconciliation_activity(tenant_id, activity_type, time DESC);

-- =============================================================================
-- AUTO-MATCH FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION core.attempt_auto_match(p_run_id UUID)
RETURNS TABLE (
    items_matched INTEGER,
    items_created INTEGER,
    items_suspense INTEGER
) AS $$
DECLARE
    v_matched INTEGER := 0;
    v_created INTEGER := 0;
    v_suspense INTEGER := 0;
    v_item RECORD;
    v_rule RECORD;
BEGIN
    -- Process unmatched items
    FOR v_item IN
        SELECT * FROM core.reconciliation_items 
        WHERE run_id = p_run_id AND match_type = 'unmatched'
    LOOP
        -- Try each active rule
        FOR v_rule IN
            SELECT * FROM core.reconciliation_rules 
            WHERE tenant_id = (SELECT tenant_id FROM core.reconciliation_runs WHERE id = p_run_id)
              AND is_active = TRUE
            ORDER BY priority
        LOOP
            -- Simple exact match example (would be more complex in production)
            IF v_rule.rule_type = 'exact' AND 
               v_item.internal_reference = v_item.external_reference AND
               ABS(COALESCE(v_item.internal_amount, 0) - COALESCE(v_item.external_amount, 0)) <= 
               COALESCE(v_rule.amount_tolerance, 0.01) * GREATEST(ABS(COALESCE(v_item.internal_amount, 0)), ABS(COALESCE(v_item.external_amount, 0))) THEN
                
                UPDATE core.reconciliation_items
                SET match_type = 'exact',
                    match_confidence = 100,
                    matched_by = 'auto',
                    matched_at = NOW()
                WHERE id = v_item.id;
                
                v_matched := v_matched + 1;
                EXIT; -- Rule matched
            END IF;
        END LOOP;
        
        -- If no match, create suspense
        IF v_item.match_type = 'unmatched' THEN
            INSERT INTO core.suspense_items (
                tenant_id, recon_run_id, source_type, amount, currency,
                description, reference, external_reference
            ) VALUES (
                (SELECT tenant_id FROM core.reconciliation_runs WHERE id = p_run_id),
                p_run_id,
                CASE WHEN v_item.internal_movement_id IS NULL THEN 'unmatched_credit' ELSE 'unmatched_debit' END,
                COALESCE(v_item.external_amount, v_item.internal_amount, 0),
                COALESCE(v_item.external_currency, v_item.internal_currency, 'USD'),
                'Unmatched reconciliation item',
                v_item.internal_reference,
                v_item.external_reference
            );
            
            UPDATE core.reconciliation_items SET match_type = 'suspense' WHERE id = v_item.id;
            v_suspense := v_suspense + 1;
        END IF;
        
        v_created := v_created + 1;
    END LOOP;
    
    RETURN QUERY SELECT v_matched, v_created, v_suspense;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.attempt_auto_match IS 'Attempts to auto-match reconciliation items based on active rules';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.reconciliation_runs TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.reconciliation_items TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.reconciliation_rules TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.suspense_items TO finos_app;
GRANT SELECT ON core.suspense_aging TO finos_app;
GRANT SELECT, INSERT ON core_history.reconciliation_activity TO finos_app;
GRANT EXECUTE ON FUNCTION core.attempt_auto_match TO finos_app;
