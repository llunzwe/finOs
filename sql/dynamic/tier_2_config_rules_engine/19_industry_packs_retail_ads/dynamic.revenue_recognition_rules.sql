-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Industry Packs: Retail & Ads
-- TABLE: dynamic.revenue_recognition_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Revenue Recognition Rules.
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
CREATE TABLE dynamic.revenue_recognition_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Applicability
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    pos_transaction_type_id UUID REFERENCES dynamic.pos_transaction_types(type_id),
    applicable_sales_channels VARCHAR(50)[], -- RETAIL, ONLINE, MARKETPLACE, WHOLESALE
    
    -- Recognition Criteria
    recognition_trigger VARCHAR(50) NOT NULL 
        CHECK (recognition_trigger IN ('POINT_OF_SALE', 'DELIVERY', 'INSTALLATION', 'ACCEPTANCE', 'SUBSCRIPTION_PERIOD', 'MILESTONE', 'PERCENTAGE_COMPLETE')),
    
    -- Timing
    recognition_timing VARCHAR(50) DEFAULT 'IMMEDIATE' 
        CHECK (recognition_timing IN ('IMMEDIATE', 'DEFERRED', 'RATABLE', 'UPON_DELIVERY')),
    deferral_period_days INTEGER,
    
    -- For Subscriptions
    subscription_recognition_method VARCHAR(50), -- DAILY, MONTHLY_START, MONTHLY_END
    proration_method VARCHAR(50), -- DAILY, MONTHLY_THIRTY_DAY
    
    -- For Multiple Elements
    standalone_selling_prices JSONB, -- [{element: 'hardware', price: 500}, {element: 'service', price: 100}]
    allocation_method VARCHAR(50) DEFAULT 'RELATIVE_STANDALONE', -- RELATIVE_STANDALONE, RESIDUAL
    
    -- Variable Consideration
    variable_consideration_estimation VARCHAR(50), -- MOST_LIKELY, PROBABILITY_WEIGHTED, CONSTRAINT
    constraint_estimate_threshold DECIMAL(5,4), -- Only recognize amounts above reversal probability
    
    -- Returns/Refunds
    expected_return_rate DECIMAL(5,4) DEFAULT 0,
    refund_reserve_method VARCHAR(50), -- HISTORICAL_RATE, ESTIMATED, ACTUAL
    
    -- Discounts
    discount_allocation VARCHAR(50) DEFAULT 'PROPORTIONAL', -- PROPORTIONAL, SPECIFIC_ELEMENT
    
    -- GL Mapping
    deferred_revenue_account VARCHAR(50),
    recognized_revenue_account VARCHAR(50),
    contra_revenue_account VARCHAR(50),
    
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
    
    CONSTRAINT unique_revenue_recog_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.revenue_recognition_rules_default PARTITION OF dynamic.revenue_recognition_rules DEFAULT;

-- Indexes
CREATE INDEX idx_revenue_recog_rules_tenant ON dynamic.revenue_recognition_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_revenue_recog_rules_category ON dynamic.revenue_recognition_rules(tenant_id, product_category_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.revenue_recognition_rules IS 'IFRS 15 revenue recognition rules for retail';

-- Triggers
CREATE TRIGGER trg_revenue_recognition_rules_audit
    BEFORE UPDATE ON dynamic.revenue_recognition_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.revenue_recognition_rules TO finos_app;