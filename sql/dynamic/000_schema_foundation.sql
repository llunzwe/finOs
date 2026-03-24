-- ============================================================================
-- FINOS DYNAMIC LAYER - SCHEMA FOUNDATION
-- ============================================================================
-- Enterprise-Grade Dynamic Configuration Layer for PostgreSQL 16+
-- Features: Bitemporal, Multi-tenant, Encrypted, Partitioning, Audit
-- Standards: FINOS, Basel III/IV, IFRS 9/15/17, GDPR, SOC2, SARB, RBZ
-- ============================================================================

-- ============================================================================
-- SCHEMA SETUP
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS dynamic;
CREATE SCHEMA IF NOT EXISTS dynamic_history;

COMMENT ON SCHEMA dynamic IS 
'FinOS Dynamic Layer - Product Configuration, Pricing, Workflow, and Business Rules. Tier 2 Low-Code Configuration.';

COMMENT ON SCHEMA dynamic_history IS 
'FinOS Dynamic Layer - Historical/Audit Data for bitemporal tracking and compliance.';

-- ============================================================================
-- CUSTOM ENUMERATIONS
-- ============================================================================

-- Product Status Enumeration
CREATE TYPE dynamic.product_status AS ENUM (
    'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'ACTIVE', 'DEPRECATED', 'SUSPENDED', 'RETIRED'
);
COMMENT ON TYPE dynamic.product_status IS 'Product lifecycle states from draft to retirement';

-- Template Inheritance Strategy
CREATE TYPE dynamic.inheritance_strategy AS ENUM (
    'STRICT', 'OVERRIDABLE', 'EXTENSIBLE', 'COMPOSITE'
);

-- Amortization Types
CREATE TYPE dynamic.amortization_type AS ENUM (
    'BULLET', 'AMORTIZING', 'ANNUITY', 'LINEAR', 'DECLINING_BALANCE', 'INTEREST_ONLY', 'CUSTOM'
);
COMMENT ON TYPE dynamic.amortization_type IS 'Loan repayment schedule types (IFRS 9)';

-- Interest Accrual Methods (ISO 20022 aligned)
CREATE TYPE dynamic.accrual_method AS ENUM (
    'ACTUAL_360', 'ACTUAL_365', 'ACTUAL_ACTUAL', 'THIRTY_360', 'THIRTY_E_360', 'THIRTY_E_360_ISDA', 'BUSINESS_252'
);
COMMENT ON TYPE dynamic.accrual_method IS 'Day count conventions for interest calculation (ISO 20022)';

-- Grace Period Types
CREATE TYPE dynamic.grace_period_type AS ENUM (
    'NONE', 'PRINCIPAL_ONLY', 'PRINCIPAL_AND_INTEREST', 'INTEREST_ONLY'
);

-- Card Schemes (PCI DSS)
CREATE TYPE dynamic.card_scheme AS ENUM (
    'VISA', 'MASTERCARD', 'AMEX', 'DISCOVER', 'JCB', 'UNIONPAY', 'DINERS', 'LOCAL'
);
COMMENT ON TYPE dynamic.card_scheme IS 'Payment card schemes (PCI DSS compliance)';

-- Card Types
CREATE TYPE dynamic.card_type AS ENUM (
    'CREDIT', 'DEBIT', 'PREPAID', 'VIRTUAL', 'FLEET', 'PURCHASE'
);

-- Coverage Types for Insurance (IFRS 17)
CREATE TYPE dynamic.coverage_type AS ENUM (
    'TERM_LIFE', 'WHOLE_LIFE', 'ENDOWMENT', 'UNIVERSAL_LIFE', 'GENERAL', 'HEALTH', 'MICRO', 'GROUP'
);
COMMENT ON TYPE dynamic.coverage_type IS 'Insurance coverage types (IFRS 17)';

-- Underwriting Automation Levels
CREATE TYPE dynamic.underwriting_level AS ENUM (
    'FULLY_AUTOMATED', 'SEMI_AUTOMATED', 'MANUAL', 'REFERRED'
);

-- Premium Frequency Options
CREATE TYPE dynamic.premium_frequency AS ENUM (
    'MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'SINGLE', 'FLEXIBLE'
);

-- Islamic Contract Types (AAOIFI)
CREATE TYPE dynamic.islamic_contract_type AS ENUM (
    'MURABAHA', 'MUDARABAH', 'IJARAH', 'WAKALAH', 'MUSHARAKAH', 'ISTISNA', 'SALAM', 'TAZARA'
);
COMMENT ON TYPE dynamic.islamic_contract_type IS 'Shariah-compliant contract structures (AAOIFI)';

-- Workflow States (BPMN 2.0)
CREATE TYPE dynamic.workflow_state AS ENUM (
    'PENDING', 'IN_PROGRESS', 'WAITING_FOR_APPROVAL', 'APPROVED', 'REJECTED', 
    'ESCALATED', 'COMPLETED', 'CANCELLED', 'ON_HOLD'
);
COMMENT ON TYPE dynamic.workflow_state IS 'Workflow instance states (BPMN 2.0 / ISO 19510)';

-- Transition Types
CREATE TYPE dynamic.transition_type AS ENUM (
    'MANUAL', 'AUTOMATIC', 'CONDITIONAL', 'TIME_BASED', 'EVENT_DRIVEN'
);

-- Fee Categories (IFRS 15)
CREATE TYPE dynamic.fee_category AS ENUM (
    'TRANSACTION', 'PERIODIC', 'PENALTY', 'UPFRONT', 'LATE_PAYMENT', 
    'PREPAYMENT', 'ADMINISTRATIVE', 'PROCESSING'
);
COMMENT ON TYPE dynamic.fee_category IS 'Fee classification for revenue recognition (IFRS 15)';

-- Tax Types (OECD)
CREATE TYPE dynamic.tax_type AS ENUM (
    'VAT', 'GST', 'INCOME', 'STAMP', 'DUTY', 'WITHHOLDING', 
    'CAPITAL_GAINS', 'CORPORATE', 'EXCISE'
);
COMMENT ON TYPE dynamic.tax_type IS 'Global tax classifications (OECD Model Tax Convention)';

-- Hook Trigger Scopes
CREATE TYPE dynamic.hook_scope AS ENUM (
    'GLOBAL', 'PRODUCT_SPECIFIC', 'TENANT_SPECIFIC', 'ENTITY_SPECIFIC'
);

-- Script Languages (Tier 3)
CREATE TYPE dynamic.script_language AS ENUM (
    'PYTHON', 'JAVASCRIPT', 'DSL', 'SQL', 'LUA'
);
COMMENT ON TYPE dynamic.script_language IS 'Supported scripting languages for Tier 3 extensions';

-- Simulation Scenario Families (Basel III)
CREATE TYPE dynamic.scenario_family AS ENUM (
    'RATE_SHOCK', 'CREDIT_CYCLE', 'STRESS_TEST', 'MACRO_ECONOMIC', 'LIQUIDITY', 'OPERATIONAL'
);
COMMENT ON TYPE dynamic.scenario_family IS 'Regulatory stress testing scenarios (Basel III/IV)';

-- ECL Model Approaches (IFRS 9)
CREATE TYPE dynamic.ecl_approach AS ENUM (
    'SIMPLIFIED', 'GENERAL', 'LOW_CREDIT_RISK', 'PURCHASED_CREDIT_IMPAIRED'
);
COMMENT ON TYPE dynamic.ecl_approach IS 'Expected Credit Loss calculation approaches (IFRS 9)';

-- Claim Types (IFRS 17)
CREATE TYPE dynamic.claim_type AS ENUM (
    'DEATH', 'MATURITY', 'SURRENDER', 'DAMAGE', 'THEFT', 'LOSS', 
    'DISABILITY', 'CRITICAL_ILLNESS', 'ACCIDENT'
);

-- Claim Status
CREATE TYPE dynamic.claim_status AS ENUM (
    'REGISTERED', 'DOCUMENTS_PENDING', 'UNDER_INVESTIGATION', 
    'UNDER_ASSESSMENT', 'APPROVED', 'REJECTED', 'PARTIALLY_APPROVED', 'PAID', 'CLOSED'
);

-- Reinsurance Treaty Types
CREATE TYPE dynamic.reinsurance_type AS ENUM (
    'QUOTA_SHARE', 'SURPLUS', 'EXCESS_OF_LOSS', 'STOP_LOSS', 'FACULTATIVE', 'TREATY'
);

-- Collateral Categories (Basel III)
CREATE TYPE dynamic.collateral_category AS ENUM (
    'REAL_ESTATE', 'VEHICLE', 'FINANCIAL_INSTRUMENT', 'CASH', 'INVENTORY', 
    'EQUIPMENT', 'INTELLECTUAL_PROPERTY', 'GUARANTEE', 'INSURANCE_POLICY'
);
COMMENT ON TYPE dynamic.collateral_category IS 'Collateral asset categories (Basel III CRM)';

-- Agreement Types (UNCITRAL)
CREATE TYPE dynamic.agreement_type AS ENUM (
    'MORTGAGE', 'BOND', 'LIEN', 'PLEDGE', 'HYPOTHECATION', 'CHARGE', 'DEBENTURE'
);
COMMENT ON TYPE dynamic.agreement_type IS 'Security agreement types (UNCITRAL Secured Transactions)';

-- Regulatory Authorities
CREATE TYPE dynamic.regulatory_authority AS ENUM (
    'SARB', 'RBZ', 'FSCA', 'PRUDENTIAL', 'FATF', 'FINTECH', 'CENTRAL_BANK', 'REVENUE_SERVICE'
);
COMMENT ON TYPE dynamic.regulatory_authority IS 'Financial regulatory bodies (SADC region)';

-- API Auth Types (ISO 27001)
CREATE TYPE dynamic.api_auth_type AS ENUM (
    'OAUTH2', 'API_KEY', 'MUTUAL_TLS', 'BASIC_AUTH', 'JWT', 'HMAC'
);
COMMENT ON TYPE dynamic.api_auth_type IS 'API authentication methods (ISO 27001)';

-- File Types (ISO 20022)
CREATE TYPE dynamic.file_type AS ENUM (
    'CSV', 'FIXED_WIDTH', 'XML', 'JSON', 'ISO20022', 'SWIFT_MT', 'SWIFT_MX', 'EXCEL'
);
COMMENT ON TYPE dynamic.file_type IS 'File format standards (ISO 20022 / SWIFT)';

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to generate dynamic entity codes
CREATE OR REPLACE FUNCTION dynamic.generate_entity_code(
    p_tenant_id UUID,
    p_entity_type VARCHAR,
    p_prefix VARCHAR DEFAULT 'DYN'
) RETURNS VARCHAR AS $$
DECLARE
    v_year_month VARCHAR(7);
    v_next_seq BIGINT;
    v_padded_seq VARCHAR;
    v_result VARCHAR;
BEGIN
    v_year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    INSERT INTO dynamic.entity_code_sequences (tenant_id, entity_type, prefix, year_month, last_sequence)
    VALUES (p_tenant_id, p_entity_type, p_prefix, v_year_month, 1)
    ON CONFLICT (tenant_id, entity_type, prefix, year_month) 
    DO UPDATE SET 
        last_sequence = dynamic.entity_code_sequences.last_sequence + 1,
        updated_at = NOW()
    RETURNING dynamic.entity_code_sequences.last_sequence INTO v_next_seq;
    
    v_padded_seq := LPAD(v_next_seq::text, 6, '0');
    v_result := p_prefix || '-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || v_padded_seq;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION dynamic.generate_entity_code IS 
'Generates unique, sortable human-readable entity codes for dynamic layer (BCBS 239 compliant)';

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT USAGE ON SCHEMA dynamic TO finos_app;
GRANT USAGE ON SCHEMA dynamic_history TO finos_app;
GRANT EXECUTE ON FUNCTION dynamic.generate_entity_code TO finos_app;

-- ============================================================================
-- COMPLIANCE NOTES
-- ============================================================================
-- This schema foundation provides:
--   - ISO 20022 aligned enumerations for financial messaging
--   - IFRS 9/15/17 compliant classifications
--   - Basel III/IV regulatory categories
--   - GDPR/SOX audit-ready structures
--   - AAOIFI Islamic finance support
--   - PCI DSS card data handling
-- ============================================================================
