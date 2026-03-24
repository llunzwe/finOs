-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.forex_exchange_control_rules
--
-- DESCRIPTION:
--   Enterprise-grade foreign exchange control rules for SARB/RBZ compliance.
--   Regional exchange controls, approval workflows, documentation requirements.
--
-- COMPLIANCE: SARB Exchange Control, RBZ Regulations, FATF
-- ============================================================================


CREATE TABLE dynamic.forex_exchange_control_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Regulatory Authority
    regulatory_authority VARCHAR(50) NOT NULL 
        CHECK (regulatory_authority IN ('SARB', 'RBZ', 'BOT', 'CBN', 'CENTRAL_BANK')),
    authority_reference VARCHAR(100), -- Regulation reference number
    
    -- Transaction Scope
    transaction_type VARCHAR(100) NOT NULL 
        CHECK (transaction_type IN ('CAPITAL_TRANSFER', 'TRADE_PAYMENT', 'DIVIDEND', 'LOAN_REPAYMENT', 'ROYALTY', 'SERVICE_FEE', 'INVESTMENT', 'PERSONAL_ALLOWANCE')),
    
    -- Currency Controls
    from_currency CHAR(3),
    to_currency CHAR(3),
    applicable_currencies CHAR(3)[],
    
    -- Limits
    annual_limit_per_person DECIMAL(28,8),
    transaction_limit DECIMAL(28,8),
    requires_approval_above DECIMAL(28,8),
    
    -- Approval Requirements
    approval_required BOOLEAN DEFAULT FALSE,
    approval_authority VARCHAR(100), -- 'BANK', 'RESERVE_BANK', 'TAX_CLEARANCE'
    approval_documentation TEXT[], -- Required documents
    
    -- Documentation
    mandatory_documents TEXT[], -- ['INVOICE', 'CONTRACT', 'TAX_CLEARANCE']
    retention_period_years INTEGER DEFAULT 5,
    
    -- Customer Categories
    applicable_resident_types VARCHAR(50)[], -- ['RESIDENT', 'NON_RESIDENT', 'EMIGRANT']
    applicable_customer_types VARCHAR(50)[], -- ['INDIVIDUAL', 'CORPORATE', 'INSTITUTIONAL']
    
    -- Reporting
    reporting_required BOOLEAN DEFAULT TRUE,
    reporting_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    reporting_deadline_days INTEGER DEFAULT 30,
    
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
    
    CONSTRAINT unique_rule_code UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.forex_exchange_control_rules_default PARTITION OF dynamic.forex_exchange_control_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_forex_control_tenant ON dynamic.forex_exchange_control_rules(tenant_id);
CREATE INDEX idx_forex_control_authority ON dynamic.forex_exchange_control_rules(tenant_id, regulatory_authority);
CREATE INDEX idx_forex_control_type ON dynamic.forex_exchange_control_rules(tenant_id, transaction_type);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.forex_exchange_control_rules IS 'Foreign exchange control rules - SARB/RBZ compliance, capital controls. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.forex_exchange_control_rules TO finos_app;
