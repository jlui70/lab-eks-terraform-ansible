# Projeto EKS-TERRAFORM-AMSIBLE - Infraestrutura AWS Production Grade

Infraestrutura completa para provisionar um **Cluster Amazon EKS production-grade** utilizando **Terraform** e **Ansible** com stacks modulares para gerenciamento de recursos AWS.

Este projeto inclui:
- ✅ **EKS Cluster 1.32** com Node Groups gerenciados
- ✅ **Karpenter** para auto-scaling dinâmico de nodes
- ✅ **AWS Load Balancer Controller** para Ingress
- ✅ **External DNS** para gerenciamento automático de DNS
- ✅ **WAF** para proteção do Application Load Balancer
- ✅ **Amazon Managed Prometheus + Grafana** para observabilidade
- ✅ **6 stacks Terraform** modulares e reutilizáveis
- ✅ **Ansible** Configuração de Serviços
- ✅ **Scripts de automação** para deploy e destroy

---

### **📚 Documentação Ansible Disponível:**

1. **[ANALISE-ANSIBLE-INTEGRACAO.md](./docs/ANALISE-ANSIBLE-INTEGRACAO.md)**  
   - Análise técnica completa das 5 áreas onde Ansible agrega valor
   - Práticas de mercado (Netflix, Spotify, Airbnb)
   - ROI e estimativa de esforço

2. **[GUIA-IMPLEMENTACAO-ANSIBLE.md](./docs/GUIA-IMPLEMENTACAO-ANSIBLE.md)**  
   - Código pronto para uso (roles, playbooks)
   - Setup passo a passo
   - Exemplos práticos

### **🎯 Benefícios da Integração Ansible:**

| Tarefa | Sem Ansible | Com Ansible | Economia |
|--------|-------------|-------------|----------|
| Configurar Grafana | 15-20 min (manual) | 2 min (automático) | **90%** |
| Deploy sample apps | 10 min (manual) | 1 min (automático) | **90%** |
| Validação cluster | 15 min (manual) | 1 min (automático) | **93%** |
| **3 ambientes completos** | **~10 horas** | **~2.5 horas** | **75%** |

## 🚀 Fluxo de Deployment Recomendado

```
┌───────────────────────────────────────────────────────────────────┐
│ FASE 1: Terraform (60-90 min)                                     │
├───────────────────────────────────────────────────────────────────│
│ 1. Stack 00 (Backend)        → S3 + DynamoDB                      │
│ 2. Stack 01 (Networking)     → VPC + Subnets + NAT                │
│ 3. Stack 02 (EKS Cluster)    → EKS + Node Group + ALB             │
│ 4. Stack 03 (Karpenter)      → Auto-scaling                       │
│ 5. Stack 04 (Security/WAF)   → WAF WebACL com regras de segurança │
│ 6. Stack 05 (Monitoring)     → Grafana + Prometheus + API Key     │
└───────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FASE 2: Configuração Grafana SSO (5-10 min) OBRIGATÓRIO         │
├─────────────────────────────────────────────────────────────────┤
│ 1. Habilitar IAM Identity Center (SSO)                          │
│ 2. Criar usuário SSO                                            │
│ 3. Atribuir usuário ao Grafana Workspace                        │
│ 4. Mudar para ADMIN (Crítico)                                   │
│ 5. Acessar Grafana via AWS Access Portal                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FASE 3A: Ansible (2 min)                                        │
├─────────────────────────────────────────────────────────────────┤
│ ansible-playbook playbooks/01-configure-grafana.yml             │
│   →  Data Source Prometheus configurado automaticamente         │
│   →  Dashboard Node Exporter importado automaticamente          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│ FASE 4: Deploy E-commerce App                                      │
├────────────────────────────────────────────────────────────────────┤
│ Stack 06 - Aplicação real com 7 microserviços                      │
│                                                                    │
│ OPÇÃO A - Ansible (3 min):    85% mais rápido                      │
│   ansible-playbook playbooks/03-deploy-ecommerce.yml               │
│   ansible-playbook playbooks/04-configure-ecommerce-monitoring.yml │
│                                                                    │
│ OPÇÃO B - Manual (20 min): kubectl apply -f ...                    │
│                                                                    │
│ Resultado: App acessível em eks.devopsproject.com.br               │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  AMBIENTE PRONTO PARA USO + APLICAÇÃO                           │
└─────────────────────────────────────────────────────────────────┘
```

**⚠️ PONTOS CRÍTICOS:**
- 🔴 **Stack 05 deve incluir API Key** para Ansible funcionar (ver seção "Stack 05")
- 🔴 **Usuário SSO DEVE ser ADMIN** senão Ansible falhará com 403 Forbidden
- 🔴 **Não pule a Fase 2** (SSO) - Grafana workspace é criado vazio sem autenticação

---

## 📋 Pré-requisitos (Obrigatório)

Antes de iniciar o deployment, certifique-se de ter:

- **AWS Account** com permissões administrativas
- **AWS CLI** configurado (versão 2.x recomendada)
- **Terraform** instalado (versão 1.12.x ou superior)
- **kubectl** instalado (versão compatível com EKS 1.32)
- **Helm** instalado (versão 3.x)
- **Conta AWS Paid Plan** ou créditos suficientes (Free Tier não suporta instâncias t3.medium)

> ⚠️ **IMPORTANTE:** O projeto utiliza instâncias **t3.medium** para os worker nodes. Contas AWS Free Tier são limitadas a t3.micro/t3.small. Certifique-se de ter upgrade para Paid Plan ou créditos AWS disponíveis.
>
> 💰 **ESTIMATIVA DE CUSTO PARA LABORATÓRIO:**
> - **30 minutos de teste:** ~$0.50 USD
> - **2 horas completas (deploy + validação):** ~$2.00 USD
> - **8 horas (dia de estudo):** ~$8.00 USD
> 
> **💡 DICA:** Execute `terraform destroy` imediatamente após os testes para evitar cobranças contínuas. O custo de ~$280/mês mencionado abaixo é apenas se você mantiver a infraestrutura rodando 24/7.

### **📚 Siga as orientações no Documento de Configuração Inicial abaixo:**

**[CONFIGURAÇÃO-INICIAL.md](./docs/Configuração-inicial.md)** 

---
## Deploy ⚠️ **IMPORTANTE:**

## (Iniciei o Deploy apenas quando finalizar a Configuração Inicial)

## 🚀 Sequência de Deploy 

### Stack 00 - Backend (S3 + DynamoDB)

A stack `backend` cria o bucket S3 e a tabela DynamoDB para o Terraform state locking e remote backend:

```bash
cd ./00-backend
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 3 (S3 bucket, S3 versioning, DynamoDB table)

📌 **Observação:** O comando considera que você está na pasta root do projeto.

---

### Stack 01 - Networking (VPC, Subnets, NAT)

Crie a base de redes para as próximas stacks:

```bash
cd ../01-networking
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 21 (VPC, Internet Gateway, 6 Subnets, NAT Gateways, Route Tables, EIPs)

**⏱️ Tempo estimado:** 2-3 minutos

---

### Stack 02 - EKS Cluster

Crie um Cluster EKS com addons instalados.

**ANTES DE APLICAR:**

1. ✅ Substitua `<YOUR_ACCOUNT>` em todos os arquivos `.tf` (veja seção 5.1)
2. ✅ EKS Access já está configurado automaticamente com terraform-role (veja seção 5.2)

```bash
cd ../02-eks-cluster
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 21 (EKS Cluster, Node Group, IAM Roles, Addons, OIDC Provider, ALB Controller, External DNS)

**⏱️ Tempo estimado:** 15-20 minutos (inclui provisionamento dos node groups)

---

### Configurar kubectl (OBRIGATÓRIO)

Após o deploy do Stack 02, configure o kubectl para acessar o cluster:

```bash
aws eks update-kubeconfig \
    --name <CLUSTER_NAME> \
    --region us-east-1 \
    --profile terraform
```

> 📝 **Nota:** Substitua `<CLUSTER_NAME>` pelo nome do seu cluster. Se você não alterou as variáveis do Terraform, o nome padrão é `eks-devopsproject-cluster`.

**Exemplo:**
```bash
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \
    --profile terraform
```

Teste o acesso:

```bash
kubectl get nodes
kubectl get pods -A
```

**✅ Validação esperada:**
- 3 nodes no estado `Ready`
- Pods do kube-system rodando
- Pods do aws-load-balancer-controller (2/2 Ready)
- Pods do external-dns (1/1 Ready)

---

### Stack 03 - Karpenter Auto Scaling

Torne o Cluster EKS dinâmico, adicionando e removendo nós sob demanda utilizando Karpenter:

```bash
cd ../03-karpenter-auto-scaling
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 10 (Karpenter Controller, IAM Roles, Security Group, CRDs, NodePool, EC2NodeClass)

**⏱️ Tempo estimado:** 3-5 minutos

**✅ Validação:**

```bash
kubectl get pods -n kube-system | grep karpenter
# Deve mostrar: karpenter-xxxxx  2/2  Running

kubectl get nodepools
# Deve mostrar: default-node-pool  Ready

kubectl get ec2nodeclasses
# Deve mostrar: default  Ready  True
```

---

### Stack 04 - Security (WAF) - OBRIGATÓRIO

Cria o **AWS WAF Web ACL** com 8 regras de segurança para proteger a aplicação contra ataques web.

**Regras de Segurança Configuradas:**
- ✅ **IP Reputation List** - Bloqueia IPs maliciosos conhecidos
- ✅ **Anonymous IP List** - Bloqueia VPNs/proxies/Tor
- ✅ **SQL Injection Protection** - Protege contra SQLi
- ✅ **Bot Control** - Detecta e bloqueia bots maliciosos
- ✅ **Common Rule Set** - Proteção geral OWASP
- ✅ **Known Bad Inputs** - Bloqueia payloads maliciosos conhecidos
- ✅ **Linux Operating System** - Proteção contra exploits Linux
- ✅ **PHP Application** - Proteção específica para PHP

```bash
cd ../04-security
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 1 (WAF WebACL com 8 regras)

**⏱️ Tempo estimado:** 30 segundos

**✅ Validação:**

```bash
# Verificar WAF criado
terraform output waf_arn

# Ou via AWS CLI
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1 --profile terraform
```

> 📝 **Nota:** O WAF será **automaticamente associado ao ALB** quando você deployar a aplicação E-commerce via Ansible (próxima stack). O playbook Ansible adiciona a anotação `alb.ingress.kubernetes.io/wafv2-acl-arn` automaticamente ao Ingress.

---


### Stack 05 - Monitoring (Prometheus + Grafana) - OBRIGATÓRIO

Configure Amazon Managed Prometheus e Amazon Managed Grafana para observabilidade completa do cluster.

**IMPORTANTE - Pré-requisito de Autenticação:**

O Grafana requer autenticação AWS SSO. **Configure ANTES de aplicar o Terraform:**

1. Acesse: https://console.aws.amazon.com/singlesignon
2. **Se não estiver habilitado:** Clique em "Enable IAM Identity Center"
3. Vá em **Users** → **Add user**:
   - Username: `grafana-admin` (ou seu email)
   - Email: seu-email@exemplo.com
   - First/Last name: Seu nome
4. Você receberá email para ativar conta
5. Após ativar, vá em **AWS accounts** → Selecione sua conta
6. Clique em **Assign users** → Selecione `grafana-admin`
7. Na tela de Permission sets, **pule** (não precisa permission set para Grafana)

> 📝 **Nota:** Este é o **ÚNICO processo manual obrigatório** do projeto. Todo o resto é automatizado via Terraform + Ansible.

```bash
cd ../05-monitoring
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 7 (Prometheus Workspace, Prometheus Scraper, Grafana Workspace, IAM Roles, CloudWatch Log Group, EKS Addon Node Exporter)

**⏱️ Tempo estimado:** 20-25 minutos (Prometheus Scraper ~17min, Grafana Workspace ~6min)

**✅ Validação:**

```bash
# Ver outputs
terraform output

# Verificar Prometheus Scraper
aws amp list-scrapers --profile terraform --region us-east-1

# Verificar pods do Node Exporter
kubectl get pods -n prometheus-node-exporter
# Esperado: 3 pods Running (1 por nó)
```

---

### Stack 06 - E-commerce Application + WAF + Grafana (AUTOMAÇÃO COMPLETA)

Deploy automatizado da aplicação E-commerce **com WAF integrado** e **Grafana configurado** usando Ansible.

**Diferencial do Projeto:** Demonstra superioridade da automação Ansible

| Abordagem | Tempo | Comandos | Configuração WAF | Configuração Grafana | Erros |
|-----------|-------|----------|------------------|---------------------|-------|
| **Manual** | 25-30 min | ~20 comandos | Manual (5 min) | Manual (10 min) | Alta chance |
| **Ansible** | **5 min** | **2 comandos** | **Automático** | **Automático** | **Zero** |
| **Economia** | **~83%** | **90% menos** | **100% auto** | **100% auto** | **100% confiável** |

---

#### Passo 6.1: Deploy da Aplicação + Associação WAF (Automatizado)

```bash
cd ansible
ansible-playbook playbooks/03-deploy-ecommerce.yml
```

**O que o playbook faz automaticamente:**

1. ✅ **Valida pré-requisitos** (kubectl, cluster, ALB Controller, WAF)
2. ✅ **Cria namespace** `ecommerce`
3. ✅ **Deploya 7 microserviços:**
   - `ecommerce-ui` (frontend React - porta 4000)
   - `product-catalog` (catálogo de produtos - porta 5001)
   - `order-management` (gestão de pedidos - porta 5002)
   - `product-inventory` (estoque - porta 5003)
   - `profile-management` (perfis de usuários - porta 5004)
   - `shipping-and-handling` (envios - porta 5005)
   - `team-contact-support` (suporte - porta 5006)
4. ✅ **Aguarda pods ficarem prontos** (até 300s)
5. ✅ **Deploya Ingress** (provisiona ALB)
6. ✅ **Aguarda ALB ser criado** (~2-3 min)
7. ✅ **Associa WAF ao ALB automaticamente** (adiciona annotation `alb.ingress.kubernetes.io/wafv2-acl-arn`)
8. ✅ **Valida health check**
9. ✅ **Salva informações** em `ansible/ecommerce-info.txt`

**⏱️ Tempo estimado:** 3-4 minutos

**✅ Validação automática no final do playbook:**

```
====================================
✅ APLICAÇÃO DEPLOYADA COM SUCESSO
====================================

📦 Microserviços: 7
🔒 WAF: Associado (waf-eks-devopsproject-webacl)
🌐 ALB URL: k8s-ecommerce-xxxxxxxx.us-east-1.elb.amazonaws.com
🌍 DNS: eks.devopsproject.com.br
====================================
```

---

#### Passo 6.2: Configurar Grafana + Dashboards (Automatizado)

Configure data source Prometheus e importe dashboards no Grafana:

```bash
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml
```

**O que o playbook faz:**

1. ✅ Obtém automaticamente outputs do Terraform (Grafana URL, API Key, Prometheus Endpoint)
2. ✅ Aguarda Grafana ficar disponível
3. ✅ Configura data source Prometheus com SigV4 auth
4. ✅ Importa dashboard **Node Exporter Full** (ID 1860) do Grafana.com
5. ✅ Valida conexão e disponibilidade de métricas

**⏱️ Tempo estimado:** 1-2 minutos

---

#### Passo 6.3: Configurar DNS Personalizado (CNAME) (Opcional)

O acesso a aplicação E-commerce já esta disponível via ALB, caso deseje acesso via DNS, siga exemplo abaixo: 

Neste Exemplo apenas como referência mostro como configurei um cname eks no meu domínio **devopsproject.com.br**, hospedado na Hostgator:

1. Acessar painel DNS do Hostgator
2. Obter o ALB URL do output do Ansible ou via:
   ```bash
   kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
3. Crie registro CNAME:
   ```
   Tipo: CNAME
   Nome: eks
   Destino: [ALB-URL]
   TTL: 300
   ```
4. Aguarde propagação: 5-10 minutos

**Validar DNS:**

```bash
# Verificar resolução
dig eks.devopsproject.com.br

# Testar acesso
curl -I http://eks.devopsproject.com.br
# Esperado: HTTP/1.1 200 OK
```

---

## ✅ Validação Completa da Infraestrutura

Após completar todas as stacks, valide tudo:

**1. Cluster e Nós:**
```bash
kubectl get nodes
# Esperado: 3 nodes Ready
```

**2. Pods da Aplicação:**
```bash
kubectl get pods -n ecommerce
# Esperado: 7 pods Running (ecommerce-ui, product-catalog, order-management, etc.)
```

**3. Ingress e ALB:**
```bash
kubectl get ingress -n ecommerce
# Esperado: ADDRESS preenchido com ALB URL
```

**4. WAF Associado ao ALB:**
```bash
# Obter ARN do ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-ecommerce')].LoadBalancerArn" \
  --output text --profile terraform)

# Verificar associação WAF
aws wafv2 get-web-acl-for-resource \
  --resource-arn "$ALB_ARN" \
  --region us-east-1 \
  --profile terraform \
  --query 'WebACL.Name' \
  --output text
# Esperado: waf-eks-devopsproject-webacl
```

**5. Acessar Aplicação:**
```bash
# Via ALB direto
curl -I http://[ALB-URL]

# Via DNS personalizado (Exemplo 6.3)
curl -I http://eks.devopsproject.com.br
# Esperado: HTTP/1.1 200 OK
```

**6. Acessar Grafana:**
```bash
# Obter URL do Grafana
cd 05-monitoring
terraform output grafana_workspace_url
```

Abra a URL no navegador:
1. Faça login com usuário SSO (`grafana-admin`)
2. Vá em **Dashboards** → **Browse**
3. Clique em **Node Exporter Full**
4. Você verá métricas dos 3 nós do cluster em tempo real

---

### 🎯 Testar Regras do WAF

O WAF está configurado com 8 regras de segurança. Teste se está bloqueando ataques:

**1. SQL Injection:**
```bash
curl -I "http://eks.devopsproject.com.br/?id=1' UNION SELECT * FROM users--"
# Esperado: HTTP/1.1 403 Forbidden
```

**2. XSS (Cross-Site Scripting):**
```bash
curl -I "http://eks.devopsproject.com.br/?search=<script>alert('XSS')</script>"
# Esperado: HTTP/1.1 403 Forbidden
```

**3. Path Traversal:**
```bash
curl -I "http://eks.devopsproject.com.br/../../etc/passwd"
# Esperado: HTTP/1.1 403 Forbidden
```

**4. Acesso Normal (deve passar):**
```bash
curl -I "http://eks.devopsproject.com.br/"
# Esperado: HTTP/1.1 200 OK
```

**Ver Logs do WAF:**
```bash
# AWS Console → CloudWatch → Log groups
# Buscar: aws-waf-logs-eks-devopsproject
```

Ou via CLI:
```bash
aws logs tail aws-waf-logs-eks-devopsproject --follow --profile terraform
```

---

### 📊 Resumo de Recursos Provisionados

| Stack | Recursos | Tempo | Automação | Status |
|-------|----------|-------|-----------|--------|
| 00 - Backend | 3 | < 1 min | Terraform | Obrigatório |
| 01 - Networking | 21 | 2-3 min | Terraform | Obrigatório |
| 02 - EKS Cluster | 21 | 15-20 min | Terraform | Obrigatório |
| 03 - Karpenter | 10 | 3-5 min | Terraform | Obrigatório |
| 04 - Security/WAF | 1 | 30 seg | Terraform | Obrigatório |
| 05 - Monitoring | 7 | 20-25 min | Terraform | Obrigatório |
| 06 - E-commerce App | 15 (K8s) | **5 min** | **Ansible (2 playbooks)** | Obrigatório |
| **TOTAL** | **78** | **~47-55 min** | **Terraform + Ansible** | **Infraestrutura Completa** |

**Processos Manuais (Apenas 2):**
- ✋ Configuração AWS SSO (uma vez, ~5 min via console)
- ✋ Configuração DNS CNAME no Hostgator (~2 min)

**Tudo mais é automatizado:** Terraform + Ansible

---

## 🤖 Scripts de Automação

Este projeto inclui scripts para **deploy** e **destroy** completos da infraestrutura.

### 🚀 rebuild-all.sh - Deploy Automatizado

Recria toda a infraestrutura do zero automaticamente (Stacks 00 → 05).

```bash
./rebuild-all.sh
```

**O que o script faz:**
1. ✅ Aplica todas as 6 stacks na ordem correta
2. ✅ Aguarda S3 backend estar disponível (10s)
3. ✅ Configura kubectl automaticamente
4. ✅ Restaura `helm/values.yml` se necessário
5. ✅ Substitui Account ID dinamicamente
6. ✅ Opcionalmente cria deployment NGINX de teste

**⏱️ Tempo total:** ~40-55 minutos

**📋 Recursos criados:** 78 recursos (63 Terraform + 15 Kubernetes)

---

### 🗑️ destroy-all.sh - Destruição Completa ⚠️ IMPORTANTE

**Destrói TODOS os recursos** na ordem reversa para **eliminar custos AWS**.

```bash
./destroy-all.sh
```

**⚠️ EXECUTE ESTE SCRIPT APÓS TERMINAR OS TESTES PARA EVITAR CUSTOS DIÁRIOS!**

**O que o script faz automaticamente:**

1. ✅ **Deleta recursos Kubernetes** (namespaces, Ingress → ALB)
   - Namespace `ecommerce` (7 microserviços)
   - Namespace `sample-app` (se existir)
   - Helm releases órfãos
   
2. ✅ **Aguarda ALB ser deletado** (45s)

3. ✅ **Destrói Stack 05** (Grafana + Prometheus)

4. ✅ **Aguarda ENIs do Prometheus** serem liberadas (até 10 min)
   - Prometheus Scraper cria ENIs gerenciadas
   - AWS leva ~5 min para liberá-las após destroy

5. ✅ **Destrói Stacks 04 → 03 → 02** (WAF, Karpenter, EKS)
   - Remove recursos órfãos do Terraform state automaticamente
   - Limpa helm releases órfãos

6. ✅ **Limpa IAM Roles/Policies órfãs** (v3.3 - modo dinâmico)
   - Lê nomes reais do Terraform state
   - Funciona mesmo se você alterar `variables.tf`
   - Previne erro "EntityAlreadyExists" em reinstalações
   - Deleta instance profiles órfãos

7. ✅ **Destrói Stack 01** (VPC + Subnets + NAT Gateways)

8. ❓ **Pergunta sobre Stack 00** (Backend S3 + DynamoDB)
   - Se destruir: remove state remoto completamente
   - Se preservar: mantém histórico do Terraform

**⏱️ Tempo total:** ~15-25 minutos

**💰 Custo AWS após destroy:** **$0/mês** (se destruir backend também)

---

### ⚠️ AVISOS IMPORTANTES SOBRE CUSTOS

| Cenário | Custo/mês | Ação Recomendada |
|---------|-----------|------------------|
| **Cluster rodando 24/7** | **~$273/mês** | ⚠️ **Destruir após testes!** |
| **Cluster por 8 horas** | ~$8 | ✅ OK para estudo |
| **Cluster por 2 horas** | ~$2 | ✅ OK para demonstração |
| **Após destroy completo** | **$0/mês** | ✅ **EXECUTE destroy-all.sh!** |

**🎯 LEMBRE-SE:** AWS cobra por hora. Se você esquecer o cluster rodando, **acumulará custos diários**.

**Principais recursos que geram custo:**
- 💰 **3x instâncias EC2 t3.medium** (~$73/mês)
- 💰 **3x NAT Gateways** (~$97/mês) - o mais caro!
- 💰 **EKS Cluster** (~$73/mês)
- 💰 **Prometheus Scraper** (~$10/mês)
- 💰 **Grafana Workspace** (~$9/mês)
- 💰 **ALB** (~$18/mês)
- 💰 **Transferência de dados** (variável)

---

### 🔄 Fluxo Completo: Deploy → Testes → Destroy

```bash
# 1. Deploy completo (40-55 min)
./rebuild-all.sh

# 2. Configurar SSO Grafana (5-10 min) - OBRIGATÓRIO
# Via AWS Console → IAM Identity Center

# 3. Configurar Grafana com Ansible (2 min)
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml

# 4. Deploy E-commerce App (opcional - 3 min)
ansible-playbook playbooks/03-deploy-ecommerce.yml
cd ..

# 5. Testar tudo (30 min - 2 horas)
kubectl get nodes
kubectl get pods -A
# Acessar Grafana, testar aplicação, validar métricas

# 6. DESTRUIR TUDO (15-25 min) ⚠️ CRÍTICO!
./destroy-all.sh
# Responda "s" quando perguntar sobre backend

# 7. Validar custos zerados
aws eks list-clusters --profile terraform
# Esperado: []

aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --profile terraform
# Esperado: nenhuma instância
```

**Custo total do teste:** ~$2 (se destruir após 2 horas)

---

