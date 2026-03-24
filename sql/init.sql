-- =============================================================================
-- FINOS CORE KERNEL - SINGLE POINT OF INITIALIZATION
-- =============================================================================
-- File: init.sql
-- Description: Master initialization script that sources all components in order:
--              1. config/         → Environment and runtime settings
--              2. foundation/     → Extensions, audit, utilities, infrastructure
--              3. core/           → 19 immutable primitives
--              4. dynamic/        → Runtime generated objects
--              5. xeno/           → Experimental and tenant-specific code
-- =============================================================================

\echo '========================================================================='
\echo 'FINOS CORE KERNEL - INITIALIZATION STARTING'
\echo '========================================================================='

-- =============================================================================
-- PHASE 1: CONFIGURATION
-- =============================================================================

\echo 'PHASE 1: Loading environment configuration...'
\i config/finos_environment.sql

-- =============================================================================
-- PHASE 2: FOUNDATION LAYER (000-011)
-- =============================================================================

\echo 'PHASE 2: Loading foundation layer...'

-- Extensions and schema setup
\echo '  -> 000_extensions.sql'
\i foundation/000_extensions.sql

-- Audit foundation
\echo '  -> 001_audit.sql'
\i foundation/001_audit.sql

-- Utility functions
\echo '  -> 002_utilities.sql'
\i foundation/002_utilities.sql

-- PII registry
\echo '  -> 003_pii_registry.sql'
\i foundation/003_pii_registry.sql

-- Partitioning
\echo '  -> 004_partitioning.sql'
\i foundation/004_partitioning.sql

-- Rate limiting
\echo '  -> 005_rate_limiting.sql'
\i foundation/005_rate_limiting.sql

-- Webhook system
\echo '  -> 006_webhook.sql'
\i foundation/006_webhook.sql

-- Scheduled jobs
\echo '  -> 007_scheduled_jobs.sql'
\i foundation/007_scheduled_jobs.sql

-- Caching layer
\echo '  -> 008_cache.sql'
\i foundation/008_cache.sql

-- Algorithm execution
\echo '  -> 009_algorithm_execution.sql'
\i foundation/009_algorithm_execution.sql

-- Scalability and RLS
\echo '  -> 010_scalability.sql'
\i foundation/010_scalability.sql

-- Grants (foundation level)
\echo '  -> 011_grants.sql'
\i foundation/011_grants.sql

-- =============================================================================
-- PHASE 3: CORE PRIMITIVES (001-019)
-- =============================================================================

\echo 'PHASE 3: Loading 19 immutable core primitives...'

-- Core extensions wrapper
\echo '  -> core/000_extensions.sql (wrapper)'
\i core/000_extensions.sql

-- Primitive 1: Identity & Tenancy
\echo '  -> core/001_identity_and_tenancy.sql'
\i core/001_identity_and_tenancy.sql

-- Primitive 2: Value Container
\echo '  -> core/002_value_container.sql'
\i core/002_value_container.sql

-- Primitive 3: Value Movement & Double-Entry
\echo '  -> core/003_value_movement_and_double_entry.sql'
\i core/003_value_movement_and_double_entry.sql

-- Primitive 4: Economic Agent & Relationships
\echo '  -> core/004_economic_agent_and_relationships.sql'
\i core/004_economic_agent_and_relationships.sql

-- Primitive 5: Temporal Transition (4D Time)
\echo '  -> core/005_temporal_transition_4d.sql'
\i core/005_temporal_transition_4d.sql

-- Primitive 6: Immutable Event Store
\echo '  -> core/006_immutable_event_store.sql'
\i core/006_immutable_event_store.sql

-- Primitive 7: Chart of Accounts
\echo '  -> core/007_chart_of_accounts.sql'
\i core/007_chart_of_accounts.sql

-- Primitive 8: Monetary System & Valuation
\echo '  -> core/008_monetary_system_and_valuation.sql'
\i core/008_monetary_system_and_valuation.sql

-- Primitive 9: Settlement & Finality
\echo '  -> core/009_settlement_and_finality.sql'
\i core/009_settlement_and_finality.sql

-- Primitive 10: Reconciliation & Suspense
\echo '  -> core/010_reconciliation_and_suspense.sql'
\i core/010_reconciliation_and_suspense.sql

-- Primitive 11: Control & Batch Processing
\echo '  -> core/011_control_and_batch_processing.sql'
\i core/011_control_and_batch_processing.sql

-- Primitive 12: Entitlements & Authorization
\echo '  -> core/012_entitlements_and_authorization.sql'
\i core/012_entitlements_and_authorization.sql

-- Primitive 13: Geography & Jurisdiction
\echo '  -> core/013_geography_and_jurisdiction.sql'
\i core/013_geography_and_jurisdiction.sql

-- Primitive 14: Provisioning & Reserves
\echo '  -> core/014_provisioning_and_reserves.sql'
\i core/014_provisioning_and_reserves.sql

-- Primitive 15: Document & Evidence References
\echo '  -> core/015_document_and_evidence_references.sql'
\i core/015_document_and_evidence_references.sql

-- Primitive 16: Sub-ledger & Segregation
\echo '  -> core/016_sub_ledger_and_segregation.sql'
\i core/016_sub_ledger_and_segregation.sql

-- Primitive 17: Legal Entity Hierarchy & Consolidation
\echo '  -> core/017_legal_entity_hierarchy_and_group_consolidation.sql'
\i core/017_legal_entity_hierarchy_and_group_consolidation.sql

-- Primitive 18: Capital & Liquidity Position Tracking
\echo '  -> core/018_capital_and_liquidity_position_tracking.sql'
\i core/018_capital_and_liquidity_position_tracking.sql

-- Primitive 19: Kernel Wiring (MUST RUN LAST)
\echo '  -> core/019_kernel_wiring.sql'
\i core/019_kernel_wiring.sql

-- =============================================================================
-- PHASE 4: GOVERNMENT-TRUST LAYER (Datomic + Blockchain)
-- =============================================================================

\echo 'PHASE 4: Loading government-trust layer...'

-- Blockchain Anchoring & Merkle Trees
\echo '  -> core/020_blockchain_anchoring.sql'
\i core/020_blockchain_anchoring.sql

-- Datalog Query Engine
\echo '  -> core/021_datalog_query_engine.sql'
\i core/021_datalog_query_engine.sql

-- =============================================================================
-- PHASE 5: ADVANCED SCALABILITY & CACHING
-- =============================================================================

\echo 'PHASE 5: Loading advanced scalability features...'

-- Peer-Style Read Caching (Datomic Model)
\echo '  -> core/022_peer_caching.sql'
\i core/022_peer_caching.sql

-- Columnar Compression & Auto-Archiving
\echo '  -> core/023_columnar_archival.sql'
\i core/023_columnar_archival.sql

-- Transaction Entity (First-Class Citizen)
\echo '  -> core/024_transaction_entity.sql'
\i core/024_transaction_entity.sql

-- =============================================================================
-- PHASE 6: DYNAMIC OBJECTS
-- =============================================================================

\echo 'PHASE 4: Loading dynamic objects...'
-- Dynamic objects are runtime-generated; placeholder for future use
-- \i dynamic/*.sql

-- =============================================================================
-- PHASE 5: XENO (EXPERIMENTAL)
-- =============================================================================

\echo 'PHASE 5: Loading xeno experimental layer...'
-- Experimental features and tenant-specific code
-- \i xeno/000_tenant_template.sql

-- =============================================================================
-- COMPLETION
-- =============================================================================

\echo '========================================================================='
\echo 'FINOS CORE KERNEL V2.0 - INITIALIZATION COMPLETE'
\echo '========================================================================='
\echo ''
\echo 'Directory Structure:'
\echo '  config/     - Environment and runtime configuration'
\echo '  foundation/ - Infrastructure, utilities, audit, security (000-011)'
\echo '  core/       - 21 immutable financial primitives (001-021)'
\echo '               Including Datomic datoms + Blockchain anchoring'
\echo '  dynamic/    - Runtime-generated objects'
\echo '  xeno/       - Experimental and tenant-specific code'
\echo ''
\echo 'New Features:'
\echo '  ✓ Datomic-style E-A-V-Tx-Op datom model'
\echo '  ✓ Universal fact indexes (EAVT/AVET/AEVT/VAET)'
\echo '  ✓ Merkle tree + blockchain anchoring'
\echo '  ✓ Government-trust verification layer'
\echo '  ✓ Zero-knowledge proof hooks'
\echo '  ✓ Datalog query engine (as-of, since, pattern matching)'
\echo '  ✓ Citus horizontal sharding support'
\echo ''
\echo 'Run SELECT * FROM core.health_check_full(); to verify installation.'
\echo '========================================================================='

-- =============================================================================
