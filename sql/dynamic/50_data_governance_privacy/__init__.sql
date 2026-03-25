-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 50: Data Governance & Privacy (GDPR Article 30)
-- Description: Data residency constraints, PII classification, and cross-border
--              transfer audit logging per GDPR/CCPA
-- Compliance: GDPR Article 30, CCPA, LGPD, Schrems II
-- ================================================================================

-- Data Governance Tables
\i dynamic.data_residency_constraint.sql
\i dynamic.pii_data_classification.sql
\i dynamic.cross_border_transfer_log.sql

-- Component Summary
-- Tables: 3
-- - data_residency_constraint: Geographic data storage and transfer rules
-- - pii_data_classification: PII element sensitivity and masking configuration
-- - cross_border_transfer_log: Article 30 records of processing activities
-- ================================================================================
