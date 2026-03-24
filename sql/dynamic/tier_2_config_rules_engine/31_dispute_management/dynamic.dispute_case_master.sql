-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 31 - Dispute Management
-- TABLE: dynamic.dispute_case_master
--
-- DESCRIPTION:
--   Enterprise-grade dispute and chargeback case management.
--   Card disputes, transaction inquiries, fraud claims resolution.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: PCI DSS, Card Scheme Rules (Visa/MC/Amex), Consumer Protection
-- ============================================================================


CREATE TABLE dynamic.dispute_case_master (
    dispute_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Case Identification
    case_number VARCHAR(100) NOT NULL, -- e.g., "DSP-2024-000001"
    case_type VARCHAR(50) NOT NULL 
        CHECK (case_type IN ('CHARGEBACK', 'FRAUD_CLAIM', 'TRANSACTION_INQUIRY', 'MERCHANT_DISPUTE', 'PROCESSING_ERROR')),
    
    -- References
    customer_id UUID NOT NULL REFERENCES core.customers(id),
    account_id UUID REFERENCES core.accounts(id),
    card_id UUID, -- If card-related
    transaction_id UUID REFERENCES core.transactions(id),
    original_transaction_reference VARCHAR(100),
    merchant_id UUID,
    
    -- Dispute Details
    dispute_amount DECIMAL(28,8) NOT NULL,
    dispute_currency CHAR(3) NOT NULL,
    dispute_reason_code VARCHAR(50) NOT NULL, -- Card scheme reason codes
    dispute_reason_description TEXT,
    customer_claim_description TEXT,
    
    -- Card Scheme Specific
    card_scheme VARCHAR(20) CHECK (card_scheme IN ('VISA', 'MASTERCARD', 'AMEX', 'DISCOVER', 'JCB', 'UNIONPAY')),
    scheme_case_number VARCHAR(100),
    scheme_deadline_date DATE, -- Response deadline from scheme
    
    -- Status Workflow
    dispute_status VARCHAR(50) DEFAULT 'OPEN' 
        CHECK (dispute_status IN ('OPEN', 'UNDER_REVIEW', 'DOCUMENTS_REQUESTED', 'REPRESENTED', 'ACCEPTED', 'REJECTED', 'CLOSED', 'ESCALATED')),
    dispute_substatus VARCHAR(50),
    
    -- Resolution
    resolution_type VARCHAR(50), -- 'CUSTOMER_FAVORED', 'MERCHANT_FAVORED', 'PARTIAL', 'WITHDRAWN'
    resolved_amount DECIMAL(28,8),
    resolved_currency CHAR(3),
    resolution_notes TEXT,
    
    -- Financial Impact
    provisional_credit_issued BOOLEAN DEFAULT FALSE,
    provisional_credit_amount DECIMAL(28,8),
    provisional_credit_date DATE,
    final_credit_amount DECIMAL(28,8),
    fee_reversal_amount DECIMAL(28,8),
    
    -- Timeline
    opened_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    documents_due_date DATE,
    response_submitted_date TIMESTAMPTZ,
    resolved_date TIMESTAMPTZ,
    closed_date TIMESTAMPTZ,
    days_open INTEGER GENERATED ALWAYS AS (
        EXTRACT(DAY FROM COALESCE(closed_date, NOW()) - opened_date)
    ) STORED,
    
    -- Assignment
    assigned_team VARCHAR(100),
    assigned_agent_id UUID,
    assigned_date TIMESTAMPTZ,
    
    -- Priority
    priority_level VARCHAR(20) DEFAULT 'MEDIUM' 
        CHECK (priority_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    is_regulatory_complaint BOOLEAN DEFAULT FALSE,
    is_media_sensitive BOOLEAN DEFAULT FALSE,
    
    -- Documentation
    evidence_documents JSONB DEFAULT '[]', -- Array of document references
    customer_response TEXT,
    merchant_response TEXT,
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_case_number_per_tenant UNIQUE (tenant_id, case_number)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dispute_case_master_default PARTITION OF dynamic.dispute_case_master DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_dispute_tenant ON dynamic.dispute_case_master(tenant_id);
CREATE INDEX idx_dispute_status ON dynamic.dispute_case_master(tenant_id, dispute_status);
CREATE INDEX idx_dispute_customer ON dynamic.dispute_case_master(tenant_id, customer_id);
CREATE INDEX idx_dispute_transaction ON dynamic.dispute_case_master(tenant_id, transaction_id);
CREATE INDEX idx_dispute_opened ON dynamic.dispute_case_master(tenant_id, opened_date);
CREATE INDEX idx_dispute_scheme ON dynamic.dispute_case_master(tenant_id, card_scheme, scheme_case_number);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.dispute_case_master IS 'Dispute and chargeback case management - card disputes, fraud claims, transaction inquiries. Tier 2 - Dispute Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.dispute_case_master TO finos_app;
