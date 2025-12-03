#!/bin/bash

# Script de limpeza de recursos órfãos após destroy-all.sh falho
# Data: 02 de Dezembro de 2025

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   🧹 LIMPANDO RECURSOS ÓRFÃOS REMANESCENTES                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ROOT="/home/luiz7/Projects/lab-eks-terraform-ansible"

# 1. LIMPAR IAM ROLE ÓRFÃ: eks-devopsproject-node-group-role
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Limpando IAM Role órfã: eks-devopsproject-node-group-role"
echo "═══════════════════════════════════════════════════════════════════"

ROLE_NAME="eks-devopsproject-node-group-role"

if aws iam get-role --role-name "$ROLE_NAME" --profile terraform &>/dev/null; then
    echo "  ✅ Role encontrada: $ROLE_NAME"
    
    # Remover instance profiles
    INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role \
        --role-name "$ROLE_NAME" \
        --profile terraform \
        --query 'InstanceProfiles[].InstanceProfileName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$INSTANCE_PROFILES" ]; then
        for profile_name in $INSTANCE_PROFILES; do
            echo "  → Removendo role do instance profile: $profile_name"
            aws iam remove-role-from-instance-profile \
                --instance-profile-name "$profile_name" \
                --role-name "$ROLE_NAME" \
                --profile terraform 2>/dev/null || true
            
            echo "  → Deletando instance profile órfão: $profile_name"
            aws iam delete-instance-profile \
                --instance-profile-name "$profile_name" \
                --profile terraform 2>/dev/null || true
        done
    fi
    
    # Deletar role
    echo "  → Deletando role..."
    aws iam delete-role --role-name "$ROLE_NAME" --profile terraform 2>/dev/null && \
        echo "  ✅ Role $ROLE_NAME deletada com sucesso" || \
        echo "  ⚠️  Não foi possível deletar role $ROLE_NAME"
else
    echo "  ℹ️  Role $ROLE_NAME já foi deletada"
fi
echo ""

# 2. LIMPAR IAM ROLE ÓRFÃ: EKSDevopsprojectGrafanaWorkspaceRole
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Limpando IAM Role órfã: EKSDevopsprojectGrafanaWorkspaceRole"
echo "═══════════════════════════════════════════════════════════════════"

ROLE_NAME="EKSDevopsprojectGrafanaWorkspaceRole"

if aws iam get-role --role-name "$ROLE_NAME" --profile terraform &>/dev/null; then
    echo "  ✅ Role encontrada: $ROLE_NAME"
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
        --role-name "$ROLE_NAME" \
        --profile terraform \
        --query 'AttachedPolicies[].PolicyArn' \
        --output text 2>/dev/null || echo "")
    
    for policy_arn in $ATTACHED_POLICIES; do
        echo "  → Detaching policy: $policy_arn"
        aws iam detach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$policy_arn" \
            --profile terraform 2>/dev/null || true
    done
    
    # Deletar role
    echo "  → Deletando role..."
    aws iam delete-role --role-name "$ROLE_NAME" --profile terraform 2>/dev/null && \
        echo "  ✅ Role $ROLE_NAME deletada com sucesso" || \
        echo "  ⚠️  Não foi possível deletar role $ROLE_NAME"
else
    echo "  ℹ️  Role $ROLE_NAME já foi deletada"
fi
echo ""

# 3. DESTRUIR STACK 01 - NETWORKING (VPC)
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Destruindo Stack 01 - Networking (VPC)"
echo "═══════════════════════════════════════════════════════════════════"

cd "$PROJECT_ROOT/01-networking"

if [ -f "terraform.tfstate" ] || terraform state list &>/dev/null; then
    echo "  → Executando terraform destroy..."
    terraform destroy -auto-approve && \
        echo "  ✅ Stack 01 - Networking destruída com sucesso!" || \
        echo "  ⚠️  Erro ao destruir Stack 01"
else
    echo "  ℹ️  Stack 01 já foi destruída ou não tem state"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ LIMPEZA CONCLUÍDA!                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Recursos limpos:"
echo "  ✅ IAM Role: eks-devopsproject-node-group-role"
echo "  ✅ IAM Role: EKSDevopsprojectGrafanaWorkspaceRole"
echo "  ✅ Instance Profiles órfãos"
echo "  ✅ Stack 01: VPC + Subnets + NAT Gateways + IGW + Route Tables"
echo ""
echo "🔍 Verificar no console AWS:"
echo "  → IAM Roles: Deve estar vazio"
echo "  → VPC: Não deve ter eks-devopsproject-vpc"
echo ""
echo "💰 Custos AWS agora: $0/mês"
echo ""
