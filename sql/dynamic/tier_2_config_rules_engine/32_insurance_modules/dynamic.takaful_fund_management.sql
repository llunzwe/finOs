-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 32 - Insurance Product Modules
-- TABLE: dynamic.takaful_fund_management
--
-- DESCRIPTION:
--   Enterprise-grade Takaful fund management configuration.
--   Participant fund (tabarru'), operator fund, surplus distribution, qard hasan.
--   Supports AAOIFI standards, bitemporal tracking, and comprehensive audit trails.
--
-- COMPLIANCE: AAOIFI, IFRS 17, Islamic Finance Regulations
-- ============================================================================


CREATE TABLE dynamic.takaful_fund_management (
    fund_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Fund Identification
    fund_code VARCHAR(100) NOT NULL,
    fund_name VARCHAR(200) NOT NULL,
    fund_type VARCHAR(50) NOT NULL 
        CHECK (fund_type IN ('PARTICIPANT_FUND', 'OPERATOR_FUND', 'WAQF_FUND', 'RESERVE_FUND')),
    
    -- Takaful Model
    takaful_model VARCHAR(50) NOT NULL 
        CHECK (takaful_model IN ('WAKALAH', 'MUDARABAH', 'WAQF', 'HYBRID')),
    
    -- Linked Product
    insurance_product_id UUID REFERENCES dynamic.insurance_product_config(config_id),
    
    -- Fund Structure
    participant_contribution_rate DECIMAL(5,4) DEFAULT 1.0, -- 100% to participant fund
    tabarru_rate DECIMAL(5,4) DEFAULT 0.80, -- 80% of contribution to risk pool
    operator_fee_rate DECIMAL(5,4) DEFAULT 0.20, -- 20% operator fee
    
    -- Mudarabah Profit Sharing (if applicable)
    mudarabah_profit_sharing_ratio DECIMAL(5,4), -- Operator's share of surplus
    participant_surplus_share DECIMAL(5,4), -- Participants' share of surplus
    
    -- Reserve Requirements
    technical_reserve_percentage DECIMAL(5,4) DEFAULT 0.50, -- 50% retained
    contingency_reserve_percentage DECIMAL(5,4) DEFAULT 0.10,
    
    -- Surplus Distribution
    surplus_distribution_frequency VARCHAR(20) DEFAULT 'ANNUAL' 
        CHECK (surplus_distribution_frequency IN ('ANNUAL', 'BIANNUAL', 'QUARTERLY')),
    surplus_distribution_method VARCHAR(50) DEFAULT 'PROPORTIONAL' 
        CHECK (surplus_distribution_method IN ('PROPORTIONAL', 'EQUAL', 'CLAIMS_EXPERIENCE')),
    minimum_surplus_for_distribution DECIMAL(28,8) DEFAULT 0,
    
    -- Qard Hasan (Interest-free Loan)
    qard_hasan_enabled BOOLEAN DEFAULT TRUE,
    max_qard_hasan_percentage DECIMAL(5,4) DEFAULT 0.30, -- 30% of fund
    qard_hasan_repayment_source VARCHAR(50) DEFAULT 'FUTURE_SURPLUS', 
    
    -- Waqf Specific (if applicable)
    waqf_purpose TEXT,
    waqf_beneficiaries TEXT[],
    
    -- Fund Status
    fund_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (fund_status IN ('FORMATION', 'ACTIVE', 'UNDER_SURPLUS', 'DEFICIT', 'CLOSED')),
    current_fund_balance DECIMAL(28,8) DEFAULT 0,
    current_surplus_amount DECIMAL(28,8) DEFAULT 0,
    accumulated_deficit DECIMAL(28,8) DEFAULT 0,
    
    -- GL Account Mapping
    participant_fund_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    operator_fund_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    tabarru_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    surplus_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_fund_code_per_tenant UNIQUE (tenant_id, fund_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.takaful_fund_management_default PARTITION OF dynamic.takaful_fund_management DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_takaful_fund_tenant ON dynamic.takaful_fund_management(tenant_id);
CREATE INDEX idx_takaful_fund_type ON dynamic.takaful_fund_management(tenant_id, fund_type);
CREATE INDEX idx_takaful_fund_product ON dynamic.takaful_fund_management(tenant_id, insurance_product_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.takaful_fund_management IS 'Takaful fund management - participant fund, operator fund, surplus distribution, qard hasan. Tier 2 - Insurance Product Modules.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.takaful_fund_management TO finos_app;
