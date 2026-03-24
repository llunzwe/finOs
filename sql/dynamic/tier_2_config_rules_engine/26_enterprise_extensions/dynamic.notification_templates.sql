-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.notification_templates
--
-- DESCRIPTION:
--   Enterprise-grade notification template management.
--   Multi-channel notifications (email, SMS, push, WhatsApp).
--
-- ============================================================================


CREATE TABLE dynamic.notification_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Template Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Template Content
    template_subject VARCHAR(500),
    template_body TEXT NOT NULL,
    template_body_html TEXT,
    
    -- Template Type
    notification_type VARCHAR(50) NOT NULL 
        CHECK (notification_type IN ('TRANSACTION_ALERT', 'MARKETING', 'SECURITY', 'REMINDER', 'WELCOME', 'STATEMENT', 'OTP', 'APPROVAL')),
    
    -- Supported Channels
    supported_channels VARCHAR(50)[] DEFAULT ARRAY['EMAIL', 'SMS', 'PUSH'], -- 'EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP'
    default_channel VARCHAR(20) DEFAULT 'EMAIL',
    
    -- Variables/Placeholders
    template_variables JSONB DEFAULT '[]', -- [{"name": "customer_name", "type": "STRING"}]
    
    -- Sender Configuration
    from_address VARCHAR(255),
    from_name VARCHAR(200),
    reply_to_address VARCHAR(255),
    
    -- Localization
    language_code CHAR(2) DEFAULT 'EN',
    localized_versions JSONB DEFAULT '{}', -- {"FR": "template_id_fr", "ES": "template_id_es"}
    
    -- UI/UX
    header_image_url TEXT,
    footer_text TEXT,
    brand_color VARCHAR(7), -- Hex color
    
    -- Delivery Settings
    priority VARCHAR(20) DEFAULT 'NORMAL' 
        CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    retry_attempts INTEGER DEFAULT 3,
    expiry_hours INTEGER DEFAULT 48,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_template_code_lang UNIQUE (tenant_id, template_code, language_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.notification_templates_default PARTITION OF dynamic.notification_templates DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_notification_templates_tenant ON dynamic.notification_templates(tenant_id);
CREATE INDEX idx_notification_templates_type ON dynamic.notification_templates(tenant_id, notification_type);
CREATE INDEX idx_notification_templates_active ON dynamic.notification_templates(tenant_id, is_active);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.notification_templates IS 'Notification templates - multi-channel (email, SMS, push, WhatsApp). Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.notification_templates TO finos_app;
