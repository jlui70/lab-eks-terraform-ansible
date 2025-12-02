#!/bin/bash

# validate-pre-commit.sh
# Script para validar segurança antes de commit no GitHub

set -e

echo "🔍 Validando segurança do repositório..."
echo ""

ERRORS=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}✅${NC} $1"
}

check_fail() {
    echo -e "${RED}❌${NC} $1"
    ERRORS=$((ERRORS + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Verificando .gitignore"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f ".gitignore" ]; then
    check_pass ".gitignore existe"
    
    if grep -q "*.tfstate" .gitignore; then
        check_pass ".gitignore bloqueia *.tfstate"
    else
        check_fail ".gitignore NÃO bloqueia *.tfstate"
    fi
    
    if grep -q "*.tfvars" .gitignore; then
        check_pass ".gitignore bloqueia *.tfvars"
    else
        check_fail ".gitignore NÃO bloqueia *.tfvars"
    fi
    
    if grep -q ".terraform" .gitignore; then
        check_pass ".gitignore bloqueia .terraform/"
    else
        check_fail ".gitignore NÃO bloqueia .terraform/"
    fi
else
    check_fail ".gitignore NÃO existe!"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Procurando arquivos sensíveis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar .tfstate
if find . -name "*.tfstate*" -not -path "./.git/*" | grep -q .; then
    check_warn "Arquivos .tfstate encontrados (mas ignorados pelo .gitignore):"
    find . -name "*.tfstate*" -not -path "./.git/*"
else
    check_pass "Nenhum arquivo .tfstate encontrado"
fi

# Verificar .terraform/
if find . -type d -name ".terraform" -not -path "./.git/*" | grep -q .; then
    check_warn "Diretórios .terraform/ encontrados (serão ignorados pelo git):"
    find . -type d -name ".terraform" -not -path "./.git/*"
else
    check_pass "Nenhum diretório .terraform/ encontrado"
fi

# Verificar .tfvars
if find . -name "*.tfvars" -not -path "./.git/*" | grep -q .; then
    check_warn "Arquivos .tfvars encontrados (verifique se contêm dados sensíveis):"
    find . -name "*.tfvars" -not -path "./.git/*"
else
    check_pass "Nenhum arquivo .tfvars encontrado"
fi

# Verificar .env
if find . -name ".env*" -not -path "./.git/*" | grep -q .; then
    check_fail "Arquivos .env encontrados:"
    find . -name ".env*" -not -path "./.git/*"
else
    check_pass "Nenhum arquivo .env encontrado"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Procurando dados sensíveis no código"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Buscar Account ID real (excluir README.md onde é exemplo)
if grep -r "<YOUR_ACCOUNT>" . \
    --exclude-dir=.git \
    --exclude-dir=docs \
    --exclude-dir=.terraform \
    --exclude="README.md" \
    --exclude="CHECKLIST-PRE-COMMIT.md" \
    --exclude="RESUMO-VALIDACAO-GITHUB.md" \
    --exclude="validate-pre-commit.sh" 2>/dev/null | grep -q .; then
    check_warn "Account ID <YOUR_ACCOUNT> encontrado em:"
    grep -r "<YOUR_ACCOUNT>" . \
        --exclude-dir=.git \
        --exclude-dir=docs \
        --exclude-dir=.terraform \
        --exclude="README.md" \
        --exclude="CHECKLIST-PRE-COMMIT.md" \
        --exclude="RESUMO-VALIDACAO-GITHUB.md" \
        --exclude="validate-pre-commit.sh" 2>/dev/null | cut -d: -f1 | sort -u
    echo ""
    echo "   ⚠️  Isso é OK se você JÁ substituiu por placeholders"
    echo "   ⚠️  Se forem valores REAIS, substitua antes do commit"
else
    check_pass "Nenhum Account ID hardcoded encontrado"
fi

# Buscar username específico
if grep -r "devops-lui" . \
    --exclude-dir=.git \
    --exclude-dir=docs \
    --exclude="CHECKLIST-PRE-COMMIT.md" \
    --exclude="RESUMO-VALIDACAO-GITHUB.md" \
    --exclude="validate-pre-commit.sh" 2>/dev/null | grep -q .; then
    check_fail "Username 'devops-lui' encontrado em:"
    grep -r "devops-lui" . \
        --exclude-dir=.git \
        --exclude-dir=docs \
        --exclude="CHECKLIST-PRE-COMMIT.md" \
        --exclude="RESUMO-VALIDACAO-GITHUB.md" \
        --exclude="validate-pre-commit.sh" 2>/dev/null | cut -d: -f1 | sort -u
else
    check_pass "Nenhum username específico encontrado"
fi

# Buscar SSO Role ID
if grep -r "a08e3792465d3f04" . \
    --exclude-dir=.git \
    --exclude-dir=docs \
    --exclude="CHECKLIST-PRE-COMMIT.md" \
    --exclude="RESUMO-VALIDACAO-GITHUB.md" \
    --exclude="validate-pre-commit.sh" 2>/dev/null | grep -q .; then
    check_fail "SSO Role ID específico encontrado em:"
    grep -r "a08e3792465d3f04" . \
        --exclude-dir=.git \
        --exclude-dir=docs \
        --exclude="CHECKLIST-PRE-COMMIT.md" \
        --exclude="RESUMO-VALIDACAO-GITHUB.md" \
        --exclude="validate-pre-commit.sh" 2>/dev/null | cut -d: -f1 | sort -u
else
    check_pass "Nenhum SSO Role ID específico encontrado"
fi

# Buscar AWS credentials patterns
if grep -rE "AKIA[0-9A-Z]{16}" . --exclude-dir=.git --exclude-dir=docs 2>/dev/null | grep -q .; then
    check_fail "Possível AWS Access Key encontrada!"
else
    check_pass "Nenhuma AWS Access Key encontrada"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Verificando estrutura do repositório"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar arquivos essenciais
[ -f "README.md" ] && check_pass "README.md existe" || check_fail "README.md não encontrado"
[ -f "SECURITY.md" ] && check_pass "SECURITY.md existe" || check_warn "SECURITY.md não encontrado (opcional)"
[ -f ".gitattributes" ] && check_pass ".gitattributes existe" || check_warn ".gitattributes não encontrado (opcional)"

# Verificar que docs/ NÃO está no git
if [ -d "docs" ]; then
    check_warn "Pasta docs/ existe (certifique-se que está no .gitignore se for privada)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Validando Git Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar se há arquivos .tfstate rastreados pelo git
if git ls-files 2>/dev/null | grep -q "\.tfstate"; then
    check_fail "Arquivos .tfstate estão rastreados pelo Git!"
    git ls-files | grep "\.tfstate"
else
    check_pass "Nenhum .tfstate rastreado pelo Git"
fi

# Verificar se há diretórios .terraform rastreados
if git ls-files 2>/dev/null | grep -q "\.terraform/"; then
    check_fail "Diretórios .terraform/ estão rastreados pelo Git!"
    git ls-files | grep "\.terraform/"
else
    check_pass "Nenhum .terraform/ rastreado pelo Git"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO DA VALIDAÇÃO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ TUDO OK! Repositório seguro para commit${NC}"
    echo ""
    echo "Próximos passos:"
    echo "  1. git add <arquivos>"
    echo "  2. git commit -m 'feat: Initial commit'"
    echo "  3. git push origin main"
    exit 0
else
    echo -e "${RED}❌ $ERRORS erro(s) encontrado(s)!${NC}"
    echo ""
    echo "⚠️  CORRIJA OS ERROS ANTES DE FAZER COMMIT!"
    echo ""
    echo "Consulte: CHECKLIST-PRE-COMMIT.md"
    exit 1
fi
