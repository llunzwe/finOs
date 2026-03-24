-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 18: LEGAL ENTITY HIERARCHY & CONSOLIDATION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: LEI, Ownership Trees, Consolidation Rules, IFRS 10
-- Standards: ISO 17442 (LEI), IFRS 10, IFRS 12, IAS 27, Basel Committee
-- =============================================================================

-- =============================================================================
-- LEGAL ENTITIES (Extension of Economic Agents)
-- =============================================================================
CREATE TABLE core.legal_entities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Legal Form
    legal_form VARCHAR(50) NOT NULL 
        CHECK (legal_form IN ('corporation', 'partnership', 'llc', 'llp', 'trust', 'foundation', 
                             'cooperative', 'state_owned', 'sovereign', 'non_profit', 'branch')),
    
    -- Registration
    registration_number VARCHAR(100) NOT NULL,
    registration_country CHAR(2) NOT NULL REFERENCES core.country_codes(iso_code),
    registration_date DATE,
    registration_authority VARCHAR(100),
    registered_office_address_id UUID REFERENCES core.addresses(id),
    
    -- Legal Entity Identifier (ISO 17442)
    lei_code VARCHAR(20) UNIQUE CHECK (lei_code ~ '^[A-Z0-9]{18}[0-9]{2}$'),
    lei_registration_status VARCHAR(20) CHECK (lei_registration_status IN ('issued', 'lapsed', 'merged', 'retired')),
    lei_validated_at TIMESTAMPTZ,
    
    -- Industry
    industry_code VARCHAR(10),
    industry_classification VARCHAR(20) DEFAULT 'ISIC' CHECK (industry_classification IN ('ISIC', 'NAICS', 'NACE', 'GICS')),
    sector VARCHAR(50),
    sub_sector VARCHAR(50),
    
    -- Group Structure
    is_standalone BOOLEAN NOT NULL DEFAULT TRUE,
    is_parent_entity BOOLEAN NOT NULL DEFAULT FALSE,
    is_ultimate_parent BOOLEAN NOT NULL DEFAULT FALSE,
    ultimate_parent_id UUID REFERENCES core.legal_entities(id),
    immediate_parent_id UUID REFERENCES core.legal_entities(id),
    group_name VARCHAR(200),
    
    -- IFRS 10 Control Assessment
    control_assessment JSONB DEFAULT '{}', -- {
                                           --   "voting_rights_pct": 0.51,
                                           --   "board_control": true,
                                           --   "operational_integration": true,
                                           --   "variable_returns": true
                                           -- }
    control_basis VARCHAR(50) CHECK (control_basis IN ('majority_voting', 'contractual', 'potential_voting', 'de_facto', 'none')),
    
    -- Consolidation
    consolidation_method VARCHAR(20) DEFAULT 'full' 
        CHECK (consolidation_method IN ('full', 'proportional', 'equity', 'none')),
    consolidation_exemption_reason VARCHAR(100),
    
    -- Regulatory
    is_regulated_entity BOOLEAN NOT NULL DEFAULT FALSE,
    regulator VARCHAR(100),
    license_type VARCHAR(50),
    license_number VARCHAR(100),
    
    -- Reporting
    fiscal_year_end_month INTEGER CHECK (fiscal_year_end_month BETWEEN 1 AND 12),
    fiscal_year_end_day INTEGER CHECK (fiscal_year_end_day BETWEEN 1 AND 31),
    reporting_currency CHAR(3) REFERENCES core.currencies(code),
    reporting_standard VARCHAR(20) CHECK (reporting_standard IN ('IFRS', 'US_GAAP', 'LOCAL_GAAP')),
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'dormant', 'liquidation', 'dissolved', 'merged', 'acquired')),
    status_effective_date DATE,
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_agent_legal_entity UNIQUE (agent_id),
    CONSTRAINT unique_lei_code UNIQUE (lei_code)
);

CREATE INDEX idx_legal_entities_agent ON core.legal_entities(agent_id);
CREATE INDEX idx_legal_entities_lei ON core.legal_entities(lei_code) WHERE lei_code IS NOT NULL;
CREATE INDEX idx_legal_entities_parent ON core.legal_entities(immediate_parent_id) WHERE immediate_parent_id IS NOT NULL;
CREATE INDEX idx_legal_entities_ultimate ON core.legal_entities(ultimate_parent_id) WHERE ultimate_parent_id IS NOT NULL;
CREATE INDEX idx_legal_entities_consolidation ON core.legal_entities(tenant_id, consolidation_method);
CREATE INDEX idx_legal_entities_status ON core.legal_entities(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_legal_entities_correlation ON core.legal_entities(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.legal_entities IS 'Legal entity details extending economic agents with LEI and consolidation data';

-- =============================================================================
-- OWNERSHIP HIERARCHIES
-- =============================================================================
CREATE TABLE core.ownership_hierarchies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Relationship
    parent_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    child_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Ownership Details
    ownership_percentage DECIMAL(5,2) NOT NULL CHECK (ownership_percentage BETWEEN 0 AND 100),
    voting_rights_percentage DECIMAL(5,2) CHECK (voting_rights_percentage BETWEEN 0 AND 100),
    control_percentage DECIMAL(5,2) CHECK (control_percentage BETWEEN 0 AND 100),
    
    -- Control Type
    control_type VARCHAR(20) NOT NULL 
        CHECK (control_type IN ('direct', 'indirect', 'voting', 'contractual', 'joint', 'significant_influence')),
    
    -- Ownership Instrument
    instrument_type VARCHAR(50), -- 'ordinary_shares', 'preference_shares', 'voting_trust'
    instrument_count DECIMAL(28,8),
    
    -- Acquisition
    acquisition_date DATE,
    acquisition_price DECIMAL(28,8),
    acquisition_currency CHAR(3),
    goodwill DECIMAL(28,8),
    
    -- Effective Period
    effective_date DATE NOT NULL,
    termination_date DATE,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Verification
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    verification_source VARCHAR(100), -- 'annual_report', 'regulatory_filing', 'shareholder_register'
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT no_self_ownership CHECK (parent_entity_id != child_entity_id),
    CONSTRAINT unique_ownership_period UNIQUE (tenant_id, parent_entity_id, child_entity_id, effective_date)
);

CREATE INDEX idx_ownership_parent ON core.ownership_hierarchies(parent_entity_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_ownership_child ON core.ownership_hierarchies(child_entity_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_ownership_control ON core.ownership_hierarchies(tenant_id, control_type);

COMMENT ON TABLE core.ownership_hierarchies IS 'Ownership relationships between legal entities';

-- =============================================================================
-- CONSOLIDATION RULES
-- =============================================================================
CREATE TABLE core.consolidation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Group
    group_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Rule Definition
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(20) NOT NULL 
        CHECK (rule_type IN ('elimination', 'minority_interest', 'currency_translation', 'goodwill', 'intercompany')),
    
    -- Parameters
    parameters JSONB NOT NULL DEFAULT '{}', -- {
                                            --   "elimination_type": "investment_subsidiary",
                                            --   "translation_method": "current_rate",
                                            --   "functional_currency": "USD"
                                            -- }
    
    -- Applicability
    applies_to_entities UUID[], -- NULL = all entities in group
    applies_to_accounts VARCHAR(50)[],
    
    -- Execution
    execution_order INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consolidation_rules_group ON core.consolidation_rules(group_entity_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.consolidation_rules IS 'Rules for group consolidation adjustments';

-- =============================================================================
-- CONSOLIDATED POSITIONS
-- =============================================================================
CREATE TABLE core.consolidated_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reporting Context
    group_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    reporting_date DATE NOT NULL,
    reporting_period VARCHAR(20), -- '2026-Q1', '2026-H1', '2026-Annual'
    
    -- Balance Sheet
    total_assets DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_liabilities DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_equity DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Components
    current_assets DECIMAL(28,8),
    non_current_assets DECIMAL(28,8),
    current_liabilities DECIMAL(28,8),
    non_current_liabilities DECIMAL(28,8),
    
    -- Equity Breakdown
    share_capital DECIMAL(28,8),
    retained_earnings DECIMAL(28,8),
    other_reserves DECIMAL(28,8),
    minority_interest DECIMAL(28,8),
    
    -- Income Statement (if period-end)
    revenue DECIMAL(28,8),
    operating_profit DECIMAL(28,8),
    net_profit DECIMAL(28,8),
    profit_attributable_to_parent DECIMAL(28,8),
    profit_attributable_to_minority DECIMAL(28,8),
    
    -- Elimination Details
    elimination_entries JSONB DEFAULT '[]',
    intercompany_receivables_eliminated DECIMAL(28,8),
    intercompany_payables_eliminated DECIMAL(28,8),
    investment_in_subsidiaries_eliminated DECIMAL(28,8),
    
    -- Currency
    reporting_currency CHAR(3) NOT NULL,
    currency_translation_reserve DECIMAL(28,8),
    
    -- Scope
    entities_included INTEGER,
    entities_excluded INTEGER,
    entity_list UUID[],
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'reviewed', 'approved', 'published')),
    
    -- Audit
    prepared_by UUID,
    reviewed_by UUID,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_consolidated_position UNIQUE (tenant_id, group_entity_id, reporting_date, reporting_period)
);

CREATE INDEX idx_consolidated_positions_group ON core.consolidated_positions(group_entity_id, reporting_date DESC);
CREATE INDEX idx_consolidated_positions_period ON core.consolidated_positions(tenant_id, reporting_date);

COMMENT ON TABLE core.consolidated_positions IS 'Consolidated financial positions by group';

-- =============================================================================
-- INTERCOMPANY ELIMINATIONS
-- =============================================================================
CREATE TABLE core.intercompany_eliminations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Consolidation Run
    consolidated_position_id UUID NOT NULL REFERENCES core.consolidated_positions(id),
    
    -- Transaction
    from_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    to_entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Elimination Type
    elimination_type VARCHAR(50) NOT NULL 
        CHECK (elimination_type IN ('investment_subsidiary', 'intercompany_loan', 'intercompany_sale', 
                                    'dividend', 'minority_interest', 'unrealized_profit')),
    
    -- Amounts
    gross_amount DECIMAL(28,8) NOT NULL,
    elimination_amount DECIMAL(28,8) NOT NULL,
    consolidated_amount DECIMAL(28,8) GENERATED ALWAYS AS (gross_amount - elimination_amount) STORED,
    
    -- Accounting
    account_code VARCHAR(50),
    account_name VARCHAR(200),
    
    -- Original Transaction
    original_movement_id UUID REFERENCES core.value_movements(id),
    original_reference VARCHAR(100),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ic_eliminations_position ON core.intercompany_eliminations(consolidated_position_id);
CREATE INDEX idx_ic_eliminations_type ON core.intercompany_eliminations(elimination_type);

COMMENT ON TABLE core.intercompany_eliminations IS 'Detailed intercompany elimination entries';

-- =============================================================================
-- GROUP STRUCTURE VIEWS
-- =============================================================================

-- View: Flattened Group Structure
CREATE OR REPLACE VIEW core.group_structure AS
WITH RECURSIVE entity_tree AS (
    -- Base case: ultimate parents
    SELECT 
        id as entity_id,
        id as root_entity_id,
        1 as level,
        id::text as path,
        100.0 as effective_ownership,  -- Ultimate parents have 100% ownership of themselves
        consolidation_method
    FROM core.legal_entities
    WHERE is_ultimate_parent = TRUE OR ultimate_parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case
    SELECT 
        oh.child_entity_id as entity_id,
        et.root_entity_id,
        et.level + 1,
        et.path || '.' || oh.child_entity_id::text,
        et.effective_ownership * (oh.ownership_percentage / 100),
        le.consolidation_method
    FROM entity_tree et
    JOIN core.ownership_hierarchies oh ON oh.parent_entity_id = et.entity_id
    JOIN core.legal_entities le ON le.id = oh.child_entity_id
    WHERE oh.is_active = TRUE
)
SELECT 
    et.*,
    ea.display_name as entity_name,
    le.legal_form,
    le.lei_code,
    le.registration_country,
    le.status
FROM entity_tree et
JOIN core.legal_entities le ON le.id = et.entity_id
JOIN core.economic_agents ea ON ea.id = le.agent_id;

COMMENT ON VIEW core.group_structure IS 'Recursive view of group ownership structure';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.legal_entities TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.ownership_hierarchies TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.consolidation_rules TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.consolidated_positions TO finos_app;
GRANT SELECT, INSERT ON core.intercompany_eliminations TO finos_app;
GRANT SELECT ON core.group_structure TO finos_app;
