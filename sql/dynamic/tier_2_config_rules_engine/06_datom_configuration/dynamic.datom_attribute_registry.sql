-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Datom Configuration
-- TABLE: dynamic.datom_attribute_registry
--
-- DESCRIPTION:
--   E-A-V-Tx datom attribute registry for immutable event store.
--   Configures Datomic-style attributes for the E-A-V-Tx-Op model.
--   Maps to core_crypto.immutable_events.datom_attribute.
--
-- CORE DEPENDENCY: 006_immutable_event_store.sql
--
-- COMPLIANCE:
--   - Datomic E-A-V-Tx model
--   - Complete provenance tracking
--
-- ============================================================================

CREATE TABLE dynamic.datom_attribute_registry (
    attribute_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Attribute Identification
    attribute_namespace VARCHAR(100) NOT NULL, -- e.g., 'container', 'agent', 'movement'
    attribute_name VARCHAR(200) NOT NULL, -- e.g., 'balance', 'status', 'owner'
    attribute_qualified_name VARCHAR(310) GENERATED ALWAYS AS (attribute_namespace || '.' || attribute_name) STORED,
    attribute_description TEXT,
    
    -- Value Type (Datomic-inspired)
    value_type dynamic.datom_value_type NOT NULL,
    value_constraints JSONB, -- Min/max for numbers, regex for strings, etc.
    default_value JSONB,
    
    -- Cardinality
    cardinality VARCHAR(20) DEFAULT 'ONE', -- ONE or MANY (Datomic cardinality)
    unique_per_entity BOOLEAN DEFAULT FALSE, -- Whether attribute must be unique per entity
    
    -- Indexing (Datomic universal indexes)
    index_eavt BOOLEAN DEFAULT TRUE, -- Entity-Attribute-Value-Time (default)
    index_avet BOOLEAN DEFAULT FALSE, -- Attribute-Value-Entity-Time (for reverse lookups)
    index_aevt BOOLEAN DEFAULT FALSE, -- Attribute-Entity-Value-Time
    index_vaet BOOLEAN DEFAULT FALSE, -- Value-Attribute-Entity-Time (for reference attrs)
    
    -- Documentation
    documentation TEXT, -- Human-readable documentation
    examples JSONB, -- Example values
    
    -- Application Context
    applicable_entity_types VARCHAR(100)[], -- Which entity types can have this attribute
    required_for_entity_types VARCHAR(100)[], -- Entity types that MUST have this attribute
    
    -- Temporal
    no_history BOOLEAN DEFAULT FALSE, -- If true, don't keep history (Datomic noHistory)
    retire_at TIMESTAMP, -- When to stop accepting new assertions
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_defined BOOLEAN DEFAULT FALSE, -- System attributes vs user-defined
    
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
    
    -- Constraints
    CONSTRAINT unique_qualified_attr_name UNIQUE (tenant_id, attribute_qualified_name),
    CONSTRAINT chk_datom_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_attr_name_format CHECK (attribute_name ~ '^[a-z][a-z0-9_]*$')
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.datom_attribute_registry_default PARTITION OF dynamic.datom_attribute_registry DEFAULT;

-- Indexes
CREATE INDEX idx_datom_attr_namespace ON dynamic.datom_attribute_registry(tenant_id, attribute_namespace) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_datom_attr_entity_types ON dynamic.datom_attribute_registry USING GIN(applicable_entity_types) WHERE is_active = TRUE;
CREATE INDEX idx_datom_attr_qualified ON dynamic.datom_attribute_registry(tenant_id, attribute_qualified_name);

-- Comments
COMMENT ON TABLE dynamic.datom_attribute_registry IS 'Datomic E-A-V-Tx attribute registry - configures attributes for immutable event store. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.datom_attribute_registry.attribute_qualified_name IS 'Fully qualified attribute name (namespace.name)';
COMMENT ON COLUMN dynamic.datom_attribute_registry.index_avet IS 'Enable Attribute-Value-Entity-Time index for reverse lookups';
COMMENT ON COLUMN dynamic.datom_attribute_registry.no_history IS 'If true, old values are not retained (Datomic noHistory)';

-- Trigger
CREATE TRIGGER trg_datom_attribute_registry_audit
    BEFORE UPDATE ON dynamic.datom_attribute_registry
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.datom_attribute_registry TO finos_app;
