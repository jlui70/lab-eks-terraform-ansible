# ✅ CHECKLIST DE INSTALAÇÃO LIMPA - EKS DevOps Project
## Para Testes do Zero - Dezembro 2025

> 📋 **Use este checklist para garantir instalação 100% limpa e sem erros**
> 
> ⏱️ **Tempo total estimado:** 60-90 minutos (inclui configuração SSO do Grafana)
> 
> 💰 **Custo do teste (2 horas):** ~$2.00 USD

---

## 📥 FASE 0: PRÉ-REQUISITOS (10 minutos)

### ✅ Ferramentas Instaladas

- [ ] **AWS CLI v2.x** instalado
  ```bash
  aws --version
  # Esperado: aws-cli/2.x.x
  ```

- [ ] **Terraform v1.12+** instalado
  ```bash
  terraform version
  # Esperado: Terraform v1.12.x ou superior
  ```

- [ ] **kubectl compatível com EKS 1.32** instalado
  ```bash
  kubectl version --client
  # Esperado: v1.28+ (compatível com EKS 1.32)
  ```

- [ ] **Helm v3.x** instalado
  ```bash
  helm version
  # Esperado: v3.x
  ```

- [ ] **jq** instalado (para validações)
  ```bash
  jq --version
  ```

### ✅ Conta AWS Configurada

- [ ] **Conta AWS Paid Plan** ou créditos suficientes
  > ⚠️ **CRÍTICO:** Free Tier NÃO suporta instâncias t3.medium

- [ ] **Permissões administrativas** na conta
  ```bash
  aws iam get-user
  # Deve retornar seu usuário sem erro
  ```

- [ ] **Região confirmada:** `us-east-1` (Virgínia do Norte)
  ```bash
  aws configure get region
  # Deve retornar: us-east-1
  ```

---

## 🔐 FASE 1: CONFIGURAÇÃO DE CREDENCIAIS (15 minutos)

### Passo 1.1: Criar Usuário IAM

```bash
# Substitua <SEU_USUARIO> por ex: terraform-deploy
aws iam create-user --user-name <SEU_USUARIO>
```

- [ ] Usuário criado com sucesso
- [ ] Anote o nome do usuário: `_______________`

### Passo 1.2: Criar Terraform Role

```bash
# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Seu Account ID: $ACCOUNT_ID"

# Criar Role (substitua <SEU_USUARIO>)
aws iam create-role \
    --role-name terraform-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::'$ACCOUNT_ID':user/<SEU_USUARIO>"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a"
                }
            }
        }]
    }'
```

- [ ] Role criada com sucesso
- [ ] Account ID anotado: `_______________`

### Passo 1.3: Anexar Permissões Administrativas

```bash
aws iam attach-role-policy \
    --role-name terraform-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

- [ ] Policy anexada com sucesso

### Passo 1.4: Configurar AWS CLI Profile

Edite `~/.aws/config` e adicione:

```ini
[profile terraform]
role_arn = arn:aws:iam::<SEU_ACCOUNT_ID>:role/terraform-role
source_profile = default
external_id = 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a
region = us-east-1
```

**Substituições necessárias:**
- [ ] `<SEU_ACCOUNT_ID>` → Account ID real
- [ ] `source_profile = default` → perfil que tem credenciais do usuário IAM

### Passo 1.5: Testar Assume Role

```bash
aws sts get-caller-identity --profile terraform
```

**Resultado esperado:**
```json
{
    "UserId": "AROAXXXXXXXXX:botocore-session-xxxxx",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/terraform-role/..."
}
```

- [ ] Profile terraform funcionando ✅
- [ ] AssumedRoleUser contém "terraform-role" ✅

---

## 📂 FASE 2: CLONAR E CONFIGURAR PROJETO (5 minutos)

### Passo 2.1: Clonar Repositório

```bash
git clone https://github.com/jlui70/lab-eks-terraform-ansible.git
cd lab-eks-terraform-ansible
```

- [ ] Repositório clonado com sucesso

### Passo 2.2: Substituir Account ID

```bash
# Obter Account ID (se ainda não tiver)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform)
echo "Account ID: $ACCOUNT_ID"

# Substituir <YOUR_ACCOUNT> em TODOS os arquivos .tf
find . -name "*.tf" -type f -exec sed -i "s/<YOUR_ACCOUNT>/$ACCOUNT_ID/g" {} +

# VALIDAR substituição
grep -r "<YOUR_ACCOUNT>" --include="*.tf" .
```

**Resultado esperado:** `(sem output = todas substituições OK)`

- [ ] Nenhum `<YOUR_ACCOUNT>` restante nos arquivos `.tf` ✅

### Passo 2.3: Validar Substituições

```bash
# Verificar 3 arquivos críticos
grep "eks-devopsproject-state-files" 00-backend/variables.tf
# Deve mostrar: eks-devopsproject-state-files-123456789012

grep "role/terraform-role" 01-networking/variables.tf
# Deve mostrar: arn:aws:iam::123456789012:role/terraform-role

grep "bucket" 02-eks-cluster/main.tf | head -1
# Deve mostrar: bucket com seu Account ID
```

- [ ] Todos os 3 arquivos mostram Account ID real ✅

---

## 🏗️ FASE 3: DEPLOYMENT DA INFRAESTRUTURA (60 minutos)

### ⚡ OPÇÃO A: Deploy Automático (Recomendado)

```bash
# Script que aplica TODAS as 6 stacks automaticamente
./rebuild-all.sh
```

**O script vai:**
1. ✅ Stack 00 → Backend S3 + DynamoDB
2. ✅ Stack 01 → VPC com subnets /26 (59 IPs cada)
3. ✅ Stack 02 → EKS Cluster + VPC CNI otimizado
4. ✅ Stack 03 → Karpenter auto-scaling
5. ✅ Stack 04 → WAF (se tiver apps)
6. ✅ Stack 05 → Grafana + Prometheus + API Key

- [ ] rebuild-all.sh executado sem erros ✅
- [ ] Aguardar ~60 minutos ⏱️

**Pular para Fase 4 (Validações)**

---

### 🔧 OPÇÃO B: Deploy Manual (Passo a Passo)

#### Stack 00 - Backend (1 min)

```bash
cd 00-backend
terraform init
terraform apply -auto-approve
cd ..
```

- [ ] 3 recursos criados: S3 bucket + versioning + DynamoDB table ✅

#### Stack 01 - Networking (3 min)

```bash
cd 01-networking
terraform init
terraform apply -auto-approve
cd ..
```

**VALIDAR subnets expandidas:**
```bash
terraform output -json | jq '.private_subnet_cidr_blocks.value'
# Deve mostrar: ["10.0.1.0/26", "10.0.1.64/26"]
```

- [ ] 21 recursos criados ✅
- [ ] Subnets privadas são /26 (59 IPs cada) ✅

#### Stack 02 - EKS Cluster (20 min)

```bash
cd 02-eks-cluster
terraform init
terraform apply -auto-approve
```

**VALIDAR VPC CNI otimizado:**
```bash
terraform state show aws_eks_addon.vpc_cni | grep WARM
# Deve mostrar:
# WARM_ENI_TARGET = 0
# WARM_IP_TARGET = 5
# MINIMUM_IP_TARGET = 10
```

- [ ] 21 recursos criados ✅
- [ ] VPC CNI addon configurado com otimização ✅

**Configurar kubectl:**
```bash
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \
    --profile terraform

# Testar acesso
kubectl get nodes
```

- [ ] kubectl configurado ✅
- [ ] 3 nodes em status `Ready` ✅

#### Stack 03 - Karpenter (5 min)

```bash
cd ../03-karpenter-auto-scaling
terraform init
terraform apply -auto-approve
cd ..
```

**VALIDAR Karpenter:**
```bash
kubectl get pods -n kube-system | grep karpenter
# Esperado: 2 pods Running

kubectl get nodepools
# Esperado: default pool com status Ready
```

- [ ] 10 recursos criados ✅
- [ ] Karpenter controller rodando ✅
- [ ] NodePool default criado ✅

#### Stack 04 - Security (1 min) - OPCIONAL

```bash
cd ../04-security
terraform init
terraform apply -auto-approve
cd ..
```

> ⚠️ **NOTA:** WAF só funciona se você já tiver ALB criado por Ingress.
> Se não tiver app ainda, pule para Stack 05.

- [ ] WAF Web ACL criado ✅ (ou pulado)

#### Stack 05 - Monitoring (25 min)

```bash
cd ../05-monitoring
terraform init
terraform apply -auto-approve
```

**VALIDAR Prometheus Scraper:**
```bash
terraform state show aws_prometheus_scraper.this | grep lifecycle
# Deve mostrar: create_before_destroy = false
```

**Obter outputs:**
```bash
terraform output
# Anote:
# - grafana_workspace_url
# - grafana_workspace_id
# - grafana_api_key (será usado no Ansible)
```

- [ ] 7 recursos criados ✅
- [ ] Prometheus scraper com lifecycle hook ✅
- [ ] Grafana API Key criada ✅
- [ ] Outputs anotados ✅

---

## ✅ FASE 4: VALIDAÇÕES DA INFRAESTRUTURA (10 minutos)

### Validação 4.1: Cluster EKS

```bash
# Nodes
kubectl get nodes
# Esperado: 3 nodes Ready

# Pods do sistema
kubectl get pods -A
# Esperado: Todos Running (coredns, aws-node, kube-proxy, etc)

# Addons EKS
aws eks list-addons --cluster-name eks-devopsproject-cluster --profile terraform
# Esperado: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent
```

- [ ] 3 nodes Ready ✅
- [ ] Todos os pods Running ✅
- [ ] 5+ addons instalados ✅

### Validação 4.2: VPC CNI Otimizado

```bash
# Verificar configuração do CNI
kubectl set env daemonset aws-node -n kube-system --list | grep WARM
# Esperado:
# WARM_ENI_TARGET=0
# WARM_IP_TARGET=5
# MINIMUM_IP_TARGET=10
```

- [ ] VPC CNI com otimização aplicada ✅

### Validação 4.3: Karpenter

```bash
# NodePools
kubectl get nodepools
# Esperado: default (Ready)

# EC2NodeClasses
kubectl get ec2nodeclasses
# Esperado: default (Ready)

# Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=20
# Esperado: Sem erros críticos
```

- [ ] NodePool e EC2NodeClass prontos ✅
- [ ] Karpenter sem erros nos logs ✅

### Validação 4.4: ALB Controller

```bash
# Pods do ALB Controller
kubectl get pods -n kube-system | grep aws-load-balancer
# Esperado: 2 pods Running

# Logs (últimas 10 linhas)
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=10
```

- [ ] ALB Controller rodando ✅

### Validação 4.5: Prometheus + Grafana

```bash
# Verificar scraper
aws amp list-scrapers --profile terraform
# Esperado: 1 scraper ativo

# Verificar workspace Grafana
aws grafana list-workspaces --profile terraform
# Esperado: 1 workspace
```

- [ ] Prometheus scraper ativo ✅
- [ ] Grafana workspace criado ✅

### Validação 4.6: Subnets com IPs Suficientes

```bash
# Verificar IPs disponíveis
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=private-subnet-us-east-1a" \
    --query 'Subnets[0].AvailableIpAddressCount' \
    --output text \
    --profile terraform
# Esperado: ~50-55 IPs disponíveis (de 59 total)
```

- [ ] Subnet /26 com 50+ IPs disponíveis ✅

---

## 🎨 FASE 5: CONFIGURAR GRAFANA SSO (10 minutos)

> ⚠️ **OBRIGATÓRIO:** Sem isso, Grafana fica inacessível

### Passo 5.1: Habilitar IAM Identity Center (SSO)

1. Acesse: AWS Console → IAM Identity Center
2. Clique "Enable"
3. Escolha região: **us-east-1**
4. Aguarde ~2 min

- [ ] IAM Identity Center habilitado ✅

### Passo 5.2: Criar Usuário SSO

1. IAM Identity Center → Users → Add user
2. Preencha:
   - Username: `grafana-admin`
   - Email: seu email real
   - First/Last name: seu nome
3. Enviar convite por email

- [ ] Usuário SSO criado ✅
- [ ] Email de convite recebido ✅

### Passo 5.3: Atribuir Usuário ao Grafana

1. AWS Console → Amazon Managed Grafana
2. Clique no workspace criado
3. Aba "Authentication" → Assign new user or group
4. Selecione `grafana-admin`
5. **CRÍTICO:** Role = `Admin` (não Viewer ou Editor!)

- [ ] Usuário atribuído ao workspace ✅
- [ ] Role = **Admin** ✅

### Passo 5.4: Acessar Grafana

1. AWS Access Portal → Applications → Grafana workspace
2. OU copie URL do `terraform output grafana_workspace_url`
3. Login com usuário SSO

- [ ] Grafana acessível ✅
- [ ] Login bem-sucedido ✅

---

## 🤖 FASE 6: CONFIGURAR GRAFANA COM ANSIBLE (2 minutos)

> 💡 **Alternativa rápida:** Ao invés de configurar Grafana manualmente

### Passo 6.1: Instalar Ansible (se não tiver)

```bash
# Ubuntu/Debian
sudo apt install ansible -y

# macOS
brew install ansible

# Verificar
ansible --version
```

- [ ] Ansible instalado ✅

### Passo 6.2: Executar Playbook de Configuração

```bash
# Obter API Key do Terraform
cd 05-monitoring
GRAFANA_API_KEY=$(terraform output -raw grafana_api_key)
cd ..

# Configurar Grafana (data source + dashboard)
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml \
    -e "grafana_api_key=$GRAFANA_API_KEY"
cd ..
```

**O playbook configura automaticamente:**
1. ✅ Data Source Prometheus
2. ✅ Dashboard Node Exporter (ID 1860)
3. ✅ Valida conectividade

- [ ] Playbook executado sem erros ✅
- [ ] Data Source Prometheus aparece no Grafana ✅
- [ ] Dashboard "Node Exporter Full" importado ✅

### Passo 6.3: Validar no Grafana

1. Acesse Grafana → Configuration → Data Sources
2. Deve ter: **Amazon Managed Service for Prometheus**
3. Acesse Dashboards → Procure "Node Exporter Full"
4. Dashboard deve mostrar métricas dos nodes

- [ ] Data Source configurado ✅
- [ ] Dashboard com dados reais ✅

---

## 🎯 FASE 7: DEPLOY APP DE TESTE (OPCIONAL - 3 minutos)

### Opção A: E-commerce App com Ansible

```bash
cd ansible
ansible-playbook playbooks/03-deploy-ecommerce.yml
ansible-playbook playbooks/04-configure-ecommerce-monitoring.yml
cd ..
```

**Resultado:**
- 7 microserviços deployados
- Ingress + ALB criado
- Monitoramento configurado

- [ ] App deployado ✅
- [ ] ALB acessível via browser ✅

### Opção B: NGINX Simples

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: nginx
EOF

# Obter URL
kubectl get svc nginx-test
```

- [ ] NGINX deployado ✅
- [ ] Service criado ✅

---

## 🗑️ FASE 8: DESTROY (15-25 minutos)

### Pré-validação (Opcional)

```bash
./pre-destroy-check.sh
```

- [ ] Script executado ✅
- [ ] Warnings revisados ✅

### Destroy Automático

```bash
./destroy-all.sh
```

**O script vai:**
1. ✅ Deletar recursos Kubernetes (namespaces, ALBs)
2. ✅ Aguardar 45s para ALBs serem removidos
3. ✅ Destroy Stack 05 (Prometheus + Grafana)
4. ✅ **Aguardar automaticamente** até 10min para ENIs serem liberadas
5. ✅ Destroy Stacks 04 → 03 → 02 → 01
6. ✅ Perguntar se quer destruir Stack 00 (backend)

- [ ] destroy-all.sh executado ✅
- [ ] Todos os recursos deletados ✅

### Se VPC não deletar (raro)

```bash
# Aguardar 5-10min e executar
./cleanup-vpc-final.sh
```

- [ ] VPC deletada ✅

### Validar Custo Zero

```bash
# Verificar recursos restantes
aws eks list-clusters --profile terraform
# Esperado: []

aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --profile terraform
# Esperado: []

aws elbv2 describe-load-balancers --profile terraform
# Esperado: []
```

- [ ] Nenhum cluster EKS ✅
- [ ] Nenhuma instância EC2 ✅
- [ ] Nenhum ALB ✅
- [ ] Custo estimado: **$0/mês** ✅

---

## 📊 RESUMO DO CHECKLIST

### ✅ Tudo OK para Produção?

- [ ] **Credenciais:** terraform-role configurada e testada
- [ ] **Código:** Nenhum `<YOUR_ACCOUNT>` restante
- [ ] **Networking:** Subnets /26 com 50+ IPs disponíveis
- [ ] **EKS:** VPC CNI otimizado (WARM_ENI_TARGET=0)
- [ ] **Karpenter:** NodePools e EC2NodeClasses prontos
- [ ] **Monitoring:** Prometheus scraper com lifecycle hooks
- [ ] **Grafana:** SSO configurado + Data Source + Dashboard
- [ ] **Scripts:** rebuild-all.sh e destroy-all.sh testados
- [ ] **Destroy:** VPC deletada sem problemas de ENI

### 🎉 RESULTADO ESPERADO

Se todos os checkboxes estão marcados:

✅ **Instalação 100% limpa e funcional**
✅ **Sem problemas de IPs (subnets /26)**
✅ **Sem problemas de destroy (ENIs do Prometheus)**
✅ **Grafana funcionando com SSO + Dashboards**
✅ **Pronto para demonstrações e testes**

---

## 🚨 PROBLEMAS COMUNS E SOLUÇÕES

### Problema 1: "the server has asked for the client to provide credentials"

**Causa:** Access entry da terraform-role não configurado

**Solução:**
```bash
cd 02-eks-cluster
terraform apply -auto-approve
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform
```

### Problema 2: "InsufficientFreeAddresses"

**Causa:** Subnets ainda /27 (código antigo)

**Validação:**
```bash
cd 01-networking
grep "cidr_block.*10.0.1" variables.tf
# Deve mostrar: 10.0.1.0/26 e 10.0.1.64/26
```

**Solução:** Código já corrigido, apenas execute terraform apply

### Problema 3: VPC não deleta (ENIs bloqueando)

**Causa:** ENIs do Prometheus scraper não foram liberadas

**Solução:** Código já corrigido com proteção automática no destroy-all.sh
- Script aguarda até 10min automaticamente
- Se ainda falhar: `./cleanup-vpc-final.sh`

### Problema 4: Grafana retorna 403 Forbidden (Ansible)

**Causa:** Usuário SSO não é Admin

**Solução:**
1. AWS Console → Amazon Managed Grafana
2. Workspace → Authentication → Editar usuário
3. **Mudar Role para Admin**
4. Reexecutar playbook Ansible

---

## 📞 SUPORTE

Se encontrar problemas:

1. ✅ Revisar seção **Troubleshooting** no README.md (Erros 1-9)
2. ✅ Executar `./pre-destroy-check.sh` para diagnóstico
3. ✅ Verificar logs: `kubectl logs -n kube-system <pod>`
4. ✅ Consultar documentação Ansible em `docs/`

**Boa sorte com os testes! 🚀**
