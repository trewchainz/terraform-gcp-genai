# 1. Enable required APIs
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  run.googleapis.com \
  vpcaccess.googleapis.com \
  secretmanager.googleapis.com \
  alloydb.googleapis.com \
  aiplatform.googleapis.com

# 2. Configure Terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with your values

# 3. Initialize with remote state
terraform init -backend-config="bucket=your-tf-state-bucket"

# 4. Plan and apply
terraform plan
terraform apply

# 5. Configure IAP access
# Visit: https://console.cloud.google.com/security/iap
