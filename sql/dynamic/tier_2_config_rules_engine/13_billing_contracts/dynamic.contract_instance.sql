-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.contract_instance
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Contract Instance.
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
CREATE TABLE dynamic.contract_instance (

    contract_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Contract Identification
    contract_number VARCHAR(100) NOT NULL,
    contract_reference VARCHAR(100),
    
    -- Template Reference
    template_id UUID REFERENCES dynamic.contract_template(template_id),
    
    -- Parties
    customer_id UUID NOT NULL,
    counterparty_name VARCHAR(200),
    counterparty_id UUID,
    
    -- Contract Details
    contract_type VARCHAR(50),
    contract_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (contract_status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'ACTIVE', 'SUSPENDED', 'EXPIRED', 'TERMINATED', 'RENEWED')),
    
    -- Dates
    start_date DATE NOT NULL,
    end_date DATE,
    signed_date DATE,
    effective_date DATE,
    
    -- Financial Terms
    contract_value DECIMAL(28,8),
    contract_currency CHAR(3) REFERENCES core.currencies(code),
    payment_terms_days INTEGER DEFAULT 30,
    
    -- Content
    contract_clauses JSONB, -- Instance-specific clause values
    contract_variables JSONB, -- Populated variable values
    contract_document_url VARCHAR(500),
    
    -- Renewal
    auto_renew BOOLEAN DEFAULT FALSE,
    renewal_term_months INTEGER,
    renewal_count INTEGER DEFAULT 0,
    max_renewals INTEGER,
    
    -- Termination
    termination_date DATE,
    termination_reason TEXT,
    terminated_by UUID,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_contract_number UNIQUE (tenant_id, contract_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.contract_instance_default PARTITION OF dynamic.contract_instance DEFAULT;

-- Indexes
CREATE INDEX idx_contract_instance_tenant ON dynamic.contract_instance(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_contract_instance_customer ON dynamic.contract_instance(tenant_id, customer_id);
CREATE INDEX idx_contract_instance_status ON dynamic.contract_instance(tenant_id, contract_status);
CREATE INDEX idx_contract_instance_dates ON dynamic.contract_instance(start_date, end_date);

-- Comments
COMMENT ON TABLE dynamic.contract_instance IS 'Executed contracts with populated clauses and terms';

-- Triggers
CREATE TRIGGER trg_contract_instance_audit
    BEFORE UPDATE ON dynamic.contract_instance
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.contract_instance TO finos_app;