#!/bin/bash
# ============================================================================
# Script: Validação da Aplicação E-commerce
# ============================================================================
# 
# Objetivo: Validar deploy e saúde da aplicação e-commerce
#
# Uso: ./validate-ecommerce.sh
#
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
NAMESPACE="ecommerce"
EXPECTED_PODS=7
INGRESS_NAME="ecommerce-ingress"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  E-COMMERCE APPLICATION - VALIDAÇÃO DE DEPLOYMENT             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Validação 1: Namespace existe
# ============================================================================
echo -e "${YELLOW}[1/8]${NC} Verificando namespace..."

if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}✅ Namespace '$NAMESPACE' existe${NC}"
else
    echo -e "${RED}❌ Namespace '$NAMESPACE' não encontrado${NC}"
    echo -e "${RED}Execute: ansible-playbook ansible/playbooks/03-deploy-ecommerce.yml${NC}"
    exit 1
fi

# ============================================================================
# Validação 2: Pods estão running
# ============================================================================
echo -e "${YELLOW}[2/8]${NC} Verificando status dos pods..."

RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$RUNNING_PODS" -eq "$EXPECTED_PODS" ]; then
    echo -e "${GREEN}✅ Todos os $EXPECTED_PODS pods estão Running${NC}"
else
    echo -e "${RED}❌ Apenas $RUNNING_PODS de $EXPECTED_PODS pods estão Running${NC}"
    echo ""
    echo "Status dos pods:"
    kubectl get pods -n $NAMESPACE
    exit 1
fi

# ============================================================================
# Validação 3: Pods prontos (Ready)
# ============================================================================
echo -e "${YELLOW}[3/8]${NC} Verificando readiness dos pods..."

NOT_READY=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v "1/1" | wc -l)

if [ "$NOT_READY" -eq "0" ]; then
    echo -e "${GREEN}✅ Todos os pods estão Ready (1/1)${NC}"
else
    echo -e "${RED}❌ $NOT_READY pod(s) não estão Ready${NC}"
    kubectl get pods -n $NAMESPACE
    exit 1
fi

# ============================================================================
# Validação 4: Services existem
# ============================================================================
echo -e "${YELLOW}[4/8]${NC} Verificando services..."

SERVICES_COUNT=$(kubectl get svc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)

if [ "$SERVICES_COUNT" -ge "$EXPECTED_PODS" ]; then
    echo -e "${GREEN}✅ $SERVICES_COUNT services criados${NC}"
else
    echo -e "${RED}❌ Esperava $EXPECTED_PODS services, encontrados $SERVICES_COUNT${NC}"
    exit 1
fi

# ============================================================================
# Validação 5: Ingress existe e tem ALB provisionado
# ============================================================================
echo -e "${YELLOW}[5/8]${NC} Verificando Ingress e ALB..."

if ! kubectl get ingress $INGRESS_NAME -n $NAMESPACE &>/dev/null; then
    echo -e "${RED}❌ Ingress '$INGRESS_NAME' não encontrado${NC}"
    exit 1
fi

ALB_HOSTNAME=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ALB_HOSTNAME" ]; then
    echo -e "${RED}❌ ALB não foi provisionado ainda${NC}"
    echo -e "${YELLOW}Aguardando provisionamento do ALB...${NC}"
    exit 1
else
    echo -e "${GREEN}✅ ALB provisionado: $ALB_HOSTNAME${NC}"
fi

# ============================================================================
# Validação 6: ALB responde (HTTP health check)
# ============================================================================
echo -e "${YELLOW}[6/8]${NC} Testando conectividade HTTP com ALB..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_HOSTNAME --connect-timeout 10 || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "404" ]; then
    echo -e "${GREEN}✅ ALB respondendo (HTTP $HTTP_STATUS)${NC}"
else
    echo -e "${RED}❌ ALB não respondeu (HTTP $HTTP_STATUS)${NC}"
    echo -e "${YELLOW}Aguarde alguns minutos para DNS do ALB propagar${NC}"
    exit 1
fi

# ============================================================================
# Validação 7: Verificar container restarts
# ============================================================================
echo -e "${YELLOW}[7/8]${NC} Verificando restarts de containers..."

RESTART_COUNT=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null | tr ' ' '\n' | awk '{s+=$1} END {print s}')

if [ -z "$RESTART_COUNT" ] || [ "$RESTART_COUNT" = "0" ]; then
    echo -e "${GREEN}✅ Nenhum restart detectado${NC}"
else
    echo -e "${YELLOW}⚠️  Total de restarts: $RESTART_COUNT${NC}"
    echo -e "${YELLOW}Verifique logs: kubectl logs -f deployment/<deployment-name> -n $NAMESPACE${NC}"
fi

# ============================================================================
# Validação 8: Verificar logs de erro
# ============================================================================
echo -e "${YELLOW}[8/8]${NC} Verificando logs de erro..."

ERROR_COUNT=$(kubectl logs --tail=100 --all-containers=true -n $NAMESPACE --selector=app 2>/dev/null | grep -i "error" | wc -l || echo "0")

if [ "$ERROR_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✅ Nenhum erro crítico nos logs recentes${NC}"
else
    echo -e "${YELLOW}⚠️  $ERROR_COUNT linha(s) com 'error' encontradas nos logs${NC}"
    echo -e "${YELLOW}Revise: kubectl logs -f deployment/<deployment-name> -n $NAMESPACE${NC}"
fi

# ============================================================================
# Resumo Final
# ============================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✅ VALIDAÇÃO CONCLUÍDA COM SUCESSO                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Resumo:${NC}"
echo -e "   • Namespace: ${GREEN}$NAMESPACE${NC}"
echo -e "   • Pods Running: ${GREEN}$RUNNING_PODS/$EXPECTED_PODS${NC}"
echo -e "   • Services: ${GREEN}$SERVICES_COUNT${NC}"
echo -e "   • ALB Hostname: ${GREEN}$ALB_HOSTNAME${NC}"
echo -e "   • HTTP Status: ${GREEN}$HTTP_STATUS${NC}"
echo -e "   • Restarts: ${GREEN}${RESTART_COUNT:-0}${NC}"
echo ""
echo -e "${GREEN}🌐 URLs de Acesso:${NC}"
echo -e "   • ALB Direto: ${BLUE}http://$ALB_HOSTNAME${NC}"
echo -e "   • DNS Personalizado: ${BLUE}http://eks.devopsproject.com.br${NC}"
echo ""
echo -e "${GREEN}📋 Comandos Úteis:${NC}"
echo -e "   • Ver pods:     ${BLUE}kubectl get pods -n $NAMESPACE${NC}"
echo -e "   • Ver services: ${BLUE}kubectl get svc -n $NAMESPACE${NC}"
echo -e "   • Ver ingress:  ${BLUE}kubectl get ingress -n $NAMESPACE${NC}"
echo -e "   • Logs UI:      ${BLUE}kubectl logs -f deployment/ecommerce-ui -n $NAMESPACE${NC}"
echo ""
echo -e "${GREEN}✨ Aplicação validada e pronta para uso!${NC}"
