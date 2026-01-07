# Secure GenAI Application on GCP

A production-ready, security-focused GenAI application infrastructure using Terraform.

## Architecture
- **Security**: IAP, VPC-SC, encrypted storage, least-privilege IAM
- **AI/ML**: Vertex AI, Gemini API, vector embeddings
- **Data**: AlloyDB with pgvector, Cloud Storage for RAG
- **Compute**: Cloud Run with VPC access
- **Monitoring**: Budget alerts, audit logging, cost controls

## Security Features
1. **Zero Trust Access**: IAP-protected Cloud Run service
2. **Encryption at Rest**: CMEK for storage and databases
3. **Network Security**: VPC-SC, private endpoints, flow logs
4. **Secrets Management**: Secret Manager for credentials
5. **Audit Trail**: Cloud Logging to BigQuery

## Deployment
1. Enable billing and required APIs
2. Configure terraform.tfvars
3. Initialize: `terraform init`
4. Plan: `terraform plan`
5. Apply: `terraform apply`

## Cost Estimate

### Compute & Containers: $320-650/mo

#### Cloud Run on Production Load
Assumptions: 10 requests/sec average, 500ms processing time

- vCPU Allocation:
  - 2 containers running 24/7: 2 x $0.00002400/sec x 2,592,000 sec/month = $124.42
  - Burst capacity (auto-scaling to 10): Additional $100-200

- Memory Allocation:
  - 512MB per instance: 2 x $0.00000250/sec x 2,592,000 sec = $12.96
  - Burst capacity: Additional $50-100

- Requests:
  - 2.6M requests/month @ $0.40 per million = $1.04

- VPC Access Connector:
  - $0.10 per vCPU hour x 720 hours = $72.00
  - Minimum 2 vCPU = $144.00

**Cloud Run Total: ~$332 - $582/month**

#### Artifact Registry for Container Storage
- Storage: 20GB @ $0.10/GB = $2.00
- Operations: Minimal = ~$5.00

**Artifact Registry Total: ~$7/month**

## Database & Vector Store: $620-$1,150/mo

### AlloyDB for PostgreSQL w/ pgvector
 • Primary Instance (Regional):
  - db-standard-4 (4 vCPU, 26GB RAM): $503.34/month
  - Storage: 500GB SSD @ $0.17/GB = $85.00
  - Backups: 100GB @ $0.17/GB = $17.00

• Read Replica (for HA & scaling):
  - db-standard-2 (2 vCPU, 13GB RAM): $251.67/month
  - Essential for production RAG workloads

• IAM Database Authentication:
  - Minimal additional cost, included

• Cross-region replication (optional):
  - Add $200-400/month

**AlloyDB Total: ~$857 - $1,257/month**

## AI/ML Services: $350-900/mo

### Gemini API usage

• Gemini Pro 1.0:
  - Input: $0.000125 per 1K characters
  - Output: $0.000375 per 1K characters
  
• Estimated Monthly Usage:
  - 100,000 queries/month (reasonable for enterprise app)
  - Avg input: 500 characters = 50M characters = 50K "1K units"
  - Avg output: 1,000 characters = 100M characters = 100K "1K units"
  
  Input cost: 50K x $0.000125 = $6.25
  Output cost: 100K x $0.000375 = $37.50
  
  **Gemini API: ~$44/month**

• Embeddings Generation (for RAG):
  - text-embedding-004: $0.0000001 per token
  - 10M tokens/month (embedding documents + queries) = $1.00
  
  **Embeddings: ~$1/month**

### Vertex AI Vector Search
• Building Index:
  - $1.5625 per 1K embeddings
  - Initial index: 100K embeddings = $156.25 (one-time)
  
• Serving Queries:
  - $0.70 per 1M vector comparisons
  - 1M queries @ 100 comparisons each = 100M comparisons = $70
  
• Index Maintenance:
  - $0.05 per 1K embeddings per month
  - 100K embeddings = $5.00
  
  **Vector Search: ~$75 - $150/month**

## Storage & Data: $150-$350/mo

### Cloud Storage for RAG Documents & Embeddings
• Standard Storage: 1TB @ $0.02/GB = $20.40
• Nearline Storage (for old embeddings): 500GB @ $0.01/GB = $5.10
• Operations:
  - Class A: 1M ops @ $0.05/10K ops = $5.00
  - Class B: 10M ops @ $0.004/10K ops = $4.00
• Network Egress: 100GB @ $0.12/GB (same region) = $12.00

  **Cloud Storage: ~$46.50/month**

### BigQuery for Audit Logs & Analytics
• Storage: 100GB @ $0.02/GB = $2.00
• Queries: 1TB processed @ $5.00/TB = $5.00
• Streaming Inserts: Minimal
  
  **BigQuery: ~$7 - $15/month**

### Secret Manager
• 10 secrets @ $0.06 each = $0.60
• 100K access operations @ $0.03/10K = $0.30
  
  **Secret Manager: ~$1/month**

## Networking & Security: $240-480/mo

### VPC Service Controls (Premium Security Feature)
• No direct charge, but requires:
  - Increased networking complexity
  - Additional monitoring
  - Implicit costs in management

### Cloud NAT
• 2 NAT gateways for HA: 2 x $0.044/hour = $63.36/month
• Data processing: 1TB @ $0.045/GB = $45.00
  
  **Cloud NAT: ~$108/month**

### Cloud Load Balancing
• Forwarding Rule: $18.00/month
• Additional rule: $2.00/month
  
  **Load Balancing: ~$20/month**

## Access
Application is secured with IAP. Configure access in GCP Console.

## Development
See cloudbuild.yaml for CI/CD pipeline using Cloud Build.
