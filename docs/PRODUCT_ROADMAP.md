# TFGen — Production-Grade Product Roadmap
### Principal PM · Terraform/AWS Solutions Architect · UX Lead Review
**Date:** May 2026 | **Baseline codebase audit included**

---

## EXECUTIVE SUMMARY

TFGen today is a functionally sound, three-panel visual HCL generator. The backend ships JWT auth, rate limiting, PostgreSQL persistence, plugin-cached `terraform fmt/validate/plan`, and split-file (main.tf / variables.tf / outputs.tf) export. The frontend has 34 AWS services across 9 categories, dependency auto-wiring, module mode, dark/light theme, and project versioning. The schema is well-structured (users → projects → resources → project_versions → validation_logs).

**The gap between "working prototype" and "production-grade DevOps toolchain" falls into six hard problems:**

1. **No visual resource graph** — resources are tabs, not an interactive canvas. DevOps teams expect a topology view they can drag, connect, and reason about spatially.
2. **Code generation is string-template based** — scaling to 50+ services with conditional blocks, `count`, `for_each`, dynamic blocks, and locals requires an AST/IR layer, not regex substitution.
3. **`terraform plan/apply` runs unsandboxed on the host** — this is a critical security risk at scale; needs ephemeral container isolation per execution.
4. **No policy enforcement** — there is zero guardrail between a user generating an `0.0.0.0/0` ingress rule and it being applied to production.
5. **No collaboration surface** — projects are single-owner with no review, comment, or approval workflow; enterprises cannot adopt without it.
6. **No cost or drift visibility** — teams cannot reason about spend impact of changes before they apply.

The roadmap below structures work into three phases, with a Jira-ready backlog and a target architecture that solves all six problems without requiring a full rewrite of what already works.

---

## PART 1 — FEATURE CHECKLIST

Legend: **P** = Priority (Must / Should / Could) | **C** = Complexity (S / M / L) | **D** = Depends on

---

### 1. CORE BUILDER (UX)

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| B-01 | **Visual resource canvas (drag-drop topology)** | DevOps teams think in topology, not tabs. A canvas with nodes and edges makes dependency relationships obvious and prevents misconfiguration. Industry standard: draw.io, Brainboard, Pulumi Visualizer. | Must | L | B-02 |
| B-02 | **Resource graph data model (nodes + edges)** | The current flat `resources[]` array cannot represent directed dependencies (VPC→Subnet→EC2). A graph model is the prerequisite for canvas, diagram export, drift detection, and dependency validation. | Must | M | — |
| B-03 | **Smart connection drawing (auto-wire on canvas)** | When a user draws an edge from EC2 to a Subnet node, the form auto-fills `subnet_id`. Extends existing `dependencyWiring.js` logic to canvas interactions. | Must | M | B-01, B-02 |
| B-04 | **Resource search + filter on canvas** | Large projects (30+ resources) need name/type search and category filter to navigate the canvas without confusion. | Should | S | B-01 |
| B-05 | **Resource groups / layers** | Logical grouping (e.g., "Networking Tier", "App Tier") mapped to Terraform `locals` tags. Visually collapses related nodes. | Should | M | B-01 |
| B-06 | **Undo / redo stack (Ctrl+Z)** | Any visual editor without undo loses user trust immediately. Must be a first-class feature from the moment canvas ships. | Must | M | B-01 |
| B-07 | **Inline HCL editor per resource** | Power users want to override generated HCL for a single resource without leaving the form. Monaco editor embed in the config panel. | Should | M | — |
| B-08 | **Keyboard shortcuts** | Tab navigation between resources, Ctrl+S save, Ctrl+Enter validate. Critical for productivity in daily use. | Should | S | — |
| B-09 | **Minimap for large canvases** | When projects exceed ~20 nodes, a minimap navigation overlay (bottom-right corner) is essential for orientation. | Could | S | B-01 |
| B-10 | **Project templates / starter kits** | "3-tier web app", "serverless API", "EKS cluster" one-click starters that pre-populate resources and wiring. Reduces time-to-first-HCL from 10 min to 30 sec. | Must | M | B-02 |
| B-11 | **Dark/light theme** *(already exists — verify completeness)* | Confirmed present in `ThemeContext.jsx`. Verify all new components honour theme tokens. | Must | S | — |
| B-12 | **Responsive / mobile read-only view** | Stakeholders review projects on phones. Builder stays desktop-only; read-only code + diagram view on mobile. | Could | M | — |
| B-13 | **Onboarding walkthrough (Shepherd.js / Intro.js)** | First-run guided tour for new users. Increases activation rate. Dismissible and re-playable. | Should | S | — |
| B-14 | **Resource notes / annotations** | Sticky-note annotations on canvas nodes. Maps to a `description` comment block in generated HCL. | Could | S | B-01 |

---

### 2. TERRAFORM / IaC (Code Generation, Structure, Variables, Outputs, Modules)

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| T-01 | **AST / IR-based code generator** | Current string-template approach breaks with dynamic blocks (`dynamic "ingress" {}`), `count`, `for_each`, `lifecycle`, conditional expressions. An intermediate representation (JS object tree → HCL serializer) enables all of these without regex hacks. | Must | L | — |
| T-02 | **`count` and `for_each` support** | Required to express "3 subnets across AZs" or "N security group rules" idiomatically. Without it, users manually duplicate resources. | Must | M | T-01 |
| T-03 | **`locals` block generation** | Consolidates repeated values (env prefix, CIDR maps, common tags). Already a best-practice; currently absent from generated code. | Must | S | T-01 |
| T-04 | **`lifecycle` block UI** | `prevent_destroy`, `ignore_changes`, `create_before_destroy` checkboxes in the config panel. Prevents costly incidents on stateful resources (RDS, EFS). | Must | S | T-01 |
| T-05 | **Dynamic block generation** | Security groups, ingress/egress rules, EBS volumes on EC2 — all benefit from `dynamic` blocks when rule count is variable. | Should | M | T-01 |
| T-06 | **`data` source generation** | Auto-generate `data "aws_ami"`, `data "aws_availability_zones"`, `data "aws_caller_identity"` alongside resources. Currently absent; causes plan failures. | Must | M | T-01 |
| T-07 | **Variables editor with type validation** | Visual form to declare `variable` blocks (type, default, description, validation block). Validates `regex` patterns before code emission. | Must | M | — |
| T-08 | **Outputs editor** | Visual form for `output` blocks with sensitive flag support. Currently partially present in schema but not fully surfaced in UI. | Must | S | — |
| T-09 | **`moved` block generator** | When a resource is renamed on canvas, emit a `moved {}` block to avoid destroy/recreate in plan. Unique differentiator. | Should | M | T-01 |
| T-10 | **`import` block generator (TF 1.5+)** | Generate `import {}` blocks for resources discovered via reverse-IaC scan (see I-01). Allows adopting TFGen for existing infra. | Must | M | I-01 |
| T-11 | **Module composer (multi-module projects)** | Split a project into multiple child modules (e.g., `modules/networking/`, `modules/compute/`). Generate `module "x" { source = "./modules/x" }` wiring. | Should | L | T-01 |
| T-12 | **Terraform Registry module search** | Inline search of registry.terraform.io for community modules. User picks a module, TFGen auto-generates the `module {}` block with required inputs populated from the form. Currently only supports pre-defined MOD-badged services. | Should | M | — |
| T-13 | **Provider version constraint manager** | UI to pin/update `required_providers` version constraints. Displays changelog warnings for breaking version jumps. | Should | M | — |
| T-14 | **Multi-region / multi-account support** | Generate aliased providers (`provider "aws" { alias = "us_east" }`) and cross-account `assume_role` blocks for enterprise topologies. | Should | M | T-01 |
| T-15 | **Terraform workspace support** | Integrate `terraform.workspace` variable into generated code; allow workspace-scoped variable override files. | Could | M | — |
| T-16 | **`check` block generator (TF 1.5+)** | Generate assertion `check {}` blocks for post-deployment validation (e.g., HTTP health checks). Cutting-edge differentiator. | Could | M | T-01 |

---

### 3. EXECUTION (Plan / Apply / State / Backends)

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| E-01 | **Sandboxed execution engine (Docker per-run)** | Current `runner.js` spawns `exec()` directly on the host — a critical security risk. Each plan/apply must run in an ephemeral, network-isolated Docker container with no AWS credentials mounted by default. | Must | L | E-02 |
| E-02 | **Execution job queue (BullMQ + Redis)** | Terraform plan/apply can take 1–15 minutes. A job queue with WebSocket status streaming eliminates HTTP timeouts and gives live log tailing in the UI. | Must | L | — |
| E-03 | **Live log streaming to UI** | Stream `terraform plan` stdout/stderr line-by-line to the browser via WebSocket or SSE. Non-negotiable UX for any ops tooling. | Must | M | E-02 |
| E-04 | **Plan result parser + visual diff** | Parse `terraform plan -json` output into a structured add/change/destroy summary. Display as colour-coded resource diff table. | Must | M | E-02 |
| E-05 | **Apply execution (with approval gate)** | `terraform apply` behind a required human approval step (see COL-04). Only available to users with `deployer` role. Never auto-applies. | Should | L | E-01, COL-04, SEC-02 |
| E-06 | **Remote backend configuration UI** | Visual form for S3 + DynamoDB backend, Terraform Cloud, GitLab-managed state. Generates `terraform { backend "s3" {} }` block. Currently schema-supported but not surfaced. | Must | M | — |
| E-07 | **State viewer** | Fetch and display `terraform.tfstate` (or remote state) in a read-only tree view. Show each resource's current attributes. | Should | M | E-06 |
| E-08 | **Drift detection** | Compare live AWS resource attributes (via AWS SDK) against the last-known state snapshot. Highlight drifted attributes in the canvas node. | Should | L | E-07, I-03 |
| E-09 | **Execution history with log archive** | Store plan/apply execution logs in the DB (gzip-compressed). Audit trail required for SOC 2 compliance. | Must | M | E-02 |
| E-10 | **Terraform version selector** | Allow per-project pinning of Terraform version. Backend pulls correct version binary via tfenv/tfswitch. Required for enterprise with legacy stacks. | Should | M | E-01 |
| E-11 | **`terraform destroy` (with multi-confirmation)** | Destroy operation behind 2-step confirmation dialog + RBAC check. Guarded, never the default action. | Could | M | E-05 |

---

### 4. SECURITY & GOVERNANCE

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| SEC-01 | **Checkov / tfsec inline scan** | Run Checkov (or tfsec) against generated HCL on every Save/Validate. Surface findings as inline annotations in the code panel and warnings on canvas nodes. Non-negotiable for security-conscious teams. | Must | M | — |
| SEC-02 | **RBAC: roles (viewer / editor / deployer / admin)** | Current schema has a `role` field but only `user`/`admin` are used. Production teams need `viewer` (read-only), `editor` (build), `deployer` (can trigger plan/apply), `admin` (manage users). | Must | M | — |
| SEC-03 | **Policy-as-code engine (OPA / Rego)** | Allow admins to upload custom Rego policies (e.g., "all S3 buckets must have versioning", "no public IPs in prod"). Policies evaluated before plan is allowed. | Should | L | SEC-01 |
| SEC-04 | **Secret injection guard** | Detect if a user types a literal secret (AWS key, password) into a config field. Block save, redirect to Secrets Manager / SSM parameter reference. | Must | M | — |
| SEC-05 | **Audit log (all mutations)** | Log every project save, plan run, apply, user management action with actor, timestamp, IP, and diff. Required for SOC 2 / ISO 27001. | Must | M | — |
| SEC-06 | **SSO / SAML / OIDC login** | Enterprise adoption requires integration with Okta, Azure AD, Google Workspace via OIDC. Current JWT-local auth is not enterprise-viable. | Should | L | — |
| SEC-07 | **Secrets Manager / SSM integration** | When a resource field requires a secret (RDS password, API key), render a "Reference Secret" picker that emits `data "aws_secretsmanager_secret_version"` or `data "aws_ssm_parameter"` HCL instead of a literal. | Must | M | T-06 |
| SEC-08 | **Network security rule linter** | Before emitting any Security Group or NACL resource, validate that no `0.0.0.0/0` ingress rule exists on privileged ports (22, 3389, 5432). Warn with override option. | Must | S | — |
| SEC-09 | **SBOM / dependency inventory** | For compliance, emit a software bill of materials for all providers, module sources, and their pinned versions alongside the exported zip. | Could | S | — |
| SEC-10 | **IP allowlisting for apply** | Restrict `apply` trigger to requests originating from a configured CIDR allowlist (corporate VPN range). | Could | S | E-05 |

---

### 5. COLLABORATION

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| COL-01 | **Project sharing (team workspace)** | Users must be able to share a project with teammates (view/edit roles). Currently projects are single-owner. | Must | M | SEC-02 |
| COL-02 | **Inline comments on resources** | Comment threads attached to a canvas node or a specific HCL line. Replaces Slack back-and-forth about "why does this SG have this rule". | Should | M | B-01 |
| COL-03 | **Change requests (PR-style review)** | Submit a project version for review. Reviewer sees a diff of HCL changes and can Approve / Request Changes / Reject. Required for regulated environments. | Should | L | COL-01 |
| COL-04 | **Apply approval gate** | `terraform apply` is blocked until the change request is approved by a designated approver. Approval record stored in DB with timestamp + approver ID. | Must | M | COL-03, E-05 |
| COL-05 | **Real-time presence (who is editing)** | Show avatar badges on canvas nodes being edited by teammates. Prevents overwrite conflicts. Uses operational transforms or cursor broadcasting over WebSocket. | Could | L | B-01 |
| COL-06 | **Notification centre** | In-app + email notifications for: review requested, approved, plan failed, drift detected, policy violation. | Should | M | COL-03, E-08 |
| COL-07 | **Version diff viewer** | Side-by-side HCL diff between any two saved `project_versions`. Already storing `full_hcl` in DB — needs a diff renderer (Monaco diff editor). | Must | M | — |
| COL-08 | **Project activity feed** | Chronological feed of all actions on a project (resource added, version saved, plan run, comment posted). Surfaces as a right-panel drawer. | Should | S | — |

---

### 6. COST & OPTIMIZATION

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| CST-01 | **Infracost integration (cost estimate per resource)** | Show estimated monthly cost per resource in the config panel and as a total project cost badge. Infracost CLI can be invoked server-side against the generated HCL. Changes DevOps from "I don't know what this costs" to "this change adds $47/month". | Must | M | — |
| CST-02 | **Cost delta on plan** | When a plan is run, show the cost delta (+ or -) alongside the resource diff table. "This change will add $312/month." | Must | M | CST-01, E-04 |
| CST-03 | **Right-sizing suggestions** | Analyse EC2/RDS instance types in config and suggest smaller alternatives if the environment is `dev` or `staging`. Lookup from a curated JSON size/price table. | Should | M | — |
| CST-04 | **Savings plan / reserved instance flagging** | Detect on-demand EC2 instances in production configurations and suggest Reserved Instance or Savings Plan alternatives with estimated savings. | Could | M | CST-01 |
| CST-05 | **Budget alert resource generator** | When a project is saved, optionally generate an `aws_budgets_budget` resource capped at the Infracost estimate + 20% buffer. | Should | S | CST-01 |
| CST-06 | **Cost history per project version** | Store Infracost estimate alongside each `project_version`. Chart cost trend over version history. | Could | M | CST-01 |

---

### 7. IMPORT / REVERSE IaC

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| I-01 | **AWS resource scanner (read-only)** | Using temporary AWS credentials (Assume Role / access keys), scan a target AWS account and enumerate existing resources by type. Prerequisite for all reverse-IaC features. | Must | L | — |
| I-02 | **`terraformer` / `tf-state-import` integration** | Invoke `terraformer import aws` inside a sandboxed container for selected resource types and import the resulting HCL + state into a new TFGen project. | Should | L | I-01, E-01 |
| I-03 | **Live state reconciliation** | After a manual `terraform import` or scan, keep a snapshot of current resource attributes for drift detection (E-08). | Should | M | I-01, E-07 |
| I-04 | **Visual import wizard** | Step-by-step UI: (1) Enter AWS credentials / role ARN, (2) select resource types to scan, (3) preview discovered resources on canvas, (4) confirm import into project. | Should | L | I-01, I-02 |
| I-05 | **ARN-to-resource resolver** | Paste an ARN and have TFGen identify the resource type, fetch its attributes via AWS SDK, and pre-fill a new resource form. | Could | M | I-01 |
| I-06 | **Bulk import from existing tfstate** | Upload an existing `terraform.tfstate` file and reconstruct the TFGen canvas from its resource graph. | Should | M | B-02 |

---

### 8. DOCUMENTATION & EXPORT

| # | Feature | Why It Matters | P | C | D |
|---|---------|----------------|---|---|---|
| DOC-01 | **Auto-generated README.md** | Generate a project README listing all resources, their purposes, estimated cost, and architecture notes. Uses resource labels + descriptions from canvas annotations. | Should | M | — |
| DOC-02 | **Architecture diagram export (SVG / PNG)** | Render the canvas topology as a clean SVG/PNG (not a screenshot). Uses the resource graph nodes/edges. The existing `docs/ui-preview.svg` is hand-crafted; this automates it. | Must | M | B-02 |
| DOC-03 | **Terraform docs integration (`terraform-docs`)** | Invoke `terraform-docs markdown` server-side on the exported module and include the output in the zip. | Should | S | — |
| DOC-04 | **CI/CD pipeline generator** | Generate a GitHub Actions / GitLab CI / Jenkins pipeline YAML that runs `terraform fmt`, `terraform validate`, Checkov scan, cost estimate, and optionally `terraform apply` on merge. | Must | M | SEC-01, CST-01 |
| DOC-05 | **Atlantis config generator** | Generate `atlantis.yaml` for teams using Atlantis as their Terraform PR automation tool. | Should | S | DOC-04 |
| DOC-06 | **Terraform Cloud / HCP integration** | Generate workspace config for Terraform Cloud (formerly TFC) and optionally push the project via TFC API. | Could | L | E-06 |
| DOC-07 | **Export formats: CDK for Terraform (CDKTF)** | Convert the TFGen project to CDKTF TypeScript output for teams migrating to code-first IaC. High-value differentiator. | Could | L | T-01 |
| DOC-08 | **In-app resource documentation** | Each resource node on canvas has a "?" icon that opens the official Terraform Registry docs for that resource type in a side panel. | Should | S | — |

---

## PART 2 — PHASED ROADMAP

### PHASE 1 — Production-Ready MVP (Weeks 1–4)

**Goal:** Make the existing codebase production-safe and complete the most critical missing foundations that block real team adoption.

| Sprint | Features | Outcome |
|--------|----------|---------|
| S1 (W1–W2) | B-02 (resource graph model), T-01 (AST codegen foundation), SEC-04 (secret injection guard), SEC-08 (SG linter), SEC-05 (audit log) | Secure, graph-aware data model; no literal secrets in code |
| S1 (W1–W2) | E-01 (sandboxed Docker runner), E-02 (BullMQ job queue), E-03 (live log streaming) | Execution is safe and non-blocking |
| S2 (W3–W4) | T-03 (locals), T-04 (lifecycle blocks), T-06 (data sources), T-07 (variables editor), T-08 (outputs editor) | Generated code is idiomatic and plan-safe |
| S2 (W3–W4) | SEC-01 (Checkov inline scan), SEC-02 (RBAC 4-tier), E-04 (plan diff UI), E-06 (remote backend UI) | Security baseline; teams can configure S3 backend |
| S2 (W3–W4) | COL-07 (version diff viewer), B-06 (undo/redo), B-08 (keyboard shortcuts), CST-01 (Infracost) | Core UX completeness + cost awareness |

**Phase 1 Exit Criteria:**
- All sandbox execution via Docker (zero host-exec risk)
- Checkov runs on every validate; results shown inline
- RBAC enforced on all API routes
- Infracost estimate shown in config panel
- Version diff viewer functional
- Zero known OWASP Top-10 vulnerabilities (pen-test sign-off)

---

### PHASE 2 — Advanced DevOps Platform (Months 1–2)

**Goal:** Add the visual canvas, collaboration surface, and CI/CD generation that make TFGen a daily driver for DevOps teams.

| Sprint | Features | Outcome |
|--------|----------|---------|
| S3 (M1 W1–2) | B-01 (visual canvas), B-03 (smart connection), B-04 (search/filter), B-09 (minimap) | Full interactive canvas ships |
| S3 | T-02 (`count`/`for_each`), T-05 (dynamic blocks), T-11 (module composer) | Complex real-world IaC patterns supported |
| S4 (M1 W3–4) | COL-01 (project sharing), COL-03 (change requests), COL-04 (apply approval), COL-06 (notifications) | Team workflows enabled |
| S4 | E-05 (apply execution), E-07 (state viewer), E-09 (execution history), E-10 (TF version selector) | Full plan→apply lifecycle |
| S5 (M2 W1–2) | SEC-03 (OPA policies), SEC-07 (Secrets Manager picker), SEC-06 (SSO/OIDC) | Enterprise security posture |
| S5 | DOC-01 (README gen), DOC-02 (diagram export), DOC-04 (CI/CD pipeline gen), DOC-08 (inline docs) | Export suite complete |
| S6 (M2 W3–4) | CST-02 (cost delta on plan), CST-03 (right-sizing), B-10 (starter kits), B-13 (onboarding tour) | Cost intelligence + activation UX |

**Phase 2 Exit Criteria:**
- Canvas ships with undo/redo, minimap, smart wiring
- Change request + apply approval workflow end-to-end
- OPA policy evaluation blocks non-compliant plans
- GitHub Actions pipeline YAML generated per project
- Infracost delta shown in plan diff

---

### PHASE 3 — Enterprise IaC Platform (Months 3–6)

**Goal:** Enterprise-grade features for large organisations: reverse-IaC, drift detection, real-time collaboration, CDKTF, and Terraform Cloud integration.

| Sprint | Features | Outcome |
|--------|----------|---------|
| S7–8 | I-01, I-02, I-03, I-04 (import wizard + terraformer) | Existing AWS infra can be imported into TFGen |
| S7–8 | E-08 (drift detection), I-06 (tfstate upload) | Continuous compliance awareness |
| S9–10 | COL-02 (inline comments), COL-05 (real-time presence), COL-08 (activity feed) | Full team collaboration surface |
| S9–10 | T-09 (`moved` blocks), T-10 (`import` blocks), T-14 (multi-region), T-15 (workspaces) | Advanced Terraform patterns |
| S11–12 | DOC-06 (TFC/HCP integration), DOC-07 (CDKTF export), SEC-09 (SBOM) | Enterprise integrations |
| S11–12 | CST-04 (RI flagging), CST-06 (cost history), B-05 (resource groups), B-14 (annotations) | Cost optimisation + canvas polish |

---

## PART 3 — JIRA-READY BACKLOG

### EPIC 1: Secure Execution Sandbox

**Business Value:** Eliminate the critical security risk of running `terraform` directly on the application host.

---

**Story E-01-S1: Containerised Terraform runner**
> As a platform engineer, I want each terraform operation to run in an ephemeral Docker container so that a malicious or malformed HCL file cannot affect the host system.

*Acceptance Criteria:*
- [ ] `runFmt`, `runValidate`, `runPlan` each spawn a `docker run --rm --network=none hashicorp/terraform:1.x` container with the HCL mounted as a read-only volume
- [ ] Container has no AWS credentials mounted (validate/fmt do not need real AWS)
- [ ] Container is destroyed after the operation completes or times out (30s for fmt/validate, 5m for plan)
- [ ] Host filesystem is not writable from within the container
- [ ] If Docker is unavailable, fallback to current `exec()` with a logged warning (dev mode only)
- [ ] Unit tests: injection attempt in HCL body does not escape container

*Edge Cases:*
- HCL with `${file("/etc/passwd")}` — sandbox must prevent host file access
- Container fails to start (Docker daemon down) — return structured error to UI, do not crash process
- Concurrent executions: 10 simultaneous plans must not exhaust container pool (implement max concurrency via BullMQ concurrency setting)

*NFR:* Container startup + plan must complete within 5 minutes for a 20-resource project (P95).

---

**Story E-02-S1: Async job queue with WebSocket streaming**
> As a developer, I want to see live terraform plan output streamed to my browser so that I don't stare at a loading spinner for 3 minutes.

*Acceptance Criteria:*
- [ ] BullMQ + Redis queue processes terraform jobs asynchronously
- [ ] Job ID returned immediately on POST /api/terraform/plan
- [ ] Frontend opens a WebSocket connection to `/ws/jobs/:jobId`
- [ ] Each stdout/stderr line is emitted as a WebSocket event within 500ms of being written
- [ ] Job states: `queued → running → succeeded | failed`
- [ ] On job completion, final structured result (add/change/destroy counts) is emitted
- [ ] Jobs older than 24h are purged from queue; logs archived to DB (gzip)

*Edge Cases:*
- Browser disconnect mid-stream: job continues; client can reconnect and replay from last offset
- Redis unavailable: graceful degradation to synchronous exec with 60s timeout
- Job queue depth > 20: return 503 with `Retry-After` header; show queue position in UI

*NFR:* 99th percentile job queue wait time < 10s under 50 concurrent users.

---

### EPIC 2: Checkov Security Scanning

---

**Story SEC-01-S1: Inline Checkov scan on validate**
> As a security engineer, I want every generated Terraform config to be scanned by Checkov before it can be applied so that policy violations are caught at authoring time.

*Acceptance Criteria:*
- [ ] On every `/api/terraform/validate` call, Checkov runs against the HCL (inside sandbox)
- [ ] Response includes `{ checkov: { passed: number, failed: number, findings: Finding[] } }`
- [ ] Each `Finding` has: `check_id`, `resource`, `severity` (CRITICAL/HIGH/MEDIUM/LOW), `message`, `guideline_url`
- [ ] UI renders findings as inline annotations in the CodePreview panel (red/orange underlines)
- [ ] CRITICAL findings block the "Plan" button (configurable per project by admin)
- [ ] Checkov version pinned in Docker image; updated via dependency update PR process

*Acceptance Criteria (edge cases):*
- [ ] Empty HCL returns zero findings, not an error
- [ ] If Checkov binary not in container image, validation still returns HCL validity result with a `checkovUnavailable: true` flag
- [ ] Suppression: resource-level suppression comments (`#checkov:skip=CKV_AWS_...`) are respected

*NFR:* Checkov scan must add < 8 seconds to validate operation (P95).

---

### EPIC 3: RBAC and Team Workspaces

---

**Story SEC-02-S1: Four-tier role system**
> As an admin, I want to assign team members one of four roles so that I can control who can view, build, deploy, or administer the platform.

*Acceptance Criteria:*
- [ ] `users.role` supports `viewer | editor | deployer | admin`
- [ ] `viewer`: can open projects (read-only canvas), view HCL, download exports; cannot save changes or trigger operations
- [ ] `editor`: all viewer permissions + can create/modify resources, save projects, run validate/fmt
- [ ] `deployer`: all editor permissions + can trigger `terraform plan` and `terraform apply` (when approved)
- [ ] `admin`: all deployer permissions + can manage users, templates, policies, and system settings
- [ ] All API routes updated with role middleware; 403 returned with descriptive message for insufficient role
- [ ] Role check is server-side; frontend role gating is UX only (buttons hidden/disabled) not security boundary

*Edge Cases:*
- Token with expired role claim: re-fetch role from DB on each request (or short-lived tokens with role embedded)
- User downgrades own role accidentally: require admin confirmation; prevent last admin from being downgraded

---

**Story COL-01-S1: Project sharing**
> As a project owner, I want to invite team members to my project so that we can collaborate on infrastructure design.

*Acceptance Criteria:*
- [ ] New DB table: `project_members (project_id, user_id, role, invited_at, accepted_at)`
- [ ] Owner can invite by email (existing user) or generate a shareable link (with expiry)
- [ ] Invitee accepts via in-app notification + email
- [ ] Project list page shows shared projects with an "Shared" badge
- [ ] Owner can remove members or change their role (within limits of own role)
- [ ] `GET /api/projects` returns all projects where caller is owner OR member

*Edge Cases:*
- Invite to non-existent email: queue pending invite; activated when user registers
- Sharing link used by already-member: idempotent (no duplicate row)
- Owner deletes project: all member records cascade-deleted; members notified

---

### EPIC 4: Infracost Cost Estimation

---

**Story CST-01-S1: Per-resource cost estimate in config panel**
> As a developer, I want to see the estimated monthly cost of each resource I configure so that I make cost-conscious decisions during design.

*Acceptance Criteria:*
- [ ] Infracost CLI invoked server-side against HCL; results returned as `{ resource_type, monthly_cost_usd }[]`
- [ ] Config panel displays "~$X.XX / month" badge next to the resource label
- [ ] Project total cost shown in the top action bar
- [ ] Cost data cached per HCL hash (Redis, 1h TTL) to avoid re-running Infracost on unchanged configs
- [ ] If Infracost unavailable, badge shows "Cost estimate unavailable" (non-blocking)

*Edge Cases:*
- Resources with variable cost (Lambda per-invocation): display "usage-based — configure usage estimates"
- Free-tier resources (e.g., small S3 bucket): display "$0.00 (within free tier)"
- Multi-region project: Infracost called with correct `--terraform-var-file` for region

---

### EPIC 5: Visual Resource Canvas

---

**Story B-01-S1: Interactive drag-drop canvas**
> As a DevOps engineer, I want to arrange AWS resources on a visual canvas so that I can understand and communicate the architecture topology.

*Acceptance Criteria:*
- [ ] Canvas renders each resource as a node (icon + label + cost badge)
- [ ] Nodes are draggable; positions persisted in `resources.position` as `{x, y}` JSON
- [ ] Edges drawn between connected resources (based on `dependencyWiring.js` relationships)
- [ ] Clicking a node opens the existing ConfigPanel (no regression)
- [ ] Right-clicking a node opens context menu: Edit, Delete, Add Note, View HCL
- [ ] Canvas supports zoom (10%–200%) and pan
- [ ] "Fit to screen" button centres and scales canvas to show all nodes
- [ ] Library: React Flow (MIT license, well-maintained, 20k+ stars)

*Edge Cases:*
- 0 resources: canvas shows empty state with "drag a service from the left panel" instruction
- 50+ resources: performance profiled; canvas must render at 60fps with node virtualization enabled
- Cyclic dependencies: detected and highlighted with a red edge + warning toast (Terraform does not support cycles)

*NFR:* Canvas must render initial layout of 30 nodes in < 300ms.

---

### EPIC 6: CI/CD Pipeline Generator

---

**Story DOC-04-S1: GitHub Actions pipeline generation**
> As a DevOps engineer, I want TFGen to generate a GitHub Actions workflow for my project so that I can automate Terraform validation and deployment through my existing CI/CD process.

*Acceptance Criteria:*
- [ ] "Export → GitHub Actions" menu item generates `.github/workflows/terraform.yml`
- [ ] Pipeline stages: checkout → setup-terraform → fmt-check → validate → Checkov scan → Infracost comment → (manual approval) → apply
- [ ] Workflow uses `aws-actions/configure-aws-credentials` with OIDC (not static keys)
- [ ] PR triggers run fmt/validate/checkov/cost; merge-to-main triggers apply
- [ ] Generated YAML included in the project zip export alongside HCL files
- [ ] Preview of generated YAML shown in UI before download

*Edge Cases:*
- Projects with multiple modules: workflow uses matrix strategy across module directories
- Apply stage only emitted if project has `deployer`-approved apply enabled

---

### NON-FUNCTIONAL REQUIREMENTS (Applies to All Epics)

| Category | Requirement |
|----------|-------------|
| **Performance** | API P95 response < 500ms for non-execution endpoints. Canvas renders 30 nodes < 300ms. |
| **Scalability** | Horizontal scaling: stateless API nodes behind ALB; Redis for shared queue/cache; PostgreSQL read replicas for project/template queries. |
| **Security** | OWASP Top 10 compliance. All user inputs sanitised server-side. No literal secrets in HCL persisted to DB. TLS 1.2+ enforced. JWT expiry ≤ 1h with refresh token. |
| **Availability** | 99.9% uptime SLA for production. Health check endpoint. Docker health checks on all containers. |
| **Observability** | Structured JSON logs (Winston, already present). OpenTelemetry traces for execution jobs. Prometheus metrics endpoint for execution queue depth, job duration, error rate. |
| **Accessibility** | WCAG 2.1 AA. Canvas keyboard navigable. ARIA labels on all interactive elements. |
| **Data Retention** | Execution logs: 90 days. Project versions: unlimited (soft-delete). Audit logs: 1 year minimum (compliance). |
| **Disaster Recovery** | PostgreSQL daily backups to S3. RTO < 4h. RPO < 24h. |
| **Compliance** | SOC 2 Type II readiness (audit log, access control, encryption at rest). |

---

## PART 4 — ARCHITECTURE

### 4.1 Frontend State Model — Resource Graph

**Current problem:** `resources` is a flat array with no edge/dependency representation.

**Proposed model:**

```typescript
// Resource Graph (replaces flat resources[])
interface ResourceGraph {
  nodes: ResourceNode[];
  edges: ResourceEdge[];
  layout: Record<string, { x: number; y: number }>;
}

interface ResourceNode {
  id: string;                     // uuid
  serviceType: string;            // "aws_vpc", "aws_instance", etc.
  label: string;                  // user-editable display name
  config: Record<string, unknown>; // form field values
  isModule: boolean;
  variables: VariableDef[];
  outputs: OutputDef[];
  annotations: string;            // free-text notes
  groupId?: string;               // for resource groups (Phase 2)
  costEstimate?: number;          // USD/month from Infracost
  securityFindings?: Finding[];   // from Checkov
  position: { x: number; y: number };
}

interface ResourceEdge {
  id: string;
  source: string;                 // node id
  target: string;                 // node id
  relationship: 'depends_on' | 'references' | 'contains';
  sourceField?: string;           // e.g. "subnet_id"
  targetAttribute?: string;       // e.g. "id"
}
```

**State management:** Zustand store (lightweight, no boilerplate) with slices:
- `graphSlice` — nodes + edges + layout
- `uiSlice` — selected node, panel state, active mode
- `projectSlice` — project metadata, region, backend config
- `executionSlice` — job queue status, plan results, log stream

**Undo/redo:** Zustand `temporal` middleware records graph mutations as inverse operations.

---

### 4.2 Code Generation Strategy — AST/IR Approach

**Current problem:** String templates with `{{placeholder}}` regex substitution cannot express conditional blocks, dynamic blocks, `count`, `for_each`, or `moved` blocks without becoming unmaintainable.

**Proposed: HCL IR (Intermediate Representation)**

```
ResourceGraph → IR Builder → HCL AST → HCL Serializer → .tf string
```

```javascript
// Example IR node
{
  type: 'resource',
  resourceType: 'aws_security_group',
  resourceName: 'web_sg',
  attributes: {
    name: { type: 'string_lit', value: 'web-sg' },
    vpc_id: { type: 'reference', expr: 'aws_vpc.main.id' },
    ingress: {
      type: 'dynamic_block',
      iterator: 'rule',
      content: {
        from_port: { type: 'reference', expr: 'rule.value.from_port' },
        to_port:   { type: 'reference', expr: 'rule.value.to_port' },
        protocol:  { type: 'reference', expr: 'rule.value.protocol' },
        cidr_blocks: { type: 'reference', expr: 'rule.value.cidr_blocks' },
      }
    },
    lifecycle: {
      prevent_destroy: { type: 'bool_lit', value: true }
    }
  }
}
```

The **HCL Serializer** walks the AST and emits properly indented HCL. It handles:
- Proper quoting (strings vs identifiers vs expressions)
- `heredoc` for multi-line values
- `jsonencode()` for inline JSON (IAM policies)
- `for_each` / `count` meta-arguments
- Block vs attribute distinction (Terraform's syntax distinguishes these)

**Migration path:** Existing `templateEngine.js` templates are parsed once at startup to seed the IR definitions. The template body becomes a fallback for any service not yet migrated to IR.

---

### 4.3 Safe Sandbox Execution Architecture

```
Browser → POST /api/terraform/plan
          ↓
       API Server
          ↓ enqueue job
       BullMQ Worker (Redis)
          ↓
       Docker Container Manager
          ┌──────────────────────────────────┐
          │  docker run --rm                 │
          │    --network none               │  ← no internet (validate/fmt)
          │    --memory 512m                │  ← resource cap
          │    --cpus 1.0                   │
          │    --read-only                  │
          │    -v /hcl-input:/workspace:ro  │
          │    hashicorp/terraform:1.x      │
          │    terraform plan -out=plan.bin │
          └──────────────────────────────────┘
          ↓ stdout/stderr stream via Docker API
       WebSocket → Browser (live log)
          ↓ on completion
       Parse plan JSON → store in DB → emit final result
```

**AWS credentials for `plan` (optional):** When the user opts into a "live plan" (with real AWS API calls), credentials are injected as environment variables into the container at runtime, never written to disk, and scoped to a read-only IAM role via `sts:AssumeRole`. The role ARN is configured per-project by admins.

**Security controls:**
- `--network none` by default (fmt/validate never need network)
- `--network tfgen-plan-net` (egress to AWS endpoints only, via iptables allowlist) for live plan
- Container runs as UID 1000 (non-root)
- `/workspace` mounted read-only; output written to a separate `/tmp` tmpfs
- `--pids-limit 50` to prevent fork bombs
- All Docker API calls go through a privileged sidecar service (not the API server itself); API server communicates over Unix socket

---

### 4.4 Storage & Versioning Strategy

**Database layers:**

```
PostgreSQL (primary relational store)
├── users, projects, project_members
├── resources (with position JSON, security findings)
├── templates (service definitions + IR schema)
├── project_versions (full_hcl, cost_estimate, checkov_summary)
├── execution_jobs (job_id, status, plan_summary, cost_delta)
├── audit_logs (actor, action, resource_id, before_json, after_json)
├── policy_rules (rego source, enabled, severity)
└── comments, change_requests, approvals

Redis (ephemeral / operational)
├── BullMQ job queues (execution jobs)
├── Infracost result cache (HCL hash → cost JSON, 1h TTL)
├── WebSocket session mapping (job_id → socket_id)
├── Rate limit counters
└── Session tokens (refresh token blocklist)

S3 / Object Storage
├── Execution log archives (gzip, 90-day lifecycle)
├── Plan binary outputs (.tfplan files, 7-day lifecycle)
├── Exported project zips (30-day lifecycle)
└── Checkov report HTML exports
```

**Versioning model:**

```
project_versions table:
- version_number: auto-incrementing per project
- full_hcl: complete main.tf content (for diff viewer)
- resource_graph_json: serialised ResourceGraph (for canvas replay)
- cost_estimate_usd: Infracost total at time of save
- checkov_passed / checkov_failed: scan summary
- saved_by: user_id
- change_summary: auto-generated description ("Added aws_rds_instance, modified aws_vpc CIDR")
```

**Diff strategy:** Monaco Editor's `createDiffEditor` renders `project_versions[n].full_hcl` vs `project_versions[n-1].full_hcl` with syntax highlighting. Server-side, `diff` library generates a structured patch for the change request review surface.

---

### 4.5 Dependency Graph & Wiring Engine

Extend the existing `dependencyWiring.js` with a formal dependency registry:

```javascript
// dependency-registry.js
export const DEPENDENCY_RULES = [
  {
    from: 'aws_subnet',   field: 'vpc_id',
    to: 'aws_vpc',        attribute: 'id',
    relationship: 'references',
    required: true,
  },
  {
    from: 'aws_instance', field: 'subnet_id',
    to: 'aws_subnet',     attribute: 'id',
    relationship: 'references',
    required: false,
  },
  // ... 80+ rules covering all 34 services
];
```

On canvas: when the user draws an edge from Node A to Node B, the engine looks up the matching `DEPENDENCY_RULE` and emits the correct HCL reference expression (`aws_vpc.main.id`). When a user types into a config field that has an associated `DEPENDENCY_RULE`, an autocomplete dropdown shows existing resources of the matching type.

---

### 4.6 API Surface (Additions to Current Routes)

```
/api/terraform/jobs          POST   → enqueue plan/apply job; returns jobId
/api/terraform/jobs/:id      GET    → job status + result
/ws/jobs/:id                 WS     → live log stream

/api/projects/:id/members    GET|POST|DELETE → team sharing
/api/projects/:id/versions   GET    → version history list
/api/projects/:id/versions/diff?a=N&b=M  GET → HCL diff

/api/change-requests         POST   → create review request
/api/change-requests/:id     GET|PUT → view/approve/reject

/api/scan/checkov            POST   → run Checkov (sync, < 8s)
/api/cost/estimate           POST   → run Infracost (cached)

/api/import/scan             POST   → AWS account scanner (async job)
/api/import/from-state       POST   → upload tfstate, returns ResourceGraph

/api/policies                GET|POST|PUT|DELETE → OPA policy management
/api/policies/evaluate       POST   → evaluate HCL against all active policies

/api/export/pipeline/:type   GET    → generate GitHub Actions / GitLab CI YAML
/api/export/readme           POST   → generate README.md
/api/export/diagram          POST   → generate SVG architecture diagram
```

---

### 4.7 Technology Additions (Minimal Footprint)

| New Dependency | Purpose | Replaces / Extends |
|---------------|---------|-------------------|
| **React Flow** (frontend) | Visual canvas with nodes, edges, zoom, minimap | Current tab-based resource list |
| **Zustand** (frontend) | Graph state management with temporal (undo/redo) | Current `useState` scattered across Builder.jsx |
| **Monaco Editor** (frontend) | Inline HCL editor per resource + diff viewer | Current read-only CodePreview |
| **BullMQ + Redis** (backend) | Async job queue for terraform operations | Current synchronous `exec()` calls |
| **Dockerode** (backend) | Node.js Docker API client for container management | Current `child_process.exec('terraform ...')` |
| **Checkov** (Docker image) | IaC security scanning | New |
| **Infracost** (Docker image) | Cost estimation | New |
| **OPA** (backend sidecar) | Policy evaluation engine | New |
| **ws** (backend) | WebSocket server for log streaming | New |
| **@hapi/joi** (backend) | Request validation schema | Current ad-hoc string checks |

All additions are open-source, MIT/Apache-2 licensed, and widely adopted in the Terraform/DevOps ecosystem.

---

## APPENDIX — QUICK WINS (Implementable in < 1 day each, no architecture changes)

These can be shipped immediately while Phase 1 planning proceeds:

| ID | Feature | File to Edit | Effort |
|----|---------|-------------|--------|
| QW-01 | Secret detection regex in `sanitize.js` — block AWS key patterns `AKIA[0-9A-Z]{16}` | `backend/utils/sanitize.js` | 2h |
| QW-02 | Network security rule linter in `/api/terraform/validate` — warn on `0.0.0.0/0` port 22/3389 | `backend/routes/terraform.js` | 3h |
| QW-03 | JWT expiry reduced to 1h + refresh token endpoint | `backend/middleware/auth.js`, `backend/routes/auth.js` | 4h |
| QW-04 | `lifecycle` checkbox (prevent_destroy) in ConfigPanel for stateful resource types | `frontend/src/components/ConfigPanel.jsx` | 3h |
| QW-05 | Monaco diff editor for version history (replace current plain text compare) | `frontend/src/pages/History.jsx` | 4h |
| QW-06 | `locals` block auto-generated from common values (env, project name, region) | `frontend/src/engine/templateEngine.js` | 3h |
| QW-07 | `data "aws_caller_identity"` auto-injected into every project's HCL | `frontend/src/engine/templateEngine.js` | 1h |
| QW-08 | Keyboard shortcut: Ctrl+S → Save, Ctrl+Enter → Validate | `frontend/src/pages/Builder.jsx` | 2h |
| QW-09 | `terraform-docs` invocation in zip export endpoint | `backend/routes/projects.js` | 3h |
| QW-10 | CORS `origin: '*'` hardened to require explicit `CORS_ORIGIN` in production | `backend/server.js` | 1h |

---

*End of TFGen Product Roadmap — v1.0*
*Maintained by: Product · Architecture · UX*
