-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 41: Transaction Event Sourcing (CQRS Pattern)
-- Table: transaction_event_journal
-- Description: Immutable event store for transaction lifecycle - Event Sourcing backbone
--              Provides complete audit trail, supports CQRS, enables temporal queries
-- Compliance: SOX, PCI-DSS, Audit Trail Requirements
-- ================================================================================

CREATE TABLE dynamic.transaction_event_journal (
    -- Primary Identity
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Event Identification
    event_sequence BIGSERIAL NOT NULL,
    event_type VARCHAR(100) NOT NULL CHECK (event_type IN (
        'TRANSACTION_INITIATED', 'TRANSACTION_VALIDATED', 'TRANSACTION_AUTHORIZED',
        'TRANSACTION_POSTED', 'TRANSACTION_SETTLED', 'TRANSACTION_RECONCILED',
        'TRANSACTION_REVERSED', 'TRANSACTION_ADJUSTED', 'TRANSACTION_CANCELLED',
        'TRANSACTION_SPLIT', 'TRANSACTION_MERGED', 'TRANSACTION_HELD',
        'TRANSACTION_RELEASED', 'TRANSACTION_EXPIRED', 'TRANSACTION_FAILED'
    )),
    event_version INTEGER NOT NULL DEFAULT 1,
    
    -- Transaction Reference
    transaction_id UUID NOT NULL,
    parent_transaction_id UUID REFERENCES dynamic.transaction_event_journal(event_id),
    correlation_id UUID NOT NULL, -- For distributed transaction tracking
    saga_id UUID, -- For saga orchestration
    
    -- Event Payload (Immutable)
    event_payload JSONB NOT NULL,
    payload_schema_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    payload_hash VARCHAR(64) NOT NULL, -- SHA-256 for integrity verification
    
    -- Event Metadata
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_source VARCHAR(100) NOT NULL, -- Service/application that generated event
    event_actor VARCHAR(100) NOT NULL, -- User or system that triggered event
    event_ip_address INET,
    event_session_id VARCHAR(255),
    
    -- Processing Status
    processing_status VARCHAR(50) DEFAULT 'PENDING' CHECK (processing_status IN (
        'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'RETRYING', 'DEAD_LETTER'
    )),
    processed_at TIMESTAMPTZ,
    processor_node VARCHAR(100),
    retry_count INTEGER DEFAULT 0,
    
    -- Event Chain (Previous Event Hash for integrity)
    previous_event_hash VARCHAR(64),
    
    -- Partitioning & Bitemporal
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns (Standardized)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_event_sequence_per_tenant UNIQUE (tenant_id, event_sequence),
    CONSTRAINT unique_correlation_event UNIQUE (tenant_id, correlation_id, event_type, event_timestamp)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.transaction_event_journal_default PARTITION OF dynamic.transaction_event_journal
    DEFAULT;

-- Monthly partitions for recent data
CREATE TABLE dynamic.transaction_event_journal_2025_01 PARTITION OF dynamic.transaction_event_journal
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.transaction_event_journal_2025_02 PARTITION OF dynamic.transaction_event_journal
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE dynamic.transaction_event_journal_2025_03 PARTITION OF dynamic.transaction_event_journal
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Indexes for Event Store Performance
CREATE INDEX idx_transaction_event_journal_tenant_transaction ON dynamic.transaction_event_journal (tenant_id, transaction_id, event_sequence);
CREATE INDEX idx_transaction_event_journal_correlation ON dynamic.transaction_event_journal (tenant_id, correlation_id);
CREATE INDEX idx_transaction_event_journal_saga ON dynamic.transaction_event_journal (tenant_id, saga_id) WHERE saga_id IS NOT NULL;
CREATE INDEX idx_transaction_event_journal_event_type ON dynamic.transaction_event_journal (tenant_id, event_type, event_timestamp);
CREATE INDEX idx_transaction_event_journal_processing ON dynamic.transaction_event_journal (tenant_id, processing_status, retry_count) WHERE processing_status IN ('PENDING', 'FAILED', 'RETRYING');
CREATE INDEX idx_transaction_event_journal_payload ON dynamic.transaction_event_journal USING GIN (event_payload jsonb_path_ops);
CREATE INDEX idx_transaction_event_journal_timestamp ON dynamic.transaction_event_journal (event_timestamp DESC);

-- Comments for documentation
COMMENT ON TABLE dynamic.transaction_event_journal IS 'Immutable event store for transaction lifecycle - Event Sourcing backbone providing complete audit trail';
COMMENT ON COLUMN dynamic.transaction_event_journal.event_sequence IS 'Monotonic sequence number for event ordering within tenant';
COMMENT ON COLUMN dynamic.transaction_event_journal.payload_hash IS 'SHA-256 hash of event_payload for integrity verification';
COMMENT ON COLUMN dynamic.transaction_event_journal.previous_event_hash IS 'Hash of previous event in chain for blockchain-like integrity';
COMMENT ON COLUMN dynamic.transaction_event_journal.saga_id IS 'Distributed saga orchestration identifier for long-running transactions';

-- Row Level Security
ALTER TABLE dynamic.transaction_event_journal ENABLE ROW LEVEL SECURITY;

CREATE POLICY transaction_event_journal_tenant_isolation ON dynamic.transaction_event_journal
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT ON dynamic.transaction_event_journal TO finos_app_user;
GRANT SELECT ON dynamic.transaction_event_journal TO finos_readonly_user;
