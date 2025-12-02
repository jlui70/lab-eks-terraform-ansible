#!/bin/bash

# Script para recriar toda infraestrutura do zero
# Versão: 3.0
# Data: 02 de Dezembro de 2025
# Stacks: 00-backend até 06-ecommerce-app (Terraform + Ansible)
# Changelog v3.0: Adicionada Stack 06 com automação Ansible (e-commerce + WAF + Grafana)

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🚀 RECRIANDO INFRAESTRUTURA EKS - 6 STACKS + ANSIBLE       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Ordem: 00-backend → 01-networking → 02-eks → 03-karpenter → 04-security → 05-monitoring → 06-ecommerce (Ansible)"
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
    
    # -reconfigure evita erro "Backend configuration changed" após recriar S3
    terraform init -reconfigure
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

# ═══════════════════════════════════════════════════════════════════
# Stack 06 - E-commerce Application + Automação (Ansible)
# ═══════════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════════════════════"
echo "🎨 Stack 06 - E-commerce Application + Automação Ansible"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Este stack deploya:"
echo "  • 7 microserviços (e-commerce-ui, product-catalog, etc.)"
echo "  • Ingress + ALB"
echo "  • Associação automática do WAF ao ALB"
echo "  • Configuração do Grafana + Data Source Prometheus"
echo "  • Dashboards para monitoramento"
echo ""
echo "⏱️  Tempo estimado: ~5 minutos via Ansible (vs 25-30 min manual)"
echo ""
read -p "Deployar aplicação E-commerce via Ansible? (S/n): " deploy_ecommerce

if [[ ! $deploy_ecommerce =~ ^[Nn]$ ]]; then
    cd "$PROJECT_ROOT/ansible"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🛍️  Passo 1/2: Deploying E-commerce + Associação WAF"
    echo "═══════════════════════════════════════════════════════════════════"
    ansible-playbook playbooks/03-deploy-ecommerce.yml
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Passo 2/2: Configurando Grafana + Dashboards"
    echo "═══════════════════════════════════════════════════════════════════"
    ansible-playbook playbooks/01-configure-grafana.yml
    
    echo ""
    echo "✅ Stack 06 completa (aplicação + WAF + monitoramento configurado)"
    echo ""
    
    # Obter URL do ALB
    ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$ALB_URL" ]; then
        echo "🌐 URLs de Acesso:"
        echo "   • ALB Direto: http://$ALB_URL"
        echo "   • DNS Personalizado: http://eks.devopsproject.com.br"
        echo ""
        echo "📋 Próximo passo: Configure CNAME no DNS"
        echo "   Tipo: CNAME"
        echo "   Nome: eks"
        echo "   Destino: $ALB_URL"
        echo ""
    fi
else
    echo "⏸️  Stack 06 pulada (você pode deployar depois com: cd ansible && ansible-playbook playbooks/03-deploy-ecommerce.yml)"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ✅ INFRAESTRUTURA COMPLETA RECRIADA!                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Stacks aplicadas:"
echo "  ✅ Stack 00: Backend (S3 + DynamoDB para Terraform State)"
echo "  ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)"
echo "  ✅ Stack 02: EKS Cluster (Kubernetes + ALB Controller + External DNS)"
echo "  ✅ Stack 03: Karpenter (Auto-scaling avançado)"
echo "  ✅ Stack 04: Security (WAF Web ACL - 8 regras)"
echo "  ✅ Stack 05: Monitoring (Grafana + Prometheus)"
if [[ ! $deploy_ecommerce =~ ^[Nn]$ ]]; then
echo "  ✅ Stack 06: E-commerce (7 microserviços + WAF + Grafana) - via Ansible"
fi
echo ""
echo "🔍 Verificar recursos:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
if [[ ! $deploy_ecommerce =~ ^[Nn]$ ]]; then
echo "  kubectl get pods -n ecommerce"
echo "  kubectl get ingress -n ecommerce"
fi
echo ""
if [[ ! $deploy_ecommerce =~ ^[Nn]$ ]]; then
echo "🧪 Testar aplicação E-commerce:"
echo "  ALB_URL=\$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "  curl http://\$ALB_URL"
echo ""
echo "🔒 Validar WAF associado:"
echo "  ALB_ARN=\$(aws elbv2 describe-load-balancers --query \"LoadBalancers[?contains(LoadBalancerName, 'k8s-ecommerce')].LoadBalancerArn\" --output text --profile terraform)"
echo "  aws wafv2 get-web-acl-for-resource --resource-arn \"\$ALB_ARN\" --region us-east-1 --profile terraform"
echo ""
fi
echo "📊 Grafana:"
cd "$PROJECT_ROOT/05-monitoring"
GRAFANA_URL=$(terraform output -raw grafana_workspace_url 2>/dev/null || echo "")
if [ -n "$GRAFANA_URL" ]; then
echo "  URL: $GRAFANA_URL"
echo "  Login: AWS SSO (usuário configurado no IAM Identity Center)"
fi
echo ""
echo "📈 Total de recursos: 78 (infraestrutura completa)"
echo "💰 Custo mensal estimado: ~$273/mês"
echo "🗑️  Para destruir tudo: ./destroy-all.sh"
echo ""
