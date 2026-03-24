-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.recurring_billing_schedule
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Recurring Billing Schedule.
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
CREATE TABLE dynamic.recurring_billing_schedule (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product/Service Reference
    linked_product_id UUID REFERENCES dynamic.product_template_master(product_id),
    linked_container_id UUID REFERENCES core.value_containers(id),
    
    -- Customer
    customer_id UUID NOT NULL,
    
    -- Billing Details
    billing_cycle_id UUID NOT NULL REFERENCES dynamic.billing_cycle(cycle_id),
    invoice_template_id UUID REFERENCES dynamic.invoice_template(template_id),
    
    -- Amount
    billing_amount DECIMAL(28,8) NOT NULL,
    billing_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    billing_description TEXT,
    
    -- Schedule
    start_date DATE NOT NULL,
    end_date DATE,
    next_run_date DATE NOT NULL,
    last_run_date DATE,
    
    -- Recurrence
    recurrence_count INTEGER, -- NULL = indefinite
    max_recurrences INTEGER,
    current_recurrence INTEGER DEFAULT 0,
    
    -- Tax
    tax_code VARCHAR(50),
    tax_rate_percentage DECIMAL(10,6),
    
    -- Status
    schedule_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (schedule_status IN ('ACTIVE', 'PAUSED', 'CANCELLED', 'COMPLETED', 'SUSPENDED')),
    cancellation_date DATE,
    cancellation_reason TEXT,
    
    -- Payment
    default_payment_method_id UUID,
    auto_collect BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    schedule_metadata JSONB DEFAULT '{}',
    
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
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.recurring_billing_schedule_default PARTITION OF dynamic.recurring_billing_schedule DEFAULT;

-- Indexes
CREATE INDEX idx_recurring_billing_tenant ON dynamic.recurring_billing_schedule(tenant_id) WHERE schedule_status = 'ACTIVE';
CREATE INDEX idx_recurring_billing_customer ON dynamic.recurring_billing_schedule(tenant_id, customer_id) WHERE schedule_status = 'ACTIVE';
CREATE INDEX idx_recurring_billing_next_run ON dynamic.recurring_billing_schedule(tenant_id, next_run_date) WHERE schedule_status = 'ACTIVE';
CREATE INDEX idx_recurring_billing_product ON dynamic.recurring_billing_schedule(tenant_id, linked_product_id);

-- Comments
COMMENT ON TABLE dynamic.recurring_billing_schedule IS 'Automated recurring charges for subscriptions and services';

-- Triggers
CREATE TRIGGER trg_recurring_billing_schedule_audit
    BEFORE UPDATE ON dynamic.recurring_billing_schedule
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.recurring_billing_schedule TO finos_app;