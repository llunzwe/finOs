-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Economic Agents
-- TABLE: dynamic.relationship_type_definitions
--
-- DESCRIPTION:
--   Relationship type definitions for economic agent relationships.
--   Configures ownership, control, and association types.
--
-- CORE DEPENDENCY: 004_economic_agent_and_relationships.sql
--
-- ============================================================================

CREATE TABLE dynamic.relationship_type_definitions (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Type Identification
    relationship_code VARCHAR(100) NOT NULL,
    relationship_name VARCHAR(200) NOT NULL,
    relationship_description TEXT,
    
    -- Relationship Classification
    category VARCHAR(50) NOT NULL, -- 'OWNERSHIP', 'CONTROL', 'ASSOCIATION', 'FAMILY', 'EMPLOYMENT'
    directionality VARCHAR(20) DEFAULT 'DIRECTED', -- DIRECTED, BIDIRECTIONAL, SYMMETRIC
    
    -- Ownership/Control Specific
    implies_ownership BOOLEAN DEFAULT FALSE,
    implies_control BOOLEAN DEFAULT FALSE,
    ownership_percentage_required BOOLEAN DEFAULT FALSE,
    min_ownership_percentage DECIMAL(5,2), -- 0.00 to 100.00
    
    -- Validation Rules
    allowed_from_entity_types VARCHAR(50)[], -- 'INDIVIDUAL', 'CORPORATION', 'TRUST', etc.
    allowed_to_entity_types VARCHAR(50)[],
    max_relationships_per_entity INTEGER, -- NULL = unlimited
    
    -- Regulatory Reporting
    reportable_to_regulator BOOLEAN DEFAULT FALSE,
    regulator_authority VARCHAR(100),
    report_threshold_amount DECIMAL(28,8),
    
    -- Risk Scoring
    default_risk_weight DECIMAL(5,4) DEFAULT 1.0000, -- Multiplier for risk calculations
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_defined BOOLEAN DEFAULT FALSE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_relationship_type_code UNIQUE (tenant_id, relationship_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.relationship_type_definitions_default PARTITION OF dynamic.relationship_type_definitions DEFAULT;

CREATE INDEX idx_relationship_type_category ON dynamic.relationship_type_definitions(tenant_id, category) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.relationship_type_definitions IS 'Relationship type definitions for economic agent relationships. Tier 2 Low-Code';

CREATE TRIGGER trg_relationship_type_definitions_audit
    BEFORE UPDATE ON dynamic.relationship_type_definitions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.relationship_type_definitions TO finos_app;
