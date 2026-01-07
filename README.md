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
~$200-300/month for full setup
- AlloyDB: ~$100/month
- Cloud Run: ~$50/month
- Vertex AI: ~$50/month
- Storage/Monitoring: ~$50/month

## Access
Application is secured with IAP. Configure access in GCP Console.

## Development
See cloudbuild.yaml for CI/CD pipeline using Cloud Build.
