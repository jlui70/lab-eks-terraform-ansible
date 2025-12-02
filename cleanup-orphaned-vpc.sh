#!/bin/bash

#########################################
# Script de Limpeza Manual de VPC Órfã
# 
# USO: ./cleanup-orphaned-vpc.sh <VPC_ID>
# 
# Este script deleta manualmente recursos de VPC
# que ficaram órfãos após perda de Terraform state.
#########################################

set -e

# Configuração
VPC_ID="${1:-vpc-051466d77ed0f9a72}"
REGION="us-east-1"
PROFILE="terraform"

echo "════════════════════════════════════════════════════════════"
echo "🗑️  Limpeza Manual de VPC Órfã"
echo "════════════════════════════════════════════════════════════"
echo "VPC ID: $VPC_ID"
echo "Region: $REGION"
echo "Profile: $PROFILE"
echo ""
read -p "⚠️  Confirma a deleção? (yes/n): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Operação cancelada pelo usuário"
    exit 0
fi

echo ""
echo "Iniciando limpeza..."
echo ""

# 1. Deletar NAT Gateways
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Deletando NAT Gateways..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NAT_GWS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --region $REGION \
    --profile $PROFILE \
    --query 'NatGateways[*].NatGatewayId' \
    --output text)

if [ -n "$NAT_GWS" ]; then
    for nat in $NAT_GWS; do
        echo "   → Deletando NAT Gateway: $nat"
        aws ec2 delete-nat-gateway \
            --nat-gateway-id $nat \
            --region $REGION \
            --profile $PROFILE
    done
    
    echo "   ⏳ Aguardando NAT Gateways serem deletados (isso leva ~2 minutos)..."
    for nat in $NAT_GWS; do
        aws ec2 wait nat-gateway-deleted \
            --nat-gateway-ids $nat \
            --region $REGION \
            --profile $PROFILE 2>/dev/null || true
    done
    echo "   ✅ NAT Gateways deletados"
else
    echo "   ℹ️  Nenhum NAT Gateway encontrado"
fi
echo ""

# 2. Deletar Elastic IPs órfãos
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Liberando Elastic IPs órfãos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EIPS=$(aws ec2 describe-addresses \
    --region $REGION \
    --profile $PROFILE \
    --filters "Name=domain,Values=vpc" \
    --query "Addresses[?NetworkInterfaceId==null].AllocationId" \
    --output text)

if [ -n "$EIPS" ]; then
    for eip in $EIPS; do
        echo "   → Liberando EIP: $eip"
        aws ec2 release-address \
            --allocation-id $eip \
            --region $REGION \
            --profile $PROFILE 2>/dev/null || echo "   ⚠️  Erro ao liberar $eip (pode estar em uso)"
    done
    echo "   ✅ Elastic IPs liberados"
else
    echo "   ℹ️  Nenhum Elastic IP órfão encontrado"
fi
echo ""

# 3. Deletar Subnets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Deletando Subnets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $REGION \
    --profile $PROFILE \
    --query 'Subnets[*].SubnetId' \
    --output text)

if [ -n "$SUBNETS" ]; then
    for subnet in $SUBNETS; do
        echo "   → Deletando Subnet: $subnet"
        aws ec2 delete-subnet \
            --subnet-id $subnet \
            --region $REGION \
            --profile $PROFILE
    done
    echo "   ✅ Subnets deletadas"
else
    echo "   ℹ️  Nenhuma Subnet encontrada"
fi
echo ""

# 4. Deletar Internet Gateway
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Deletando Internet Gateway..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --region $REGION \
    --profile $PROFILE \
    --query 'InternetGateways[*].InternetGatewayId' \
    --output text)

if [ -n "$IGW" ]; then
    echo "   → Desanexando IGW: $IGW da VPC"
    aws ec2 detach-internet-gateway \
        --internet-gateway-id $IGW \
        --vpc-id $VPC_ID \
        --region $REGION \
        --profile $PROFILE
    
    echo "   → Deletando IGW: $IGW"
    aws ec2 delete-internet-gateway \
        --internet-gateway-id $IGW \
        --region $REGION \
        --profile $PROFILE
    echo "   ✅ Internet Gateway deletado"
else
    echo "   ℹ️  Nenhum Internet Gateway encontrado"
fi
echo ""

# 5. Deletar Route Tables customizadas
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Deletando Route Tables customizadas..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ROUTE_TABLES=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $REGION \
    --profile $PROFILE \
    --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
    --output text)

if [ -n "$ROUTE_TABLES" ]; then
    for rt in $ROUTE_TABLES; do
        echo "   → Deletando Route Table: $rt"
        aws ec2 delete-route-table \
            --route-table-id $rt \
            --region $REGION \
            --profile $PROFILE 2>/dev/null || echo "   ⚠️  Erro ao deletar $rt (pode ter associações)"
    done
    echo "   ✅ Route Tables deletadas"
else
    echo "   ℹ️  Nenhuma Route Table customizada encontrada"
fi
echo ""

# 6. Deletar VPC
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Deletando VPC..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if aws ec2 delete-vpc \
    --vpc-id $VPC_ID \
    --region $REGION \
    --profile $PROFILE 2>&1; then
    echo "   ✅ VPC $VPC_ID deletada com sucesso!"
else
    echo "   ⚠️  Erro ao deletar VPC"
    echo ""
    echo "Verifique se há recursos dependentes ainda ativos:"
    echo "   aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport --region $REGION --profile $PROFILE"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Limpeza concluída!"
echo "════════════════════════════════════════════════════════════"
