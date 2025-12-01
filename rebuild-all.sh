#!/bin/bash

# Script para recriar toda infraestrutura do zero
# Versão: 2.0
# Data: 27 de Novembro de 2025
# Stacks: 00-backend até 05-monitoring

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🚀 RECRIANDO INFRAESTRUTURA EKS - 6 STACKS                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Ordem: 00-backend → 01-networking → 02-eks → 03-karpenter → 04-security → 05-monitoring"
echo ""

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Função para aplicar uma stack
apply_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🚀 Aplicando: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    terraform init
    terraform apply -auto-approve
    
    echo "✅ $stack_name aplicado com sucesso!"
    echo ""
}

# Ordem correta de criação (00 → 05)
apply_stack "Stack 00 - Backend (S3 + DynamoDB)" "00-backend"

# Aguardar S3 bucket estar disponível antes de continuar
echo "⏳ Aguardando S3 bucket estar disponível para backend remoto (10s)..."
sleep 10
echo ""

apply_stack "Stack 01 - Networking (VPC)" "01-networking"
apply_stack "Stack 02 - EKS Cluster" "02-eks-cluster"

# Configurar kubectl após cluster criado
echo "═══════════════════════════════════════════════════════════════════"
echo "🔧 Configurando kubectl"
echo "═══════════════════════════════════════════════════════════════════"
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1
echo "✅ kubectl configurado"
echo ""

# Verificar helm/values.yml antes da Stack 03
echo "═══════════════════════════════════════════════════════════════════"
echo "🔍 Verificando helm/values.yml para Karpenter"
echo "═══════════════════════════════════════════════════════════════════"

# Obter Account ID dinamicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform 2>/dev/null || aws sts get-caller-identity --query Account --output text)

if [ ! -f "$PROJECT_ROOT/03-karpenter-auto-scaling/helm/values.yml" ] || ! grep -q "affinity" "$PROJECT_ROOT/03-karpenter-auto-scaling/helm/values.yml"; then
    echo "⚠️  helm/values.yml incompleto ou ausente, restaurando versão completa..."
    cat > "$PROJECT_ROOT/03-karpenter-auto-scaling/helm/values.yml" << 'EOFVALUES'
# Karpenter Helm Chart Values
# Configurações para rodar o Karpenter Controller apenas nos nodes do Node Group original

# Service Account com IRSA (IAM Roles for Service Accounts)
serviceAccount:
  name: karpenter
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/karpenter-controller-role

# Affinity: Força Karpenter a rodar APENAS em nodes do Node Group (não em nodes provisionados por ele mesmo)
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: karpenter.sh/nodepool
          operator: DoesNotExist

# Tolerations: Permite rodar em nodes do Node Group
tolerations:
  - key: CriticalAddonsOnly
    operator: Exists

# Replicas para alta disponibilidade
replicas: 2

# Resources para o controller
controller:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# NodeSelector: Garante que rode apenas em nodes do Node Group original
nodeSelector:
  eks.amazonaws.com/nodegroup: NODEGROUP_PLACEHOLDER
EOFVALUES
    
    # Substituir <ACCOUNT_ID> pelo Account ID real
    sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" "$PROJECT_ROOT/03-karpenter-auto-scaling/helm/values.yml"
    echo "✅ helm/values.yml restaurado (Account ID: $ACCOUNT_ID)"
else
    echo "✅ helm/values.yml já existe e está completo"
fi
echo ""

apply_stack "Stack 03 - Karpenter (Auto-scaling)" "03-karpenter-auto-scaling"
apply_stack "Stack 04 - Security (WAF)" "04-security"
apply_stack "Stack 05 - Monitoring (Grafana + Prometheus)" "05-monitoring"

# Criar recursos Kubernetes de teste (opcional)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧪 Recursos de Teste (Opcional)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "Criar deployment NGINX de teste? (S/n): " create_test

if [[ ! $create_test =~ ^[Nn]$ ]]; then
    echo "🌐 Criando deployment NGINX + Ingress..."
    
    # Criar deployment e service
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eks-devopsproject-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
    
    echo "⏳ Aguardando ALB ser provisionado (90s)..."
    sleep 90
    echo "✅ Recursos de teste criados"
else
    echo "⏸️  Pulando criação de recursos de teste"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ✅ INFRAESTRUTURA COMPLETA RECRIADA!                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Stacks aplicadas (6 stacks):"
echo "  ✅ Stack 00: Backend (S3 + DynamoDB para Terraform State)"
echo "  ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)"
echo "  ✅ Stack 02: EKS Cluster (Kubernetes + ALB Controller + External DNS)"
echo "  ✅ Stack 03: Karpenter (Auto-scaling avançado)"
echo "  ✅ Stack 04: Security (WAF Web ACL)"
echo "  ✅ Stack 05: Monitoring (Grafana + Prometheus)"
if [[ ! $create_test =~ ^[Nn]$ ]]; then
echo "  ✅ Recursos de teste (NGINX + Ingress + ALB)"
fi
echo ""
echo "🔍 Verificar recursos:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get ingress"
echo ""
if [[ ! $create_test =~ ^[Nn]$ ]]; then
echo "🌐 Obter URL do ALB:"
echo "  kubectl get ingress eks-devopsproject-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "🧪 Testar aplicação:"
echo "  ALB_URL=\$(kubectl get ingress eks-devopsproject-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "  curl http://\$ALB_URL"
echo ""
fi
echo "📊 Monitoramento:"
echo "  - Grafana: Acesse via AWS Console → Amazon Managed Grafana"
echo "  - Prometheus: Integrado automaticamente"
echo ""
echo "💰 Custo mensal estimado: ~$273/mês"
echo "🗑️  Para destruir tudo: ./destroy-all.sh"
echo ""
