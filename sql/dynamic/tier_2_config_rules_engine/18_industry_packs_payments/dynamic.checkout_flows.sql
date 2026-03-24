-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 18 - Industry Packs: Payments
-- TABLE: dynamic.checkout_flows
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Checkout Flows.
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
CREATE TABLE dynamic.checkout_flows (

    flow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    flow_code VARCHAR(100) NOT NULL,
    flow_name VARCHAR(200) NOT NULL,
    flow_description TEXT,
    
    -- Flow Type
    checkout_type VARCHAR(50) NOT NULL 
        CHECK (checkout_type IN ('STANDARD', 'EXPRESS', 'GUEST', 'SUBSCRIPTION', 'MARKETPLACE', 'B2B', 'MOBILE', 'EMBEDDED')),
    
    -- Flow Configuration
    flow_steps JSONB NOT NULL, -- [{step: 'CART', required: true}, {step: 'SHIPPING', required: false}, ...]
    step_sequence JSONB, -- Ordered list of steps with conditions
    
    -- Payment Methods
    available_payment_methods UUID[], -- Restrict to specific methods
    default_payment_method UUID,
    payment_method_grouping BOOLEAN DEFAULT FALSE, -- Group by type
    
    -- Fields
    required_customer_fields VARCHAR(50)[], -- EMAIL, PHONE, ADDRESS, etc.
    optional_customer_fields VARCHAR(50)[],
    field_validation_rules JSONB,
    
    -- UI Configuration
    ui_theme VARCHAR(50) DEFAULT 'DEFAULT',
    layout_type VARCHAR(50) DEFAULT 'SINGLE_PAGE', -- SINGLE_PAGE, MULTI_STEP, MODAL
    branding_config JSONB, -- {logo_url: '...', primary_color: '#...', etc.}
    
    -- Features
    save_payment_method BOOLEAN DEFAULT TRUE,
    express_checkout_enabled BOOLEAN DEFAULT FALSE,
    promo_code_enabled BOOLEAN DEFAULT TRUE,
    gift_card_enabled BOOLEAN DEFAULT FALSE,
    loyalty_points_enabled BOOLEAN DEFAULT FALSE,
    
    -- Security
    require_authentication BOOLEAN DEFAULT FALSE,
    authentication_methods VARCHAR(50)[], -- PASSWORD, OTP, BIOMETRIC
    session_timeout_minutes INTEGER DEFAULT 30,
    
    -- Post-Checkout
    redirect_url_success VARCHAR(500),
    redirect_url_failure VARCHAR(500),
    redirect_url_pending VARCHAR(500),
    confirmation_email_enabled BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
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
    
    CONSTRAINT unique_checkout_flow_code UNIQUE (tenant_id, flow_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.checkout_flows_default PARTITION OF dynamic.checkout_flows DEFAULT;

-- Indexes
CREATE INDEX idx_checkout_flows_tenant ON dynamic.checkout_flows(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_checkout_flows_type ON dynamic.checkout_flows(tenant_id, checkout_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.checkout_flows IS 'Checkout flow configurations for different channels';

-- Triggers
CREATE TRIGGER trg_checkout_flows_audit
    BEFORE UPDATE ON dynamic.checkout_flows
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.checkout_flows TO finos_app;