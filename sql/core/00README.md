# FinOS Core Kernel Schema V2.0

## Overview
Complete PostgreSQL schema for a multi-tenant, bitemporal financial operating system with cryptographic integrity, immutable event sourcing, Datomic-inspired datom model, blockchain anchoring, and enterprise-grade compliance features.

## Architecture Principles
- **Multi-tenancy**: Row-level security with tenant isolation
- **Bitemporal modeling**: Valid time + system time tracking
- **Immutable event store**: Cryptographic hashing for audit trails
- **Datomic-inspired datom model**: E-A-V-Tx-Op facts with universal indexes
- **Government-trust layer**: Merkle trees + blockchain anchoring
- **Scalability**: Native partitioning, Citus sharding, TimescaleDB hypertables
- **Compliance**: Built-in GDPR, PCI-DSS, Basel III/IV, FATF support

## File Structure (22 Files)

### Core Primitives (000-021)

| # | File | Description | Lines | Status |
|---|------|-------------|-------|--------|
| 000 | `000_extensions.sql` | Core extensions wrapper | 35 | ✅ |
| 001 | `001_identity_and_tenancy.sql` | Tenants, namespaces, ID generation | ~300 | ✅ |
| 002 | `002_value_container.sql` | Value containers with measurement units | ~400 | ✅ |
| 003 | `003_value_movement_and_double_entry.sql` | Value movements, double-entry legs, conservation | ~361 | ✅ |
| 004 | `004_economic_agent_and_relationships.sql` | Agents, relationships, sanctions | ~400 | ✅ |
| 005 | `005_temporal_transition_4d.sql` | Bitemporal state transitions, 4D time | ~295 | ✅ |
| 006 | `006_immutable_event_store.sql` | **Event store with Datomic datom model, ZK proofs** | ~677 | ✅ V2.0 |
| 007 | `007_chart_of_accounts.sql` | GL accounts, hierarchies, mappings | ~316 | ✅ |
| 008 | `008_monetary_system_and_valuation.sql` | Currencies, instruments, prices | ~354 | ✅ |
| 009 | `009_settlement_and_finality.sql` | Settlement, liquidity positions | ~328 | ✅ |
| 010 | `010_reconciliation_and_suspense.sql` | Reconciliation, suspense items | ~396 | ✅ |
| 011 | `011_control_and_batch_processing.sql` | Control batches, entries, policies | ~461 | ✅ |
| 012 | `012_entitlements_and_authorization.sql` | Entitlements, authorizations | ~364 | ✅ |
| 013 | `013_geography_and_jurisdiction.sql` | Geographic, jurisdictional data | ~425 | ✅ |
| 014 | `014_provisioning_and_reserves.sql` | Provisions, reserves, utilization | ~331 | ✅ |
| 015 | `015_document_and_evidence_references.sql` | Documents, evidence, integrity | ~393 | ✅ |
| 016 | `016_sub_ledger_and_segregation.sql` | Master/sub-accounts, posting rules | ~376 | ✅ |
| 017 | `017_legal_entity_hierarchy_and_group_consolidation.sql` | LEI, ownership, consolidation | ~368 | ✅ |
| 018 | `018_capital_and_liquidity_position_tracking.sql` | Capital, liquidity, risk (Basel) | ~570 | ✅ |
| 019 | `019_kernel_wiring.sql` | **Triggers, indexes, RLS, Citus, Datomic integration** | ~783 | ✅ V2.0 |
| 020 | `020_blockchain_anchoring.sql` | **Merkle trees, blockchain anchors, sovereign chains** | ~516 | ✅ V2.0 |
| 021 | `021_datalog_query_engine.sql` | **Datalog queries, as-of, pattern matching** | ~439 | ✅ V2.0 |
| 022 | `022_peer_caching.sql` | **Peer-style read caching, content-addressable storage** | ~650 | ✅ V2.0 |
| 023 | `023_columnar_archival.sql` | **TimescaleDB compression, S3/Parquet archival** | ~750 | ✅ V2.0 |
| 024 | `024_transaction_entity.sql` | **Transaction entities, chain of custody** | ~800 | ✅ V2.0 |

**Total**: ~11,000+ lines across 25 files

## V2.0 New Features

### Datomic-Inspired Transformation
- ✅ **Datom Model**: Full E-A-V-Tx-Op implementation in `immutable_events`
- ✅ **Universal Indexes**: EAVT, AVET, AEVT, VAET indexes for Datalog queries
- ✅ **As-Of Queries**: Point-in-time database reconstruction
- ✅ **Entity History**: Complete audit trail of all assertions and retractions

### Government-Trust Layer
- ✅ **Merkle Trees**: Batch hashing with root anchoring
- ✅ **Blockchain Anchoring**: Multi-chain support (Ethereum, Polygon, Hyperledger, SARB)
- ✅ **Verification Proofs**: On-demand proof generation for regulators
- ✅ **Sovereign Chains**: Pre-configured for SARB, RBZ, SADC, BRICS

### Privacy & Scale
- ✅ **Zero-Knowledge Proofs**: Hooks for range, membership, equality proofs
- ✅ **Citus Sharding**: Horizontal scaling to trillion-row capacity
- ✅ **TimescaleDB**: Time-series optimization with compression

## Deployment Order

```sql
-- Prerequisites
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "timescaledb";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_partman";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "citus";  -- Optional, for sharding

-- Foundation (must run first via init.sql or execute_all_schemas.sql)
-- foundation/000_extensions.sql through foundation/011_grants.sql

-- Core Primitives (run in strict order 000-021)
\i core/000_extensions.sql
\i core/001_identity_and_tenancy.sql
-- ... continue through 021
```

## Post-Deployment
1. Create first tenant: `SELECT core.create_all_tenant_partitions('tenant-uuid');`
2. Verify datomic integration: `SELECT * FROM core.health_check_full();`
3. Configure sovereign chains in `core.sovereign_chain_configs`
4. Enable scheduled jobs via pg_cron for Merkle batch creation

## Key Features

### Scalability
- Native LIST partitioning by `tenant_id`
- Time-based sub-partitioning for high-volume tables
- Citus horizontal sharding (trillion-row scale)
- Automatic partition lifecycle management
- `pg_partman` integration for automated partition maintenance

### Security
- Row-level security (RLS) auto-generation
- PII detection and masking
- Rate limiting and API abuse prevention
- GDPR data lineage tracking
- Cryptographic hash chains

### Compliance
- Cryptographic hash chains for audit
- Immutable event store with Datomic model
- Sanctions screening
- KYC/AML verification tracking
- Basel III/IV capital calculations

### Functions (80+)
- `core.datom_query()` - Universal Datalog pattern matching
- `core.datoms_as_of()` - Point-in-time queries
- `core_crypto.verify_chain_integrity()` - Cryptographic verification
- `core.create_merkle_batch()` - Merkle tree generation
- `core.get_event_verification_proof()` - Government audit interface
- `core.generate_rls_policies()` - Auto-apply RLS
- `core.create_all_tenant_partitions()` - Tenant onboarding

## ISO/IEC Standards Compliance

| Standard | Status | Notes |
|----------|--------|-------|
| ISO 27001 | ✅ | Encryption, RLS, audit, PII registry |
| ISO 17442 (LEI) | ✅ | Regex validation on lei_code |
| ISO 9362 (BIC) | ✅ | Regex validation on bic_code |
| ISO 20022 | ✅ | message_type, uetr, end_to_end_id |
| ISO 4217 | ✅ | Currency codes table |
| ISO 3166 | ✅ | Country codes |
| ISO 10962 (CFI) | ✅ | Regex on cfi_code |
| ISO 6166 (ISIN) | ✅ | Regex on isin_code |
| ISO 13616 (IBAN) | ⚠️ | Basic validation; MOD97 for production |
| ISO 8601 | ✅ | TIMESTAMPTZ throughout |
| ISO 18774 (FISN) | ✅ | fisn column defined |
| IFRS | ✅ | Chart of accounts, ECL, consolidation |
| Basel III/IV | ✅ | Capital ratios, RWA, LCR, NSFR |
| GDPR | ✅ | PII registry, encryption, retention |
| eIDAS | ✅ | Digital signatures, qualified flag |
| FATF | ✅ | Country/jurisdiction fatf_status |
| PSD2 (SCA) | ✅ | sca_method, sca_exemption_applied |

## Datomic Architecture Mapping

| Datomic Concept | FinOS Implementation | Location |
|-----------------|---------------------|----------|
| Datom (E-A-V-Tx-Op) | `immutable_events` table | `006_immutable_event_store.sql` |
| EAVT Index | `idx_datom_eavt` | `006_immutable_event_store.sql` |
| AVET Index | `idx_datom_avet` | `006_immutable_event_store.sql` |
| As-Of Queries | `core.datoms_as_of()` | `021_datalog_query_engine.sql` |
| Transaction Entity | `event_id` as tx | `006_immutable_event_store.sql` |
| Universal Relation | `core.datom_query()` | `021_datalog_query_engine.sql` |

## Government Verification Interface

```sql
-- Regulators can verify any event
SELECT * FROM core.get_event_verification_proof(12345);

-- Returns:
--   event_hash: SHA-256 of the event
--   merkle_root: Root hash of the batch
--   tx_hash: Blockchain transaction hash
--   chain_type: Which blockchain (sarb_sovereign, ethereum, etc.)
--   proof_path: Sibling hashes for verification
--   anchor_status: pending/mined/confirmed
```

## License
Copyright (c) 2026 FinOS Contributors - Proprietary
