#!/bin/bash

# Script para verificar recursos que podem bloquear a destruição
# Execute ANTES de rodar destroy-all.sh
# Autor: DevOps Team
# Data: Dezembro 2025

set -e

PROFILE="terraform"
PROJECT_NAME="eks-devopsproject"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🔍 PRÉ-VALIDAÇÃO DE RECURSOS ANTES DO DESTROY              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Este script verifica recursos que podem bloquear a destruição"
echo "e sugere ações corretivas ANTES de executar destroy-all.sh"
echo ""

ISSUES_FOUND=0

# 1. Verificar Prometheus Scrapers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Verificando Prometheus Scrapers..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCRAPERS=$(aws amp list-scrapers --profile "$PROFILE" --query 'scrapers[].scraperId' --output text 2>/dev/null || echo "")

if [ -n "$SCRAPERS" ]; then
    echo "⚠️  ATENÇÃO: Encontrados Prometheus Scrapers ativos!"
    echo ""
    for scraper in $SCRAPERS; do
        DETAILS=$(aws amp describe-scraper --scraper-id "$scraper" --profile "$PROFILE" --query 'scraper.{Status:status.statusCode,Source:source.eks.clusterArn,Subnets:source.eks.subnetIds}' --output json 2>/dev/null)
        echo "  📊 Scraper: $scraper"
        echo "     $DETAILS" | jq '.'
    done
    echo ""
    echo "  ⚠️  RISCO: Scrapers criam ENIs gerenciadas que levam ~5min para serem"
    echo "     liberadas após o 'terraform destroy'. Isso pode bloquear a"
    echo "     destruição da VPC/Subnets."
    echo ""
    echo "  ✅ AÇÃO: O destroy-all.sh já tem proteção automática (aguarda 10min)"
    echo "     Caso falhe, use: ./cleanup-vpc-final.sh"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo "✅ Nenhum Prometheus Scraper encontrado"
fi
echo ""

# 2. Verificar ENIs órfãs (amp_collector)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Verificando ENIs do Prometheus (amp_collector)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

AMP_ENIS=$(aws ec2 describe-network-interfaces \
    --filters "Name=interface-type,Values=amp_collector" \
    --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status,Subnet:SubnetId}' \
    --output json \
    --profile "$PROFILE" 2>/dev/null || echo "[]")

AMP_ENI_COUNT=$(echo "$AMP_ENIS" | jq 'length')

if [ "$AMP_ENI_COUNT" -gt 0 ]; then
    echo "⚠️  ATENÇÃO: Encontradas $AMP_ENI_COUNT ENI(s) do Prometheus!"
    echo "$AMP_ENIS" | jq '.'
    echo ""
    echo "  ⚠️  RISCO: Estas ENIs são gerenciadas pela AWS e não podem ser deletadas"
    echo "     manualmente. Você DEVE deletar o Prometheus Scraper primeiro."
    echo ""
    echo "  ✅ AÇÃO: Execute 'terraform destroy' na Stack 05 OU delete via CLI:"
    for scraper_id in $SCRAPERS; do
        echo "     aws amp delete-scraper --scraper-id $scraper_id --profile $PROFILE"
    done
    echo "     Depois aguarde ~5min para ENIs serem liberadas"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo "✅ Nenhuma ENI do Prometheus encontrada"
fi
echo ""

# 3. Verificar ALBs (Load Balancers criados pelo Ingress Controller)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Verificando Application Load Balancers (ALBs)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ALBS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].{Name:LoadBalancerName,ARN:LoadBalancerArn,State:State.Code}" \
    --output json \
    --profile "$PROFILE" 2>/dev/null || echo "[]")

ALB_COUNT=$(echo "$ALBS" | jq 'length')

if [ "$ALB_COUNT" -gt 0 ]; then
    echo "⚠️  ATENÇÃO: Encontrados $ALB_COUNT ALB(s) criados pelo Kubernetes!"
    echo "$ALBS" | jq '.'
    echo ""
    echo "  ⚠️  RISCO: ALBs criados por Ingress/Service não são gerenciados pelo Terraform."
    echo "     Se não deletados, bloquearão a destruição de Security Groups e VPC."
    echo ""
    echo "  ✅ AÇÃO: O destroy-all.sh já deleta recursos Kubernetes automaticamente."
    echo "     Se falhar, delete manualmente:"
    echo "     kubectl delete ingress --all --all-namespaces"
    echo "     kubectl delete namespace ecommerce"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo "✅ Nenhum ALB do Kubernetes encontrado"
fi
echo ""

# 4. Verificar EKS Cluster
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Verificando EKS Cluster..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CLUSTER=$(aws eks describe-cluster --name "$PROJECT_NAME-cluster" --profile "$PROFILE" --query 'cluster.{Name:name,Status:status,Version:version}' --output json 2>/dev/null || echo "{}")

if [ "$CLUSTER" != "{}" ]; then
    echo "✅ EKS Cluster encontrado:"
    echo "$CLUSTER" | jq '.'
    echo ""
    echo "  ℹ️  Cluster será destruído automaticamente pelo destroy-all.sh"
else
    echo "ℹ️  Nenhum EKS Cluster encontrado (já foi destruído ou nunca foi criado)"
fi
echo ""

# 5. Verificar Grafana Workspaces
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Verificando Grafana Workspaces..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

GRAFANA=$(aws grafana list-workspaces --profile "$PROFILE" --query 'workspaces[].{ID:id,Name:name,Status:status}' --output json 2>/dev/null || echo "[]")
GRAFANA_COUNT=$(echo "$GRAFANA" | jq 'length')

if [ "$GRAFANA_COUNT" -gt 0 ]; then
    echo "✅ Encontrados $GRAFANA_COUNT Grafana Workspace(s):"
    echo "$GRAFANA" | jq '.'
    echo "  ℹ️  Serão destruídos automaticamente pelo destroy-all.sh"
else
    echo "ℹ️  Nenhum Grafana Workspace encontrado"
fi
echo ""

# 6. Verificar Prometheus Workspaces
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Verificando Prometheus Workspaces..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROMETHEUS=$(aws amp list-workspaces --profile "$PROFILE" --query 'workspaces[].{Alias:alias,ID:workspaceId,Status:status.statusCode}' --output json 2>/dev/null || echo "[]")
PROM_COUNT=$(echo "$PROMETHEUS" | jq 'length')

if [ "$PROM_COUNT" -gt 0 ]; then
    echo "✅ Encontrados $PROM_COUNT Prometheus Workspace(s):"
    echo "$PROMETHEUS" | jq '.'
    echo "  ℹ️  Serão destruídos automaticamente pelo destroy-all.sh"
else
    echo "ℹ️  Nenhum Prometheus Workspace encontrado"
fi
echo ""

# 7. Verificar WAF Web ACLs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  Verificando WAF Web ACLs..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WAF=$(aws wafv2 list-web-acls --scope REGIONAL --profile "$PROFILE" --query "WebACLs[?contains(Name, '$PROJECT_NAME')].{Name:Name,ID:Id,ARN:ARN}" --output json 2>/dev/null || echo "[]")
WAF_COUNT=$(echo "$WAF" | jq 'length')

if [ "$WAF_COUNT" -gt 0 ]; then
    echo "✅ Encontrados $WAF_COUNT WAF Web ACL(s):"
    echo "$WAF" | jq '.'
    echo "  ℹ️  Serão destruídos automaticamente pelo destroy-all.sh"
else
    echo "ℹ️  Nenhum WAF Web ACL encontrado"
fi
echo ""

# RESUMO FINAL
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    📊 RESUMO DA VALIDAÇÃO                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ TUDO OK! Pode executar destroy-all.sh com segurança."
    echo ""
    echo "🚀 Próximo passo:"
    echo "   ./destroy-all.sh"
    echo ""
    exit 0
else
    echo "⚠️  ENCONTRADOS $ISSUES_FOUND PROBLEMA(S) QUE PODEM BLOQUEAR O DESTROY!"
    echo ""
    echo "📋 Recomendações:"
    echo ""
    echo "  1️⃣  Prometheus Scrapers/ENIs:"
    echo "     → O destroy-all.sh JÁ tem proteção automática (aguarda 10min)"
    echo "     → Se ainda falhar, use: ./cleanup-vpc-final.sh"
    echo ""
    echo "  2️⃣  ALBs do Kubernetes:"
    echo "     → O destroy-all.sh JÁ deleta recursos Kubernetes primeiro"
    echo "     → Se quiser deletar manualmente antes:"
    echo "       kubectl delete namespace ecommerce"
    echo "       kubectl delete namespace sample-app"
    echo ""
    echo "  3️⃣  Outros recursos (Grafana, Prometheus Workspaces, WAF):"
    echo "     → Serão destruídos automaticamente pelo Terraform"
    echo ""
    echo "✅ PODE PROSSEGUIR COM:"
    echo "   ./destroy-all.sh"
    echo ""
    echo "💡 Este script é apenas INFORMATIVO. O destroy-all.sh já tem todas"
    echo "   as proteções necessárias implementadas!"
    echo ""
    exit 0
fi
