# FinOS Dynamic Layer - Three-Tier Architecture

## Overview

The **FinOS Dynamic Layer** is implemented as a three-tier system that balances ease of use with maximum flexibility for financial services configuration.

## Three-Tier Structure

### Tier 1 - Instant Library (Zero-Code) 📦
**Location**: `tier_1_instant_library/`

Pre-built, ready-to-use product templates and industry packs that tenants can enable with a single click, without any configuration or coding.

| Table | Description |
|-------|-------------|
| `dynamic.product_library_catalog` | Seeded catalog of 60+ products (mortgages, loans, deposits, cards, etc.) |
| `dynamic.product_pack_enablement` | Industry packs (Banking, Insurance, Payments) bundling multiple products |

**Use Case**: Fintechs who need immediate product deployment without configuration.

---

### Tier 2 - Config & Rules Engine (Low-Code) ⚙️
**Location**: `tier_2_config_rules_engine/`

The largest part of the Dynamic Layer with 240+ tables. All configuration tables, parameterized rules, workflows, and operational definitions. Business users interact through UI forms, JSON parameters, and rule builders – **no code required**.

#### Components (25 Total):

| Component | Tables | Description |
|-----------|--------|-------------|
| 01_product_taxonomy | 19 | Product classification, templates, parameters |
| 02_pricing_calculation_engines | 18 | Interest rates, fees, taxes, transfer pricing |
| 03_workflow_state_machine | 13 | BPMN workflows, tasks, approvals |
| 04_event_scheduling | 7 | Cron schedules, event schemas, outbox |
| 05_simulation_forecasting | 6 | Stress testing, cash flow projections |
| 06_accounting_financial_control | 11 | ECL, revenue recognition, reconciliation |
| 07_insurance_takaful | 12 | Policy management, claims, reinsurance |
| 08_customer_management | 9 | KYC, segmentation, consent |
| 09_collateral_security | 8 | Collateral tracking, security agreements |
| 10_regulatory_reporting | 9 | XBRL, Basel reporting, AML |
| 11_integration_api_management | 10 | API endpoints, file ingestion |
| 12_performance_operations | 9 | Batch jobs, monitoring, alerts |
| 13_billing_contracts | 8 | Invoicing, contracts, usage metering |
| 14_rules_engines | 9 | Business rules, fraud detection, AML |
| 15_industry_packs_banking | 5 | Banking-specific loan configurations |
| 16_industry_packs_insurance | 6 | Insurance policy templates |
| 17_industry_packs_investments | 6 | Portfolio models, order execution |
| 18_industry_packs_payments | 5 | Payment gateways, checkout flows |
| 19_industry_packs_retail_ads | 5 | POS, loyalty, ad pricing |
| 20_reporting_analytics | 8 | Reports, metrics, dashboards |
| 21_integration_hooks | 5 | Webhooks, data imports |
| 22_marqeta_entities | 26 | Card programs, authorizations |
| 23_api_streaming_config | 6 | API surfaces, streaming |
| 24_simulation_testing | 9 | Test suites, deployment configs |
| 25_supporting_accounting | 8 | GL mappings, ring-fencing |

**Total Tier 2 Tables**: 240

---

### Tier 3 - Scripted Extensions (Smart Contracts) 🔐
**Location**: `tier_3_scripted_extensions/`

Advanced extensibility via sandboxed scripts (JavaScript, Lua, WASM). These are **optional, developer-only** features for creating entirely new product behavior.

| Table | Description |
|-------|-------------|
| `dynamic.product_smart_contracts` | Vault-style smart contracts with WASM/Lua/JS |
| `dynamic.contract_execution_log` | Audit log of smart contract executions |
| `dynamic.hook_definition` | Superhook definitions with sandboxed scripts |
| `dynamic.hook_parameter_mapping` | Input/output contracts for hooks |
| `dynamic_history.hook_execution_log` | Audit trail of hook executions |
| `dynamic.business_rule_engine` | General-purpose rule engine with scripting |
| `dynamic_history.business_rule_execution_log` | Business rule execution history |

**Use Case**: When unique behavior cannot be expressed through configuration alone.

---

## Schema Foundation
**File**: `000_schema_foundation.sql`

Contains:
- Schema creation (`dynamic`, `dynamic_history`)
- 25+ Custom ENUM types (ISO 20022, IFRS, Basel aligned)
- Helper functions (entity code generation)
- Grants and comments

---

## Compliance Framework

All tables implement enterprise-grade compliance:

### Accounting Standards
- **IFRS 9**: Financial Instruments (ECL, classification)
- **IFRS 15**: Revenue Recognition (performance obligations)
- **IFRS 17**: Insurance Contracts (BBA, VFA, PAA)

### Regulatory Frameworks
- **Basel III/IV**: Capital adequacy, stress testing
- **BCBS 239**: Risk data aggregation
- **Solvency II**: Insurance capital requirements
- **MiFID II**: Investment services
- **PSD2**: Payment services & SCA

### Data Standards
- **ISO 4217**: Currency codes
- **ISO 8601**: Date/time representation
- **ISO 20022**: Financial messaging
- **ISO 17442**: Legal Entity Identifier
- **ISO 27001**: Information security
- **XBRL**: eXtensible Business Reporting

### Data Protection
- **GDPR**: EU data protection
- **POPIA**: South Africa data protection

### Regional Compliance
- **NCA**: National Credit Act (South Africa)
- **SARS**: South African Revenue Service
- **RBZ**: Reserve Bank of Zimbabwe
- **FSCA**: Financial Sector Conduct Authority

---

## File Naming Convention

```
{schema}.{table_name}.sql

Examples:
- dynamic.product_library_catalog.sql
- dynamic_history.workflow_history.sql
```

---

## Usage

### Load Complete Dynamic Layer
```bash
psql -U your_user -d your_database -f sql/dynamic/000_schema_foundation.sql
psql -U your_user -d your_database -f sql/dynamic/_master_dynamic_layer.sql
```

### Load Individual Component
```bash
# Example: Pricing & Calculation Engines
psql -U your_user -d your_database \
  -f sql/dynamic/tier_2_config_rules_engine/02_pricing_calculation_engines/dynamic.interest_rate_curve.sql
```

### Load Specific Table
```bash
psql -U your_user -d your_database \
  -f sql/dynamic/tier_2_config_rules_engine/03_workflow_state_machine/dynamic.workflow_instance.sql
```

---

## Architecture Benefits

| Aspect | Benefit |
|--------|---------|
| **Zero-Code (Tier 1)** | 95% of fintechs never need to write code |
| **Low-Code (Tier 2)** | Business users configure via UI/API |
| **Full-Code (Tier 3)** | Developers extend when needed |
| **Bitemporal** | Full audit trail for regulatory compliance |
| **Tenant Isolation** | Data residency and GDPR compliance |
| **Standards Aligned** | 50+ ISO/IFRS/Basel standards |

---

## Statistics

| Metric | Count |
|--------|-------|
| Total Tables | 249 |
| Tier 1 Tables | 2 |
| Tier 2 Tables | 240 |
| Tier 3 Tables | 7 |
| Total SQL Files | 250 |
| Components | 25 |
| Compliance Standards | 50+ |

---

## Last Updated

March 2026 - Complete three-tier implementation with full compliance documentation.
