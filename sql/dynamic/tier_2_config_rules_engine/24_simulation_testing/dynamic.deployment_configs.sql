-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.deployment_configs
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.deployment_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Deployment Identity
    deployment_name VARCHAR(200) NOT NULL,
    deployment_type VARCHAR(50) NOT NULL 
        CHECK (deployment_type IN ('SAAS_SHARED', 'SAAS_DEDICATED', 'BANK_HOSTED', 'HYBRID', 'PRIVATE_CLOUD')),
    
    -- Infrastructure
    infrastructure_provider VARCHAR(50) 
        CHECK (infrastructure_provider IN ('AWS', 'AZURE', 'GCP', 'OPENSHIFT', 'ANTHOS', 'ON_PREMISE')),
    infrastructure_config JSONB DEFAULT '{}',
    -- Example: {
    --   region: 'eu-west-1',
    --   availability_zones: ['a', 'b', 'c'],
    --   kubernetes_cluster: 'finos-prod-1',
    --   node_pools: {...}
    -- }
    
    -- Database
    database_tier VARCHAR(50) DEFAULT 'standard' 
        CHECK (database_tier IN ('shared', 'standard', 'premium', 'dedicated')),
    database_config JSONB DEFAULT '{}',
    -- {instance_class: 'db.r6g.xlarge', storage_gb: 1000, read_replicas: 2}
    
    -- Scaling
    auto_scaling_enabled BOOLEAN DEFAULT TRUE,
    scaling_config JSONB DEFAULT '{}',
    -- {min_instances: 2, max_instances: 20, target_cpu: 70, target_memory: 80}
    
    -- Security
    security_config JSONB DEFAULT '{}',
    -- {vpc_id: '...', security_groups: [...], encryption_at_rest: true, tls_version: '1.3'}
    
    -- Backup & DR
    backup_config JSONB DEFAULT '{}',
    -- {retention_days: 35, frequency_hours: 24, cross_region_backup: true}
    
    dr_config JSONB DEFAULT '{}',
    -- {rpo_minutes: 5, rto_minutes: 30, failover_region: 'eu-central-1'}
    
    -- Compliance
    compliance_zones TEXT[] DEFAULT ARRAY['GDPR'], -- GDPR, PCI_DSS, SOC2, etc.
    data_residency_requirement VARCHAR(100), -- e.g., 'EU_ONLY', 'ZA_ONLY'
    
    -- Network
    network_config JSONB DEFAULT '{}',
    -- {vpn_enabled: true, direct_connect: false, waf_enabled: true}
    
    -- Monitoring
    monitoring_config JSONB DEFAULT '{}',
    -- {prometheus: true, grafana: true, datadog: false, custom_dashboards: [...]}
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' 
        CHECK (status IN ('draft', 'provisioning', 'active', 'maintenance', 'decommissioning')),
    
    -- Timestamps
    provisioned_at TIMESTAMPTZ,
    last_deployed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.deployment_configs_default PARTITION OF dynamic.deployment_configs DEFAULT;

-- Indexes
CREATE INDEX idx_deployment_configs_tenant ON dynamic.deployment_configs(tenant_id, status);

-- Comments
COMMENT ON TABLE dynamic.deployment_configs IS 
    'Tenant-specific deployment configurations for SaaS/Bank-hosted/Hybrid/OpenShift/Anthos';

-- Triggers
CREATE TRIGGER trg_deployment_configs_update
    BEFORE UPDATE ON dynamic.deployment_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_simulation_testing_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.deployment_configs TO finos_app;