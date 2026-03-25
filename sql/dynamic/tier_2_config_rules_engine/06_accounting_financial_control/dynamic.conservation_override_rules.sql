-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.conservation_override_rules
--
-- DESCRIPTION:
--   Emergency bypass rules for double-entry conservation violations.
--   Configures when conservation of value can be overridden.
--   Maps to core.value_movements conservation enforcement.
--
-- CORE DEPENDENCY: 003_value_movement_and_double_entry.sql
--
-- COMPLIANCE:
--   - SOX emergency procedures
--   - Regulatory investigation support
--   - Audit trail preservation
--
-- ============================================================================

CREATE TABLE dynamic.conservation_override_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Override Conditions
    override_reason dynamic.conservation_override_reason NOT NULL,
    required_authorization_level INTEGER NOT NULL DEFAULT 3, -- Higher = more senior required
    required_approvers_count INTEGER DEFAULT 2, -- Number of approvers required
    
    -- Amount Limits
    max_override_amount DECIMAL(28,8), -- NULL = unlimited
    max_override_percentage DECIMAL(5,4), -- Of total ledger value, NULL = unlimited
    cumulative_limit_daily DECIMAL(28,8), -- Daily cumulative override limit
    cumulative_limit_monthly DECIMAL(28,8), -- Monthly cumulative override limit
    
    -- Applicability
    applicable_movement_types VARCHAR(50)[], -- Which movement types this applies to
    applicable_container_types VARCHAR(50)[], -- Which container types
    applicable_currencies CHAR(3)[], -- Which currencies
    
    -- Auto-Approval Conditions
    auto_approve_below_amount DECIMAL(28,8), -- Auto-approve if under this amount
    auto_approve_if_emergency BOOLEAN DEFAULT FALSE,
    emergency_conditions JSONB, -- JSON logic defining emergency conditions
    
    -- Notifications
    notify_roles VARCHAR(100)[], -- Roles to notify on override
    notify_external BOOLEAN DEFAULT FALSE, -- Notify external auditors
    require_incident_report BOOLEAN DEFAULT TRUE,
    
    -- Workflow
    workflow_template_id UUID, -- Link to workflow for approval process
    escalation_hours INTEGER DEFAULT 4, -- Hours before escalation
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    emergency_only BOOLEAN DEFAULT TRUE, -- Only usable during declared emergencies
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_conservation_rule_code UNIQUE (tenant_id, rule_code),
    CONSTRAINT chk_conservation_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_max_percentage CHECK (max_override_percentage IS NULL OR max_override_percentage BETWEEN 0 AND 1)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.conservation_override_rules_default PARTITION OF dynamic.conservation_override_rules DEFAULT;

-- Indexes
CREATE INDEX idx_conservation_rule_reason ON dynamic.conservation_override_rules(tenant_id, override_reason) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_conservation_rule_active ON dynamic.conservation_override_rules(tenant_id) WHERE is_active = TRUE AND is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.conservation_override_rules IS 'Emergency bypass rules for double-entry conservation violations. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.conservation_override_rules.override_reason IS 'Valid reason for conservation override per SOX/regulatory requirements';
COMMENT ON COLUMN dynamic.conservation_override_rules.required_authorization_level IS 'Minimum authorization level required (1-5, 5 = C-level)';
COMMENT ON COLUMN dynamic.conservation_override_rules.cumulative_limit_daily IS 'Maximum cumulative override amount per day';

-- Trigger
CREATE TRIGGER trg_conservation_override_rules_audit
    BEFORE UPDATE ON dynamic.conservation_override_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.conservation_override_rules TO finos_app;
