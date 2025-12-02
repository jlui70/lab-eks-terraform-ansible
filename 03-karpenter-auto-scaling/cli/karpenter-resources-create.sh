#!/bin/bash

# Script para aplicar recursos do Karpenter (NodePool e EC2NodeClass)
# Versão: 1.1

set -e

echo "📦 Aplicando Karpenter Resources (NodePool + EC2NodeClass)..."

# Atualizar kubeconfig antes de aplicar recursos
echo "🔑 Atualizando kubeconfig..."
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform 2>/dev/null || \
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1

# Aplicar NodePool
kubectl apply -f resources/karpenter-node-pool.yml

# Aplicar EC2NodeClass
kubectl apply -f resources/karpenter-node-class.yml

echo "✅ Karpenter Resources aplicados com sucesso!"
