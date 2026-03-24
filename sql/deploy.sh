#!/bin/bash
# =============================================================================
# FINOS CORE KERNEL - DEPLOYMENT SCRIPT V2.0
# =============================================================================
# Description: Deploys the complete FinOS Core Kernel schema to PostgreSQL
# Usage: ./deploy.sh [options]
# =============================================================================

set -e

# Default values
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="finos_dev"
DB_USER="postgres"
DB_PASSWORD="016510"
VERBOSE=false
DRY_RUN=false
PHASE="all"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCTIONS
# =============================================================================

print_usage() {
    cat << EOF
FinOS Core Kernel Deployment Script V2.0

USAGE:
    ./deploy.sh [OPTIONS]

OPTIONS:
    -h, --host          Database host (default: localhost)
    -p, --port          Database port (default: 5432)
    -d, --database      Database name (required)
    -U, --user          Database user (default: postgres)
    -W, --password      Database password
    -P, --phase         Deployment phase: all|foundation|core|post (default: all)
    -v, --verbose       Verbose output
    --dry-run           Show what would be executed without running
    --help              Show this help message

EXAMPLES:
    # Full deployment
    ./deploy.sh -d finos_db -U admin -W secret

    # Deploy only foundation
    ./deploy.sh -d finos_db -U admin -P foundation

    # Dry run
    ./deploy.sh -d finos_db --dry-run

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

execute_sql() {
    local file=$1
    local description=$2
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would execute: $file"
        return 0
    fi
    
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        exit 1
    fi
    
    log_info "Executing: $description"
    
    if [ -n "$DB_PASSWORD" ]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -f "$file" -q 2>&1 | tee -a deploy.log || {
            log_error "Failed: $description"
            exit 1
        }
    else
        psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -f "$file" -q 2>&1 | tee -a deploy.log || {
            log_error "Failed: $description"
            exit 1
        }
    fi
    
    log_success "Completed: $description"
}

check_prerequisites() {
    if ! command -v psql &> /dev/null; then
        log_error "psql command not found. Please install PostgreSQL client."
        exit 1
    fi
    
    if [ -z "$DB_NAME" ]; then
        log_error "Database name is required. Use -d or --database option."
        print_usage
        exit 1
    fi
}

test_connection() {
    log_info "Testing database connection..."
    
    if [ -n "$DB_PASSWORD" ]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT version();" > /dev/null 2>&1
    else
        psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT version();" > /dev/null 2>&1
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to connect to database. Please check credentials."
        exit 1
    fi
    
    log_success "Database connection successful"
}

check_postgres_version() {
    local version
    if [ -n "$DB_PASSWORD" ]; then
        version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SHOW server_version_num;" 2>/dev/null | xargs)
    else
        version=$(psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SHOW server_version_num;" 2>/dev/null | xargs)
    fi
    
    if [ "$version" -lt "160000" ]; then
        log_error "PostgreSQL 16+ is required. Current version: $version"
        exit 1
    fi
    
    log_success "PostgreSQL version check passed (version: $version)"
}

deploy_foundation() {
    log_info "=========================================="
    log_info "PHASE 1: Deploying Foundation Layer (000-011)"
    log_info "=========================================="
    
    execute_sql "foundation/000_extensions.sql" "000: Extensions & Enterprise Foundation"
    execute_sql "foundation/001_audit.sql" "001: Audit Foundation"
    execute_sql "foundation/002_utilities.sql" "002: Utility Functions"
    execute_sql "foundation/003_pii_registry.sql" "003: PII Registry & Data Protection"
    execute_sql "foundation/004_partitioning.sql" "004: Partitioning & Scale Enhancements"
    execute_sql "foundation/005_rate_limiting.sql" "005: Rate Limiting & Throttling"
    execute_sql "foundation/006_webhook.sql" "006: Webhook System"
    execute_sql "foundation/007_scheduled_jobs.sql" "007: Scheduled Jobs"
    execute_sql "foundation/008_cache.sql" "008: Caching Layer"
    execute_sql "foundation/009_algorithm_execution.sql" "009: Algorithm Execution Logging"
    execute_sql "foundation/010_scalability.sql" "010: Scalability & Monitoring"
    execute_sql "foundation/011_grants.sql" "011: Grants & Permissions"
}

deploy_core() {
    log_info "=========================================="
    log_info "PHASE 2: Deploying Core Primitives (000-024)"
    log_info "=========================================="
    
    execute_sql "core/000_extensions.sql" "000: Core Extensions Wrapper"
    execute_sql "core/001_identity_and_tenancy.sql" "001: Primitive 1 - Identity & Tenancy"
    execute_sql "core/002_value_container.sql" "002: Primitive 2 - Value Container"
    execute_sql "core/003_value_movement_and_double_entry.sql" "003: Primitive 3 - Value Movement & Double-Entry"
    execute_sql "core/004_economic_agent_and_relationships.sql" "004: Primitive 4 - Economic Agent & Relationships"
    execute_sql "core/005_temporal_transition_4d.sql" "005: Primitive 5 - Temporal Transition (4D Time)"
    execute_sql "core/006_immutable_event_store.sql" "006: Primitive 6 - Immutable Event Store (DATOMIC MODEL)"
    execute_sql "core/007_chart_of_accounts.sql" "007: Primitive 7 - Chart of Accounts"
    execute_sql "core/008_monetary_system_and_valuation.sql" "008: Primitive 8 - Monetary System & Valuation"
    execute_sql "core/009_settlement_and_finality.sql" "009: Primitive 9 - Settlement & Finality"
    execute_sql "core/010_reconciliation_and_suspense.sql" "010: Primitive 10 - Reconciliation & Suspense"
    execute_sql "core/011_control_and_batch_processing.sql" "011: Primitive 11 - Control & Batch Processing"
    execute_sql "core/012_entitlements_and_authorization.sql" "012: Primitive 12 - Entitlements & Authorization"
    execute_sql "core/013_geography_and_jurisdiction.sql" "013: Primitive 13 - Geography & Jurisdiction"
    execute_sql "core/014_provisioning_and_reserves.sql" "014: Primitive 14 - Provisioning & Reserves"
    execute_sql "core/015_document_and_evidence_references.sql" "015: Primitive 15 - Document & Evidence References"
    execute_sql "core/016_sub_ledger_and_segregation.sql" "016: Primitive 16 - Sub-ledger & Segregation"
    execute_sql "core/017_legal_entity_hierarchy_and_group_consolidation.sql" "017: Primitive 17 - Legal Entity Hierarchy & Consolidation"
    execute_sql "core/018_capital_and_liquidity_position_tracking.sql" "018: Primitive 18 - Capital & Liquidity Position Tracking"
    execute_sql "core/019_kernel_wiring.sql" "019: Primitive 19 - Kernel Wiring"
    execute_sql "core/020_blockchain_anchoring.sql" "020: Blockchain Anchoring & Merkle Trees"
    execute_sql "core/021_datalog_query_engine.sql" "021: Datalog Query Engine"
    execute_sql "core/022_peer_caching.sql" "022: Peer-Style Read Caching"
    execute_sql "core/023_columnar_archival.sql" "023: Columnar Compression & Auto-Archiving"
    execute_sql "core/024_transaction_entity.sql" "024: Transaction Entity (First-Class Citizen)"
}

verify_deployment() {
    log_info "=========================================="
    log_info "Verifying Deployment"
    log_info "=========================================="
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Skipping verification"
        return 0
    fi
    
    # Check table counts
    local table_count
    if [ -n "$DB_PASSWORD" ]; then
        table_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit', 'core_reporting');" 2>/dev/null | xargs)
    else
        table_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit', 'core_reporting');" 2>/dev/null | xargs)
    fi
    
    log_info "Total tables deployed: $table_count"
    
    # Run health check
    if [ -n "$DB_PASSWORD" ]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT * FROM core.health_check_full();" 2>/dev/null || log_warning "Health check not available yet"
    else
        psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c "SELECT * FROM core.health_check_full();" 2>/dev/null || log_warning "Health check not available yet"
    fi
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            DB_HOST="$2"
            shift 2
            ;;
        -p|--port)
            DB_PORT="$2"
            shift 2
            ;;
        -d|--database)
            DB_NAME="$2"
            shift 2
            ;;
        -U|--user)
            DB_USER="$2"
            shift 2
            ;;
        -W|--password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        -P|--phase)
            PHASE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main execution
log_info "FinOS Core Kernel V2.0 Deployment"
log_info "================================="

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE - No changes will be made"
fi

check_prerequisites
test_connection
check_postgres_version

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

case $PHASE in
    all)
        deploy_foundation
        deploy_core
        ;;
    foundation)
        deploy_foundation
        ;;
    core)
        deploy_core
        ;;
    *)
        log_error "Unknown phase: $PHASE"
        print_usage
        exit 1
        ;;
esac

verify_deployment

log_success "=========================================="
log_success "Deployment Complete!"
log_success "=========================================="
