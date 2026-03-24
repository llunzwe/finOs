-- =============================================================================
-- FINOS CORE KERNEL - ENVIRONMENT CONFIGURATION
-- =============================================================================
-- File: config/finos_environment.sql
-- Description: Runtime flags, regulatory switches, and multi-currency defaults
-- Standards: SARB/RBZ Compliance, POPIA Data Residency, ZAR/ZIG Precision
-- =============================================================================

-- =============================================================================
-- SECTION 1: REGULATORY JURISDICTION CONFIGURATION
-- =============================================================================

-- Default regulatory jurisdiction (ZA = South Africa, ZW = Zimbabwe, etc.)
ALTER DATABASE current SET app.regulatory_jurisdiction = 'ZA';

-- Data residency requirement (for POPIA/GDPR compliance)
ALTER DATABASE current SET app.data_residency = 'ZA';

-- Primary and secondary regulators
ALTER DATABASE current SET app.primary_regulator = 'SARB';
ALTER DATABASE current SET app.secondary_regulator = '';

-- =============================================================================
-- SECTION 2: CURRENCY DEFAULTS AND PRECISION
-- =============================================================================

-- Base/functional currency for the system
ALTER DATABASE current SET app.base_currency = 'ZAR';

-- Multi-currency support flag
ALTER DATABASE current SET app.multi_currency_enabled = 'true';

-- Supported currencies (comma-separated ISO 4217 codes)
ALTER DATABASE current SET app.supported_currencies = 'ZAR,ZIG,USD,EUR,GBP';

-- Default decimal precision by currency
ALTER DATABASE current SET app.currency_precision_zar = '2';
ALTER DATABASE current SET app.currency_precision_zig = '2';
ALTER DATABASE current SET app.currency_precision_usd = '2';
ALTER DATABASE current SET app.currency_precision_btc = '8';
ALTER DATABASE current SET app.currency_precision_eth = '18';

-- =============================================================================
-- SECTION 3: COMPLIANCE AND AUDIT SETTINGS
-- =============================================================================

-- Audit retention period (years)
ALTER DATABASE current SET app.audit_retention_years = '7';

-- Immutable event store retention (years)
ALTER DATABASE current SET app.event_store_retention_years = '10';

-- PII data retention (years) - per GDPR/POPIA
ALTER DATABASE current SET app.pii_retention_years = '7';

-- Regulatory snapshot frequency (daily, weekly, monthly)
ALTER DATABASE current SET app.regulatory_snapshot_frequency = 'daily';

-- =============================================================================
-- SECTION 4: OPERATIONAL SETTINGS
-- =============================================================================

-- Default timezone for the system
ALTER DATABASE current SET app.default_timezone = 'Africa/Johannesburg';

-- Business day calculation (country code for holidays)
ALTER DATABASE current SET app.business_day_country = 'ZA';

-- Batch processing window start time (HH:MM)
ALTER DATABASE current SET app.batch_window_start = '02:00';

-- Batch processing window end time (HH:MM)
ALTER DATABASE current SET app.batch_window_end = '06:00';

-- =============================================================================
-- SECTION 5: SECURITY SETTINGS
-- =============================================================================

-- Minimum password length for service accounts
ALTER DATABASE current SET app.min_password_length = '16';

-- Session timeout (minutes)
ALTER DATABASE current SET app.session_timeout_minutes = '30';

-- MFA enforcement level (none, sensitive, all)
ALTER DATABASE current SET app.mfa_enforcement = 'sensitive';

-- Encryption key rotation period (days)
ALTER DATABASE current SET app.key_rotation_days = '90';

-- =============================================================================
-- SECTION 6: FEATURE FLAGS
-- =============================================================================

-- Enable real-time event streaming
ALTER DATABASE current SET app.feature_event_streaming = 'true';

-- Enable webhook delivery
ALTER DATABASE current SET app.feature_webhooks = 'true';

-- Enable scheduled jobs
ALTER DATABASE current SET app.feature_scheduled_jobs = 'true';

-- Enable ML/algorithm execution tracking
ALTER DATABASE current SET app.feature_algorithm_tracking = 'true';

-- Enable blockchain anchoring
ALTER DATABASE current SET app.feature_blockchain_anchor = 'false';

-- =============================================================================
-- SECTION 7: SOVEREIGN BLOCKCHAIN CONFIGURATION (Government Trust Layer)
-- =============================================================================

-- Primary sovereign chain type (sarb_sovereign, zim_sovereign, sadc_regional, brics_bridge)
ALTER DATABASE current SET app.sovereign_chain_type = 'sarb_sovereign';

-- Sovereign chain RPC endpoint
ALTER DATABASE current SET app.sovereign_chain_rpc = 'https://sovereign-chain.sarb.gov.za';

-- Sovereign chain WebSocket endpoint
ALTER DATABASE current SET app.sovereign_chain_ws = 'wss://sovereign-chain.sarb.gov.za/ws';

-- Sovereign chain ID
ALTER DATABASE current SET app.sovereign_chain_id = 'sarb-mainnet-1';

-- Anchor contract address (set when deployed)
ALTER DATABASE current SET app.anchor_contract_address = '';

-- Anchor frequency (minutes)
ALTER DATABASE current SET app.anchor_frequency_minutes = '60';

-- Minimum events before anchoring
ALTER DATABASE current SET app.anchor_min_batch_size = '100';

-- Maximum events per anchor batch
ALTER DATABASE current SET app.anchor_max_batch_size = '10000';

-- Zero-knowledge proof enabled
ALTER DATABASE current SET app.zk_proofs_enabled = 'false';

-- Datomic-style query engine enabled
ALTER DATABASE current SET app.datomic_queries_enabled = 'true';

-- =============================================================================
-- SECTION 7: HELPER FUNCTION FOR ENVIRONMENT ACCESS
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_config(p_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN current_setting('app.' || p_key, TRUE);
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION core.get_config IS 'Retrieves environment configuration values';

-- =============================================================================
-- SECTION 8: CONFIGURATION VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FINOS ENVIRONMENT CONFIGURATION LOADED';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Jurisdiction: %', current_setting('app.regulatory_jurisdiction', TRUE);
    RAISE NOTICE 'Data Residency: %', current_setting('app.data_residency', TRUE);
    RAISE NOTICE 'Base Currency: %', current_setting('app.base_currency', TRUE);
    RAISE NOTICE 'Timezone: %', current_setting('app.default_timezone', TRUE);
    RAISE NOTICE '========================================';
END $$;

-- =============================================================================
