-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 41: Transaction Event Sourcing (CQRS Pattern)
-- Description: Event sourcing infrastructure for transaction lifecycle management
--              with saga orchestration and compensation patterns
-- Compliance: SOX, PCI-DSS, Audit Trail Requirements
-- ================================================================================

-- Core Event Sourcing Tables
\i dynamic.transaction_event_journal.sql
\i dynamic.transaction_compensation_log.sql
\i dynamic.saga_orchestration_config.sql

-- Component Summary
-- Tables: 3
-- - transaction_event_journal: Immutable event store with blockchain-like integrity
-- - transaction_compensation_log: Saga compensation tracking for distributed rollback
-- - saga_orchestration_config: Distributed transaction workflow configuration
-- ================================================================================
