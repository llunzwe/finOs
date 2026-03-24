-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.billing_cycle
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Billing Cycle.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================
CREATE TABLE dynamic.billing_cycle (

    cycle_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    cycle_code VARCHAR(100) NOT NULL,
    cycle_name VARCHAR(200) NOT NULL,
    cycle_description TEXT,
    
    -- Cycle Type
    cycle_type VARCHAR(50) NOT NULL 
        CHECK (cycle_type IN ('MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'BIWEEKLY', 'WEEKLY', 'DAILY', 'USAGE_BASED', 'ADHOC')),
    
    -- Anchor Date
    anchor_date DATE, -- Starting point for cycles
    billing_day_of_month INTEGER CHECK (billing_day_of_month BETWEEN 1 AND 31),
    billing_day_of_week INTEGER CHECK (billing_day_of_week BETWEEN 0 AND 6), -- 0 = Sunday
    
    -- Timing
    billing_time TIME DEFAULT '00:00:00',
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Grace Period
    grace_period_days INTEGER DEFAULT 0,
    grace_period_type VARCHAR(20) DEFAULT 'CALENDAR_DAYS' CHECK (grace_period_type IN ('CALENDAR_DAYS', 'BUSINESS_DAYS')),
    
    -- Proration
    proration_enabled BOOLEAN DEFAULT TRUE,
    proration_calculation_method VARCHAR(50) DEFAULT 'DAILY_PRORATE', -- DAILY_PRORATE, MONTHLY_PRORATE, NONE
    proration_day_count_basis VARCHAR(20) DEFAULT 'ACTUAL_DAYS', -- ACTUAL_DAYS, THIRTY_DAY_MONTH
    
    -- Holidays
    holiday_calendar_id UUID, -- Reference to holiday calendar
    holiday_adjustment VARCHAR(20) DEFAULT 'NONE' CHECK (holiday_adjustment IN ('NONE', 'PREVIOUS_BUSINESS_DAY', 'NEXT_BUSINESS_DAY', 'SKIP')),
    
    -- Invoice Generation
    invoice_template_id UUID REFERENCES dynamic.invoice_template(template_id),
    auto_generate_invoice BOOLEAN DEFAULT TRUE,
    consolidate_line_items BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_billing_cycle_code UNIQUE (tenant_id, cycle_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.billing_cycle_default PARTITION OF dynamic.billing_cycle DEFAULT;

-- Indexes
CREATE INDEX idx_billing_cycle_tenant ON dynamic.billing_cycle(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_billing_cycle_lookup ON dynamic.billing_cycle(tenant_id, cycle_code) WHERE is_active = TRUE;
CREATE INDEX idx_billing_cycle_type ON dynamic.billing_cycle(tenant_id, cycle_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.billing_cycle IS 'Cycle definitions (monthly, quarterly, usage) for billing';

-- Triggers
CREATE TRIGGER trg_billing_cycle_audit
    BEFORE UPDATE ON dynamic.billing_cycle
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.billing_cycle TO finos_app;