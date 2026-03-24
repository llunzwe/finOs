-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.kyc_requirement_template
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
-- ============================================================================


CREATE TABLE dynamic.kyc_requirement_template (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Scope
    customer_type VARCHAR(20) NOT NULL CHECK (customer_type IN ('INDIVIDUAL', 'CORPORATE', 'TRUST', 'PARTNERSHIP')),
    risk_band VARCHAR(20), -- Specific to risk band
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    jurisdiction_id UUID REFERENCES dynamic.tax_jurisdiction_master(jurisdiction_id),
    
    -- Required Documents
    required_documents JSONB NOT NULL, -- [{doc_type: 'ID', mandatory: true, validity_months: 60}, ...]
    required_verifications JSONB, -- [{type: 'ADDRESS', mandatory: true}, ...]
    
    -- Renewal
    renewal_frequency_months INTEGER DEFAULT 12,
    renewal_trigger_events VARCHAR(50)[], -- RISK_CHANGE, DOCUMENT_EXPIRY, etc.
    
    -- EDD Triggers
    enhanced_due_diligence_triggers JSONB, -- {pep_status: true, high_risk_country: true, ...}
    edd_additional_requirements JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.kyc_requirement_template_default PARTITION OF dynamic.kyc_requirement_template DEFAULT;

-- Indexes
CREATE INDEX idx_kyc_template_tenant ON dynamic.kyc_requirement_template(tenant_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.kyc_requirement_template IS 'KYC requirements by customer type and risk profile';

-- Triggers
CREATE TRIGGER trg_kyc_template_audit
    BEFORE UPDATE ON dynamic.kyc_requirement_template
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.kyc_requirement_template TO finos_app;