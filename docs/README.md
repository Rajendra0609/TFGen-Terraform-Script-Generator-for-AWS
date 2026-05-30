# TFGen v3 — Terraform AWS Studio

> A full-stack visual infrastructure builder — generate, validate, and export production-ready Terraform HCL for AWS.  
> Built for DevOps engineers, SREs, and cloud learners.

---

## What's New in v3

| Feature | Description |
|---|---|
| 🏗️ **Architecture Pattern Library** | 8 pre-built patterns (VPC, EKS, Serverless, etc.) with one-click load |
| 🧪 **Guided Scenario Labs** | 5 step-by-step labs with progress tracking and architecture checklists |
| 🎓 **HCL Explainer** | Paste any HCL block → get plain-English explanation + pro tips |
| 📋 **Interview Q&A Bank** | Service-aware interview questions — updates as you add resources |
| 🛡️ **IAM Policy Generator** | Minimum-privilege IAM JSON for every resource you've added |
| 🔐 **JWT Auth (fixed)** | Cleaned up duplicate route handlers; proper access + refresh token rotation |
| 🎨 **Advanced UI v3** | New design system: Inter + JetBrains Mono, glow effects, grid backgrounds |

---

## Architecture

```
tf-new/
├── backend/                    Node.js + Express API
│   ├── routes/
│   │   ├── auth.js             JWT login / register / refresh / logout
│   │   ├── projects.js         CRUD, resources, versions, members
│   │   ├── terraform.js        fmt / validate / plan / cost / scan
│   │   ├── aws.js              EC2 types, AMIs, AZs, credentials
│   │   ├── export.js           GitHub Actions, GitLab CI, README gen
│   │   ├── learn.js  ← NEW     HCL explain, labs, patterns, Q&A
│   │   ├── iam.js    ← NEW     IAM policy generator
│   │   └── audit.js            Audit log
│   ├── middleware/
│   │   ├── auth.js             JWT verify, requireRole(), optionalAuth()
│   │   └── audit.js            Request audit logging
│   ├── services/
│   │   ├── infracost.js        Cost estimation
│   │   ├── checkov.js          Security scanning
│   │   └── jobQueue.js         Async job streaming (WebSocket)
│   └── server.js               Express app + WebSocket server
│
├── frontend/                   React 18 SPA
│   └── src/
│       ├── pages/
│       │   ├── Login.jsx       Redesigned auth page
│       │   ├── Dashboard.jsx   Project grid with stats
│       │   ├── Builder.jsx     Main IDE (code/graph/vars/learn/labs)
│       │   └── History.jsx     Version history
│       ├── components/
│       │   ├── HclExplainer.jsx      ← NEW: block-level HCL explanation
│       │   ├── InterviewPanel.jsx    ← NEW: service-aware Q&A
│       │   ├── ScenarioLabs.jsx      ← NEW: guided labs with progress
│       │   ├── ArchPatternPicker.jsx ← NEW: pattern library modal
│       │   ├── IamPolicyModal.jsx    ← NEW: IAM JSON generator
│       │   ├── ResourceGraph.jsx     Visual drag-and-drop graph
│       │   ├── ConfigPanel.jsx       Resource config forms
│       │   ├── LintPanel.jsx         Architecture linter
│       │   ├── PresetsPanel.jsx      One-click preset configs
│       │   └── ...
│       ├── api/client.js       Axios client + learnAPI + iamAPI
│       └── index.css           Design system v3
│
└── database/
    ├── schema.sql              Full schema + Phase-3 (lab_progress table)
    └── seed.sql                34 AWS service templates
```

---

## Local Setup

### Prerequisites

| Tool | Version | Notes |
|---|---|---| 
| Node.js | ≥ 18 | https://nodejs.org |
| PostgreSQL | ≥ 13 | https://postgresql.org/download |
| Terraform CLI | ≥ 1.5 | Required for `fmt` and `validate` |

### 1 — Install Terraform CLI

**Ubuntu / Debian:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform version
```

**macOS:**
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

### 2 — Set Up PostgreSQL

```bash
sudo -u postgres psql
```
```sql
CREATE USER tfgen WITH PASSWORD 'tfgen123';
CREATE DATABASE terraform_generator OWNER tfgen;
GRANT ALL PRIVILEGES ON DATABASE terraform_generator TO tfgen;
\q
```

Apply schema and seed:
```bash
psql -U tfgen -h localhost -d terraform_generator -f database/schema.sql
psql -U tfgen -h localhost -d terraform_generator -f database/seed.sql
```

### 3 — Configure Backend

```bash
cp backend/.env.example backend/.env
```

Edit `backend/.env`:
```env
DATABASE_URL=postgresql://tfgen:tfgen123@localhost:5432/terraform_generator
PORT=4000
HOST=0.0.0.0

# JWT — change both secrets before deploying to production
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

### 4 — Configure Frontend

```bash
cp frontend/.env.example frontend/.env
```

Edit `frontend/.env`:
```env
REACT_APP_API_URL=http://localhost:4000
```

### 5 — Start the App

**Backend:**
```bash
cd backend
npm install
npm run dev     # nodemon auto-reload
```

**Frontend (new terminal):**
```bash
cd frontend
npm install
npm start       # http://localhost:3000
```

---

## JWT Token — How It Works

TFGen uses a **two-token system** (standard OAuth2 pattern):

```
┌─────────┐     POST /api/auth/login       ┌─────────┐
│ Browser │ ──────────────────────────────► │ Backend │
│         │ ◄────────────────────────────── │         │
│         │   { token, refreshToken, user } │         │
└─────────┘                                 └─────────┘
     │
     │  Store tokens:
     │    localStorage: token (access)
     │    localStorage: refreshToken
     ▼
┌─────────────────────────────────────────────────────┐
│  Access Token (JWT)       │  Refresh Token (JWT)    │
│  Expires: 1 hour          │  Expires: 7 days        │
│  Contains: id, email, role│  Contains: id only      │
│  Used for: API requests   │  Used for: get new pair │
└─────────────────────────────────────────────────────┘
```

### Generate a JWT manually (for testing):

```bash
node -e "
const jwt = require('jsonwebtoken');
const secret = process.env.JWT_SECRET || 'tfgen-dev-secret-change-in-production';
const token = jwt.sign(
  { id: 'test-user-id', email: 'test@example.com', role: 'admin' },
  secret,
  { expiresIn: '1h' }
);
console.log('Bearer ' + token);
"
```

Use the token in API requests:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:4000/api/projects
```

### Token Rotation

When the access token expires (401 response), the frontend automatically:
1. Calls `POST /api/auth/refresh` with the refresh token
2. Gets a new access + refresh token pair
3. Revokes the old refresh token (stored hash in DB)
4. Retries the original request

### Role Hierarchy

There are **5 roles** in ascending order of privilege:

| Role | Level | Permissions |
|---|---|---|
| `viewer` | 0 | Read-only access to projects |
| `user` | 1 | Create and view own projects |
| `editor` | 2 | Edit resources, invite members |
| `deployer` | 3 | Run `terraform plan` and deploy |
| `admin` | 4 | Full access — manage users, delete projects, all operations |

**Default role assignment on registration:**
- The **first user** to register is automatically assigned `admin`.
- All subsequent users are assigned `user` (level 1).

> ⚠️ **Bug fixed in v5:** Previously, all new users were hardcoded to `editor`. This has been corrected — new users now get `user` role, and the very first signup gets `admin`.

---

### Role Management

#### Check all users and their roles
```sql
SELECT id, email, role, created_at FROM users ORDER BY created_at DESC;
```

#### Promote a user to admin
```sql
UPDATE users SET role = 'admin' WHERE email = 'youruser@example.com';
```

#### Change a user's role to any valid role
```sql
-- Valid roles: viewer | user | editor | deployer | admin
UPDATE users SET role = 'deployer' WHERE email = 'youruser@example.com';
```

#### Demote a user back to basic user
```sql
UPDATE users SET role = 'user' WHERE email = 'youruser@example.com';
```

#### Make an existing user admin (if you forgot to register first)
```bash
# Connect to your DB and run:
psql -U tfgen -h localhost -d terraform_generator -c \
  "UPDATE users SET role = 'admin' WHERE email = 'your-email@example.com';"
```

#### Generate an admin JWT manually (for API testing)
```bash
node -e "
const jwt = require('jsonwebtoken');
const secret = process.env.JWT_SECRET || 'tfgen-dev-secret-change-in-production';
const token = jwt.sign(
  { id: 'test-user-id', email: 'admin@example.com', role: 'admin' },
  secret,
  { expiresIn: '1h' }
);
console.log('Bearer ' + token);
"
```

---

## New API Endpoints (v3)

### Learning API (`/api/learn`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/learn/explain` | Explain a HCL block — `{ hcl: string }` |
| `GET` | `/api/learn/questions?services=ec2,vpc` | Interview questions by service |
| `GET` | `/api/learn/labs` | List all scenario labs |
| `GET` | `/api/learn/labs/:id` | Get specific lab with steps |
| `POST` | `/api/learn/labs/progress` | Save step progress (auth) |
| `GET` | `/api/learn/labs/progress` | Get user's progress (auth) |
| `GET` | `/api/learn/patterns` | Architecture pattern library |
| `GET` | `/api/learn/patterns/:id` | Get specific pattern |

### IAM Policy Generator (`/api/iam`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/iam/generate` | Generate policy — `{ service_type: string }` |
| `POST` | `/api/iam/generate/batch` | Merged policy — `{ service_types: string[] }` |

**Example:**
```bash
curl -X POST http://localhost:4000/api/iam/generate/batch \
  -H "Content-Type: application/json" \
  -d '{"service_types":["ec2","vpc","rds"]}'
```

---

## Architecture Patterns Available

| Pattern | Services | Use Case |
|---|---|---|
| 3-Tier VPC | VPC, Subnet, IGW, NAT, Route Tables | Foundation for all workloads |
| EC2 + ALB + ASG | EC2, ALB, Auto Scaling, CloudWatch | High-availability web app |
| Serverless REST API | Lambda, DynamoDB, API GW, IAM | Pay-per-request API |
| Event-Driven Pipeline | S3, SQS, Lambda, SNS | Async message processing |
| RDS High Availability | RDS, Secrets Manager, CloudWatch | Production database |
| EKS Production Cluster | EKS, IAM, VPC, Managed Node Group | Kubernetes on AWS |
| Static Site + CDN | S3, CloudFront, Route 53 | Frontend hosting |
| CI/CD Pipeline | CodePipeline, CodeBuild, CodeDeploy | Automated deployment |

---

## Guided Scenario Labs

| Lab | Difficulty | Duration | Focus |
|---|---|---|---|
| Deploy a 3-Tier VPC | Beginner | 45 min | Networking foundation |
| EC2 + ALB + Auto Scaling | Intermediate | 60 min | HA compute |
| Serverless API | Intermediate | 50 min | Lambda + DynamoDB |
| RDS + Read Replica + Secrets | Intermediate | 55 min | Production database |
| EKS with Managed Node Groups | Advanced | 75 min | Kubernetes |

---

## Services Supported (34 total)

| Category | Services |
|---|---|
| **Compute** | EC2, Auto Scaling Group, ALB, Lambda |
| **Storage** | S3, EBS Volume, EFS |
| **Networking** | VPC, Subnet, Security Group, Internet Gateway, NAT Gateway, Route Table, Route 53, CloudFront |
| **Database** | RDS, DynamoDB, ElastiCache |
| **IAM & Security** | IAM Role, IAM User, IAM Policy, IAM Group, KMS Key, Secrets Manager |
| **Monitoring** | CloudWatch Alarm, CloudWatch Log Group, SNS Topic, SQS Queue, EventBridge Rule |
| **Containers** | EKS Cluster, ECS Cluster, ECR Repository |
| **CI/CD** | CodePipeline, CodeBuild, CodeDeploy, API Gateway |
| **Admin** | SSM Parameter Store, AWS Backup, CloudTrail, GuardDuty, WAF, Budget, Config Rule, Transit Gateway |

---

## Docker (optional)

```bash
docker compose up -d
```

Compose starts: PostgreSQL → Backend → Frontend. Applies schema and seed automatically.

---

## Troubleshooting

**"Cannot reach backend"**
```bash
cd backend && npm start            # ensure backend is running
curl http://localhost:4000/api/health   # should return {"status":"ok"}
```

**CORS errors in browser**
- Set `CORS_ORIGIN=http://localhost:3000` in `backend/.env`
- Restart backend after `.env` changes

**401 on every request**
- `JWT_SECRET` in backend must match what was used to sign the token
- Run the manual JWT generation command above and test with curl

**Database connection error**
```bash
psql -U tfgen -h localhost -d terraform_generator -c "\dt"
```
