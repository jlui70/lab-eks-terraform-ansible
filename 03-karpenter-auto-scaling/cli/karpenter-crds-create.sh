#!/bin/bash

# Script para aplicar CRDs do Karpenter
# Versão: 1.1

set -e

echo "📦 Aplicando Karpenter CRDs..."

# Atualizar kubeconfig antes de aplicar CRDs
echo "🔑 Atualizando kubeconfig..."
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform 2>/dev/null || \
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1

# Aplicar CRDs do Karpenter v1.5.0 sem validação (evita erro de auth no OpenAPI)
echo "📥 Baixando e aplicando CRDs..."
kubectl apply --validate=false -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodepools.yaml
kubectl apply --validate=false -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml
kubectl apply --validate=false -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml

echo "✅ Karpenter CRDs aplicados com sucesso!"
