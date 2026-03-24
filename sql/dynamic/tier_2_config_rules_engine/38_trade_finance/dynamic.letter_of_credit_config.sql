-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 38 - Trade Finance
-- TABLE: dynamic.letter_of_credit_config
--
-- DESCRIPTION:
--   Enterprise-grade letter of credit, guarantee, and trade finance configuration.
--   LC issuance, amendment, negotiation, and settlement rules.
--
-- COMPLIANCE: UCP 600, URDG 758, ICC Rules, Basel III/IV
-- ============================================================================


CREATE TABLE dynamic.letter_of_credit_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration Identification
    config_name VARCHAR(200) NOT NULL,
    instrument_type VARCHAR(50) NOT NULL 
        CHECK (instrument_type IN ('LETTER_OF_CREDIT', 'STANDBY_LC', 'BANK_GUARANTEE', 'PERFORMANCE_BOND', 'DOCUMENTARY_COLLECTION')),
    
    -- LC Type
    lc_type VARCHAR(50) DEFAULT 'IRREVOCABLE' 
        CHECK (lc_type IN ('IRREVOCABLE', 'CONFIRMED', 'TRANSFERABLE', 'BACK_TO_BACK', 'REVOLVING', 'RED_CLAUSE')),
    
    -- Applicability
    applicable_customer_segments VARCHAR(50)[], -- ['IMPORTERS', 'EXPORTERS', 'CONTRACTORS']
    
    -- Financial Limits
    minimum_lc_amount DECIMAL(28,8),
    maximum_lc_amount DECIMAL(28,8),
    maximum_tenor_days INTEGER DEFAULT 365,
    
    -- Margin & Commission
    margin_requirement_percentage DECIMAL(5,4) DEFAULT 0.10, -- 10%
    issuance_commission_rate DECIMAL(10,6), -- Annual rate
    amendment_commission_rate DECIMAL(10,6),
    negotiation_commission_rate DECIMAL(10,6),
    
    -- Confirmation
    confirmation_allowed BOOLEAN DEFAULT TRUE,
    confirmation_commission_rate DECIMAL(10,6),
    
    -- Documents Required
    standard_documents_required TEXT[] DEFAULT ARRAY['COMMERCIAL_INVOICE', 'BILL_OF_LADING', 'PACKING_LIST', 'INSURANCE_CERTIFICATE'],
    additional_documents_options TEXT[], -- ['CERTIFICATE_OF_ORIGIN', 'INSPECTION_CERTIFICATE']
    
    -- Risk Controls
    country_risk_limit_enabled BOOLEAN DEFAULT TRUE,
    bank_risk_limit_enabled BOOLEAN DEFAULT TRUE,
    sanctions_check_required BOOLEAN DEFAULT TRUE,
    
    -- Settlement
    settlement_method VARCHAR(50) DEFAULT 'REIMBURSEMENT' 
        CHECK (settlement_method IN ('REIMBURSEMENT', 'ACCEPTANCE', 'DEFERRED_PAYMENT')),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.letter_of_credit_config_default PARTITION OF dynamic.letter_of_credit_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.letter_of_credit_config IS 'Letter of credit and guarantee configuration - LC issuance, amendments, settlement. Tier 2 - Trade Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.letter_of_credit_config TO finos_app;
