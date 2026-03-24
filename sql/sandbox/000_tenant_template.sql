-- =============================================================================
-- FINOS CORE KERNEL - XENO: TENANT TEMPLATE
-- =============================================================================
-- File: xeno/000_tenant_template.sql
-- Description: Template for tenant-specific customizations and extensions
--              This is part of the experimental/xeno layer - use with caution
-- =============================================================================

-- =============================================================================
-- TENANT-SPECIFIC CUSTOMIZATIONS
-- =============================================================================

-- Example: Custom views for a specific tenant
-- CREATE OR REPLACE VIEW xeno.tenant_custom_report AS ...

-- Example: Tenant-specific functions
-- CREATE OR REPLACE FUNCTION xeno.tenant_custom_logic() RETURNS ...

-- Example: Tenant-specific tables (non-core)
-- CREATE TABLE xeno.tenant_custom_data (...)

-- =============================================================================
-- SHARED EXPERIMENTS
-- =============================================================================

-- Experimental features can be placed in xeno/shared_experiments/
-- and promoted to core/ or foundation/ after validation

-- =============================================================================
