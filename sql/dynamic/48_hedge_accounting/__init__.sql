-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 48: Hedge Accounting (IFRS 9)
-- Description: Hedge designation, effectiveness testing, and accounting entries
--              for fair value, cash flow, and net investment hedges
-- Compliance: IFRS 9 (2014), IAS 39, US GAAP ASC 815
-- ================================================================================

-- Hedge Accounting Tables
\i dynamic.hedge_designation.sql
\i dynamic.hedge_effectiveness_testing.sql
\i dynamic.hedge_accounting_entries.sql

-- Component Summary
-- Tables: 3
-- - hedge_designation: Hedge relationship documentation and ratio configuration
-- - hedge_effectiveness_testing: Prospective/retrospective effectiveness results
-- - hedge_accounting_entries: Journal entries for OCI, ineffective portions
-- ================================================================================
