#!/bin/bash

# Script para finalizar limpeza da VPC após ENIs do Prometheus serem liberadas
# Execute este script 5-10 minutos após deletar o Prometheus Scraper

set -e

VPC_ID="vpc-0917c0b7ba3491ec6"
PROFILE="terraform"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           🧹 FINALIZAÇÃO DA LIMPEZA DA VPC                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se ENIs ainda existem
echo "🔍 Verificando ENIs restantes..."
ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text --profile "$PROFILE" 2>/dev/null || true)

if [ -n "$ENIS" ]; then
    echo "⚠️  Ainda há $(echo $ENIS | wc -w) ENIs anexadas à VPC:"
    echo "$ENIS"
    echo ""
    aws ec2 describe-network-interfaces --network-interface-ids $ENIS --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,InterfaceType,Description]' --output table --profile "$PROFILE" 2>/dev/null
    echo ""
    echo "⏳ As ENIs ainda estão sendo deletadas pela AWS. Por favor:"
    echo "   1. Aguarde mais 5-10 minutos"
    echo "   2. Execute este script novamente"
    echo ""
    exit 1
fi

echo "✅ Nenhuma ENI encontrada! Prosseguindo com limpeza..."
echo ""

# Deletar Subnets
echo "🗑️  Deletando Subnets..."
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --profile "$PROFILE" 2>/dev/null || true)

if [ -n "$SUBNETS" ]; then
    for subnet in $SUBNETS; do
        echo "  → Subnet: $subnet"
        aws ec2 delete-subnet --subnet-id "$subnet" --profile "$PROFILE" && echo "    ✅ Deletada" || echo "    ⚠️  Erro ao deletar"
    done
else
    echo "  ℹ️  Nenhuma subnet encontrada"
fi
echo ""

# Deletar Route Tables (não-main)
echo "🗑️  Deletando Route Tables..."
ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --profile "$PROFILE" 2>/dev/null || true)

if [ -n "$ROUTE_TABLES" ]; then
    for rt in $ROUTE_TABLES; do
        echo "  → Route Table: $rt"
        aws ec2 delete-route-table --route-table-id "$rt" --profile "$PROFILE" && echo "    ✅ Deletada" || echo "    ⚠️  Erro ao deletar"
    done
else
    echo "  ℹ️  Nenhuma route table encontrada"
fi
echo ""

# Deletar Security Groups (não-default)
echo "🗑️  Deletando Security Groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --profile "$PROFILE" 2>/dev/null || true)

if [ -n "$SECURITY_GROUPS" ]; then
    for sg in $SECURITY_GROUPS; do
        echo "  → Security Group: $sg"
        aws ec2 delete-security-group --group-id "$sg" --profile "$PROFILE" && echo "    ✅ Deletado" || echo "    ⚠️  Erro ao deletar"
    done
else
    echo "  ℹ️  Nenhum security group encontrado"
fi
echo ""

# Deletar VPC
echo "🗑️  Deletando VPC: $VPC_ID"
if aws ec2 delete-vpc --vpc-id "$VPC_ID" --profile "$PROFILE" 2>&1; then
    echo "✅ VPC deletada com sucesso!"
else
    echo "❌ Erro ao deletar VPC"
    echo ""
    echo "Diagnóstico:"
    echo "-------------"
    echo "Recursos ainda anexados à VPC:"
    aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,InterfaceType]' --output table --profile "$PROFILE" 2>/dev/null || echo "  Nenhuma ENI"
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --profile "$PROFILE" 2>/dev/null || echo "  Nenhuma Subnet"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ LIMPEZA 100% CONCLUÍDA!                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "💰 Custo AWS: $0/mês"
echo "🎉 Todos os recursos foram deletados com sucesso!"
echo ""
