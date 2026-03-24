-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.product_instances
--
-- DESCRIPTION:
--   Enterprise-grade runtime product instance management.
--   Live customer contracts linking product templates to core accounts.
--   Bridges static product configuration to active customer relationships.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: IFRS, Basel III/IV, GDPR, SOC2, Banking Regulations
-- ============================================================================


CREATE TABLE dynamic.product_instances (
    instance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Instance Identification
    instance_reference VARCHAR(100) NOT NULL, -- e.g., "ACC-2024-000001"
    instance_status VARCHAR(50) DEFAULT 'PENDING_ACTIVATION' 
        CHECK (instance_status IN ('PENDING_ACTIVATION', 'ACTIVE', 'SUSPENDED', 'DORMANT', 'CLOSED', 'CANCELLED')),
    
    -- Template Reference (Static Configuration)
    product_template_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    product_version INTEGER NOT NULL DEFAULT 1,
    
    -- Core Links (Runtime Bridge to Core Kernel)
    customer_id UUID NOT NULL REFERENCES core.customers(id),
    account_id UUID REFERENCES core.accounts(id), -- Primary account for this product
    account_ids UUID[], -- Multiple accounts if product spans accounts
    
    -- Contract Details
    contract_date DATE NOT NULL DEFAULT CURRENT_DATE,
    activation_date DATE,
    maturity_date DATE,
    closure_date DATE,
    
    -- Instance-Specific Configuration (Overrides from template)
    instance_parameters JSONB NOT NULL DEFAULT '{}', -- Runtime parameter values
    interest_rate DECIMAL(10,6), -- Instance-specific rate (if different from template)
    currency_code CHAR(3) REFERENCES core.currencies(code),
    
    -- Limits & Controls
    credit_limit DECIMAL(28,8),
    debit_limit DECIMAL(28,8),
    daily_transaction_limit DECIMAL(28,8),
    monthly_transaction_limit DECIMAL(28,8),
    
    -- Balance Tracking
    current_balance DECIMAL(28,8) DEFAULT 0,
    available_balance DECIMAL(28,8) DEFAULT 0,
    hold_balance DECIMAL(28,8) DEFAULT 0,
    
    -- Fees & Charges Instance Settings
    fee_schedule_id UUID REFERENCES dynamic.fee_schedule_matrix(schedule_id),
    interest_calculation_rule_id UUID REFERENCES dynamic.interest_rate_curve(curve_id),
    
    -- Status Control
    is_active BOOLEAN DEFAULT TRUE,
    is_dormant BOOLEAN DEFAULT FALSE,
    dormant_since DATE,
    
    -- Documentation
    signed_agreement_document_id UUID,
    terms_accepted_at TIMESTAMPTZ,
    terms_version VARCHAR(20),
    
    -- Metadata
    source_channel VARCHAR(50), -- 'BRANCH', 'MOBILE', 'WEB', 'API'
    referral_code VARCHAR(50),
    campaign_id UUID,
    attributes JSONB DEFAULT '{}',
    tags TEXT[],
    
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
    CONSTRAINT unique_instance_reference UNIQUE (tenant_id, instance_reference),
    CONSTRAINT chk_product_instance_valid_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_instances_default PARTITION OF dynamic.product_instances DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_product_instances_tenant ON dynamic.product_instances(tenant_id);
CREATE INDEX idx_product_instances_customer ON dynamic.product_instances(tenant_id, customer_id);
CREATE INDEX idx_product_instances_account ON dynamic.product_instances(tenant_id, account_id);
CREATE INDEX idx_product_instances_template ON dynamic.product_instances(tenant_id, product_template_id);
CREATE INDEX idx_product_instances_status ON dynamic.product_instances(tenant_id, instance_status);
CREATE INDEX idx_product_instances_temporal ON dynamic.product_instances(tenant_id, valid_from, valid_to) WHERE is_current = TRUE;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_instances IS 'Runtime product instances - live customer contracts linking templates to core accounts. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_instances TO finos_app;
