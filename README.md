<p align="center">
  <img src="docs/screenshots/01-login.png" alt="TFGen — Terraform Studio" width="900"/>
</p>

<h1 align="center">TFGen v3 — Terraform AWS Studio</h1>

<p align="center">
  <strong>Infrastructure as Code, without the YAML headaches.</strong><br/>
  Design AWS infrastructure visually → get production-ready Terraform HCL in seconds.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-v3.0-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/Node.js-%E2%89%A518-green?style=flat-square"/>
  <img src="https://img.shields.io/badge/React-18-61DAFB?style=flat-square"/>
  <img src="https://img.shields.io/badge/Terraform-%E2%89%A51.5-7B42BC?style=flat-square"/>
  <img src="https://img.shields.io/badge/AWS-44%2B_Services-FF9900?style=flat-square"/>
  <img src="https://img.shields.io/badge/PostgreSQL-%E2%89%A513-336791?style=flat-square"/>
</p>

---

## 🤔 What Is TFGen?

TFGen is a **full-stack visual Terraform builder** for AWS. Instead of hand-writing `.tf` files from scratch, you drag AWS services onto a canvas, wire them together, fill in simple form fields, and TFGen generates clean, validated, production-ready Terraform HCL — instantly.

It is designed for three audiences:

| Audience | How TFGen Helps |
|---|---|
| **DevOps / SRE engineers** | Scaffold complex multi-resource infra in minutes, not hours. Export to CI/CD pipelines immediately. |
| **Cloud architects** | Visualize resource topology, validate architecture decisions, catch misconfigurations before `apply`. |
| **Learners & interview preppers** | Understand every Terraform block in plain English. Practice with guided labs. Answer interview questions in context. |

> **One sentence summary:** TFGen is the Figma of Terraform — design your AWS infrastructure visually, then export the code.

---

## ✨ What Can You Do With TFGen?

### 1. Build AWS Infrastructure Visually

Drag any of 44+ AWS services from the sidebar → drop them on the canvas → wire dependencies with a click. The graph view shows your entire architecture as an interactive topology diagram, so you can see how resources connect before writing a single line of code.

### 2. Generate Production-Ready Terraform HCL

Every resource you add is instantly translated into clean, formatted Terraform HCL (`.tf`). The code updates in real time as you configure resources. No template guessing — the output is the same code a senior DevOps engineer would write.

### 3. Validate, Lint & Scan Your Infrastructure

- **Validate** — runs `terraform validate` on your generated code
- **Lint** — checks for architecture best practices (e.g. "subnet is missing a NAT gateway", "EC2 has no security group")
- **Security scan** — Checkov integration flags misconfigurations (e.g. "S3 bucket is public", "RDS has no encryption")
- **Cost estimate** — Infracost integration shows monthly cost before you deploy

### 4. Export to CI/CD

Export your Terraform to a ZIP with GitHub Actions or GitLab CI pipeline files ready to go. One click and your infra is in version control.

### 5. Learn While You Build

Every resource has a **Learn tab** that explains what it does, why it exists, what each field means, and how it connects to other resources — all in plain English.

### 6. Practice for AWS Interviews

The **Labs & Interview** tab gives you 14+ context-aware interview questions that update based on the resources you've added to your project. Guided labs walk you through building real infrastructure step by step.

---

## 📸 Application Walkthrough

### The Builder — Code View
Real-time Terraform HCL generation as you configure resources. The code panel shows your `main.tf`, `variables.tf`, and `outputs.tf` — always in sync with your canvas.

<p align="center">
  <img src="docs/screenshots/02-code-editor.png" alt="TFGen Code Editor — Real-time HCL generation" width="900"/>
</p>

> **What you're seeing:** A VPC resource being configured in the left form panel. The right panel shows the generated `main.tf` file — provider block, locals, data sources, and the VPC resource — updating live. The bottom bar shows lint findings: 2 critical, 3 low. The top-right badge shows `3,528 bytes` of generated Terraform code across `179 lines`.

---

### The Builder — Graph View (Resource Topology)
A visual, interactive map of every resource and how they connect. Drag to reposition, click a node to jump to its config, and spot architecture issues at a glance.

<p align="center">
  <img src="docs/screenshots/03-graph-view.png" alt="TFGen Graph View — Resource Topology Diagram" width="900"/>
</p>

> **What you're seeing:** 8 resources (IGW → VPC → Subnet → EC2, ECR, SG, Route Table, Key Pair) laid out as a connected topology graph. The orange warning badge marks an architecture issue. Color coding distinguishes resource types. Public and private subnets are visually separated. Edges show Terraform `depends_on` relationships.

---

### The Learn Tab — Understand Every Resource
Click any field on any resource and get a plain-English explanation of what it does, why it matters, what happens after `terraform apply`, and which other resources it connects to.

<p align="center">
  <img src="docs/screenshots/04-learn-tab.png" alt="TFGen Learn Tab — In-context HCL explainer" width="900"/>
</p>

> **What you're seeing:** The Security Group resource's Learn tab. The top section shows "What it is / Why it's used / After apply." Below, each config field (name, description, vpc_id) is expanded with a plain-English explanation of **What** it controls, **Why** it exists, and **References** to connected resources. The orange tip at the bottom nudges toward best-practice naming conventions.

---

### Labs & Interview — Build Real Skills
Five guided scenario labs with step-by-step instructions and progress tracking. Plus 14 interview questions that are auto-filtered by the services in your current project.

<p align="center">
  <img src="docs/screenshots/05-labs-interview.png" alt="TFGen Labs and Interview Questions" width="900"/>
</p>

> **What you're seeing:** Left panel: 5 scenario labs (Host a Web App, Serverless API, RDS with Read Replica, EKS Cluster) with difficulty level and estimated time. Right panel: 14 interview questions covering Terraform fundamentals, VPC architecture, EC2 lifecycle, and more — all relevant to the resources in the current project. Filter by service (vpc, subnet, ec2, etc.) to focus your prep.

---

## 🏗️ Architecture Overview

```
tfgen_v14_fixed/
│
├── frontend/                       React 18 SPA
│   └── src/
│       ├── pages/
│       │   ├── Login.jsx           Auth page (sign in / create account)
│       │   ├── Dashboard.jsx       Project grid — create, open, delete projects
│       │   ├── Builder.jsx         Main IDE (code / graph / vars / learn / labs)
│       │   └── History.jsx         Version history — restore any past state
│       │
│       ├── components/
│       │   ├── ResourceGraph.jsx         Drag-and-drop topology canvas (graph view)
│       │   ├── ConfigPanel.jsx           Resource form — fills in real time
│       │   ├── CodePreview.jsx           Live HCL code display with syntax highlighting
│       │   ├── HclExplainer.jsx   ←NEW   Paste HCL → get plain-English explanation
│       │   ├── InterviewPanel.jsx ←NEW   Service-aware interview Q&A bank
│       │   ├── ScenarioLabs.jsx   ←NEW   Guided labs with progress tracking
│       │   ├── ArchPatternPicker.jsx ←NEW Architecture pattern library
│       │   ├── IamPolicyModal.jsx ←NEW   Minimum-privilege IAM JSON generator
│       │   ├── LintPanel.jsx             Architecture linter — critical + low findings
│       │   ├── PresetsPanel.jsx          One-click preset resource configurations
│       │   ├── SecurityFindings.jsx      Checkov scan results
│       │   ├── ValidationPanel.jsx       terraform validate output
│       │   ├── CostBadge.jsx             Infracost monthly estimate
│       │   ├── MultiEnvPanel.jsx         dev / staging / prod environment switcher
│       │   ├── VariablesEditor.jsx       variables.tf editor
│       │   ├── OutputsEditor.jsx         outputs.tf editor
│       │   └── BackendGenerator.jsx      Remote state backend config generator
│       │
│       ├── store/useStore.js        Zustand global state + undo/redo (zundo)
│       ├── api/client.js            Axios client + learnAPI + iamAPI
│       └── engine/templateEngine.js HCL template rendering engine
│
├── backend/                        Node.js + Express API
│   ├── routes/
│   │   ├── auth.js                 JWT login / register / refresh / logout
│   │   ├── projects.js             CRUD — projects, resources, versions, members
│   │   ├── terraform.js            fmt / validate / plan / cost / security scan
│   │   ├── aws.js                  EC2 types, AMIs, AZs, real AWS credentials
│   │   ├── export.js               GitHub Actions / GitLab CI / README export
│   │   ├── learn.js        ←NEW    HCL explain, labs, patterns, Q&A bank
│   │   ├── iam.js          ←NEW    IAM policy generator (single + batch)
│   │   └── audit.js                Request audit log
│   │
│   ├── middleware/
│   │   ├── auth.js                 JWT verify, requireRole(), optionalAuth()
│   │   └── audit.js                Per-request audit logging to DB
│   │
│   ├── services/
│   │   ├── infracost.js            Cost estimation via Infracost CLI
│   │   ├── checkov.js              Security scanning via Checkov CLI
│   │   └── jobQueue.js             Async job streaming over WebSocket
│   │
│   └── server.js                   Express app + WebSocket server
│
├── database/
│   ├── schema.sql                  Full schema (users, projects, resources, versions, lab_progress)
│   ├── seed.sql                    34 AWS service templates pre-seeded
│   └── migrate*.sql                Incremental migration files
│
└── docker-compose.yml              One-command startup: PG + backend + frontend
```

---

## 🚀 What's New in v3

| Feature | What It Does |
|---|---|
| 🏗️ **Architecture Pattern Library** | 8 pre-built patterns (VPC, EKS, Serverless, etc.) — load a full multi-resource pattern with one click, then customize |
| 🧪 **Guided Scenario Labs** | 5 step-by-step labs with progress tracking, checklists, and architecture guidance — learn by building real infra |
| 🎓 **HCL Explainer** | Paste any HCL block and get a plain-English breakdown of every field, every argument, and every best-practice tip |
| 📋 **Interview Q&A Bank** | 14+ Terraform and AWS interview questions that auto-filter based on the resources in your open project |
| 🛡️ **IAM Policy Generator** | One-click minimum-privilege IAM JSON for every service you've added — single resource or merged batch policy |
| 🔐 **JWT Auth (hardened)** | Two-token system with proper access + refresh token rotation and revocation; duplicate route handlers fixed |
| 🎨 **Design System v3** | Inter + JetBrains Mono, glow effects, grid backgrounds, dark mode throughout |

---

## ⚙️ Local Setup

### Prerequisites

| Tool | Minimum Version | Install |
|---|---|---|
| Node.js | ≥ 18 | https://nodejs.org |
| PostgreSQL | ≥ 13 | https://postgresql.org/download |
| Terraform CLI | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |

---

### Step 1 — Install Terraform CLI

**Ubuntu / Debian:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform version   # should print Terraform v1.5+
```

**macOS:**
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

**Windows:** Download the binary from [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) and add it to PATH.

---

### Step 2 — Set Up PostgreSQL

```bash
sudo -u postgres psql
```

```sql
CREATE USER tfgen WITH PASSWORD 'tfgen123';
CREATE DATABASE terraform_generator OWNER tfgen;
GRANT ALL PRIVILEGES ON DATABASE terraform_generator TO tfgen;
\q
```

Apply schema and seed data:
```bash
psql -U tfgen -h localhost -d terraform_generator -f database/schema.sql
psql -U tfgen -h localhost -d terraform_generator -f database/seed.sql
```

---

### Step 3 — Configure the Backend

```bash
cp backend/.env.example backend/.env
```

Open `backend/.env` and fill in:
```env
DATABASE_URL=postgresql://tfgen:tfgen123@localhost:5432/terraform_generator
PORT=4000
HOST=0.0.0.0

# JWT — generate strong random secrets before any non-local deployment
JWT_SECRET=your-super-secret-key-min-32-chars
JWT_REFRESH_SECRET=your-refresh-secret-key-min-32-chars
JWT_ACCESS_EXPIRY=1h
JWT_REFRESH_EXPIRY=7d

NODE_ENV=development
CORS_ORIGIN=http://localhost:3000
# Optional: override the Terraform Language Server executable path used by Studio
# features. If `terraform-ls` is not on PATH, set the full path here.
# TF_LSP_PATH=/usr/local/bin/terraform-ls
```

`terraform-ls` must be installed on the backend system for Studio editor LSP features.
Install it from HashiCorp releases or your operating system package manager.

> ⚠️ **Never commit real secrets to git.** The `.env` file is already in `.gitignore`.

---

### Step 4 — Configure the Frontend

```bash
cp frontend/.env.example frontend/.env
```

`frontend/.env`:
```env
REACT_APP_API_URL=http://localhost:4000
```

---

### Step 5 — Start the Application

**Terminal 1 — Backend:**
```bash
cd backend
npm install
npm run dev     # nodemon with auto-reload — listens on :4000
```

**Terminal 2 — Frontend:**
```bash
cd frontend
npm install
npm start       # CRA dev server — opens http://localhost:3000
```

Open **http://localhost:3000** and sign in. Use **"Try with demo credentials"** to log in instantly without creating an account.

---

### Alternative: Docker (one command)

```bash
docker compose up -d
```

Docker Compose starts PostgreSQL → Backend → Frontend in the correct order, applies schema + seed automatically, and maps all ports. No manual DB setup needed.

---

## 🔐 Authentication & Security

TFGen uses a **two-token JWT system** — the same pattern used by most production OAuth2 implementations.

```
┌─────────┐   POST /api/auth/login    ┌──────────┐
│ Browser │ ────────────────────────► │  Backend │
│         │ ◄──────────────────────── │          │
│         │  { token, refreshToken }  │          │
└─────────┘                           └──────────┘
     │
     ▼
┌──────────────────────────┬──────────────────────────┐
│     Access Token (JWT)   │    Refresh Token (JWT)   │
│  Expires: 1 hour         │  Expires: 7 days         │
│  Payload: id, email, role│  Payload: id only         │
│  Used for: every API call│  Used for: get new pair  │
└──────────────────────────┴──────────────────────────┘
```

When the access token expires, the frontend automatically calls `/api/auth/refresh`, gets a new pair, revokes the old refresh token in the database, and retries the original request. The user never sees a login prompt during a normal session.

### Role Hierarchy

| Role | Level | What They Can Do |
|---|---|---|
| `viewer` | 0 | Read-only: view projects and generated code |
| `user` | 1 | Create new projects |
| `editor` | 2 | Edit resources, invite members ← **default for new accounts** |
| `deployer` | 3 | Run `terraform plan` and cost estimates |
| `admin` | 4 | Full access: delete projects, manage all users |

---

## 🌐 API Reference

### Auth (`/api/auth`)

| Method | Endpoint | Body | Description |
|---|---|---|---|
| `POST` | `/register` | `{ email, password, name }` | Create account |
| `POST` | `/login` | `{ email, password }` | Get token pair |
| `POST` | `/refresh` | `{ refreshToken }` | Rotate tokens |
| `POST` | `/logout` | `{ refreshToken }` | Revoke refresh token |

### Projects (`/api/projects`)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | List all projects for current user |
| `POST` | `/` | Create a new project |
| `GET` | `/:id` | Get project with all resources |
| `PUT` | `/:id` | Update project settings |
| `DELETE` | `/:id` | Delete project (admin only) |
| `GET` | `/:id/versions` | Version history |
| `POST` | `/:id/versions` | Save a new version snapshot |

### Terraform Operations (`/api/terraform`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/validate` | Run `terraform validate` |
| `POST` | `/fmt` | Run `terraform fmt` (format code) |
| `POST` | `/plan` | Run `terraform plan` (requires AWS creds) |
| `POST` | `/cost` | Infracost estimate |
| `POST` | `/scan` | Checkov security scan |

### Learning API (`/api/learn`) ← New in v3

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/explain` | Explain a HCL block — `{ hcl: string }` |
| `GET` | `/questions?services=ec2,vpc` | Interview Q&A filtered by service |
| `GET` | `/labs` | List all scenario labs |
| `GET` | `/labs/:id` | Get a specific lab with all steps |
| `POST` | `/labs/progress` | Save user's step progress |
| `GET` | `/labs/progress` | Get current user's lab progress |
| `GET` | `/patterns` | Architecture pattern library |
| `GET` | `/patterns/:id` | Get a specific pattern |

### IAM Policy Generator (`/api/iam`) ← New in v3

| Method | Endpoint | Body | Description |
|---|---|---|---|
| `POST` | `/generate` | `{ service_type: "ec2" }` | Minimum-privilege policy for one service |
| `POST` | `/generate/batch` | `{ service_types: ["ec2","rds","s3"] }` | Merged policy for multiple services |

**Example — generate a merged IAM policy:**
```bash
curl -X POST http://localhost:4000/api/iam/generate/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"service_types":["ec2","vpc","rds","s3"]}'
```

---

## 🗺️ Architecture Patterns (8 pre-built)

Load any pattern with one click and get a fully-wired, multi-resource starting point:

| Pattern | Core Services | Best For |
|---|---|---|
| **3-Tier VPC** | VPC, Subnet × 2, IGW, NAT, Route Tables | Foundation for every workload |
| **EC2 + ALB + Auto Scaling** | EC2, ALB, ASG, CloudWatch | High-availability web app |
| **Serverless REST API** | Lambda, DynamoDB, API Gateway, IAM | Pay-per-request API |
| **Event-Driven Pipeline** | S3, SQS, Lambda, SNS | Async message processing |
| **RDS High Availability** | RDS, Secrets Manager, CloudWatch | Production database |
| **EKS Production Cluster** | EKS, IAM, VPC, Managed Node Group | Kubernetes on AWS |
| **Static Site + CDN** | S3, CloudFront, Route 53 | Frontend hosting |
| **CI/CD Pipeline** | CodePipeline, CodeBuild, CodeDeploy | Automated deployments |

---

## 🧪 Guided Scenario Labs

Hands-on labs that walk you through building real AWS infrastructure end-to-end, with a checklist, step-by-step instructions, and progress tracking saved to your account.

| Lab | Level | Time | What You Build |
|---|---|---|---|
| **Deploy a 3-Tier VPC** | Beginner | 45 min | Networking foundation: VPC, public/private subnets, IGW, NAT |
| **EC2 + ALB + Auto Scaling** | Intermediate | 60 min | HA web app behind a load balancer that scales on demand |
| **Serverless API** | Intermediate | 50 min | Full CRUD API: Lambda + DynamoDB + API Gateway + IAM |
| **RDS + Read Replica + Secrets Manager** | Intermediate | 55 min | Production DB with automatic backups and secret rotation |
| **EKS with Managed Node Groups** | Advanced | 75 min | Production Kubernetes: IRSA, node groups, cluster autoscaler |

---

## ☁️ AWS Services Supported (44+)

| Category | Services |
|---|---|
| **Compute** | EC2 Instance, Auto Scaling Group, Application Load Balancer, Lambda, EC2 Launch Template, EC2 Key Pair |
| **Storage** | S3 Bucket, EBS Volume, EFS File System |
| **Networking** | VPC, Subnet, Security Group, Internet Gateway, NAT Gateway, Route Table, Route 53, CloudFront, Transit Gateway |
| **Database** | RDS Instance, DynamoDB Table, ElastiCache Cluster |
| **IAM & Security** | IAM Role, IAM User, IAM Policy, IAM Group, KMS Key, Secrets Manager |
| **Monitoring** | CloudWatch Alarm, CloudWatch Log Group, SNS Topic, SQS Queue, EventBridge Rule |
| **Containers** | EKS Cluster, ECS Cluster, ECR Repository |
| **CI/CD** | CodePipeline, CodeBuild, CodeDeploy, API Gateway |
| **Admin & Compliance** | SSM Parameter Store, AWS Backup, CloudTrail, GuardDuty, WAF, AWS Budget, Config Rule |
| **App Services** | AWS App Runner Service, AWS Batch Compute Environment, EC2 Image Builder Pipeline |

---

## 🛠️ Troubleshooting

### "Cannot reach backend"
```bash
# Make sure backend is running
cd backend && npm start
# Test health endpoint
curl http://localhost:4000/api/health   # → {"status":"ok"}
```

### CORS errors in the browser
- Ensure `CORS_ORIGIN=http://localhost:3000` is set in `backend/.env`
- Restart the backend after any `.env` change

### 401 Unauthorized on every request
- `JWT_SECRET` in `backend/.env` must match the secret used to sign the token
- Generate a test token manually:
```bash
node -e "
const jwt = require('jsonwebtoken');
const token = jwt.sign(
  { id: 'test-user', email: 'test@example.com', role: 'admin' },
  process.env.JWT_SECRET || 'tfgen-dev-secret-change-in-production',
  { expiresIn: '1h' }
);
console.log('Bearer ' + token);
"
```
- Test it: `curl -H "Authorization: Bearer <token>" http://localhost:4000/api/projects`

### Database connection error
```bash
# Check the tables exist
psql -U tfgen -h localhost -d terraform_generator -c "\dt"
# Re-apply schema if needed
psql -U tfgen -h localhost -d terraform_generator -f database/schema.sql
```

### "terraform: command not found"
- Terraform CLI must be on your system PATH, not just installed
- Verify: `terraform version`
- Follow Step 1 of the setup guide above

---

## 📁 Project File Structure (abbreviated)

```
tfgen_v14_fixed/
├── README.md                  ← You are here
├── docker-compose.yml         ← One-command startup
├── database/
│   ├── schema.sql             ← Run this first
│   └── seed.sql               ← Run this second
├── backend/
│   ├── .env.example           ← Copy to .env and fill in
│   ├── server.js
│   └── routes/ middleware/ services/
├── frontend/
│   ├── .env.example           ← Copy to .env and fill in
│   ├── package.json
│   └── src/
└── docs/
    ├── PRODUCT_ROADMAP.md
    └── screenshots/           ← UI screenshots used in this README
```
What migrate.js Does
This is a database migration runner for your TFGen project. It manages and applies SQL schema changes to your PostgreSQL database in a controlled, sequential way.

Core Problem It Solves
When your app evolves, your database schema changes — new tables, new columns, constraints, etc. Without a migration tool, you'd manually run SQL scripts and lose track of what's been applied where (local, staging, prod). This script automates that.

How It Works — Step by Step
1. Discovers migration files from the database/ folder
Files must follow the naming pattern: 001_initial_schema.sql, 002_add_user_role.sql, etc.
2. Tracks what's already applied via a schema_migrations table it creates automatically in Postgres — so re-running is always safe.
3. Applies only pending migrations in order, each wrapped in a transaction — if a migration fails, it rolls back and exits, so your DB is never left half-migrated.

npm install pg
npm install pg dotenv
# Check status first
node migrate.js --status

# Dry run — see what SQL will execute
node migrate.js --dry-run

# Apply all pending migrations
node migrate.js
---

## 📜 License

MIT — free to use, modify, and distribute. Attribution appreciated but not required.

---

<p align="center">
  Built for the cloud community. Star ⭐ the repo if TFGen saved you time.
</p>
