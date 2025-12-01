#!/bin/bash

# Script de limpeza emergencial quando Terraform state está inacessível
# Use APENAS quando destroy-all.sh falhar por problemas de backend/state

set +e  # Continuar mesmo com erros

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        🚨 LIMPEZA EMERGENCIAL DE RECURSOS AWS                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  Este script deleta recursos AWS DIRETAMENTE via AWS CLI"
echo "⚠️  Use APENAS se destroy-all.sh falhar por problemas de state"
echo ""
read -p "Continuar com limpeza emergencial? (s/N): " confirm

if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

CLUSTER_NAME="eks-devopsproject-cluster"
PROFILE="terraform"
REGION="us-east-1"

echo ""
echo "🔍 Verificando recursos existentes..."
echo ""

# 1. Verificar se cluster existe
if aws eks describe-cluster --name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION" &>/dev/null; then
    echo "✅ Cluster EKS encontrado: $CLUSTER_NAME"
    
    # Deletar node groups
    echo ""
    echo "🗑️  Deletando Node Groups..."
    NODEGROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION" --query 'nodegroups[]' --output text)
    
    if [ -n "$NODEGROUPS" ]; then
        for ng in $NODEGROUPS; do
            echo "  → Deletando node group: $ng"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$ng" \
                --profile "$PROFILE" \
                --region "$REGION" 2>/dev/null || echo "  ⚠️  Falha ao deletar $ng (pode já estar sendo deletado)"
        done
        
        echo ""
        echo "⏳ Aguardando node groups serem deletados (isso pode demorar 3-5 minutos)..."
        
        while true; do
            REMAINING=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION" --query 'nodegroups[]' --output text 2>/dev/null | wc -w)
            
            if [ "$REMAINING" -eq 0 ]; then
                echo "  ✅ Todos os node groups foram deletados"
                break
            fi
            
            echo "  ⏳ Aguardando... ($REMAINING node groups restantes)"
            sleep 15
        done
    else
        echo "  ℹ️  Nenhum node group encontrado"
    fi
    
    # Deletar addons
    echo ""
    echo "🗑️  Deletando EKS Addons..."
    ADDONS=$(aws eks list-addons --cluster-name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION" --query 'addons[]' --output text 2>/dev/null)
    
    if [ -n "$ADDONS" ]; then
        for addon in $ADDONS; do
            echo "  → Deletando addon: $addon"
            aws eks delete-addon \
                --cluster-name "$CLUSTER_NAME" \
                --addon-name "$addon" \
                --profile "$PROFILE" \
                --region "$REGION" 2>/dev/null || true
        done
        sleep 5
    fi
    
    # Deletar cluster
    echo ""
    echo "🗑️  Deletando Cluster EKS..."
    aws eks delete-cluster --name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION"
    
    echo "  ⏳ Aguardando cluster ser deletado (2-3 minutos)..."
    aws eks wait cluster-deleted --name "$CLUSTER_NAME" --profile "$PROFILE" --region "$REGION" 2>/dev/null && echo "  ✅ Cluster deletado" || echo "  ⚠️  Timeout aguardando cluster (pode ainda estar sendo deletado)"
else
    echo "ℹ️  Cluster EKS não encontrado (já foi deletado ou não existe)"
fi

# 2. Deletar VPC e recursos de rede
echo ""
echo "🗑️  Deletando recursos de Networking..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-devopsproject-vpc" --query 'Vpcs[0].VpcId' --output text --profile "$PROFILE" 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "  ✅ VPC encontrada: $VPC_ID"
    
    # Deletar NAT Gateways
    echo "  → Deletando NAT Gateways..."
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State==`available`].NatGatewayId' --output text --profile "$PROFILE")
    for nat in $NAT_GATEWAYS; do
        echo "    • NAT Gateway: $nat"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --profile "$PROFILE" 2>/dev/null || true
    done
    
    if [ -n "$NAT_GATEWAYS" ]; then
        echo "  ⏳ Aguardando NAT Gateways serem deletados (60s)..."
        sleep 60
    fi
    
    # Deletar Elastic IPs
    echo "  → Liberando Elastic IPs..."
    EIPS=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=*nat-gateway-eip*" --query 'Addresses[].AllocationId' --output text --profile "$PROFILE")
    for eip in $EIPS; do
        echo "    • EIP: $eip"
        aws ec2 release-address --allocation-id "$eip" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Deletar Internet Gateway
    echo "  → Deletando Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --profile "$PROFILE")
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --profile "$PROFILE" 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --profile "$PROFILE" 2>/dev/null || true
    fi
    
    # Deletar Subnets
    echo "  → Deletando Subnets..."
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --profile "$PROFILE")
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id "$subnet" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Deletar Route Tables (exceto main)
    echo "  → Deletando Route Tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --profile "$PROFILE")
    for rt in $ROUTE_TABLES; do
        aws ec2 delete-route-table --route-table-id "$rt" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Deletar Security Groups (exceto default)
    echo "  → Deletando Security Groups..."
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --profile "$PROFILE")
    for sg in $SGS; do
        aws ec2 delete-security-group --group-id "$sg" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Deletar VPC
    echo "  → Deletando VPC..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --profile "$PROFILE" 2>/dev/null && echo "  ✅ VPC deletada" || echo "  ⚠️  Falha ao deletar VPC (pode ter recursos dependentes)"
else
    echo "  ℹ️  VPC não encontrada"
fi

# 3. Deletar recursos do Grafana/Prometheus
echo ""
echo "🗑️  Deletando Grafana e Prometheus..."

# Grafana Workspaces
GRAFANA_WORKSPACES=$(aws grafana list-workspaces --query 'workspaces[?tags.Project==`eks-devopsproject`].id' --output text --profile "$PROFILE" 2>/dev/null)
for ws in $GRAFANA_WORKSPACES; do
    echo "  → Deletando Grafana Workspace: $ws"
    aws grafana delete-workspace --workspace-id "$ws" --profile "$PROFILE" 2>/dev/null || true
done

# Prometheus Workspaces
PROMETHEUS_WORKSPACES=$(aws amp list-workspaces --query 'workspaces[?tags.Project==`eks-devopsproject`].workspaceId' --output text --profile "$PROFILE" 2>/dev/null)
for ws in $PROMETHEUS_WORKSPACES; do
    echo "  → Deletando Prometheus Workspace: $ws"
    aws amp delete-workspace --workspace-id "$ws" --profile "$PROFILE" 2>/dev/null || true
done

# 4. Deletar WAF
echo ""
echo "🗑️  Deletando WAF Web ACLs..."
WAF_ARNS=$(aws wafv2 list-web-acls --scope REGIONAL --region "$REGION" --query "WebACLs[?contains(Name, 'eks-devopsproject')].ARN" --output text --profile "$PROFILE" 2>/dev/null)

for arn in $WAF_ARNS; do
    echo "  → Deletando WAF: $arn"
    WAF_ID=$(echo "$arn" | awk -F'/' '{print $3}')
    WAF_NAME=$(echo "$arn" | awk -F'/' '{print $2}')
    LOCK_TOKEN=$(aws wafv2 get-web-acl --scope REGIONAL --region "$REGION" --id "$WAF_ID" --name "$WAF_NAME" --query 'LockToken' --output text --profile "$PROFILE" 2>/dev/null)
    
    if [ -n "$LOCK_TOKEN" ]; then
        aws wafv2 delete-web-acl --scope REGIONAL --region "$REGION" --id "$WAF_ID" --name "$WAF_NAME" --lock-token "$LOCK_TOKEN" --profile "$PROFILE" 2>/dev/null || true
    fi
done

# 5. Deletar IAM Roles
echo ""
echo "🗑️  Deletando IAM Roles..."

ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eks-devopsproject')].RoleName" --output text --profile "$PROFILE" 2>/dev/null)

for role in $ROLES; do
    echo "  → Deletando IAM Role: $role"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text --profile "$PROFILE" 2>/dev/null)
    for policy in $ATTACHED_POLICIES; do
        aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text --profile "$PROFILE" 2>/dev/null)
    for policy in $INLINE_POLICIES; do
        aws iam delete-role-policy --role-name "$role" --policy-name "$policy" --profile "$PROFILE" 2>/dev/null || true
    done
    
    # Delete role
    aws iam delete-role --role-name "$role" --profile "$PROFILE" 2>/dev/null || true
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          ✅ LIMPEZA EMERGENCIAL CONCLUÍDA                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  Verifique manualmente no Console AWS se todos os recursos foram deletados:"
echo "  • EKS Clusters"
echo "  • EC2 Instances"
echo "  • VPCs e Networking"
echo "  • Grafana/Prometheus Workspaces"
echo "  • WAF Web ACLs"
echo "  • IAM Roles"
echo ""
echo "💰 Custos devem estar ~$0/mês agora"
echo ""
