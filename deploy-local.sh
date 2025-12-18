#!/bin/bash
set -e

echo "🚀 Deploying AWS Cloud Platform - Dev Environment"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGION="eu-west-1"
ENVIRONMENT="dev"

echo -e "${YELLOW}Step 1: Deploying Dev Environment (includes all modules)${NC}"
cd terraform/environments/dev

terraform init
terraform plan -out=tfplan
terraform apply tfplan

cd ../../..

echo -e "${GREEN}✅ Infrastructure deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure kubectl: aws eks update-kubeconfig --region ${REGION} --name dev-eks-cluster"
echo "2. Deploy Kubernetes resources: kubectl apply -f kubernetes/base/"
echo "3. Deploy monitoring: Use Helm charts in kubernetes/monitoring/"
