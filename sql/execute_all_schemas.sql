-- =============================================================================
-- FINOS CORE KERNEL - MASTER EXECUTION SCRIPT
-- =============================================================================
-- Description: Complete schema deployment script for FinOS Core Kernel
--              Executes all SQL files in the correct dependency order
-- Version: 1.0.0
-- PostgreSQL: 16+
-- =============================================================================

-- =============================================================================
-- PRE-DEPLOYMENT CHECKS
-- =============================================================================
DO $$
BEGIN
    -- Check PostgreSQL version
    IF current_setting('server_version_num')::INTEGER < 160000 THEN
        RAISE EXCEPTION 'PostgreSQL 16+ is required. Current version: %', current_setting('server_version');
    END IF;
    
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'FINOS CORE KERNEL V2.0 - SCHEMA DEPLOYMENT';
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'PostgreSQL Version: %', current_setting('server_version');
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'Started at: %', NOW();
    RAISE NOTICE '==============================================================';
END $$;

-- =============================================================================
-- PHASE 1: FOUNDATION (Files 000-011)
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 1: Deploying Foundation Layer...';
END $$;

-- 000: Extensions & Enterprise Foundation
\echo 'Executing foundation/000_extensions.sql...'
\i foundation/000_extensions.sql

-- 001: Audit Foundation
\echo 'Executing foundation/001_audit.sql...'
\i foundation/001_audit.sql

-- 002: Utility Functions
\echo 'Executing foundation/002_utilities.sql...'
\i foundation/002_utilities.sql

-- 003: PII Registry & Data Protection
\echo 'Executing foundation/003_pii_registry.sql...'
\i foundation/003_pii_registry.sql

-- 004: Partitioning & Scale Enhancements
\echo 'Executing foundation/004_partitioning.sql...'
\i foundation/004_partitioning.sql

-- 005: Rate Limiting & Throttling
\echo 'Executing foundation/005_rate_limiting.sql...'
\i foundation/005_rate_limiting.sql

-- 006: Webhook System
\echo 'Executing foundation/006_webhook.sql...'
\i foundation/006_webhook.sql

-- 007: Scheduled Jobs
\echo 'Executing foundation/007_scheduled_jobs.sql...'
\i foundation/007_scheduled_jobs.sql

-- 008: Caching Layer
\echo 'Executing foundation/008_cache.sql...'
\i foundation/008_cache.sql

-- 009: Algorithm Execution
\echo 'Executing foundation/009_algorithm_execution.sql...'
\i foundation/009_algorithm_execution.sql

-- 010: Scalability & Monitoring
\echo 'Executing foundation/010_scalability.sql...'
\i foundation/010_scalability.sql

-- 011: Grants & Permissions (Initial)
\echo 'Executing foundation/011_grants.sql...'
\i foundation/011_grants.sql

-- =============================================================================
-- PHASE 2: CORE PRIMITIVES (Files 000-021)
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 2: Deploying Core Primitives (19 Primitives + Datomic + Blockchain)...';
END $$;

-- 000: Core Extensions Wrapper
\echo 'Executing core/000_extensions.sql...'
\i core/000_extensions.sql

-- 001: Primitive 1 - Identity & Tenancy
\echo 'Executing core/001_identity_and_tenancy.sql...'
\i core/001_identity_and_tenancy.sql

-- 002: Primitive 2 - Value Container
\echo 'Executing core/002_value_container.sql...'
\i core/002_value_container.sql

-- 003: Primitive 3 - Value Movement & Double-Entry
\echo 'Executing core/003_value_movement_and_double_entry.sql...'
\i core/003_value_movement_and_double_entry.sql

-- 004: Primitive 4 - Economic Agent & Relationships
\echo 'Executing core/004_economic_agent_and_relationships.sql...'
\i core/004_economic_agent_and_relationships.sql

-- 005: Primitive 5 - Temporal Transition (4D Time)
\echo 'Executing core/005_temporal_transition_4d.sql...'
\i core/005_temporal_transition_4d.sql

-- 006: Primitive 6 - Immutable Event Store (DATOMIC MODEL)
\echo 'Executing core/006_immutable_event_store.sql...'
\i core/006_immutable_event_store.sql

-- 007: Primitive 7 - Chart of Accounts
\echo 'Executing core/007_chart_of_accounts.sql...'
\i core/007_chart_of_accounts.sql

-- 008: Primitive 8 - Monetary System & Valuation
\echo 'Executing core/008_monetary_system_and_valuation.sql...'
\i core/008_monetary_system_and_valuation.sql

-- 009: Primitive 9 - Settlement & Finality
\echo 'Executing core/009_settlement_and_finality.sql...'
\i core/009_settlement_and_finality.sql

-- 010: Primitive 10 - Reconciliation & Suspense
\echo 'Executing core/010_reconciliation_and_suspense.sql...'
\i core/010_reconciliation_and_suspense.sql

-- 011: Primitive 11 - Control & Batch Processing
\echo 'Executing core/011_control_and_batch_processing.sql...'
\i core/011_control_and_batch_processing.sql

-- 012: Primitive 12 - Entitlements & Authorization
\echo 'Executing core/012_entitlements_and_authorization.sql...'
\i core/012_entitlements_and_authorization.sql

-- 013: Primitive 13 - Geography & Jurisdiction
\echo 'Executing core/013_geography_and_jurisdiction.sql...'
\i core/013_geography_and_jurisdiction.sql

-- 014: Primitive 14 - Provisioning & Reserves
\echo 'Executing core/014_provisioning_and_reserves.sql...'
\i core/014_provisioning_and_reserves.sql

-- 015: Primitive 15 - Document & Evidence References
\echo 'Executing core/015_document_and_evidence_references.sql...'
\i core/015_document_and_evidence_references.sql

-- 016: Primitive 16 - Sub-ledger & Segregation
\echo 'Executing core/016_sub_ledger_and_segregation.sql...'
\i core/016_sub_ledger_and_segregation.sql

-- 017: Primitive 17 - Legal Entity Hierarchy & Consolidation
\echo 'Executing core/017_legal_entity_hierarchy_and_group_consolidation.sql...'
\i core/017_legal_entity_hierarchy_and_group_consolidation.sql

-- 018: Primitive 18 - Capital & Liquidity Position Tracking
\echo 'Executing core/018_capital_and_liquidity_position_tracking.sql...'
\i core/018_capital_and_liquidity_position_tracking.sql

-- 019: Primitive 19 - Kernel Wiring (MUST RUN LAST FOR PRIMITIVES)
\echo 'Executing core/019_kernel_wiring.sql...'
\i core/019_kernel_wiring.sql

-- =============================================================================
-- PHASE 3: GOVERNMENT-TRUST LAYER (Datomic + Blockchain)
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 3: Deploying Government-Trust Layer...';
END $$;

-- 020: Blockchain Anchoring & Merkle Trees
\echo 'Executing core/020_blockchain_anchoring.sql...'
\i core/020_blockchain_anchoring.sql

-- 021: Datalog Query Engine
\echo 'Executing core/021_datalog_query_engine.sql...'
\i core/021_datalog_query_engine.sql

-- =============================================================================
-- PHASE 4: ADVANCED SCALABILITY & CACHING
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 4: Deploying Advanced Scalability Features...';
END $$;

-- 022: Peer-Style Read Caching (Datomic Model)
\echo 'Executing core/022_peer_caching.sql...'
\i core/022_peer_caching.sql

-- 023: Columnar Compression & Auto-Archiving
\echo 'Executing core/023_columnar_archival.sql...'
\i core/023_columnar_archival.sql

-- 024: Transaction Entity (First-Class Citizen)
\echo 'Executing core/024_transaction_entity.sql...'
\i core/024_transaction_entity.sql

-- =============================================================================
-- PHASE 3.5: CORE V1.1 ADDITIONS (Primitives 25-27)
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 3.5: Deploying Core v1.1 Additions (Universal Product Engine + Marqeta Richness)...';
END $$;

-- 025: Primitive 25 - Product Contract Anchor
\echo 'Executing core/025_product_contract_anchor.sql...'
\i core/025_product_contract_anchor.sql

-- 026: Primitive 26 - Real-Time Posting & Authorisation
\echo 'Executing core/026_real_time_posting.sql...'
\i core/026_real_time_posting.sql

-- 027: Primitive 27 - Streaming & Mutation Log
\echo 'Executing core/027_streaming_mutation_log.sql...'
\i core/027_streaming_mutation_log.sql

-- =============================================================================
-- PHASE 5: DYNAMIC LAYER (400+ Schema Models)
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PHASE 5: Deploying Dynamic Layer (400+ Schema Models)...';
END $$;

-- 001: Dynamic Schema Foundation
\echo 'Executing dynamic/001_dynamic_schema.sql...'
\i dynamic/001_dynamic_schema.sql

-- 002: Domain 1 - Product Management (35+ tables)
\echo 'Executing dynamic/002_product_management.sql...'
\i dynamic/002_product_management.sql

-- 003: Domain 2 - Pricing & Calculation Engines (40+ tables)
\echo 'Executing dynamic/003_pricing_calculation_engines.sql...'
\i dynamic/003_pricing_calculation_engines.sql

-- 004: Domain 3 - Workflow & State Machine (30+ tables)
\echo 'Executing dynamic/004_workflow_state_machine.sql...'
\i dynamic/004_workflow_state_machine.sql

-- 005: Domain 4 - Events & Hooks (25+ tables)
\echo 'Executing dynamic/005_events_hooks.sql...'
\i dynamic/005_events_hooks.sql

-- 006: Domain 5 - Simulation & Forecasting (20+ tables)
\echo 'Executing dynamic/006_simulation_forecasting.sql...'
\i dynamic/006_simulation_forecasting.sql

-- 007: Domain 6 - Accounting & Financial Control (35+ tables)
\echo 'Executing dynamic/007_accounting_financial_control.sql...'
\i dynamic/007_accounting_financial_control.sql

-- 008: Domain 7 - Insurance & Takaful (30+ tables)
\echo 'Executing dynamic/008_insurance_takaful.sql...'
\i dynamic/008_insurance_takaful.sql

-- 009: Domain 8 - Customer Management (25+ tables)
\echo 'Executing dynamic/009_customer_management_overlay.sql...'
\i dynamic/009_customer_management_overlay.sql

-- 010: Domain 9 - Collateral & Security (20+ tables)
\echo 'Executing dynamic/010_collateral_security.sql...'
\i dynamic/010_collateral_security.sql

-- 011: Domain 10 - Regulatory Reporting (30+ tables)
\echo 'Executing dynamic/011_regulatory_reporting.sql...'
\i dynamic/011_regulatory_reporting.sql

-- 012: Domain 11 - Integration & API Management (25+ tables)
\echo 'Executing dynamic/012_integration_api_management.sql...'
\i dynamic/012_integration_api_management.sql

-- 013: Domain 12 - Performance & Operations (15+ tables)
\echo 'Executing dynamic/013_performance_operations.sql...'
\i dynamic/013_performance_operations.sql

-- 014: Domain 13 - Billing, Invoicing & Contracts (20+ tables)
\echo 'Executing dynamic/014_billing_contracts.sql...'
\i dynamic/014_billing_contracts.sql

-- 015: Domain 14 - Rules Engines (25+ tables)
\echo 'Executing dynamic/015_rules_engines.sql...'
\i dynamic/015_rules_engines.sql

-- 016: Industry Pack - Banking & Lending (15+ tables)
\echo 'Executing dynamic/016_industry_packs_banking.sql...'
\i dynamic/016_industry_packs_banking.sql

-- 017: Industry Pack - Insurance (20+ tables)
\echo 'Executing dynamic/017_industry_packs_insurance.sql...'
\i dynamic/017_industry_packs_insurance.sql

-- 018: Industry Pack - Investments & Trading (18+ tables)
\echo 'Executing dynamic/018_industry_packs_investments.sql...'
\i dynamic/018_industry_packs_investments.sql

-- 019: Industry Pack - Payments & E-commerce (15+ tables)
\echo 'Executing dynamic/019_industry_packs_payments.sql...'
\i dynamic/019_industry_packs_payments.sql

-- 020: Industry Pack - Retail & Advertising (12+ tables)
\echo 'Executing dynamic/020_industry_packs_retail_ads.sql...'
\i dynamic/020_industry_packs_retail_ads.sql

-- 021: Domain 15 - Reporting, Analytics & Alerts (15+ tables)
\echo 'Executing dynamic/021_reporting_analytics.sql...'
\i dynamic/021_reporting_analytics.sql

-- 022: Domain 16 - Integration, Hooks & Scheduling (18+ tables)
\echo 'Executing dynamic/022_integration_hooks.sql...'
\i dynamic/022_integration_hooks.sql

-- 200: Universal Product Engine (Vault/Marqeta Smart-Contracts)
\echo 'Executing dynamic/200_universal_product_engine.sql...'
\i dynamic/200_universal_product_engine.sql

-- 210: Marqeta-Inspired Entities (Cards, Funding, Credit, Rewards)
\echo 'Executing dynamic/210_marqeta_entities.sql...'
\i dynamic/210_marqeta_entities.sql

-- 220: API, Streaming & Real-Time Configuration
\echo 'Executing dynamic/220_api_streaming_config.sql...'
\i dynamic/220_api_streaming_config.sql

-- 230: Simulation, Testing & Management
\echo 'Executing dynamic/230_simulation_testing.sql...'
\i dynamic/230_simulation_testing.sql

-- 240: Supporting & Accounting Enforcement Tables
\echo 'Executing dynamic/240_supporting_accounting.sql...'
\i dynamic/240_supporting_accounting.sql

-- 099: Master Summary
\echo 'Executing dynamic/099_dynamic_layer_master.sql...'
\i dynamic/099_dynamic_layer_master.sql

-- =============================================================================
-- POST-DEPLOYMENT VERIFICATION
-- =============================================================================

DO $$
DECLARE
    v_health JSONB;
    v_table_count INTEGER;
    v_function_count INTEGER;
    v_index_count INTEGER;
BEGIN
    -- Get deployment statistics
    SELECT COUNT(*) INTO v_table_count 
    FROM pg_tables 
    WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit', 'core_reporting', 'dynamic', 'dynamic_history');
    
    SELECT COUNT(*) INTO v_function_count 
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('core', 'core_history', 'core_crypto', 'core_audit', 'dynamic', 'dynamic_history');
    
    SELECT COUNT(*) INTO v_index_count 
    FROM pg_indexes 
    WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit', 'core_reporting', 'dynamic', 'dynamic_history');
    
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'DEPLOYMENT COMPLETE - FINOS CORE KERNEL V2.1';
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'Total Tables: %', v_table_count;
    RAISE NOTICE 'Total Functions: %', v_function_count;
    RAISE NOTICE 'Total Indexes: %', v_index_count;
    RAISE NOTICE 'Completed at: %', NOW();
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'Core Layer Features:';
    RAISE NOTICE '  ✓ Datomic-style E-A-V-Tx-Op datom model';
    RAISE NOTICE '  ✓ Universal fact indexes (EAVT/AVET/AEVT/VAET)';
    RAISE NOTICE '  ✓ Merkle tree + blockchain anchoring';
    RAISE NOTICE '  ✓ Government-trust verification layer';
    RAISE NOTICE '  ✓ Zero-knowledge proof hooks';
    RAISE NOTICE '  ✓ Datalog query engine (as-of, since, pattern matching)';
    RAISE NOTICE '  ✓ Citus horizontal sharding support';
    RAISE NOTICE '  ✓ Peer-style read caching (Datomic model)';
    RAISE NOTICE '  ✓ Content-addressable storage';
    RAISE NOTICE '  ✓ Columnar compression (TimescaleDB)';
    RAISE NOTICE '  ✓ Automated archival to S3/Parquet';
    RAISE NOTICE '  ✓ Transaction entities (first-class citizen)';
    RAISE NOTICE '  ✓ Complete chain of custody tracking';
    RAISE NOTICE '  ✓ [V1.1] Product Contract Anchors (cryptographic smart-contract linking)';
    RAISE NOTICE '  ✓ [V1.1] Real-Time Posting & Authorisation (<10ms auth, JIT, velocity)';
    RAISE NOTICE '  ✓ [V1.1] Streaming & Mutation Log (Kafka-compatible, 4D replay)';
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'Dynamic Layer Features:';}, {
    RAISE NOTICE '  ✓ Product Management (35+ tables) - Templates, Variants, Bundles';
    RAISE NOTICE '  ✓ Pricing Engines (40+ tables) - Curves, Fees, Tax, FTP';
    RAISE NOTICE '  ✓ Workflow Engine (30+ tables) - State Machines, Approvals';
    RAISE NOTICE '  ✓ Event Architecture (25+ tables) - Hooks, Schema Registry';
    RAISE NOTICE '  ✓ Simulation (20+ tables) - Scenarios, IFRS 9 ECL';
    RAISE NOTICE '  ✓ Accounting Control (35+ tables) - COA, Revenue, Provisions';
    RAISE NOTICE '  ✓ Insurance/Takaful (30+ tables) - Policy, Claims, Reinsurance';
    RAISE NOTICE '  ✓ Customer Overlay (25+ tables) - Segments, KYC, Consent';
    RAISE NOTICE '  ✓ Collateral (20+ tables) - Security Perfection, Insurance';
    RAISE NOTICE '  ✓ Regulatory Reporting (30+ tables) - Basel, FATF, SARB/RBZ';
    RAISE NOTICE '  ✓ Integration (25+ tables) - API Gateway, File Processing';
    RAISE NOTICE '  ✓ Operations (15+ tables) - Batch Control, Health Monitoring';
    RAISE NOTICE '  ✓ Billing & Contracts (20+ tables) - Invoicing, Usage Metering';
    RAISE NOTICE '  ✓ Rules Engines (25+ tables) - Fraud, Compliance, BRE';
    RAISE NOTICE '  ✓ Banking Pack (15+ tables) - Credit Scoring, Restructuring';
    RAISE NOTICE '  ✓ Insurance Pack (20+ tables) - Underwriting, Benefit Schedules';
    RAISE NOTICE '  ✓ Investments Pack (18+ tables) - Portfolio Models, Trading';
    RAISE NOTICE '  ✓ Payments Pack (15+ tables) - Gateways, Checkout, Disputes';
    RAISE NOTICE '  ✓ Retail/Ads Pack (12+ tables) - POS, Campaign Billing';
    RAISE NOTICE '  ✓ Reporting & Analytics (15+ tables) - Metrics, Dashboards';
    RAISE NOTICE '  ✓ Integration & Hooks (18+ tables) - Webhooks, Scheduling';
    RAISE NOTICE '==============================================================';
    RAISE NOTICE 'TOTAL: 400+ Dynamic Layer Schema Models';
    RAISE NOTICE '==============================================================';
END $$;

-- Final health check
SELECT * FROM core.health_check_full();

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
