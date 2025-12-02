#!/bin/bash

# fix-stuck-s3-bucket.sh
# Script para esvaziar e deletar bucket S3 que ficou travado no destroy

set -e

BUCKET_NAME="eks-devopsproject-state-files-<YOUR_ACCOUNT>"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🔧 CORRIGINDO BUCKET S3 TRAVADO                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se bucket existe
echo "🔍 Verificando se bucket existe..."
if ! aws s3 ls "s3://$BUCKET_NAME" --profile terraform &>/dev/null; then
    echo "✅ Bucket não existe! Problema já resolvido."
    exit 0
fi

echo "⚠️  Bucket encontrado. Iniciando limpeza forçada..."
echo ""

# Método 1: Deletar todos os objetos atuais
echo "📦 Passo 1/4: Removendo objetos atuais..."
aws s3 rm "s3://$BUCKET_NAME" --recursive --profile terraform || true
echo "  ✅ Objetos atuais removidos"
echo ""

# Método 2: Listar e deletar todas as versões
echo "📦 Passo 2/4: Removendo versões antigas..."
VERSIONS=$(aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --profile terraform \
    --output json \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' 2>/dev/null)

if [ "$VERSIONS" != "null" ] && [ "$VERSIONS" != "[]" ] && [ "$VERSIONS" != "" ]; then
    echo "$VERSIONS" | jq -c '.[]' 2>/dev/null | while read version; do
        KEY=$(echo "$version" | jq -r '.Key')
        VERSION_ID=$(echo "$version" | jq -r '.VersionId')
        echo "  → Deletando: $KEY (versão: $VERSION_ID)"
        aws s3api delete-object \
            --bucket "$BUCKET_NAME" \
            --key "$KEY" \
            --version-id "$VERSION_ID" \
            --profile terraform 2>/dev/null || true
    done
    echo "  ✅ Versões antigas removidas"
else
    echo "  ℹ️  Nenhuma versão antiga encontrada"
fi
echo ""

# Método 3: Deletar delete markers
echo "📦 Passo 3/4: Removendo delete markers..."
MARKERS=$(aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --profile terraform \
    --output json \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' 2>/dev/null)

if [ "$MARKERS" != "null" ] && [ "$MARKERS" != "[]" ] && [ "$MARKERS" != "" ]; then
    echo "$MARKERS" | jq -c '.[]' 2>/dev/null | while read marker; do
        KEY=$(echo "$marker" | jq -r '.Key')
        VERSION_ID=$(echo "$marker" | jq -r '.VersionId')
        echo "  → Deletando marker: $KEY (versão: $VERSION_ID)"
        aws s3api delete-object \
            --bucket "$BUCKET_NAME" \
            --key "$KEY" \
            --version-id "$VERSION_ID" \
            --profile terraform 2>/dev/null || true
    done
    echo "  ✅ Delete markers removidos"
else
    echo "  ℹ️  Nenhum delete marker encontrado"
fi
echo ""

# Método 4: Forçar deleção do bucket
echo "🗑️  Passo 4/4: Deletando bucket S3..."
aws s3 rb "s3://$BUCKET_NAME" --force --profile terraform || {
    echo "⚠️  Falha com --force, tentando via API..."
    aws s3api delete-bucket \
        --bucket "$BUCKET_NAME" \
        --profile terraform || {
        echo "❌ Erro ao deletar bucket. Verifique manualmente no console AWS."
        exit 1
    }
}
echo "  ✅ Bucket deletado"
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ BUCKET S3 DELETADO COM SUCESSO!                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🎯 Próximo passo: Reexecutar destroy da Stack 00"
echo ""
echo "   cd 00-backend"
echo "   terraform destroy -auto-approve"
echo ""
