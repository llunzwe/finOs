-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic.business_rule_engine
-- DESCRIPTION:
--   Enterprise-grade configuration table for Business Rule Engine. - Script storage
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)

-- TIER CLASSIFICATION:
--   Tier 3 - Pro-Code Extensions: Developer-only JavaScript, Lua, WASM scripts.
--   Requires coding expertise - managed through developer interfaces.
-- ============================================================================

CREATE TABLE dynamic.business_rule_engine (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_set_name VARCHAR(200) NOT NULL,
    rule_code VARCHAR(100) NOT NULL,
    rule_description TEXT,
    
    -- Categorization
    rule_category VARCHAR(100) NOT NULL, -- CUSTOM_LOGIC, VALIDATION, WORKFLOW, PRICING, etc.
    rule_subcategory VARCHAR(100),
    
    -- Rule Logic
    expression_language VARCHAR(50) DEFAULT 'JSONLOGIC' 
        CHECK (expression_language IN ('JSONLOGIC', 'LUA', 'JAVASCRIPT', 'SQL', 'DSL')),
    expression TEXT NOT NULL, -- The actual rule expression
    
    -- Inputs/Outputs
    input_schema JSONB, -- JSON Schema for inputs
    output_schema JSONB, -- JSON Schema for outputs
    
    -- Context
    applicable_context VARCHAR(50) NOT NULL 
        CHECK (applicable_context IN ('GLOBAL', 'PRODUCT_SPECIFIC', 'CUSTOMER_SPECIFIC', 'TRANSACTION_SPECIFIC', 'WORKFLOW_SPECIFIC')),
    context_entity_type VARCHAR(50), -- If context-specific
    context_entity_id UUID,
    
    -- Execution
    execution_trigger VARCHAR(50) DEFAULT 'API_CALL' 
        CHECK (execution_trigger IN ('API_CALL', 'EVENT', 'SCHEDULE', 'WORKFLOW')),
    trigger_event_type VARCHAR(100), -- If event-triggered
    
    -- Priority and Ordering
    priority INTEGER DEFAULT 0,
    execution_order INTEGER DEFAULT 0,
    
    -- Actions
    true_action VARCHAR(50) DEFAULT 'RETURN_TRUE',
    false_action VARCHAR(50) DEFAULT 'RETURN_FALSE',
    action_config JSONB, -- {true: {...}, false: {...}}
    
    -- Testing
    test_cases JSONB, -- [{inputs: {...}, expected_output: {...}}]
    
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
    
    CONSTRAINT unique_business_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.business_rule_engine_default PARTITION OF dynamic.business_rule_engine DEFAULT;

COMMENT ON TABLE dynamic.business_rule_engine IS 'Business Rule Engine - Script storage. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic.business_rule_engine TO finos_app;
