-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.accounting_enforcement_log
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.accounting_enforcement_log (

    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Source Event
    source_event_id UUID NOT NULL, -- Links to posting, movement, etc.
    source_event_type VARCHAR(50) NOT NULL,
    
    -- Rule Applied
    rule_override_id UUID REFERENCES dynamic.accounting_rule_overrides(override_id),
    rule_template_id UUID REFERENCES dynamic.accounting_rule_templates(template_id),
    
    -- GL Entries Generated
    gl_entries_generated JSONB NOT NULL DEFAULT '[]',
    -- Example: [
    --   {account_code: '1200', debit: 1000.00, credit: 0, leg_sequence: 1},
    --   {account_code: '3100', debit: 0, credit: 1000.00, leg_sequence: 2}
    -- ]
    
    -- Validation
    double_entry_valid BOOLEAN NOT NULL DEFAULT FALSE,
    conservation_check_passed BOOLEAN NOT NULL DEFAULT FALSE,
    validation_errors JSONB DEFAULT '[]',
    
    -- Core Movement Link
    core_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Status
    processing_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (processing_status IN ('pending', 'applied', 'failed', 'reversed')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    applied_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.accounting_enforcement_log_default PARTITION OF dynamic.accounting_enforcement_log DEFAULT;

-- Indexes
CREATE INDEX idx_acct_enforcement_event ON dynamic.accounting_enforcement_log(tenant_id, source_event_id);
CREATE INDEX idx_acct_enforcement_status ON dynamic.accounting_enforcement_log(tenant_id, processing_status) 
    WHERE processing_status IN ('pending', 'failed');
CREATE INDEX idx_acct_enforcement_movement ON dynamic.accounting_enforcement_log(core_movement_id);

-- Comments
COMMENT ON TABLE dynamic.accounting_enforcement_log IS 
    'Complete audit trail of accounting rule applications';

GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_enforcement_log TO finos_app;