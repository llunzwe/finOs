-- =============================================================================
-- FINOS CORE KERNEL - RATE LIMITING & THROTTLING
-- =============================================================================
-- File: 005_rate_limiting.sql
-- Description: Multi-tier rate limiting policies and counters
-- Standards: API Management, DDoS Protection
-- =============================================================================

-- SECTION 15: RATE LIMITING & THROTTLING
-- =============================================================================

CREATE TABLE core.rate_limit_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Policy Definition
    policy_name VARCHAR(100) NOT NULL,
    policy_type VARCHAR(50) NOT NULL CHECK (policy_type IN ('endpoint', 'client_type', 'user', 'global')),
    
    -- Limits
    requests_per_second INTEGER,
    requests_per_minute INTEGER,
    requests_per_hour INTEGER,
    requests_per_day INTEGER,
    
    -- Burst Allowance
    burst_size INTEGER DEFAULT 10,
    
    -- Temporal Validity (Bitemporal)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Scope
    applies_to_endpoint VARCHAR(200),
    applies_to_client_type VARCHAR(50),
    applies_to_user_id UUID,
    
    -- Action on Limit
    action_on_limit VARCHAR(50) DEFAULT 'reject' CHECK (action_on_limit IN ('reject', 'queue', 'throttle')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_rate_policy UNIQUE (tenant_id, policy_name, valid_from)
);

-- Add FK constraint for applies_to_user_id
ALTER TABLE core.rate_limit_policies 
    ADD CONSTRAINT fk_rate_policies_user 
    FOREIGN KEY (applies_to_user_id) REFERENCES core.economic_agents(id) ON DELETE CASCADE;

CREATE INDEX idx_rate_policies_active ON core.rate_limit_policies(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.rate_limit_policies IS 'Multi-tier rate limiting policies with bitemporal validity';

-- Rate Limit Counter Table (for tracking current usage)
CREATE TABLE core.rate_limit_counters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    policy_id UUID REFERENCES core.rate_limit_policies(id),
    
    -- Counter Key
    counter_key TEXT NOT NULL, -- Composite key: endpoint + client + user
    
    -- Current Counts
    current_count INTEGER DEFAULT 0,
    window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    window_type VARCHAR(20) NOT NULL CHECK (window_type IN ('second', 'minute', 'hour', 'day')),
    
    -- Expiry
    expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '1 day',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_counter_key UNIQUE (tenant_id, counter_key, window_type, window_start)
);

CREATE INDEX idx_rate_counters_expiry ON core.rate_limit_counters(expires_at) WHERE expires_at < NOW();
CREATE INDEX idx_rate_counters_lookup ON core.rate_limit_counters(tenant_id, counter_key, window_type);

COMMENT ON TABLE core.rate_limit_counters IS 'Active rate limit counters with automatic expiration';

-- =============================================================================
