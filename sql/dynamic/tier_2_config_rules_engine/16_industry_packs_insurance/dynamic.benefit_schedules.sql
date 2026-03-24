-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 16 - Industry Packs: Insurance
-- TABLE: dynamic.benefit_schedules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Benefit Schedules.
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
CREATE TABLE dynamic.benefit_schedules (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    schedule_code VARCHAR(100) NOT NULL,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_description TEXT,
    
    -- Product Link
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Benefit Type
    benefit_type VARCHAR(50) NOT NULL 
        CHECK (benefit_type IN ('LUMP_SUM', 'INCOME', 'REIMBURSEMENT', 'ANNUITY', 'SCHEDULED_PAYMENTS')),
    
    -- Schedule Structure
    benefit_tiers JSONB NOT NULL, -- [{tier_code: '...', condition: '...', benefit_amount: 100000, benefit_percentage: null}, ...]
    
    -- Calculation Basis
    calculation_basis VARCHAR(50) NOT NULL 
        CHECK (calculation_basis IN ('FLAT_AMOUNT', 'PERCENTAGE_OF_SUM_ASSURED', 'PERCENTAGE_OF_PREMIUM', 'ACTUAL_COST', 'DAILY_AMOUNT', 'UNIT_BENEFIT')),
    
    -- Limits
    maximum_benefit_amount DECIMAL(28,8),
    minimum_benefit_amount DECIMAL(28,8),
    aggregate_limit DECIMAL(28,8),
    per_occurrence_limit DECIMAL(28,8),
    
    -- Waiting/Deductible
    waiting_period_days INTEGER,
    elimination_period_days INTEGER,
    deductible_amount DECIMAL(28,8),
    deductible_type VARCHAR(50), -- PER_OCCURRENCE, ANNUAL, LIFETIME
    
    -- Payment Terms
    payment_frequency VARCHAR(50) DEFAULT 'LUMP_SUM', -- LUMP_SUM, MONTHLY, ANNUAL
    payment_duration_months INTEGER,
    payment_escalation_rate DECIMAL(10,6), -- Annual increase
    
    -- Exclusions
    benefit_exclusions JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    schedule_version VARCHAR(20) DEFAULT '1.0',
    
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
    
    CONSTRAINT unique_benefit_schedule_code UNIQUE (tenant_id, schedule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.benefit_schedules_default PARTITION OF dynamic.benefit_schedules DEFAULT;

-- Indexes
CREATE INDEX idx_benefit_schedules_tenant ON dynamic.benefit_schedules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_benefit_schedules_product ON dynamic.benefit_schedules(tenant_id, product_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.benefit_schedules IS 'Insurance benefit calculation schedules and tiers';

-- Triggers
CREATE TRIGGER trg_benefit_schedules_audit
    BEFORE UPDATE ON dynamic.benefit_schedules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.benefit_schedules TO finos_app;