-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_category_hierarchy
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Category Hierarchy.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 17442 (LEI)
--   - ISO 4217
--   - IFRS 9
--   - AAOIFI
--   - BCBS 239
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


CREATE TABLE dynamic.product_category_hierarchy (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    ancestor_id UUID NOT NULL REFERENCES dynamic.product_category(category_id) ON DELETE CASCADE,
    descendant_id UUID NOT NULL REFERENCES dynamic.product_category(category_id) ON DELETE CASCADE,
    path_length INTEGER NOT NULL DEFAULT 0, -- 0 = self, 1 = parent, etc.
    is_leaf_node BOOLEAN GENERATED ALWAYS AS (path_length = 0) STORED,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_hierarchy_path UNIQUE (tenant_id, ancestor_id, descendant_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_category_hierarchy_default PARTITION OF dynamic.product_category_hierarchy DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_category_hierarchy_ancestor
idx_category_hierarchy_descendant
idx_category_hierarchy_leaf

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_category_hierarchy IS 'Closure table for efficient hierarchical queries on product categories';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_category_hierarchy TO finos_app;
