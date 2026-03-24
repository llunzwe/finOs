-- =============================================================================
-- FINOS CORE KERNEL - CORE EXTENSIONS WRAPPER
-- =============================================================================
-- File: core/000_extensions.sql
-- Description: Thin wrapper that ensures foundation extensions are loaded
--              plus any core-specific extensions
-- Dependencies: foundation/000_extensions.sql must run first
-- =============================================================================

-- =============================================================================
-- SECTION 1: VERIFY FOUNDATION SCHEMAS EXIST
-- =============================================================================

DO $$
BEGIN
    -- Verify foundation schemas were created
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'core') THEN
        RAISE EXCEPTION 'Foundation schemas not found. Run foundation/000_extensions.sql first.';
    END IF;
END $$;

-- =============================================================================
-- SECTION 2: CORE-SPECIFIC EXTENSIONS
-- =============================================================================

-- Additional extensions specific to core primitives (if any)
-- Most extensions are already loaded in foundation/000_extensions.sql

-- =============================================================================
-- SECTION 3: CORE SCHEMA VERIFICATION
-- =============================================================================

COMMENT ON SCHEMA core IS 'FinOS Core Kernel - Immutable 19 Financial Primitives';

-- =============================================================================
