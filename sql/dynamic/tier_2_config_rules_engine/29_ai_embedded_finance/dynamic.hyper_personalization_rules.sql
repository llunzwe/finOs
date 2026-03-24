-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 29 - AI & Embedded Finance
-- TABLE: dynamic.hyper_personalization_rules
--
-- DESCRIPTION:
--   Enterprise-grade hyper-personalization and next-best-action configuration.
--   Predictive analytics, recommendation engines, behavioral targeting.
--
-- COMPLIANCE: GDPR, POPIA, AI Ethics, Financial Regulations
-- ============================================================================


CREATE TABLE dynamic.hyper_personalization_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Configuration
    rule_name VARCHAR(200) NOT NULL,
    rule_type VARCHAR(50) NOT NULL 
        CHECK (rule_type IN ('NEXT_BEST_ACTION', 'PRODUCT_RECOMMENDATION', 'PRICING_OPTIMIZATION', 'CHURN_PREVENTION', 'CROSS_SELL', 'UP_SELL')),
    
    -- Target Audience
    target_customer_segments VARCHAR(50)[],
    target_lifecycle_stage VARCHAR(50), -- 'NEW', 'ACTIVE', 'DORMANT', 'AT_RISK'
    
    -- Trigger Conditions
    trigger_events VARCHAR(100)[], -- ['LOGIN', 'TRANSACTION', 'BALANCE_THRESHOLD']
    behavioral_conditions JSONB DEFAULT '{}', -- {"transaction_frequency": "low", "savings_balance": "low"}
    
    -- AI/ML Model
    ml_model_id VARCHAR(100),
    prediction_confidence_threshold DECIMAL(5,4) DEFAULT 0.70,
    
    -- Recommendation Content
    recommended_products UUID[], -- Product IDs
    recommended_actions VARCHAR(100)[], -- ['SHOW_SAVINGS_ACCOUNT', 'OFFER_LOAN']
    personalized_pricing_modifier DECIMAL(5,4), -- e.g., 0.95 for 5% discount
    
    -- Delivery Channels
    delivery_channels VARCHAR(50)[] DEFAULT ARRAY['MOBILE_APP', 'EMAIL', 'SMS'],
    delivery_timing VARCHAR(50) DEFAULT 'REALTIME' 
        CHECK (delivery_timing IN ('REALTIME', 'DAILY_DIGEST', 'WEEKLY_DIGEST')),
    
    -- Constraints
    max_recommendations_per_day INTEGER DEFAULT 3,
    cooldown_period_hours INTEGER DEFAULT 24,
    
    -- Performance Tracking
    track_conversion BOOLEAN DEFAULT TRUE,
    success_metric VARCHAR(50) DEFAULT 'CLICK_THROUGH' 
        CHECK (success_metric IN ('CLICK_THROUGH', 'CONVERSION', 'ENGAGEMENT')),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.hyper_personalization_rules_default PARTITION OF dynamic.hyper_personalization_rules DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.hyper_personalization_rules IS 'Hyper-personalization rules - next-best-action, predictive analytics, recommendations. Tier 2 - AI & Embedded Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.hyper_personalization_rules TO finos_app;
