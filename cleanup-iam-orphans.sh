#!/bin/bash

# Script para limpar IAM Roles/Policies órfãs
# Versão: 1.0
# Data: 02 de Dezembro de 2025
# Uso: ./cleanup-iam-orphans.sh

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   🧹 LIMPEZA DE IAM ROLES/POLICIES ÓRFÃS                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  Este script deleta IAM Roles/Policies que podem ter ficado órfãs"
echo "   após um terraform destroy incompleto ou reinstalação do lab."
echo ""
echo "📋 Recursos que serão verificados e deletados (se existirem):"
echo "   • AmazonEKS_EFS_CSI_DriverRole"
echo "   • aws-load-balancer-controller"
echo "   • eks-devopsproject-node-group-role"
echo "   • eks-devopsproject-cluster-role"
echo "   • external-dns-irsa-role"
echo "   • KarpenterControllerRole"
echo "   • KarpenterNodeRole"
echo "   • GrafanaWorkspaceRole"
echo "   • AWSLoadBalancerControllerIAMPolicy"
echo "   • KarpenterControllerPolicy"
echo ""

# Verificar se profile terraform existe
if ! aws sts get-caller-identity --profile terraform &>/dev/null; then
    echo "❌ Erro: Profile 'terraform' não configurado ou credenciais inválidas"
    echo ""
    echo "Configure com:"
    echo "  aws configure --profile terraform"
    exit 1
fi

# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Erro: Não foi possível obter Account ID"
    exit 1
fi

echo "📊 Account ID: $ACCOUNT_ID"
echo ""

read -p "Continuar com a limpeza? (s/N): " confirm

if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "⏸️  Limpeza cancelada pelo usuário"
    exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Iniciando limpeza..."
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Função auxiliar para deletar role IAM (detach policies primeiro)
delete_iam_role() {
    local role_name=$1
    
    if aws iam get-role --role-name "$role_name" --profile terraform &>/dev/null; then
        echo "  🔍 Role encontrada: $role_name"
        
        # Detach managed policies
        echo "    → Detaching managed policies..."
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$role_name" \
            --profile terraform \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$ATTACHED_POLICIES" ]; then
            for policy_arn in $ATTACHED_POLICIES; do
                echo "      • Detaching: $policy_arn"
                aws iam detach-role-policy \
                    --role-name "$role_name" \
                    --policy-arn "$policy_arn" \
                    --profile terraform 2>/dev/null || true
            done
        else
            echo "      ℹ️  Nenhuma managed policy attached"
        fi
        
        # Delete inline policies
        echo "    → Deletando inline policies..."
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$role_name" \
            --profile terraform \
            --query 'PolicyNames[]' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$INLINE_POLICIES" ]; then
            for policy_name in $INLINE_POLICIES; do
                echo "      • Deleting inline policy: $policy_name"
                aws iam delete-role-policy \
                    --role-name "$role_name" \
                    --policy-name "$policy_name" \
                    --profile terraform 2>/dev/null || true
            done
        else
            echo "      ℹ️  Nenhuma inline policy encontrada"
        fi
        
        # Remove instance profiles (se houver)
        echo "    → Removendo instance profiles..."
        INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role \
            --role-name "$role_name" \
            --profile terraform \
            --query 'InstanceProfiles[].InstanceProfileName' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$INSTANCE_PROFILES" ]; then
            for profile_name in $INSTANCE_PROFILES; do
                echo "      • Removing from instance profile: $profile_name"
                aws iam remove-role-from-instance-profile \
                    --instance-profile-name "$profile_name" \
                    --role-name "$role_name" \
                    --profile terraform 2>/dev/null || true
                
                # Deletar o instance profile órfão (criado pelo EKS)
                echo "      • Deleting orphan instance profile: $profile_name"
                aws iam delete-instance-profile \
                    --instance-profile-name "$profile_name" \
                    --profile terraform 2>/dev/null || true
            done
        else
            echo "      ℹ️  Nenhum instance profile associado"
        fi
        
        # Delete role
        echo "    → Deletando role..."
        if aws iam delete-role --role-name "$role_name" --profile terraform 2>/dev/null; then
            echo "  ✅ Role $role_name deletada com sucesso"
        else
            echo "  ⚠️  Não foi possível deletar role $role_name"
        fi
    else
        echo "  ℹ️  Role $role_name não encontrada (OK)"
    fi
    echo ""
}

# Função para deletar policy IAM
delete_iam_policy() {
    local policy_name=$1
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"
    
    if aws iam get-policy --policy-arn "$policy_arn" --profile terraform &>/dev/null; then
        echo "  🔍 Policy encontrada: $policy_name"
        
        # Verificar se está attached a alguma role
        echo "    → Verificando attachments..."
        ATTACHED_COUNT=$(aws iam list-entities-for-policy \
            --policy-arn "$policy_arn" \
            --profile terraform \
            --query 'length(PolicyRoles) + length(PolicyUsers) + length(PolicyGroups)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$ATTACHED_COUNT" != "0" ]; then
            echo "    ⚠️  Policy está attached a $ATTACHED_COUNT entidade(s)"
            echo "    → Detaching de todas as entidades..."
            
            # Detach de roles
            ROLES=$(aws iam list-entities-for-policy \
                --policy-arn "$policy_arn" \
                --profile terraform \
                --query 'PolicyRoles[].RoleName' \
                --output text 2>/dev/null || echo "")
            
            for role in $ROLES; do
                echo "      • Detaching de role: $role"
                aws iam detach-role-policy \
                    --role-name "$role" \
                    --policy-arn "$policy_arn" \
                    --profile terraform 2>/dev/null || true
            done
        fi
        
        # Deletar todas as versões antigas (não-default)
        echo "    → Deletando versões antigas..."
        VERSIONS=$(aws iam list-policy-versions \
            --policy-arn "$policy_arn" \
            --profile terraform \
            --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
            --output text 2>/dev/null || echo "")
        
        for version in $VERSIONS; do
            aws iam delete-policy-version \
                --policy-arn "$policy_arn" \
                --version-id "$version" \
                --profile terraform 2>/dev/null || true
        done
        
        # Delete policy
        echo "    → Deletando policy..."
        if aws iam delete-policy --policy-arn "$policy_arn" --profile terraform 2>/dev/null; then
            echo "  ✅ Policy $policy_name deletada com sucesso"
        else
            echo "  ⚠️  Não foi possível deletar policy $policy_name"
        fi
    else
        echo "  ℹ️  Policy $policy_name não encontrada (OK)"
    fi
    echo ""
}

# Deletar roles da Stack 02 (EKS Cluster)
echo "🗂️  Stack 02 - EKS Cluster Roles"
echo "─────────────────────────────────────────────────────────────────"
delete_iam_role "AmazonEKS_EFS_CSI_DriverRole"
delete_iam_role "aws-load-balancer-controller"
delete_iam_role "eks-devopsproject-node-group-role"
delete_iam_role "eks-devopsproject-cluster-role"
delete_iam_role "external-dns-irsa-role"

# Deletar roles da Stack 03 (Karpenter)
echo "🗂️  Stack 03 - Karpenter Roles"
echo "─────────────────────────────────────────────────────────────────"
delete_iam_role "KarpenterControllerRole"
delete_iam_role "KarpenterNodeRole"

# Deletar roles da Stack 05 (Monitoring)
echo "🗂️  Stack 05 - Monitoring Roles"
echo "─────────────────────────────────────────────────────────────────"
delete_iam_role "GrafanaWorkspaceRole"

# Deletar policies standalone
echo "📜 Policies Standalone"
echo "─────────────────────────────────────────────────────────────────"
delete_iam_policy "AWSLoadBalancerControllerIAMPolicy"
delete_iam_policy "KarpenterControllerPolicy"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ LIMPEZA CONCLUÍDA!                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 Próximos passos:"
echo "   1. Se estava fazendo terraform apply: rode novamente"
echo "      → cd 02-eks-cluster && terraform apply -auto-approve"
echo ""
echo "   2. Se vai reinstalar tudo do zero:"
echo "      → ./rebuild-all.sh"
echo ""
