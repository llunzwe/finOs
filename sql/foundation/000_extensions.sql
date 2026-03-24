-- =============================================================================
-- FINOS CORE KERNEL - EXTENSIONS & ENTERPRISE FOUNDATION
-- =============================================================================
-- File: 000_extensions.sql (MUST RUN FIRST)
-- Description: Bootstrap file declaring all extensions, security foundations,
--              utilities, and enterprise-grade features for the 19 primitives.
-- Standards: ISO 27001, SOC2, GDPR, Basel III/IV, PCI-DSS
-- =============================================================================

-- =============================================================================
-- SECTION 1: EXTENSIONS
-- =============================================================================

-- Core extensions (always required)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- PostGIS (for geolocation) - optional, create if available
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "postgis";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PostGIS extension not available, skipping...';
END $$;

-- TimescaleDB - required for time-series
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "timescaledb";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TimescaleDB extension handling...';
END $$;

-- pg_partman - for advanced partition management (optional but recommended)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "pg_partman";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_partman extension not available, skipping...';
END $$;

-- =============================================================================
-- SECTION 2: SCHEMA SETUP
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS core_history;
CREATE SCHEMA IF NOT EXISTS core_crypto;
CREATE SCHEMA IF NOT EXISTS core_audit;
CREATE SCHEMA IF NOT EXISTS core_reporting;

COMMENT ON SCHEMA core IS 'FinOS Core Kernel - Immutable financial primitives';
COMMENT ON SCHEMA core_history IS 'FinOS Core - Temporal/historical data using TimescaleDB';
COMMENT ON SCHEMA core_crypto IS 'FinOS Core - Cryptographic anchoring and immutable event store';
COMMENT ON SCHEMA core_audit IS 'FinOS Core - Audit trails, logging, and compliance';
COMMENT ON SCHEMA core_reporting IS 'FinOS Core - Materialized views and reporting snapshots';

-- =============================================================================
-- SECTION 3: ROLES AND PERMISSIONS
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_app') THEN
        CREATE ROLE finos_app WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_readonly') THEN
        CREATE ROLE finos_readonly WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_admin') THEN
        CREATE ROLE finos_admin WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_replication') THEN
        CREATE ROLE finos_replication WITH REPLICATION LOGIN PASSWORD 'changeme_in_production';
    END IF;
END
$$;

-- Grant schema usage
GRANT USAGE ON SCHEMA core TO finos_app, finos_readonly, finos_admin, finos_replication;
GRANT USAGE ON SCHEMA core_history TO finos_app, finos_readonly, finos_admin;
GRANT USAGE ON SCHEMA core_crypto TO finos_app, finos_admin, finos_replication;
GRANT USAGE ON SCHEMA core_audit TO finos_app, finos_admin;
GRANT USAGE ON SCHEMA core_reporting TO finos_app, finos_readonly, finos_admin;

-- Grant sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_history TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_crypto TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_audit TO finos_app;

-- =============================================================================
-- SECTION 4: DATOMIC-STYLE EXTENSIONS (Government-Trust Layer)
-- =============================================================================

-- Citus - for horizontal sharding at trillion-row scale
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "citus";
    RAISE NOTICE 'Citus extension loaded - horizontal sharding available';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Citus extension not available, running in single-node mode...';
END $$;

-- pg_crypto is already loaded (for hashes)
-- Additional crypto for ECDSA signatures if available
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgcrypto handling...';
END $$;

-- =============================================================================
-- SECTION 5: ENVIRONMENT CONFIGURATION
-- =============================================================================

-- Set default environment (can be overridden per session)
ALTER DATABASE current SET app.environment = 'development';

-- Helper function to get current environment
CREATE OR REPLACE FUNCTION core.get_environment()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(current_setting('app.environment', TRUE), 'development');
EXCEPTION WHEN OTHERS THEN
    RETURN 'development';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION core.get_environment IS 'Returns the current application environment';

-- =============================================================================
