-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 47: Regulatory Identifiers
-- Description: UTI/UPI registry for EMIR, MiFID II, SFTR with trade repository
--              submission tracking and data lineage
-- Compliance: EMIR REFIT, MiFID II RTS 22, CFTC Part 43/45, SFTR
-- ================================================================================

-- Regulatory Identifier Tables
\i dynamic.uti_upi_registry.sql
\i dynamic.trade_repository_submission.sql
\i dynamic.regulatory_data_lineage.sql

-- Component Summary
-- Tables: 3
-- - uti_upi_registry: Unique Trade/Product Identifier lifecycle management
-- - trade_repository_submission: TR/ARM submission tracking with rejection handling
-- - regulatory_data_lineage: Data provenance for regulatory reporting (BCBS 239)
-- ================================================================================
