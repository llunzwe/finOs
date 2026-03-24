# FinOS – Universal Financial Operating System

## Complete System Documentation

**Version**: 1.0  
**Date**: March 2026  
**Classification**: Public Technical Documentation

---

## Table of Contents

1. [Introduction & Philosophy](#1-introduction--philosophy)
2. [System Architecture](#2-system-architecture)
3. [Core Kernel – The 19 Immutable Primitives](#3-core-kernel--the-19-immutable-primitives)
4. [Dynamic Layer – Product-as-Code](#4-dynamic-layer--product-as-code)
5. [Unknown Layer – Tenant Innovation](#5-unknown-layer--tenant-innovation)
6. [Accounting & Financial Control](#6-accounting--financial-control)
7. [Scalability & Performance](#7-scalability--performance)
8. [Blockchain & Smart Contract Integration](#8-blockchain--smart-contract-integration)
9. [Deployment & Delivery Models](#9-deployment--delivery-models)
10. [Security & Compliance](#10-security--compliance)
11. [Getting Started](#11-getting-started)
12. [Conclusion](#12-conclusion)

---

## 1. Introduction & Philosophy

FinOS is a **universal, southern‑African fintech operating system** designed as a clean, immutable kernel that underpins any financial product or service. It is deliberately layered into three distinct sections:

- **Core Kernel** – 19 immutable primitives that encode the fundamental “financial physics” of value, time, identity, and regulation.
- **Dynamic Layer** – configurable product logic, business rules, and workflows that sit on top of the Core.
- **Unknown Layer** – tenant‑specific innovation, custom fields, and experimental features.

The entire system follows a strict philosophy: **the Core never changes once written**; everything else builds on it. This ensures auditability, regulatory compliance, and zero vendor lock‑in for product innovation.

**Design Principles**
- **Immutability First** – All facts are recorded in an append‑only, cryptographically linked log.
- **Event Sourcing + Double‑Entry** – Every value change is a balanced movement (debits = credits). Balances are derived, never mutated.
- **Bitemporal (4D Time)** – Every record carries system time, valid business time, decision time, and sequence. Enables perfect “as‑of” queries.
- **Universal Tenancy & Isolation** – Every row is partitioned and isolated by `tenant_id`. Row‑Level Security is mandatory.
- **Standards Alignment** – ISO 4217, ISO 17442 (LEI), ISO 13616 (IBAN), ISO 20022, IFRS, Basel III/IV, FATF baked into the schema.
- **Separation of Concerns** – Core = immutable physics; Dynamic = product logic; Unknown = tenant innovation.
- **Southern‑African Optimisations** – Multi‑currency (ZAR, USD, ZIG, EUR), offline‑first mobile sync, POPIA data residency, RBZ/SARB regulatory reporting, Islamic finance, and rural network resilience.

---

## 2. System Architecture

The architecture is layered, with each layer having a distinct role and strict boundaries.

```
FinOS Operating System
├─ Core Kernel (19 Primitives)          ← Immutable, never changes
│   ├── Identity & Tenancy
│   ├── Value Containers & Movements
│   ├── Economic Agents & Relationships
│   ├── Temporal Transitions (4D)
│   ├── Immutable Event Store
│   ├── Chart of Accounts, Settlement, Sub‑ledger
│   └── Capital & Liquidity Tracking
├─ Dynamic Layer                        ← Product‑as‑code, configuration
│   ├── Product Catalog & Versions
│   ├── Interest & Fee Engines
│   ├── Workflows & State Machines
│   ├── Accounting Rules & GL Mapping
│   ├── Reconciliation Rules
│   └── Hooks & Scheduled Jobs
└─ Unknown Layer                        ← Tenant innovation & extensions
    ├── Custom Tables & Fields
    ├── Custom Scripts & Hooks
    ├── KYC Workflows & Integrations
    └── Tenant‑specific Dashboards & Reports
```

All interaction between layers is through **APIs and events** – the Dynamic Layer never directly modifies Core tables; it only reads from them and posts new value movements or events. The Unknown Layer extends the system without altering Core or Dynamic schemas.

---

## 3. Core Kernel – The 19 Immutable Primitives

The Core Kernel consists of 19 tables (primitives) that form the complete financial foundation. Every table is **immutable**, **bitemporal**, and **partitioned by tenant**.

| # | Primitive | Core Purpose | File |
|---|-----------|--------------|------|
| 1 | **Identity & Tenancy** | Tenants, entities, LEI, BIC | `001_identity_and_tenancy.sql` |
| 2 | **Value Container** | Universal account (asset, liability, equity, income, expense) | `002_value_container.sql` |
| 3 | **Value Movement & Double‑Entry** | Balanced journal entries, 9 movement types | `003_value_movement_and_double_entry.sql` |
| 4 | **Economic Agent & Relationships** | Parties, KYC, ownership, guarantees | `004_economic_agent_and_relationships.sql` |
| 5 | **Temporal Transition (4D Time)** | Bitemporal state tracking | `005_temporal_transition_4d.sql` |
| 6 | **Immutable Event Store** | Append‑only cryptographic log, hash chain | `006_immutable_event_store.sql` |
| 7 | **Chart of Accounts** | Hierarchical GL structure, multi‑GAAP | `007_chart_of_accounts.sql` |
| 8 | **Monetary System & Valuation** | Currencies, exchange rates, price history | `008_monetary_system_and_valuation.sql` |
| 9 | **Settlement & Finality** | Provisional → final lifecycle, DvP, netting | `009_settlement_and_finality.sql` |
| 10 | **Reconciliation & Suspense** | Internal/external matching, suspense management | `010_reconciliation_and_suspense.sql` |
| 11 | **Control & Batch Processing** | Control totals, hash totals, EOD processing | `011_control_and_batch_processing.sql` |
| 12 | **Entitlements & Authorization** | Permissions, 4‑eyes, digital signatures | `012_entitlements_and_authorization.sql` |
| 13 | **Geography & Jurisdiction** | Addresses, FATF status, timezones | `013_geography_and_jurisdiction.sql` |
| 14 | **Provisioning & Reserves** | IFRS 9 expected credit loss, staging | `014_provisioning_and_reserves.sql` |
| 15 | **Document & Evidence References** | Contracts, KYC docs, hashes, retention | `015_document_and_evidence_references.sql` |
| 16 | **Sub‑ledger & Segregation** | Client‑money rules, master/sub‑accounts | `016_sub_ledger_and_segregation.sql` |
| 17 | **Legal Entity Hierarchy & Group Consolidation** | LEI, ownership trees, IFRS 10 consolidation | `017_legal_entity_hierarchy_and_group_consolidation.sql` |
| 18 | **Capital & Liquidity Position Tracking** | RWA, LCR, NSFR, Basel III/IV ratios | `018_capital_and_liquidity_position_tracking.sql` |
| 19 | **Kernel Wiring** | RLS, triggers, indexes, partitioning, health checks | `019_kernel_wiring.sql` |

All tables share **universal columns**:
- `id` UUID, `tenant_id` UUID, `valid_from`, `valid_to`, `system_time`
- `created_at`, `updated_at`, `version`, `immutable_hash`
- `is_deleted`, `correlation_id`, `causation_id`

**Key Technical Features**
- **Partitioning**: Tables are LIST‑partitioned by `tenant_id`; time‑based sub‑partitioning for high‑volume tables.
- **TimescaleDB**: Used for time‑series data (`immutable_events`, `container_balances`, etc.) with automatic chunking and compression.
- **Cryptographic Hashing**: Every row has an `immutable_hash`; events form a chain with `previous_hash` and `event_hash`.
- **RLS**: Row‑Level Security automatically applied to all tables via `core.generate_rls_policies()`.
- **Hard‑Delete Prevention**: Triggers prevent deletion; only soft‑delete via `is_deleted` flag.

---

## 4. Dynamic Layer – Product-as-Code

The Dynamic Layer is the **configurable, business‑logic layer**. It contains all product definitions, pricing rules, workflows, and accounting rules. It is stored in the `dynamic` schema and is **versioned** and **tenant‑isolated**.

### 4.1 Core Dynamic Tables

| Table | Purpose |
|-------|---------|
| `product_catalogue` | Master list of product types (savings, loans, insurance, etc.) |
| `product_versions` | Bitemporal versioning of product terms (JSONB) |
| `product_parameters` | Structured key‑value parameters for a product version |
| `product_eligibility_rules` | Rules for customer eligibility (age, residency, credit score) |
| `product_limits` | Product‑level limits (min/max balance, transaction caps) |
| `interest_methods` | Reusable interest calculation definitions (simple, compound, etc.) |
| `interest_rate_schedules` | Tiered or time‑based interest rates |
| `fee_templates` | Flat, percentage, or tiered fee definitions |
| `fee_triggers` | Mapping of events (e.g., monthly cycle) to fees |
| `workflow_definitions` | State machine definitions for processes (loan origination, KYC) |
| `workflow_instances` | Running instances per entity |
| `tasks` | Manual tasks assigned to users/roles |
| `accounting_rules` | Maps product events to GL accounts (debit/credit) |
| `tax_rules` | Tax calculation rules per jurisdiction and transaction type |
| `reconciliation_rules` | Auto‑matching rules for reconciliation |
| `product_hooks` | Scripts executed on core events (e.g., movement posted) |
| `scheduled_rules` | Time‑based triggers (daily accrual, monthly fee) |

### 4.2 Product Management

Tenants can **create, version, and retire products** entirely through APIs or the admin dashboard. For example, a bank creates a “Premium Savings” product with:

- Interest rate 3.5% (tiered)
- Monthly fee R25, waived if balance > R20,000
- Minimum opening balance R5,000
- Eligibility: age ≥ 18, resident of South Africa

All this is stored in `dynamic.product_versions` as JSONB, with separate entries for parameters, limits, and eligibility rules.

### 4.3 Workflow & Hooks

The Dynamic Layer includes a **workflow engine** that can define state machines for any business process (e.g., loan application, account opening, dispute handling). Workflows can include **automatic tasks**, **approval steps**, and **external service calls**.

Hooks (inspired by Thought Machine Vault) allow tenants to execute custom logic on core events. For example:

- **On movement posted**: Check fraud rules, update a risk score, or call an external webhook.
- **On container opened**: Generate a welcome email, create a sub‑ledger entry.

Hooks can be written in a safe scripting language (JavaScript, Lua) and are sandboxed.

### 4.4 Accounting Rules

The Dynamic Layer’s `accounting_rules` table maps product events to the Core’s chart of accounts. For instance:

| Event | Debit Account | Credit Account |
|-------|---------------|----------------|
| Loan disbursement | 1112 (Bank) | 2120 (Loan receivable) |
| Interest accrual | 5110 (Interest expense) | 3200 (Interest payable) |

These rules are applied when the product logic creates a value movement, ensuring consistent GL postings.

---

## 5. Unknown Layer – Tenant Innovation

The Unknown Layer is where tenants can **extend the system** without modifying Core or Dynamic schemas. It is stored in tenant‑isolated schemas (e.g., `unknown_tenant_<uuid>`).

### 5.1 Custom Tables & Fields

Tenants can create any number of custom tables to store data not covered by the Core or Dynamic layers. For example:

- `customer_loyalty_points` – track loyalty program balances.
- `carbon_credit_transactions` – record carbon credit transfers.
- `agent_notes` – store internal notes on customers.

Additionally, tenants can attach **custom fields** to core entities using the `custom_attributes` table (provided in the Dynamic Layer) or create their own. This allows them to store tenant‑specific data without altering core tables.

### 5.2 KYC Workflows & Integrations

While the Core stores KYC documents (`core.documents`) and basic status (`economic_agents.kyc_status`), the Unknown Layer implements the **actual KYC process**. Tenants can:

- Define their own KYC verification steps.
- Integrate with third‑party KYC providers (Jumio, Onfido, etc.) via webhooks.
- Store verification results in custom tables.
- Enforce re‑verification schedules using scheduled rules.

For example, a tenant can create a custom table `kyc_attempts` with fields `attempt_id`, `provider_response`, `score`, and then use a hook to update `core.economic_agents.kyc_status` when verification passes.

### 5.3 Custom Scripts & Hooks

The Unknown Layer allows tenants to **upload scripts** that run in a sandboxed environment. These scripts can:

- Implement proprietary algorithms (e.g., Shariah‑compliant profit sharing).
- Calculate custom fees or interest based on external data.
- Call external APIs (credit bureaus, payment gateways) and use the results.

Scripts are versioned and can be assigned to product hooks or scheduled rules.

### 5.4 Tenant‑Specific Dashboards & Reports

The platform includes a set of pre‑built dashboards (admin, operations, compliance, customer portal) that tenants can **customise or replace**. Using the Unknown Layer, tenants can:

- Add new widgets to existing dashboards.
- Create entirely new dashboard pages (using HTML/JS) that call FinOS APIs.
- Define custom report templates (SQL) and schedule them.

---

## 6. Accounting & Financial Control

FinOS implements a complete, immutable accounting system that meets IFRS, US GAAP, and Basel III/IV requirements.

### 6.1 Double‑Entry Ledger

All financial events are recorded as **value movements** (`core.value_movements`) with **legs** (`core.movement_legs`). Conservation is enforced at the database level: `total_debits = total_credits`. Balances are derived from posted movements, never stored directly (except for materialised views).

### 6.2 Chart of Accounts & Sub‑ledgers

- **Primitive 7** provides a hierarchical chart of accounts with support for multiple GAAPs via `account_mappings`.
- **Primitive 17** provides sub‑ledger segregation (client money, trust accounts) with master accounts and sub‑accounts. Triggers ensure that the sum of sub‑accounts equals the master balance.

### 6.3 Reconciliation & Suspense

**Primitive 10** handles reconciliation:
- `reconciliation_runs` – a reconciliation session (e.g., bank statement import).
- `reconciliation_items` – individual internal/external lines.
- `suspense_items` – unmatched items awaiting resolution.
- `reconciliation_rules` – auto‑matching rules (exact, tolerance, fuzzy).

Reconciliation is fully automated using configurable rules, with manual intervention available via the operations dashboard.

### 6.4 IFRS 9 Provisions

**Primitive 15** implements expected credit loss (ECL) with staging (1, 2, 3). Provisions are stored per container, with PD, LGD, and forward‑looking scenarios. The system can automatically re‑stage based on days past due or credit rating changes.

### 6.5 Consolidation & Intercompany Eliminations

**Primitive 18** provides legal entity hierarchy and group consolidation. Ownership trees and control percentages are stored, and the system can produce consolidated financial statements with automatic elimination of intercompany transactions.

### 6.6 Capital & Liquidity (Basel III/IV)

**Primitive 19** tracks:
- Risk‑weighted assets (RWA) by asset class.
- Capital positions (CET1, Tier 1, total capital) and ratios.
- Liquidity Coverage Ratio (LCR) and Net Stable Funding Ratio (NSFR).
- Stress scenarios and reverse stress tests.

All ratios are computed and stored, with compliance flags.

---

## 7. Scalability & Performance

FinOS is designed to handle **trillions of records** over years.

### 7.1 Partitioning & TimescaleDB

- **LIST partitioning** by `tenant_id` ensures each tenant’s data is physically separate.
- **RANGE sub‑partitioning** by time (e.g., `event_time`) on high‑volume tables like `immutable_events` and `value_movements`.
- **TimescaleDB hypertables** for time‑series data (`immutable_events`, `container_balances`, etc.) with automatic chunking and compression.
- **pg_partman** integration for automated partition management (create new partitions, drop old ones).

### 7.2 Indexing

- Partial indexes on active records (`WHERE is_deleted = false`).
- Composite indexes on `(tenant_id, valid_from, valid_to)` for bitemporal queries.
- GIN indexes on JSONB columns (`metadata`, `attributes`).
- BRIN indexes on large, naturally ordered columns (e.g., `event_time`).

### 7.3 Read Scaling

- **Logical replication** publishes core tables to read‑only replicas for reporting and analytics.
- **Materialised views** (e.g., `gl_snapshot`, `current_exchange_rates`) are refreshed concurrently on replicas.
- **Event streaming** via `immutable_events` can feed Kafka or a data warehouse.

### 7.4 Write Optimisation

The event store is **append‑only**, avoiding lock contention. Transactions are serialised by a lightweight coordinator, and all writes are simple inserts. The core also supports **bulk inserts** via `COPY` for large‑scale data migration.

### 7.5 Tiered Storage

- **Hot tier**: Active partitions (last 3 months) on NVMe.
- **Warm tier**: Older partitions on cheaper SSD.
- **Cold tier**: Archived to S3‑compatible object storage with pointers retained.

---

## 8. Blockchain & Smart Contract Integration

FinOS can be extended to interact with blockchain networks while maintaining the core’s immutability.

### 8.1 Anchoring (Proof of Integrity)

The core already stores a hash chain of events. A background job computes a daily Merkle root for each tenant and can **anchor** it to a public blockchain (Bitcoin, Ethereum). This creates a tamper‑proof external timestamp. Auditors can verify that the ledger hasn’t been altered since the anchor date.

### 8.2 Smart Contract‑Driven Movements

Smart contracts can act as **automated decision‑makers** for certain movements. A bridge service listens to smart contract events and, upon confirmation, creates a `value_movement` in FinOS. The movement’s `context` includes the blockchain transaction hash, linking on‑chain and off‑chain records.

### 8.3 Tokenisation of Assets

Value containers can represent **tokenised real‑world assets**. Each container can store:
- `blockchain_network` (e.g., Ethereum)
- `token_contract_address`
- `token_id` (for NFTs)

When a movement affects the container, a corresponding smart contract call is triggered (via bridge) to mint/burn tokens, ensuring on‑chain representation matches the core ledger.

### 8.4 Programmable Compliance

Sanctions lists, KYC rules, or transaction limits can be enforced by smart contracts. Before posting a movement, FinOS can call a smart contract that returns whether the transaction is allowed, based on the counterparty’s address and the current state.

---

## 9. Deployment & Delivery Models

FinOS can be deployed in two primary ways:

### 9.1 Cloud SaaS

- Managed by the FinOS operator.
- Tenants access the system via **APIs and web dashboards**.
- Infrastructure, scaling, security, and backups are handled automatically.
- Multi‑tenancy is built into the core.

### 9.2 On‑Premise / Private Cloud

- The FinOS software is deployed inside a tenant’s own environment (AWS, Azure, on‑prem).
- The tenant manages the database, application servers, and network.
- Full control over data residency and custom integrations.

### 9.3 API & Dashboard Availability

- **REST, GraphQL, and gRPC APIs** cover all core, dynamic, and administrative functions.
- **Pre‑built dashboards** include:
    - Tenant Admin Dashboard
    - Operations Dashboard (customer support, reconciliation)
    - Compliance Dashboard (KYC, sanctions, regulatory reports)
    - Customer Portal
- All dashboards are fully customisable via the Unknown Layer.

---

## 10. Security & Compliance

### 10.1 Multi‑Tenancy & Isolation

- **Data**: All tables partitioned by `tenant_id`. RLS ensures that even a compromised connection cannot access other tenants’ data.
- **API**: API keys and OAuth2 tokens are scoped to a tenant.
- **Administration**: Separate roles (`finos_app`, `finos_readonly`, `finos_admin`, `finos_replication`) with granular permissions.

### 10.2 Encryption

- **At rest**: PostgreSQL encryption at the storage level.
- **In transit**: TLS for all connections.
- **Column‑level encryption**: Sensitive fields (`tax_id_encrypted`, `config_encrypted`) are encrypted with `pgcrypto` (AES‑256).

### 10.3 PII & GDPR Compliance

- **PII registry** (`core.pii_registry`) tracks all personally identifiable information fields.
- **Data masking** functions (`core.mask_pii`, `core.mask_email`) are available for non‑production environments.
- **Retention policies** can be defined per document type and jurisdiction; automatic deletion via scheduled jobs.

### 10.4 Audit Trail

- **`core_audit.audit_log`** captures all changes to core tables (INSERT, UPDATE, DELETE).
- **Event store** provides a complete, immutable history of all financial events.
- **Transaction entities** record who initiated each change and why.

### 10.5 Regulatory Compliance

FinOS is built to satisfy:
- **South Africa**: SARB BA 700, POPIA, FSCA
- **Zimbabwe**: RBZ capital adequacy & liquidity returns
- **International**: IFRS 9/10/13, Basel III/IV, FATF, ISO 20022
- **Islamic finance**: Shariah‑compliant flags, profit‑sharing rules

All reports (regulatory returns, financial statements) are generated by replaying the immutable event store.

---

## 11. Getting Started

### 11.1 Installation

1. **Prerequisites**:
    - PostgreSQL 16+ with extensions: `uuid-ossp`, `pgcrypto`, `ltree`, `timescaledb`, `pg_partman` (optional)
    - A Linux server (or cloud instance) with adequate CPU and memory.

2. **Deploy the Core Kernel**:
    - Execute the SQL files in order: `000_extensions.sql` → `001_identity_and_tenancy.sql` → ... → `019_kernel_wiring.sql`.
    - All schemas and tables will be created.

3. **Deploy the Dynamic Layer**:
    - Execute the dynamic layer scripts (e.g., `100_product_catalog.sql`, `101_interest_engines.sql`, etc.) – these create the dynamic schema and seed initial data.

4. **Configure a Tenant**:
    - Insert a row into `core.tenants`.
    - Run `core.create_tenant_partitions(tenant_id)` to create tenant‑specific partitions.
    - Set up the tenant’s admin user and API keys.

5. **Start the Application Servers**:
    - The reference dashboard and API gateway are provided as separate components (Node.js, Java, or Go). They connect to the database using the `finos_app` role.

### 11.2 First Steps for a Tenant

1. **Log in to the Admin Dashboard**.
2. **Create a product** using the product wizard.
3. **Set up accounting rules** for the product (GL mapping).
4. **Create a customer** (economic agent) and open an account.
5. **Post a transaction** (e.g., deposit) via the API or dashboard.
6. **View the reconciliation** dashboard to match transactions.

### 11.3 Extending with Unknown Layer

- **Add custom tables** in the tenant’s unknown schema.
- **Upload custom scripts** (JavaScript) via the API to define new hooks.
- **Configure KYC workflows** using the workflow editor.
- **Build custom dashboards** using the provided front‑end framework.

---

## 12. Conclusion

FinOS is a complete, production‑ready financial operating system that combines the **immutability and auditability of a cryptographic ledger** with the **flexibility of a configurable product‑as‑code platform**. Its three‑layer architecture (Core, Dynamic, Unknown) ensures that the fundamental financial record remains unchanged while allowing unlimited innovation on top.

Designed specifically for southern African realities (multi‑currency, offline‑first, local regulations), FinOS can power any financial service – from a micro‑lender to a national payment system. Its use of PostgreSQL, TimescaleDB, and modern scalability patterns allows it to handle trillions of records over decades.

With built‑in support for blockchain anchoring, smart contract integration, and full regulatory compliance, FinOS is not only a system for today but a foundation for the next decade of fintech innovation.

---

**For further information**, please refer to the individual schema documentation, API reference, and the developer guide. The source code and detailed examples are available in the FinOS repository.