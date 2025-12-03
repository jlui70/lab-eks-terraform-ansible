#!/bin/bash

# Script para destruir todos os recursos na ordem correta
# Versão: 3.3
# Data: 02 de Dezembro de 2025
# Stacks: 00-backend até 06-ecommerce-app (Terraform + Kubernetes resources)
# Changelog v3.3: Documentação atualizada (Stack 06 já estava sendo deletada via namespace ecommerce)
# Changelog v3.2: Limpeza IAM dinâmica (lê nomes do Terraform state - suporta nomes customizados)
# Changelog v3.1: Limpeza IAM automática (previne erro EntityAlreadyExists)
# Changelog v3.0: Remoção automática de resources órfãos do state (Stack 04, 03, 02)

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🗑️  DESTRUINDO INFRAESTRUTURA EKS - 6 STACKS               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Função para destruir uma stack
destroy_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Destruindo: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    if [ -f "terraform.tfstate" ] || terraform state list &>/dev/null; then
        terraform destroy -auto-approve || {
            echo "⚠️  Erro ao destruir $stack_name, tentando remover state órfão..."
            terraform state list 2>/dev/null | while read resource; do
                terraform state rm "$resource" 2>/dev/null || true
            done
            echo "✅ $stack_name limpo (recursos já removidos)"
        }
        echo "✅ $stack_name destruído com sucesso!"
    else
        echo "⚠️  $stack_name: Nenhum recurso para destruir"
    fi
    
    echo ""
}

# IMPORTANTE: Primeiro deletar recursos Kubernetes que criam recursos AWS
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 PASSO 1: Deletando recursos Kubernetes (Ingress → ALB)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Verificar se kubectl consegue acessar o cluster
if kubectl cluster-info &>/dev/null; then
    echo "  ✅ Cluster acessível via kubectl"
    
    # Deletar namespace ecommerce (aplicação com 7 microserviços + Ingress → ALB)
    if kubectl get namespace ecommerce &>/dev/null; then
        echo "  🗑️  Deletando namespace ecommerce (7 microserviços + ALB)..."
        kubectl delete namespace ecommerce --timeout=90s 2>/dev/null || true
    fi
    
    # Deletar recursos do namespace sample-app (se existir)
    if kubectl get namespace sample-app &>/dev/null; then
        echo "  🗑️  Deletando namespace sample-app..."
        kubectl delete ingress eks-devopsproject-ingress -n sample-app --ignore-not-found=true 2>/dev/null || true
        kubectl delete service nginx -n sample-app --ignore-not-found=true 2>/dev/null || true
        kubectl delete deployment nginx -n sample-app --ignore-not-found=true 2>/dev/null || true
        kubectl delete namespace sample-app --timeout=90s 2>/dev/null || true
    fi
    
    # Deletar kube-state-metrics se existir (instalado manualmente via Helm)
    if helm list -n kube-system | grep -q kube-state-metrics; then
        echo "  🗑️  Desinstalando kube-state-metrics..."
        helm uninstall kube-state-metrics -n kube-system 2>/dev/null || true
    fi

    echo "  ⏳ Aguardando ALB(s) serem deletados pela AWS (45s)..."
    sleep 45
    echo "  ✅ Recursos Kubernetes deletados"
else
    echo "  ⚠️  Cluster inaccessível via kubectl (pode já ter sido destruído)"
    echo "  ℹ️  Prosseguindo com destroy do Terraform (limpará ALB se existir)"
fi
echo ""

# Ordem correta de destruição (REVERSA da criação: 05 → 00)
echo "📋 Ordem de destruição: 05-monitoring → 04-security → 03-karpenter → 02-eks → 01-networking → 00-backend"
echo ""

destroy_stack "Stack 05 - Monitoring (Grafana + Prometheus)" "05-monitoring"

# CRÍTICO: Aguardar ENIs do Prometheus Scraper serem liberadas pela AWS
echo "═══════════════════════════════════════════════════════════════════"
echo "⏳ Aguardando liberação de ENIs do Prometheus Scraper..."
echo "═══════════════════════════════════════════════════════════════════"
echo "ℹ️  O Prometheus Scraper cria ENIs gerenciadas que levam ~5min para"
echo "   serem liberadas pela AWS após o terraform destroy."
echo ""

MAX_WAIT=600  # 10 minutos
INTERVAL=15   # Verificar a cada 15 segundos
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
    # Verificar ENIs com tipo amp_collector (Prometheus)
    ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --filters "Name=interface-type,Values=amp_collector" \
        --query 'length(NetworkInterfaces)' \
        --output text \
        --profile terraform 2>/dev/null || echo "0")
    
    if [ "$ENI_COUNT" = "0" ]; then
        echo "✅ Todas as ENIs do Prometheus foram liberadas!"
        break
    fi
    
    echo "  ⏳ Ainda há $ENI_COUNT ENI(s) do Prometheus... aguardando ${elapsed}s/${MAX_WAIT}s"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

if [ $elapsed -ge $MAX_WAIT ]; then
    echo "⚠️  TIMEOUT: ENIs ainda não foram liberadas após ${MAX_WAIT}s"
    echo "   Prosseguindo mesmo assim (pode causar erro na Stack 01 - VPC)"
    echo "   Se VPC não deletar, aguarde mais 5min e execute:"
    echo "   → ./cleanup-vpc-final.sh"
else
    echo "✅ Pronto para deletar recursos de rede!"
fi
echo ""

# Stack 04: Remover WAF association do state (ALB já foi deletado via kubectl)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Stack 04: Limpando state de WAF association órfã..."
echo "═══════════════════════════════════════════════════════════════════"
cd "$PROJECT_ROOT/04-security"
terraform state rm aws_wafv2_web_acl_association.alb 2>/dev/null && echo "  ✅ WAF association removida do state" || echo "  ℹ️  WAF association já removida ou não existe"
terraform state rm data.aws_lb.eks 2>/dev/null && echo "  ✅ Data source ALB removido do state" || echo "  ℹ️  Data source já removido"
echo ""

destroy_stack "Stack 04 - Security (WAF)" "04-security"

# Stack 03: Remover helm release do state (pode estar órfão se cluster foi destruído)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Stack 03: Limpando state de Karpenter helm release órfão..."
echo "═══════════════════════════════════════════════════════════════════"
cd "$PROJECT_ROOT/03-karpenter-auto-scaling"
terraform state rm helm_release.karpenter 2>/dev/null && echo "  ✅ Karpenter helm release removido do state" || echo "  ℹ️  Helm release já removido ou não existe"
echo ""

destroy_stack "Stack 03 - Karpenter (Auto-scaling)" "03-karpenter-auto-scaling"

# Stack 02: Remover helm releases do state (cluster inacessível após addons destruídos)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Stack 02: Limpando state de helm releases órfãos..."
echo "═══════════════════════════════════════════════════════════════════"
cd "$PROJECT_ROOT/02-eks-cluster"
terraform state rm helm_release.load_balancer_controller 2>/dev/null && echo "  ✅ ALB Controller helm release removido do state" || echo "  ℹ️  ALB Controller já removido ou não existe"
terraform state rm helm_release.external_dns 2>/dev/null && echo "  ✅ External DNS helm release removido do state" || echo "  ℹ️  External DNS já removido ou não existe"
echo ""

destroy_stack "Stack 02 - EKS Cluster" "02-eks-cluster"

# IMPORTANTE: Limpar IAM roles/policies órfãs que o Terraform pode não ter deletado
# Isso evita erro "EntityAlreadyExists" em reinstalações
# VERSÃO DINÂMICA v3.2: Lê nomes reais do Terraform state (funciona mesmo se usuário alterar variables.tf)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Limpando IAM Roles/Policies órfãs (prevenção de conflitos)..."
echo "═══════════════════════════════════════════════════════════════════"

# Função auxiliar para deletar role IAM (detach policies primeiro)
delete_iam_role() {
    local role_name=$1
    
    if [ -z "$role_name" ]; then
        return 0
    fi
    
    if aws iam get-role --role-name "$role_name" --profile terraform &>/dev/null; then
        echo "  🗑️  Deletando role: $role_name"
        
        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$role_name" \
            --profile terraform \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        for policy_arn in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "$role_name" \
                --policy-arn "$policy_arn" \
                --profile terraform 2>/dev/null || true
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$role_name" \
            --profile terraform \
            --query 'PolicyNames' \
            --output text 2>/dev/null || echo "")
        
        for policy_name in $INLINE_POLICIES; do
            aws iam delete-role-policy \
                --role-name "$role_name" \
                --policy-name "$policy_name" \
                --profile terraform 2>/dev/null || true
        done
        
        # Remove from instance profiles AND delete the profiles
        INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role \
            --role-name "$role_name" \
            --profile terraform \
            --query 'InstanceProfiles[].InstanceProfileName' \
            --output text 2>/dev/null || echo "")
        
        for profile_name in $INSTANCE_PROFILES; do
            echo "    → Removendo role do instance profile: $profile_name"
            aws iam remove-role-from-instance-profile \
                --instance-profile-name "$profile_name" \
                --role-name "$role_name" \
                --profile terraform 2>/dev/null || true
            
            # Deletar o instance profile (órfão criado pelo EKS)
            echo "    → Deletando instance profile órfão: $profile_name"
            aws iam delete-instance-profile \
                --instance-profile-name "$profile_name" \
                --profile terraform 2>/dev/null || true
        done
        
        # Delete role
        aws iam delete-role --role-name "$role_name" --profile terraform 2>/dev/null && \
            echo "    ✅ Role $role_name deletada" || \
            echo "    ⚠️  Role $role_name não pôde ser deletada"
    fi
}

# Função auxiliar para extrair nome de role do Terraform state
get_role_name_from_state() {
    local stack_path=$1
    local resource_address=$2
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da role do state
    local role_name=$(terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
    echo "$role_name"
}

# Função auxiliar para extrair nome de policy do Terraform state
get_policy_name_from_state() {
    local stack_path=$1
    local resource_address=$2
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da policy do state
    local policy_name=$(terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
    echo "$policy_name"
}

# Obter account ID dinamicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
    echo "  ⚠️  Não foi possível obter Account ID, pulando limpeza de IAM"
else
    echo "  📊 Account ID: $ACCOUNT_ID"
    echo "  🔍 Lendo nomes reais das roles do Terraform state..."
    echo ""
    
    # ======================================================================
    # STACK 02 - EKS CLUSTER ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 02 - EKS Cluster"
    
    ROLE_CSI=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.container_storage_interface")
    ROLE_ALB=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.load_balancer_controller")
    ROLE_NODE=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.eks_cluster_node_group")
    ROLE_CLUSTER=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.eks_cluster")
    ROLE_DNS=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.external_dns")
    
    POLICY_ALB=$(get_policy_name_from_state "02-eks-cluster" "aws_iam_policy.load_balancer_controller")
    
    [ -n "$ROLE_CSI" ] && delete_iam_role "$ROLE_CSI" || delete_iam_role "AmazonEKS_EFS_CSI_DriverRole"
    [ -n "$ROLE_ALB" ] && delete_iam_role "$ROLE_ALB" || delete_iam_role "aws-load-balancer-controller"
    [ -n "$ROLE_NODE" ] && delete_iam_role "$ROLE_NODE" || delete_iam_role "eks-devopsproject-node-group-role"
    [ -n "$ROLE_CLUSTER" ] && delete_iam_role "$ROLE_CLUSTER" || delete_iam_role "eks-devopsproject-cluster-role"
    [ -n "$ROLE_DNS" ] && delete_iam_role "$ROLE_DNS" || delete_iam_role "external-dns-irsa-role"
    
    # Deletar policy ALB Controller
    if [ -n "$POLICY_ALB" ]; then
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_ALB}"
    else
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
    fi
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" --profile terraform &>/dev/null; then
        echo "  🗑️  Deletando policy: $(basename $POLICY_ARN)"
        aws iam delete-policy --policy-arn "$POLICY_ARN" --profile terraform 2>/dev/null && \
            echo "    ✅ Policy deletada" || \
            echo "    ⚠️  Policy não pôde ser deletada (pode estar attached)"
    fi
    echo ""
    
    # ======================================================================
    # STACK 03 - KARPENTER ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 03 - Karpenter"
    
    ROLE_KARPENTER=$(get_role_name_from_state "03-karpenter-auto-scaling" "aws_iam_role.karpenter_controller")
    POLICY_KARPENTER=$(get_policy_name_from_state "03-karpenter-auto-scaling" "aws_iam_policy.karpenter_controller")
    
    [ -n "$ROLE_KARPENTER" ] && delete_iam_role "$ROLE_KARPENTER" || delete_iam_role "KarpenterControllerRole"
    
    # Deletar policy Karpenter
    if [ -n "$POLICY_KARPENTER" ]; then
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_KARPENTER}"
    else
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterControllerPolicy"
    fi
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" --profile terraform &>/dev/null; then
        echo "  🗑️  Deletando policy: $(basename $POLICY_ARN)"
        aws iam delete-policy --policy-arn "$POLICY_ARN" --profile terraform 2>/dev/null && \
            echo "    ✅ Policy deletada" || \
            echo "    ⚠️  Policy não pôde ser deletada"
    fi
    echo ""
    
    # ======================================================================
    # STACK 05 - MONITORING ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 05 - Monitoring"
    
    ROLE_GRAFANA=$(get_role_name_from_state "05-monitoring" "aws_iam_role.grafana")
    
    [ -n "$ROLE_GRAFANA" ] && delete_iam_role "$ROLE_GRAFANA" || delete_iam_role "GrafanaWorkspaceRole"
    echo ""
    
    echo "  ✅ Limpeza de IAM concluída (modo dinâmico v3.2)"
fi
echo ""

destroy_stack "Stack 01 - Networking (VPC)" "01-networking"

# Backend por último
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Destruindo: Stack 00 - Backend (S3 + DynamoDB)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "⚠️  Destruir backend também? Isso removerá o state remoto! (s/N): " destroy_backend

if [[ $destroy_backend =~ ^[Ss]$ ]]; then
    cd "$PROJECT_ROOT/00-backend"
    
    # Obter nome do bucket do terraform
    BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
    
    if [ -z "$BUCKET_NAME" ]; then
        echo "⚠️  Não foi possível obter nome do bucket. Tentando detectar..."
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"
        echo "  → Bucket detectado: $BUCKET_NAME"
    fi
    
    echo "🧹 Esvaziando bucket S3: $BUCKET_NAME"
    
    # Verificar se bucket existe antes de tentar esvaziar
    if aws s3 ls "s3://$BUCKET_NAME" --profile terraform &>/dev/null; then
        echo "  → Removendo todos os objetos e versões do bucket..."
        
        # Método 1: Usar aws s3 rm com --recursive (mais simples e confiável)
        aws s3 rm "s3://$BUCKET_NAME" --recursive --profile terraform 2>/dev/null || true
        
        # Método 2: Deletar versões antigas (versionamento habilitado)
        echo "  → Verificando versões antigas..."
        VERSIONS=$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --profile terraform \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ "$VERSIONS" != "null" ] && [ "$VERSIONS" != "" ] && [ "$VERSIONS" != "{}" ]; then
            echo "  → Removendo versões de objetos..."
            aws s3api delete-objects \
                --bucket "$BUCKET_NAME" \
                --profile terraform \
                --delete "$VERSIONS" 2>/dev/null || true
        fi
        
        # Método 3: Deletar delete markers
        echo "  → Verificando delete markers..."
        MARKERS=$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --profile terraform \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ "$MARKERS" != "null" ] && [ "$MARKERS" != "" ] && [ "$MARKERS" != "{}" ]; then
            echo "  → Removendo delete markers..."
            aws s3api delete-objects \
                --bucket "$BUCKET_NAME" \
                --profile terraform \
                --delete "$MARKERS" 2>/dev/null || true
        fi
        
        echo "  ✅ Bucket esvaziado completamente"
    else
        echo "  ℹ️  Bucket não encontrado ou já foi deletado"
    fi
    echo ""
    
    # Agora destruir o backend (com force_destroy = true, mesmo se houver objetos restantes)
    terraform destroy -auto-approve
    echo "✅ Stack 00 - Backend destruído"
else
    echo "⏸️  Stack 00 - Backend preservado (state remoto mantido)"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ DESTRUIÇÃO COMPLETA!                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Recursos destruídos:"
echo "  ✅ Namespace ecommerce + ALB (via kubectl)"
echo "  ✅ Namespace sample-app (se existia)"
echo "  ✅ kube-state-metrics (se existia)"
echo "  ✅ Stack 05: Grafana + Prometheus"
echo "  ✅ Stack 04: WAF Web ACL + Association"
echo "  ✅ Stack 03: Karpenter + IAM Roles + Resources"
echo "  ✅ Stack 02: EKS Cluster + Node Group + ALB Controller + External DNS"
echo "  ✅ Stack 01: VPC + Subnets + NAT Gateways + EIPs"
if [[ $destroy_backend =~ ^[Ss]$ ]]; then
echo "  ✅ Stack 00: Backend (S3 + DynamoDB)"
else
echo "  ⏸️  Stack 00: Backend preservado"
fi
echo ""
echo "💰 Custos AWS agora: ~$0/mês"
if [[ ! $destroy_backend =~ ^[Ss]$ ]]; then
echo "   (S3 + DynamoDB do backend: <$1/mês)"
fi
echo ""
echo "🔄 Para recriar tudo: ./rebuild-all.sh"
echo ""
