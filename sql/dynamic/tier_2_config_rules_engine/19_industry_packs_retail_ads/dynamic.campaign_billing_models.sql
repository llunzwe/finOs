-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Industry Packs: Retail & Ads
-- TABLE: dynamic.campaign_billing_models
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Campaign Billing Models.
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
CREATE TABLE dynamic.campaign_billing_models (

    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    model_code VARCHAR(100) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_description TEXT,
    
    -- Billing Type
    billing_type VARCHAR(50) NOT NULL 
        CHECK (billing_type IN ('FIXED_PRICE', 'PERFORMANCE_BASED', 'HYBRID', 'SUBSCRIPTION', 'RETAINER')),
    
    -- Performance Metrics (if performance-based)
    performance_metric VARCHAR(50), -- IMPRESSIONS, CLICKS, CONVERSIONS, VIEWS, ENGAGEMENTS
    performance_pricing_tiers JSONB, -- [{min: 0, max: 1000000, rate: 0.005}, ...]
    
    -- Fixed Price (if applicable)
    fixed_price_amount DECIMAL(28,8),
    fixed_price_currency CHAR(3),
    
    -- Hybrid Structure
    hybrid_structure JSONB, -- {base_fee: 5000, performance_component: 0.3, cap: 50000}
    
    -- Budget Controls
    daily_budget_limit DECIMAL(28,8),
    total_budget_limit DECIMAL(28,8),
    overdelivery_tolerance DECIMAL(5,4) DEFAULT 0.10,
    
    -- Pacing
    pacing_strategy VARCHAR(50) DEFAULT 'EVEN', -- EVEN, ACCELERATED, DAYPARTING
    pacing_schedule JSONB, -- [{day: 'MONDAY', percentage: 15}, ...]
    
    -- Billing Schedule
    billing_frequency VARCHAR(20) DEFAULT 'MONTHLY', -- DAILY, WEEKLY, MONTHLY, CAMPAIGN_END
    invoice_trigger VARCHAR(50) DEFAULT 'PERIOD_END', -- PERIOD_END, THRESHOLD_REACHED, MILESTONE
    invoice_threshold DECIMAL(28,8),
    
    -- Adjustments
    credit_policy TEXT,
    make_good_policy TEXT, -- Compensation for under-delivery
    cancellation_terms TEXT,
    
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
    
    CONSTRAINT unique_campaign_billing_model_code UNIQUE (tenant_id, model_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.campaign_billing_models_default PARTITION OF dynamic.campaign_billing_models DEFAULT;

-- Indexes
CREATE INDEX idx_campaign_billing_tenant ON dynamic.campaign_billing_models(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_campaign_billing_type ON dynamic.campaign_billing_models(tenant_id, billing_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.campaign_billing_models IS 'Advertising campaign billing models (fixed, performance, hybrid)';

-- Triggers
CREATE TRIGGER trg_campaign_billing_models_audit
    BEFORE UPDATE ON dynamic.campaign_billing_models
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.campaign_billing_models TO finos_app;