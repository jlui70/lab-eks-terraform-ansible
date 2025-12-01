# EKS Express - Infraestrutura AWS Production Grade

Infraestrutura completa para provisionar um **Cluster Amazon EKS production-grade** utilizando **Terraform**, com stacks modulares para gerenciamento de recursos AWS.

Este projeto inclui:
- ✅ **EKS Cluster 1.32** com Node Groups gerenciados
- ✅ **Karpenter** para auto-scaling dinâmico de nodes
- ✅ **AWS Load Balancer Controller** para Ingress
- ✅ **External DNS** para gerenciamento automático de DNS
- ✅ **WAF** para proteção do Application Load Balancer
- ✅ **Amazon Managed Prometheus + Grafana** para observabilidade
- ✅ **6 stacks Terraform** modulares e reutilizáveis
- ✅ **Scripts de automação** para deploy e destroy

---

## 🆕 Novidade: Integração com Ansible

Este projeto foi expandido com **documentação completa** para integração com **Ansible**, automatizando a configuração de serviços após o deployment Terraform.

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

__name__="up", instance="10.0.0.100:61678", job="pod_exporter"}
{__name__="up", instance="10.0.0.100:80", job="pod_exporter"}
{__name__="up", instance="10.0.0.100:8162", job="pod_exporter"}
{__name__="up", instance="10.0.0.100:9100", job="pod_exporter"}
{__name__="up", instance="10.0.0.106:3003", job="pod_exporter"}
{__name__="up", instance="10.0.0.107:53", job="pod_exporter"}
{__name__="up", instance="10.0.0.107:9153", job="pod_exporter"}
{__name__="up", instance="10.0.0.109:4000", job="pod_exporter"}
{__name__="up", instance="10.0.0.110:8080", job="pod_exporter"}
{__name__="up", instance="10.0.0.111:80", job="pod_exporter"}
{__name__="up", instance="10.0.0.113:8080", job="pod_exporter"}
{__name__="up", instance="10.0.0.113:8081", job="pod_exporter"}
{__name__="up", instance="10.0.0.115:9090", job="pod_exporter"}
{__name__="up", instance="10.0.0.116:10251", job="pod_exporter"}
{__name__="up", instance="10.0.0.117:80", job="pod_exporter"}---

## 🚀 Fluxo de Deployment Recomendado

```
┌─────────────────────────────────────────────────────────────────┐
│ FASE 1: Terraform (60-90 min)                                   │
├─────────────────────────────────────────────────────────────────┤
│ 1. Stack 00 (Backend)        → S3 + DynamoDB                    │
│ 2. Stack 01 (Networking)     → VPC + Subnets + NAT              │
│ 3. Stack 02 (EKS Cluster)    → EKS + Node Group + ALB           │
│ 4. Stack 03 (Karpenter)      → Auto-scaling                     │
│ 5. Stack 04 (Security/WAF)   → WAF WebACL (OPCIONAL - requer apps) │
│ 6. Stack 05 (Monitoring)     → Grafana + Prometheus + API Key   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FASE 2: Configuração Grafana SSO (5-10 min) ⚠️ OBRIGATÓRIO     │
├─────────────────────────────────────────────────────────────────┤
│ 1. Habilitar IAM Identity Center (SSO)                          │
│ 2. Criar usuário SSO                                            │
│ 3. Atribuir usuário ao Grafana Workspace                        │
│ 4. ⚠️ MUDAR PARA ADMIN (crítico!)                               │
│ 5. Acessar Grafana via AWS Access Portal                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FASE 3A: Ansible (2 min) - RECOMENDADO                         │
├─────────────────────────────────────────────────────────────────┤
│ ansible-playbook playbooks/01-configure-grafana.yml             │
│   → ✅ Data Source Prometheus configurado automaticamente       │
│   → ✅ Dashboard Node Exporter importado automaticamente        │
└─────────────────────────────────────────────────────────────────┘
                              OU
┌─────────────────────────────────────────────────────────────────┐
│ FASE 3B: Manual (10-15 min) - Alternativa                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Configurar Data Source Prometheus manualmente                │
│ 2. Importar Dashboard 1860 manualmente                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ FASE 4: Deploy E-commerce App (OPCIONAL - Demonstração)        │
├─────────────────────────────────────────────────────────────────┤
│ Stack 06 - Aplicação real com 7 microserviços                  │
│                                                                 │
│ OPÇÃO A - Ansible (3 min): ⚡ 85% mais rápido                  │
│   ansible-playbook playbooks/03-deploy-ecommerce.yml            │
│   ansible-playbook playbooks/04-configure-ecommerce-monitoring.yml │
│                                                                 │
│ OPÇÃO B - Manual (20 min): kubectl apply -f ...                │
│                                                                 │
│ Resultado: App acessível em eks.devopsproject.com.br           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ ✅ AMBIENTE PRONTO PARA USO + APLICAÇÃO DEMO                   │
└─────────────────────────────────────────────────────────────────┘
```

**⚠️ PONTOS CRÍTICOS:**
- 🔴 **Stack 05 deve incluir API Key** para Ansible funcionar (ver seção "Stack 05")
- 🔴 **Usuário SSO DEVE ser ADMIN** senão Ansible falhará com 403 Forbidden
- 🔴 **Não pule a Fase 2** (SSO) - Grafana workspace é criado vazio sem autenticação

---

## 📋 Pré-requisitos

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

---

## 🛠️ Configuração Inicial

### 1. Criar IAM User para Terraform

Crie um usuário IAM na sua conta AWS para realizar o deployment:

**Atenção:** Substitua `<YOUR_USER>` pelo nome desejado (ex: `terraform-deploy`).

```bash
aws iam create-user --user-name <YOUR_USER>
```

---

### 2. Criar e Configurar a Role do Terraform

Crie uma Role na sua conta AWS que será assumida pelo Terraform:

**Atenção:** Substitua `<YOUR_ACCOUNT>` pelo ID da sua conta AWS e `<YOUR_USER>` pelo usuário criado no passo anterior.

```bash
aws iam create-role \
    --role-name terraform-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<YOUR_ACCOUNT>:user/<YOUR_USER>"
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

📌 **Observação:** O External ID `3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a` já está configurado em todos os arquivos do projeto. Você pode alterá-lo, mas precisará atualizar todos os arquivos `variables.tf`.

---

### 3. Anexar Permissões Administrativas à Role

```bash
aws iam attach-role-policy \
    --role-name terraform-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

---

### 4. Configurar AWS CLI Profile

Configure um profile específico para o Terraform assumir a role:

**Atenção:** Substitua `<YOUR_ACCOUNT>` pelo ID da sua conta AWS.

```bash
aws configure set role_arn arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role --profile terraform
aws configure set source_profile default --profile terraform
aws configure set external_id 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a --profile terraform
aws configure set region us-east-1 --profile terraform
```

Teste a configuração:

```bash
aws sts get-caller-identity --profile terraform
```

---

## 🔧 Substituições Necessárias nos Arquivos

### 5.1. Substituir `<YOUR_ACCOUNT>` pelo seu Account ID

**CRÍTICO:** Todos os arquivos `.tf` contêm o placeholder `<YOUR_ACCOUNT>` que **deve** ser substituído pelo ID da sua conta AWS.

#### **Obter seu Account ID:**

```bash
aws sts get-caller-identity --query Account --output text --profile terraform
```

Anote o número retornado (ex: `123456789012`).

#### 🐧 **(WSL/Linux)**

```bash
find . -type f -name "*.tf" -exec sed -i \
    's|<YOUR_ACCOUNT>|123456789012|g' {} +
```

#### 🍎 **(MacOS)**

```bash
find . -type f -name "*.tf" -exec sed -i '' \
    's|<YOUR_ACCOUNT>|123456789012|g' {} +
```

> ⚠️ **ATENÇÃO:** Substitua `123456789012` pelo seu Account ID real obtido no comando acima.

**O que será substituído:**
- ✅ IAM Role ARN: `arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role`
- ✅ Bucket S3: `eks-devopsproject-state-files-<YOUR_ACCOUNT>`
- ✅ EKS Access entries (cluster admin)

**Total:** 16 ocorrências em 10 arquivos `.tf`

---

### 5.2. Verificar EKS Access Configuration (Automático)

✅ **NENHUMA AÇÃO NECESSÁRIA!** O arquivo `02-eks-cluster/eks.cluster.access.tf` já está configurado corretamente para usar a `terraform-role`.

O Terraform automaticamente:
- Detecta seu Account ID via `data.aws_caller_identity`
- Configura access entry para `arn:aws:iam::{ACCOUNT_ID}:role/terraform-role`
- Garante permissões de Cluster Admin para kubectl funcionar

> 💡 **Nota:** Se você encontrar erro `"the server has asked for the client to provide credentials"` ao usar kubectl, verifique se você está usando o profile correto:
> ```bash
> aws sts get-caller-identity --profile terraform
> # Deve retornar AssumedRoleUser com terraform-role
> ```

---

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
3. (Opcional) Ajuste quantidade de worker nodes em `variables.tf` se necessário

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

### Stack 04 - Security (WAF) - OPCIONAL

> 💡 **IMPORTANTE:** Este stack é **opcional** e só faz sentido após deployar aplicações que criam ALBs. 
> 
> O WAF protege Application Load Balancers, mas eles só são criados quando você cria recursos Ingress no Kubernetes. Se você ainda não tem aplicações deployadas, pode **pular este stack** e voltar depois.

**Quando usar:**
- ✅ Você já deployou aplicações com Ingress (que criam ALBs)
- ✅ Você quer proteger seus ALBs contra ataques web (SQL injection, XSS, rate limiting)

**Se você não tem aplicações ainda:**
- ⏭️ Pule para Stack 05 (Monitoring)
- 🔄 Volte aqui depois de deployar apps

---

#### Passo 4.1: Criar WAF WebACL

#### Passo 4.1: Criar WAF WebACL

```bash
cd ../04-security
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 1 (WAF WebACL)

**⏱️ Tempo estimado:** 30 segundos

---

#### Passo 4.2: Criar Ingress Sample (provisionará o ALB)

> 📝 **Nota:** Este passo cria uma aplicação de exemplo apenas para demonstrar a integração WAF + ALB. 
> Em produção, você associaria o WAF aos ALBs das suas aplicações reais.

Antes de associar o WAF ao ALB, é necessário que um ALB exista. Vamos criar um deployment de teste:

```bash
kubectl apply -f ../02-eks-cluster/samples/ingress-sample-deployment.yml
```

**Aguarde o ALB ser provisionado (~2-3 minutos):**

```bash
kubectl get ingress eks-devopsproject-ingress -n sample-app -w
```

Quando aparecer o endereço do ALB na coluna `ADDRESS`, pressione Ctrl+C.

**Teste o ALB (aguarde DNS propagar ~60-90 segundos):**

```bash
ALB_URL=$(kubectl get ingress eks-devopsproject-ingress -n sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://$ALB_URL
```

**✅ Esperado:** `HTTP/1.1 200 OK`

> 💡 **Automação com Ansible:** Em ambientes de produção, recomendamos automatizar o deploy de aplicações e associação do WAF usando Ansible. Veja [GUIA-IMPLEMENTACAO-ANSIBLE.md](./docs/GUIA-IMPLEMENTACAO-ANSIBLE.md) para exemplos.

---

#### Passo 4.3: Associar WAF ao ALB

Agora que o ALB existe, associe o WAF adicionando uma anotação ao Ingress.

**Obtenha o ARN do WAF:**

```bash
cd ../04-security
WAF_ARN=$(terraform state show aws_wafv2_web_acl.this | grep "arn " | awk '{print $3}' | tr -d '"')
echo "WAF ARN: $WAF_ARN"
```

**Adicione a anotação do WAF ao Ingress:**

```bash
kubectl annotate ingress eks-devopsproject-ingress \
  -n sample-app \
  alb.ingress.kubernetes.io/wafv2-acl-arn="$WAF_ARN" \
  --overwrite
```

**Aguarde o ALB Controller processar (~30-60 segundos):**

```bash
kubectl get ingress eks-devopsproject-ingress -n sample-app -w
```

Quando a coluna `ADDRESS` aparecer novamente (pode piscar), pressione Ctrl+C.

**✅ Validação:**

Verifique se a associação foi criada:

```bash
# Obter ARN do ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-sampleap')].LoadBalancerArn" \
  --output text --profile terraform)

# Verificar associação WAF
aws wafv2 get-web-acl-for-resource \
  --resource-arn "$ALB_ARN" \
  --region us-east-1 \
  --profile terraform \
  --query 'WebACL.Name' \
  --output text
```

**Esperado:** `waf-eks-devopsproject-webacl`

Ou verifique no AWS Console:
1. Acesse: https://console.aws.amazon.com/wafv2/home?region=us-east-1
2. Clique em **Web ACLs** → `waf-eks-devopsproject-webacl`
3. Na aba **Associated AWS resources**, você verá o ALB listado

---

### 🤖 Automatizando WAF com Ansible (Recomendado para Produção)

Os passos manuais acima são úteis para **demonstração e aprendizado**, mas em produção recomendamos automatizar:

**Por que automatizar?**
- ✅ Evita passos manuais repetitivos
- ✅ Garante consistência entre ambientes (dev/staging/prod)
- ✅ Permite CI/CD completo
- ✅ Reduz erros humanos

**Como fazer:**

Crie um playbook Ansible que:
1. Deploya sua aplicação com Ingress
2. Aguarda o ALB ser provisionado
3. Associa automaticamente o WAF ao ALB

**Exemplo básico:**

```yaml
# ansible/playbooks/deploy-app-with-waf.yml
- name: Deploy aplicação com WAF
  hosts: localhost
  tasks:
    - name: Deploy aplicação
      kubernetes.core.k8s:
        state: present
        src: ../k8s/my-app-ingress.yml
    
    - name: Aguardar ALB ser criado
      kubernetes.core.k8s_info:
        kind: Ingress
        name: my-app-ingress
        namespace: production
      register: ingress
      until: ingress.resources[0].status.loadBalancer.ingress is defined
      retries: 30
      delay: 10
    
    - name: Obter ARN do WAF
      shell: |
        cd ../04-security
        terraform output -raw waf_arn
      register: waf_arn
    
    - name: Associar WAF ao Ingress
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: my-app-ingress
            namespace: production
            annotations:
              alb.ingress.kubernetes.io/wafv2-acl-arn: "{{ waf_arn.stdout }}"
```

📖 **Para implementação completa, veja:** [GUIA-IMPLEMENTACAO-ANSIBLE.md](./docs/GUIA-IMPLEMENTACAO-ANSIBLE.md)

---

### Stack 05 - Monitoring (Prometheus + Grafana)

Configure Amazon Managed Prometheus e Amazon Managed Grafana para monitorar o Cluster EKS.

**ANTES DE APLICAR:**

1. Verifique se `05-monitoring/data.cluster.remote-state.tf` usa o bucket correto com seu Account ID
2. O arquivo `05-monitoring/grafana.workspace.tf` já está configurado com `authentication_providers = ["AWS_SSO"]`
   - ✅ **AWS_SSO é RECOMENDADO** (gratuito, integrado com AWS)
   - ⚠️ Se você usa IdP externo (Okta, Azure AD), altere para `["SAML"]` e configure federation metadata após o deploy
3. Após o `terraform apply`, você **deve** configurar o acesso ao Grafana (ver seção "Configuração do Grafana" abaixo)

```bash
cd ../05-monitoring
terraform init
terraform apply -auto-approve
```

**Recursos criados:** 7 (Prometheus Workspace, Prometheus Scraper, Grafana Workspace, IAM Roles, CloudWatch Log Group, EKS Addon)

**⏱️ Tempo estimado:** 20-25 minutos (Prometheus Scraper ~17min, Grafana Workspace ~6min)

**✅ Outputs importantes:**

```bash
terraform output
```

Você receberá:
- `grafana_workspace_url`: URL de acesso ao Grafana
- `prometheus_workspace_endpoint`: Endpoint do Prometheus
- `grafana_workspace_id`: ID do workspace Grafana
- `prometheus_workspace_id`: ID do workspace Prometheus
- `grafana_api_key`: API Key para automação Ansible (sensitive)

**⚠️ PRÓXIMO PASSO OBRIGATÓRIO:** Vá para a seção "📊 Configuração do Grafana" mais abaixo antes de usar o Grafana

---

## ✅ Validação Final da Infraestrutura

Após completar todos os stacks, valide a infraestrutura completa:

```bash
# 1. Verificar nodes do cluster
kubectl get nodes
# Esperado: 3 nodes Ready

# 2. Verificar pods de sistema
kubectl get pods -A
# Esperado: Todos Running

# 3. Verificar Karpenter
kubectl get nodepools
kubectl get ec2nodeclasses
# Esperado: Status Ready

# 4. Verificar Ingress e ALB
kubectl get ingress
# Esperado: ADDRESS preenchido

# 5. Testar acesso HTTP
ALB_URL=$(kubectl get ingress eks-devopsproject-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://$ALB_URL
# Esperado: HTTP/1.1 200 OK

# 6. Verificar addons EKS
aws eks list-addons --cluster-name eks-devopsproject-cluster --profile terraform
# Esperado: vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver, eks-pod-identity-agent, prometheus-node-exporter
```

**📊 Resumo de Recursos Provisionados:**

| Stack | Recursos | Tempo Estimado | Notas |
|-------|----------|----------------|-------|
| 00 - Backend | 3 | < 1 min | Obrigatório |
| 01 - Networking | 21 | 2-3 min | Obrigatório |
| 02 - EKS Cluster | 21 | 15-20 min | Obrigatório |
| 03 - Karpenter | 10 | 3-5 min | Obrigatório |
| 04 - Security/WAF | 2 | 1 min | **Opcional*** |
| 05 - Monitoring | 7 | 20-25 min | Obrigatório |
| 06 - E-commerce App | 15 (K8s) | 3 min (Ansible) / 20 min (Manual) | **Opcional**†† |
| **TOTAL (sem Stacks opcionais)** | **62** | **~39-54 min** | Cluster funcional |
| **TOTAL (com Stack 04)** | **64** | **~40-55 min** | + WAF |
| **TOTAL (completo com app)** | **79** | **~42-58 min** | + Aplicação demo |

> **\* Stack 04 (WAF) é opcional** porque:
> - WAF protege ALBs, que só existem quando você deploya aplicações com Ingress
> - Se você ainda não tem apps, pode pular este stack
> - Você pode voltar e aplicar Stack 04 depois de deployar suas aplicações
> - Para automação completa de apps + WAF, veja [GUIA-IMPLEMENTACAO-ANSIBLE.md](./docs/GUIA-IMPLEMENTACAO-ANSIBLE.md)
> 
> **†† Stack 06 (E-commerce App) é opcional** porque:
> - É uma aplicação de demonstração para mostrar cluster em funcionamento
> - Demonstra o valor do Ansible (3 min vs 20 min manual - economia de 85%)
> - Ideal para apresentações e validação de observabilidade
> - Pode ser removida a qualquer momento sem afetar infraestrutura

---

### Stack 06 - E-commerce Application (Demonstração) - OPCIONAL

Deploy de uma aplicação real (e-commerce com microserviços) para demonstrar o cluster em funcionamento com observabilidade completa.

> 💡 **NOVO DIFERENCIAL:** Este stack demonstra a **superioridade do Ansible** sobre processos manuais!
> 
> | Abordagem | Tempo | Comandos | Erros Possíveis |
> |-----------|-------|----------|-----------------|
> | **Manual** | 15-20 min | ~15 kubectl apply + validações | Alta chance de erro |
> | **Ansible** | 2-3 min | 1 comando | Zero erros (idempotente) |
> | **Economia** | **~85%** | **93% menos comandos** | **100% confiável** |

**Sobre a Aplicação:**
- **7 microserviços** (Frontend React + 6 APIs backend)
- Arquitetura moderna (microservices pattern)
- Imagens Docker prontas (rslim087/*)
- **Ingress com ALB** (reutiliza Stack 02)
- **Auto-scaling** (usa Karpenter da Stack 03)
- **WAF opcional** (pode usar Stack 04)
- **Monitoramento automático** (integrado com Stack 05)

**Pré-requisitos:**
- ✅ Stacks 00-03 deployadas (obrigatório)
- ✅ Stack 05 deployada (recomendado para monitoramento)
- ✅ Ansible instalado (para automação)

---

#### Opção A: Deploy Automatizado com Ansible (RECOMENDADO) 🚀

```bash
# Deploy completo da aplicação (namespace + deployments + services + ingress + validações)
ansible-playbook ansible/playbooks/03-deploy-ecommerce.yml
```

**O que o playbook faz automaticamente:**
1. ✅ Valida conexão com cluster e ALB Controller
2. ✅ Cria namespace `ecommerce`
3. ✅ Deploy de 7 microserviços (Deployments + Services)
4. ✅ Aguarda pods ficarem prontos (health checks)
5. ✅ Cria Ingress e provisiona ALB
6. ✅ Aguarda ALB ficar acessível
7. ✅ Executa testes de conectividade
8. ✅ Salva informações de acesso em arquivo

**Tempo total:** ~3 minutos ⏱️

**Configurar Monitoramento (Opcional mas Recomendado):**

```bash
# Importa dashboards Grafana específicos para monitorar a aplicação
ansible-playbook ansible/playbooks/04-configure-ecommerce-monitoring.yml
```

**O que o playbook faz:**
1. ✅ Importa 3 dashboards Grafana (Kubernetes App Metrics, Pods, Deployments)
2. ✅ Cria dashboard customizado para e-commerce
3. ✅ Configura queries Prometheus para métricas dos microserviços
4. ✅ Documenta alertas recomendados

**Tempo total:** ~2 minutos ⏱️

---

#### Opção B: Deploy Manual (Para Comparação Educacional)

Se quiser ver a diferença e entender o valor do Ansible:

```bash
# 1. Criar namespace
kubectl create namespace ecommerce

# 2. Deploy dos microserviços (7 arquivos)
kubectl apply -f 06-ecommerce-app/manifests/ecommerce-ui.yaml
kubectl apply -f 06-ecommerce-app/manifests/product-catalog.yaml
kubectl apply -f 06-ecommerce-app/manifests/order-management.yaml
kubectl apply -f 06-ecommerce-app/manifests/product-inventory.yaml
kubectl apply -f 06-ecommerce-app/manifests/profile-management.yaml
kubectl apply -f 06-ecommerce-app/manifests/shipping-and-handling.yaml
kubectl apply -f 06-ecommerce-app/manifests/team-contact-support.yaml

# 3. Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod --all -n ecommerce --timeout=300s

# 4. Deploy do Ingress
kubectl apply -f 06-ecommerce-app/manifests/ingress.yaml

# 5. Aguardar ALB ser provisionado (2-5 minutos)
kubectl get ingress ecommerce-ingress -n ecommerce -w

# 6. Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Aplicação disponível em: http://$ALB_URL"

# 7. Testar acesso
curl -I http://$ALB_URL

# 8. Configurar DNS no Hostgator (manual via painel)
# CNAME: eks → [ALB_URL]
```

**Tempo total:** ~15-20 minutos ⏱️

**Problemas comuns do processo manual:**
- ❌ Esquecer algum microserviço
- ❌ Não aguardar pods ficarem prontos
- ❌ Testar ALB antes de propagar DNS
- ❌ Não salvar informações de acesso

---

#### Acessar a Aplicação

Após o deploy (Ansible ou manual):

**Via ALB Direto:**
```bash
# Obter URL
kubectl get ingress ecommerce-ingress -n ecommerce

# Acessar no navegador
http://[ALB-URL]
```

**Via DNS Personalizado (Recomendado):**

1. Acesse o painel DNS do Hostgator
2. Crie/Edite registro CNAME:
   - **Nome:** `eks`
   - **Tipo:** `CNAME`
   - **Destino:** `[ALB-URL]`
   - **TTL:** `300`

3. Aguarde propagação (~5-10 minutos)

4. Acesse: **http://eks.devopsproject.com.br**

---

#### Validar Aplicação

```bash
# Status dos pods
kubectl get pods -n ecommerce

# Logs do frontend
kubectl logs -f deployment/ecommerce-ui -n ecommerce

# Logs de um microserviço específico
kubectl logs -f deployment/product-catalog -n ecommerce

# Informações do Ingress
kubectl describe ingress ecommerce-ingress -n ecommerce

# Health check
curl -I http://[ALB-URL]
```

---

#### Monitoramento no Grafana

Se você executou o playbook de monitoramento, acesse o Grafana e veja:

1. **Dashboard "Kubernetes App Metrics"**
   - CPU/Memory por microserviço
   - Network I/O
   - Pod status

2. **Dashboard "E-commerce Application - Overview"**
   - Métricas específicas dos 7 microserviços
   - Contagem de restarts
   - Status de health checks

3. **Queries úteis para criar alertas:**
   ```promql
   # Pods running
   count(kube_pod_status_phase{namespace="ecommerce", phase="Running"})
   
   # CPU usage por pod
   sum(rate(container_cpu_usage_seconds_total{namespace="ecommerce"}[5m])) by (pod)
   
   # Restarts nas últimas 24h
   sum(increase(kube_pod_container_status_restarts_total{namespace="ecommerce"}[24h]))
   ```

---

#### Associar WAF ao E-commerce (Opcional)

Se você deployou Stack 04 (WAF), pode proteger a aplicação:

```bash
# Obter ARN do WAF
cd 04-security
WAF_ARN=$(terraform output -raw waf_arn)

# Adicionar annotation ao Ingress
kubectl annotate ingress ecommerce-ingress \
  -n ecommerce \
  alb.ingress.kubernetes.io/wafv2-acl-arn="$WAF_ARN" \
  --overwrite

# Verificar associação
kubectl describe ingress ecommerce-ingress -n ecommerce | grep waf
```

**Proteções ativadas:**
- ✅ Rate limiting (200 req/5min por IP)
- ✅ SQL Injection detection
- ✅ Cross-Site Scripting (XSS) protection
- ✅ Geographic blocking (se configurado)

---

#### Remover Aplicação

**Via Ansible:**
```bash
kubectl delete namespace ecommerce
```

**Manual:**
```bash
kubectl delete -f 06-ecommerce-app/manifests/ -n ecommerce
kubectl delete namespace ecommerce
```

O ALB será automaticamente removido.

---

#### 📊 Comparativo Final: Ansible vs Manual

| Tarefa | Manual | Ansible | Diferença |
|--------|--------|---------|-----------|
| **Deploy aplicação** | 15-20 min | 3 min | ⚡ **83% mais rápido** |
| **Configurar monitoramento** | 15 min | 2 min | ⚡ **87% mais rápido** |
| **Validações** | Manual (5 min) | Automático | ⚡ **100% automatizado** |
| **Documentação** | Manual | Auto-gerada | ⚡ **Zero esforço** |
| **Comandos executados** | ~15 | 1 | ⚡ **93% menos comandos** |
| **Chance de erro** | Alta | Zero | ⚡ **100% confiável** |
| **Reprodutibilidade** | Baixa | Perfeita | ⚡ **Idempotente** |
| **Total (deploy + monitor)** | **30-35 min** | **5 min** | ⚡ **85% mais rápido** |

**Conclusão:** Ansible economiza ~30 minutos por deploy e elimina completamente erros humanos! 🎯

---

## �� Troubleshooting - Erros Comuns

### Erro 1: "the server has asked for the client to provide credentials" (kubectl)

**Causa:** Access entry da terraform-role não foi criado no EKS.

**Solução:** 
1. Verifique se `02-eks-cluster/eks.cluster.access.tf` contém o bloco terraform_role (veja seção 5.4)
2. Reaplique Stack 02: `terraform apply -auto-approve`
3. Atualize kubeconfig: `aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform`

---

### Erro 2: "S3 bucket eks-devopsproject-state-files does not exist"

**Causa:** Nome do bucket S3 não inclui o Account ID ou não foi substituído corretamente.

**Solução:**
1. Verifique o nome do bucket no Stack 00: `cat 00-backend/variables.tf | grep bucket`
2. Deve ser: `eks-devopsproject-state-files-<YOUR_ACCOUNT>`
3. Corrija todos os arquivos `main.tf` e `data.cluster.remote-state.tf` nos stacks 01-05
4. Execute o comando de substituição da seção 5.2 novamente

---

### Erro 3: "SSO is not enabled in any region" (Grafana)

**Causa:** Tentativa de usar `AWS_SSO` como autenticação do Grafana sem SSO configurado.

**Solução:**
1. Edite `05-monitoring/grafana.workspace.tf`
2. Altere: `authentication_providers = ["SAML"]`
3. Reaplique: `terraform apply -auto-approve`

---

### Erro 4: "The specified instance type is not eligible for Free Tier"

**Causa:** Conta AWS Free Tier não suporta instâncias t3.medium.

**Solução:**
- **Opção 1 (Recomendada):** Faça upgrade da conta AWS para Paid Plan
- **Opção 2:** Altere em `02-eks-cluster/variables.tf`:
  ```hcl
  instance_types = ["t3.small"]  # ou ["t3.micro"]
  ```
  > ⚠️ **ATENÇÃO:** Instâncias menores podem causar problemas de performance no cluster.

---

### Erro 5: "Error creating WAF Web ACL Association" (Stack 04)

**Causa:** Tentativa de associar WAF antes do ALB existir.

**Solução:** Siga a sequência correta da seção Stack 04:
1. Criar WAF (`terraform apply`)
2. Criar Ingress (`kubectl apply -f ingress-sample-deployment.yml`)
3. Aguardar ALB ser provisionado (`kubectl get ingress -w`)
4. Renomear arquivos `.disabled` para `.tf`
5. Aplicar associação (`terraform apply`)

---

### Erro 6: "InvalidParameterException: bash_user_arn not found" ou "invalid principal"

**Causa:** Nome de usuário IAM em `locals.tf` não foi atualizado ou você está usando role assumida.

**Solução para usuário IAM direto:**
1. Edite `02-eks-cluster/locals.tf`
2. Substitua `<YOUR_IAM_USER>` pelo nome do seu usuário IAM
3. Reaplique: `terraform apply -auto-approve`

**Solução se estiver usando terraform-role (AWS profile com assume role):**
1. Comente o `bash_user` em `02-eks-cluster/eks.cluster.access.tf`
2. Atualize dependências em `eks.cluster.external.alb.tf`:
   ```hcl
   depends_on = [
     aws_iam_role_policy_attachment.load_balancer_controller,
     aws_eks_node_group.this,
     aws_eks_access_policy_association.terraform_role  # alterado de bash_user
   ]
   ```
3. Reaplique: `terraform apply -auto-approve`

---

### Erro 7: Helm provider version conflicts

**Causa:** Incompatibilidade entre versões do provider Helm.

**Solução:**
O projeto já está fixado no Helm provider v2.17.0. Se encontrar problemas:
```bash
cd 02-eks-cluster
terraform init -upgrade
```

---

### Erro 8: "VPC has dependencies and cannot be deleted" (Destroy)

**Causa:** ENIs (Network Interfaces) do Prometheus Scraper ainda anexadas à VPC.

**Sintomas:**
- `terraform destroy` da Stack 01 falha com erro de VPC dependente
- Subnets não podem ser deletadas
- Após destroy do Stack 05, VPC permanece com recursos

**Explicação Técnica:**
O Prometheus Scraper cria ENIs gerenciadas pela AWS (tipo `amp_collector`) nas subnets privadas. Quando você executa `terraform destroy`, o Terraform solicita a deleção do scraper, mas as ENIs levam **5-10 minutos** para serem liberadas automaticamente pela AWS. Durante este período, a VPC e subnets não podem ser deletadas.

**Solução Automática (destroy-all.sh):**
O script `destroy-all.sh` JÁ TEM proteção automática que aguarda até 10 minutos pelas ENIs. **Simplesmente execute:**
```bash
./destroy-all.sh
```

**Solução Manual (se destroy-all.sh falhar):**
```bash
# 1. Verificar se há ENIs do Prometheus ainda anexadas
aws ec2 describe-network-interfaces \
  --filters "Name=interface-type,Values=amp_collector" \
  --profile terraform

# 2. Se ainda houver ENIs, aguardar 5-10 minutos

# 3. Executar script de limpeza final
./cleanup-vpc-final.sh
```

**Prevenção:**
- ✅ Sempre use `./destroy-all.sh` ao invés de destroy manual
- ✅ Execute `./pre-destroy-check.sh` antes para ver warnings
- ✅ NUNCA force delete ENIs do tipo `amp_collector` (são gerenciadas pela AWS)

**Por que acontece:**
- AWS Prometheus Scraper (AMP) cria ENIs gerenciadas nas subnets do EKS
- Estas ENIs são "owned" pela AWS (`InstanceOwnerId: amazon-aws`)
- Quando você deleta o scraper, a AWS precisa de tempo para cleanup interno
- O Terraform não espera automaticamente, causando falha no destroy da VPC

**Como o código foi corrigido:**
1. **`05-monitoring/prometheus.scraper.tf`**: Adicionado lifecycle hook
2. **`destroy-all.sh`**: Adicionado wait loop de 10min verificando ENIs
3. **`cleanup-vpc-final.sh`**: Script de fallback caso ainda falhe

---

### Erro 9: "ALB still exists, cannot delete Security Groups" (Destroy)

**Causa:** Load Balancer criado por Ingress não foi deletado antes do destroy.

**Solução:**
O `destroy-all.sh` já deleta recursos Kubernetes primeiro. Se ainda encontrar:
```bash
# Deletar ALBs manualmente
kubectl delete ingress --all --all-namespaces
kubectl delete namespace ecommerce
kubectl delete namespace sample-app

# Aguardar 45s para ALB ser removido
sleep 45

# Tentar destroy novamente
cd 02-eks-cluster
terraform destroy -auto-approve
```

---

## 🗑️ Destruir Infraestrutura

### Método 1: Automático (RECOMENDADO) 🚀

**Pré-validação (Opcional):**
```bash
# Verifica recursos que podem causar problemas antes do destroy
./pre-destroy-check.sh
```

**Destroy Completo:**
```bash
# Destrói TODAS as stacks automaticamente na ordem correta
./destroy-all.sh
```

**O script faz automaticamente:**
1. ✅ Deleta recursos Kubernetes (namespaces, Ingress → ALB)
2. ✅ Aguarda ALBs serem removidos pela AWS
3. ✅ Destrói Stack 05 (Monitoring: Grafana + Prometheus)
4. ✅ **PROTEÇÃO AUTOMÁTICA:** Aguarda até 10min para ENIs do Prometheus serem liberadas
5. ✅ Remove recursos órfãos do state (WAF, Helm releases)
6. ✅ Destrói Stack 04 → 03 → 02 → 01
7. ✅ Pergunta se quer destruir Stack 00 (backend)

**⏱️ Tempo total:** ~15-25 minutos (inclui espera de ENIs)

**Se VPC não deletar (raro):**
```bash
# Script de emergência que limpa ENIs órfãs e finaliza VPC
./cleanup-vpc-final.sh
```

---

### Método 2: Manual (Para Troubleshooting)

Para destruir os recursos manualmente, siga **EXATAMENTE** esta ordem:

```bash
# Stack 05 - Monitoring
cd ./05-monitoring
terraform destroy -auto-approve

# ⚠️ CRÍTICO: Aguardar ENIs do Prometheus serem liberadas (5-10 min)
# Verificar se ENIs ainda existem:
aws ec2 describe-network-interfaces --filters "Name=interface-type,Values=amp_collector" --profile terraform

# Stack 04 - Security (WAF)
cd ../04-security
terraform destroy -auto-approve

# Stack 03 - Karpenter
cd ../03-karpenter-auto-scaling
terraform destroy -auto-approve

# Stack 02 - EKS Cluster
cd ../02-eks-cluster
terraform destroy -auto-approve

# Stack 01 - Networking
cd ../01-networking
terraform destroy -auto-approve

# Stack 00 - Backend (OPCIONAL - mantém histórico de state)
# cd ../00-backend
# terraform destroy -auto-approve
```

**⚠️ ATENÇÃO:** 
- **Não destrua** o Stack 00 se quiser manter o histórico de state do Terraform
- **CRÍTICO:** Sempre aguarde ENIs do Prometheus serem liberadas antes de destruir VPC (Stack 01)
- Aguarde cada comando concluir antes de executar o próximo
- Se houver erro, verifique seção **Troubleshooting de Destroy** abaixo

**⏱️ Tempo total de destruição:** ~15-25 minutos

---

## 💰 Estimativa de Custos

**Custos mensais aproximados (us-east-1):**

| Serviço | Custo Estimado |
|---------|----------------|
| EKS Control Plane | $73/mês |
| EC2 (3x t3.medium) | ~$90/mês |
| NAT Gateways (2x) | ~$65/mês |
| EBS Volumes | ~$10/mês |
| ALB | ~$23/mês |
| Prometheus | ~$10/mês |
| Grafana | ~$9/mês |
| **TOTAL** | **~$280/mês** |

**💡 Economia:** Destrua os recursos quando não estiver usando para economizar ~$9-10 por noite.

---


---

## 📊 Configuração do Grafana

**⚠️ OBRIGATÓRIO:** Após aplicar a Stack 05, o Grafana Workspace é criado **vazio** e **sem acesso configurado**. Você deve seguir esta seção para configurar autenticação e dashboards.

### Visão Geral do Processo

```
┌─────────────────────────────────────────────────────────────────┐
│ ETAPA 1: Configurar Autenticação SSO (OBRIGATÓRIA)             │
│ ⏱️ Tempo: 5-10 minutos                                          │
├─────────────────────────────────────────────────────────────────┤
│ 1. Habilitar IAM Identity Center (SSO)                          │
│ 2. Criar usuário SSO                                            │
│ 3. Atribuir usuário ao Grafana Workspace                        │
│ 4. Promover usuário para ADMIN (crítico!)                       │
│ 5. Acessar Grafana via AWS Access Portal                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ ETAPA 2: Configurar Data Source + Dashboards                   │
│ Escolha UMA das opções abaixo:                                  │
├─────────────────────────────────────────────────────────────────┤
│ OPÇÃO A (RECOMENDADA): Ansible Automation                      │
│ ⏱️ Tempo: 2 minutos                                             │
│ ✅ Data Source Prometheus configurado automaticamente           │
│ ✅ Dashboard Node Exporter importado automaticamente            │
├─────────────────────────────────────────────────────────────────┤
│ OPÇÃO B: Configuração Manual                                   │
│ ⏱️ Tempo: 10-15 minutos                                         │
│ ⚙️ Configurar Data Source Prometheus manualmente                │
│ ⚙️ Importar Dashboard 1860 (Node Exporter Full) manualmente     │
└─────────────────────────────────────────────────────────────────┘
```

---

## ETAPA 1: Configurar Autenticação SSO (Obrigatória para Ambas Opções)

### Passo 1: Habilitar AWS IAM Identity Center (SSO)

1. Acesse o console AWS: https://console.aws.amazon.com/singlesignon
2. Clique em **"Enable"** para ativar o IAM Identity Center
3. Anote o **Instance ID** que será criado (formato: `ssoins-xxxxxxxxxxxx`)

### Passo 2: Criar Usuário SSO

1. No IAM Identity Center, vá em **Users** (menu lateral)
2. Clique em **"Add user"**
3. Preencha:
   - **Username**: `grafana-admin` (ou nome de sua preferência)
   - **Email**: seu e-mail corporativo
   - **First name**: Seu nome
   - **Last name**: Seu sobrenome
4. Clique em **"Next"**
5. Em "Add user to groups": Pule esta etapa (Next)
6. Clique em **"Add user"**
7. Verifique seu e-mail e clique no link de verificação
8. Defina uma senha quando solicitado

### Passo 3: Obter URLs Importantes

```bash
cd 05-monitoring

# URL do Grafana Workspace
terraform output -raw grafana_workspace_url

# ID do Grafana Workspace
terraform output -raw grafana_workspace_id

# Endpoint do Prometheus (você usará no Passo 7)
terraform output -raw prometheus_workspace_endpoint
```

**Anote esses valores!** Você precisará:
- **grafana_workspace_id**: Para encontrar o workspace no console AWS
- **prometheus_workspace_endpoint**: Para configurar o Data Source no Passo 7

**Exemplo de output esperado:**
```
Grafana URL: https://g-7b4f900d4a.grafana-workspace.us-east-1.amazonaws.com/
Grafana ID: g-7b4f900d4a
Prometheus Endpoint: https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-12345678-abcd-1234-efgh-123456789012
```

### Passo 4: Atribuir Usuário ao Grafana Workspace

1. Acesse: https://console.aws.amazon.com/grafana/home?region=us-east-1
2. Clique no workspace que foi criado (ex: `g-8e1225a34f`)
3. Vá na aba **"Authentication"**
4. Na seção **"AWS IAM Identity Center"**, clique em **"Assign new user or group"**
5. Selecione:
   - **Type**: User
   - **User**: Selecione o usuário que criou (ex: `grafana-admin`)
6. Clique em **"Assign users and groups"**

### Passo 5: Alterar Permissão para ADMIN ⚠️ OBRIGATÓRIO

1. Na mesma aba **"Authentication"**, localize o usuário na tabela
2. Selecione o usuário (marque o checkbox ao lado do nome)
3. Clique no botão **"Actions"** (no topo da tabela)
4. Selecione **"Make admin"**
5. Confirme a alteração

> ⚠️ **CRÍTICO:** Sem permissão ADMIN, você NÃO conseguirá:
> - Adicionar Data Sources (manual ou via Ansible)
> - Importar Dashboards (manual ou via Ansible)
> - Executar playbook Ansible (falhará com erro 403 Forbidden)

> 📝 **Nota:** A interface AWS foi atualizada. Se você ainda vê os 3 pontinhos **[...]**, use essa opção. Caso contrário, use o botão **Actions** → **Make admin**.

---

### ✅ Checkpoint: Autenticação SSO Configurada

**Parabéns!** Você completou a ETAPA 1. Agora você tem:
- ✅ IAM Identity Center (SSO) habilitado
- ✅ Usuário SSO criado e verificado
- ✅ Usuário atribuído ao Grafana Workspace com permissão ADMIN
- ✅ Acesso ao Grafana via AWS Access Portal

**🎯 Próximo Passo:** Configure o Grafana com Ansible (automação)

---

## ETAPA 2: Configuração Automática com Ansible ⭐

**⏱️ Tempo:** 2 minutos  
**📋 Pré-requisitos:**
- ✅ ETAPA 1 completa (SSO configurado com usuário ADMIN)
- ✅ Ansible instalado (ver [QUICK-START-ANSIBLE.md](./docs/QUICK-START-ANSIBLE.md))

**🚀 Execução:**

```bash
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml
```

**✅ Resultado esperado:**
```
PLAY RECAP *********************************************************************
localhost : ok=3 changed=2 unreachable=0 failed=0

✅ Data Source Prometheus configurado automaticamente
✅ Dashboard Node Exporter Full (ID 1860) importado automaticamente
✅ Grafana 100% pronto para uso
```

**🎉 Pronto!** Prossiga para a "Validação Final" abaixo.

---

### 🔧 Preferiu Configurar Manualmente?

Se você **não pode** usar Ansible ou quer entender o processo passo a passo:

📖 **Guia Completo:** [CONFIGURACAO-MANUAL-GRAFANA.md](./docs/CONFIGURACAO-MANUAL-GRAFANA.md)

**Tempo estimado:** 10-15 minutos (vs 2 minutos com Ansible)

O guia manual inclui:
- Passo a passo detalhado para configurar Data Source Prometheus
- Instruções para importar Dashboard Node Exporter (ID 1860)
- Troubleshooting de erros comuns
- Queries PromQL para testes

---

## ✅ Validação Final do Grafana

Após executar o playbook Ansible, valide se tudo está funcionando:

**1. Verificar Data Source:**
- Menu lateral → **Connections** → **Data sources**
- Deve aparecer: **Prometheus** (verde, ativo)

**2. Verificar Dashboard:**
- Menu lateral → **Dashboards**
- Deve aparecer: **Node Exporter Full**
- Clique no dashboard e verifique se os gráficos estão mostrando dados

**3. Verificar Métricas:**
- No dashboard, você deve ver métricas dos 3 nodes do EKS
- Gráficos de CPU, Memória, Disco devem estar populados com dados

🎉 **Sucesso!** Seu Grafana está 100% configurado e monitorando o cluster!

### 📊 Métricas Disponíveis no Dashboard Node Exporter Full

- 📊 **CPU**: Usage, cores, idle, system, user, iowait
- 💾 **Memória**: Total, usado, disponível, cache, buffers
- 💿 **Disco**: I/O read/write, utilização, espaço livre
- 🌐 **Rede**: Tráfego RX/TX, pacotes, erros, drops
- ⚡ **Sistema**: Load average (1m, 5m, 15m), uptime, processes
- 📁 **File System**: Inodes, mount points, file descriptors

### Troubleshooting

#### ❌ Grafana vazio (sem data sources, sem dashboards)
**Causa:** Isso é **esperado**! O Terraform provisiona apenas o workspace Grafana vazio.

**Solução:** Você **deve** configurar manualmente:
1. **Data Source Prometheus**: Siga o Passo 7 acima
   - Menu lateral → Connections → Add data source → Prometheus
   - Configure URL do Prometheus (obtido via `terraform output`)
   - Habilite SigV4 auth
2. **Dashboards**: Siga o Passo 8 acima
   - Menu lateral → Dashboards → New → Import
   - Digite ID **1860** (Node Exporter Full)

**Tempo estimado:** 5 minutos para configuração completa

---

#### ❌ Erro "sso.auth.access-denied" ao tentar acessar Grafana
**Causa:** Usuário SSO existe, mas não está atribuído ao workspace Grafana ou tem permissão VIEWER.

**Solução:**
1. Acesse: https://console.aws.amazon.com/grafana/home?region=us-east-1
2. Clique no workspace criado (ex: `g-7b4f900d4a`)
3. Vá na aba **"Authentication"**
4. Verifique se seu usuário SSO está na lista
   - Se **NÃO**: Clique em "Assign new user or group" e adicione
   - Se **SIM**: Verifique se a role é **ADMIN** (não VIEWER)
5. Aguarde 1-2 minutos e tente novamente

---

#### ❌ Erro "403 Forbidden" ao executar Ansible
**Causa:** Usuário SSO tem permissão VIEWER ao invés de ADMIN.

**Solução:**
1. Acesse: https://console.aws.amazon.com/grafana/home?region=us-east-1
2. Clique no workspace → aba "Authentication"
3. Selecione o usuário → Actions → Make admin
4. Aguarde 1-2 minutos
5. Re-execute o playbook Ansible

---

#### ❌ Erro 404 ao clicar "Go to connections"
**Solução**: Acesse diretamente via menu lateral → Connections

#### ❌ Botão "Add data source" desabilitado
**Solução**: Usuário está com role VIEWER. Altere para ADMIN (Passo 5)

#### ❌ "Missing Authentication Token" ao testar Prometheus
**Solução**: Certifique-se de:
- Marcar **SigV4 auth**
- Preencher **Service: aps**
- URL sem barra `/` no final

#### ❌ "Page not found" ou "HttpNotFoundException"
**Solução**: Verifique se a URL do Prometheus está correta (sem `/api/v1/query` no final)

### Queries PromQL Úteis

Teste no **Explore** do Grafana:

```promql
# CPU usage por node
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memória disponível em %
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disco usado em %
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Load average 5 minutos
node_load5

# Tráfego de rede (recebido)
rate(node_network_receive_bytes_total[5m])
```


## 📚 Recursos Adicionais

### Testes e Validação

O projeto inclui arquivos de exemplo (YAML manifests) para validação manual dos componentes:

📖 **Guia Completo de Testes:** [TESTES-VALIDACAO-MANUAL.md](./docs/TESTES-VALIDACAO-MANUAL.md)

O guia inclui:
- ✅ Validação de EBS CSI Driver (Persistent Volumes)
- ✅ Validação de ALB Ingress Controller + WAF
- ✅ Validação de Karpenter Auto-Scaling
- ✅ Validação de External DNS
- ✅ Validação de Prometheus Node Exporter
- 📊 Checklist completo de validação

> 💡 **Dica:** Para ambientes de produção, considere automatizar estes testes com Ansible ou CI/CD pipelines ao invés de executá-los manualmente.

### Comandos Úteis

```bash
# Verificar versão do cluster
aws eks describe-cluster \
    --name eks-devopsproject-cluster \
    --query 'cluster.version' \
    --profile terraform

# Listar todos os addons instalados
aws eks list-addons \
    --cluster-name eks-devopsproject-cluster \
    --profile terraform

# Verificar logs do Karpenter
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=100 -f

# Ver detalhes do NodePool do Karpenter
kubectl describe nodepool default-node-pool

# Verificar WAF rules aplicadas
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1 --profile terraform

# Acessar Grafana (após deploy do Stack 05)
cd 05-monitoring
terraform output -raw grafana_workspace_url

# Ou obter URL do Prometheus
terraform output -raw prometheus_workspace_endpoint
```

### Links da Documentação Oficial

- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Karpenter Documentation](https://karpenter.sh/)
- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/)
- [Amazon Managed Prometheus](https://docs.aws.amazon.com/prometheus/)
- [Amazon Managed Grafana](https://docs.aws.amazon.com/grafana/)

---

## 🤝 Suporte

Se encontrar problemas durante o deployment:

1. Verifique a seção **Troubleshooting** acima
2. Confirme que seguiu **exatamente** a sequência de deployment
3. Verifique se todas as substituições de variáveis foram feitas (Account ID, Bucket S3, IAM User)
4. Consulte os logs do Terraform: `terraform apply` sem `-auto-approve` para ver detalhes
5. Verifique se sua conta AWS tem os limites de serviço adequados

---

## 📝 Notas Importantes

- ✅ Projeto testado e validado com Terraform 1.12.2
- ✅ Compatível com EKS 1.32
- ✅ Helm provider fixado em v2.17.0 para evitar breaking changes
- ✅ Todos os stacks usam remote state em S3 com state locking em DynamoDB
- ✅ IAM Roles seguem princípio de least privilege exceto AdministratorAccess na terraform-role
- ⚠️ Requer AWS Paid Plan ou créditos suficientes para instâncias t3.medium
- ⚠️ Custo estimado: ~$280/mês se mantido ligado 24/7
- 💡 Economia: ~$9-10/noite destruindo recursos fora do horário de uso

---

## ✅ CAPACIDADE DE IPs OTIMIZADA

### 📊 Configuração Atual

Este projeto já está **otimizado automaticamente** para evitar problemas de esgotamento de IPs:

**Subnets Privadas:**
- **CIDR:** /26 (ao invés de /27)
- **Capacidade:** 59 IPs úteis por subnet (vs 27 anteriormente)
- **Total:** ~118 IPs disponíveis para workloads

**AWS VPC CNI Otimizado:**
- `WARM_ENI_TARGET=0` - Não pré-aloca ENIs desnecessárias
- `WARM_IP_TARGET=5` - Mantém apenas 5 IPs warm por node
- `MINIMUM_IP_TARGET=10` - Garante mínimo de 10 IPs por node
- **Economia:** ~15-20% de IPs comparado com configuração padrão

### 🎯 Capacidade de Workload

Com esta configuração, você pode executar:
- ✅ **5-8 nodes t3.medium** confortavelmente
- ✅ **40-60 pods** distribuídos no cluster
- ✅ **Monitoramento completo** (Prometheus + Grafana + Node Exporter)
- ✅ **Aplicação e-commerce** (7 microserviços)
- ✅ **Karpenter auto-scaling** com margem para crescimento

### 🔍 Monitoramento de IPs (Opcional)

Se quiser verificar quantos IPs estão disponíveis:

```bash
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private-subnet*" \
    --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform
```

**Valores esperados após deploy:**
- `private-subnet-us-east-1a`: ~50-55 IPs disponíveis
- `private-subnet-us-east-1b`: ~50-55 IPs disponíveis

> 💡 **Nota:** Se você precisar expandir ainda mais (produção de grande escala), considere usar subnets /25 (123 IPs úteis) editando `01-networking/variables.tf` antes do primeiro deploy.

---

## ⚠️ TROUBLESHOOTING: Problemas Históricos Resolvidos

### Esgotamento de IPs nas Subnets (RESOLVIDO ✅)

**Versões antigas** deste projeto (antes de 01/12/2025) usavam subnets /27 (27 IPs úteis), o que causava esgotamento em ambientes com muitos pods.

**Solução aplicada automaticamente:**
- ✅ Subnets expandidas para /26 (59 IPs úteis)
- ✅ AWS VPC CNI otimizado por padrão
- ✅ Sem necessidade de configuração manual

Se você ainda encontrar o erro `InsufficientFreeAddresses`, verifique se está usando a versão atualizada:

#### Diagnóstico Rápido (apenas para troubleshooting)

Verifique quantos IPs estão disponíveis:

```bash
# 1. Listar todas as subnets privadas
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private*" \
    --query 'Subnets[].[SubnetId,CidrBlock,AvailableIpAddressCount,Tags[?Key==`Name`].Value|[0]]' \
    --output table \
    --profile terraform

# 2. Ver detalhes de uma subnet específica
aws ec2 describe-subnets \
    --subnet-ids subnet-xxxxxxxxx \
    --query 'Subnets[0].[SubnetId,CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform

# 3. Contar ENIs e IPs secundários por node
aws ec2 describe-network-interfaces \
    --filters "Name=subnet-id,Values=subnet-xxxxxxxxx" \
    --query 'NetworkInterfaces[].[NetworkInterfaceId,PrivateIpAddress,PrivateIpAddresses[].PrivateIpAddress|length(@),Description]' \
    --output table \
    --profile terraform
```

**Indicadores de problema:**
- ✅ **Saudável:** AvailableIpAddressCount > 10 (>40% da capacidade)
- ⚠️ **Atenção:** AvailableIpAddressCount 5-10 (20-40% da capacidade)
- 🔴 **Crítico:** AvailableIpAddressCount < 5 (<20% da capacidade)

---

```bash
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private-subnet*" \
    --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform
```

**Valores esperados:**
- ✅ **Saudável:** AvailableIpAddressCount > 40 (com subnets /26)
- ⚠️ **Atenção:** AvailableIpAddressCount < 20 (subnet sob pressão)
- 🔴 **Crítico:** AvailableIpAddressCount < 10 (precisa expansão urgente)

**Se você ainda usar subnets /27 antigas:**
Edite `01-networking/variables.tf` e mude os CIDRs para:
- `10.0.1.0/26` e `10.0.1.64/26` (staging - 59 IPs cada)
- `10.0.2.0/25` e `10.0.2.128/25` (produção - 123 IPs cada)

Depois execute `./rebuild-all.sh` para recriar a infraestrutura.

---

## 📋 Checklist de Validação Pós-Deploy

**Quando usar:** Ambiente de desenvolvimento/testes, subnet /27, poucos nodes (2-4)

**Prós:**
- ✅ **Custo:** $0 (zero investimento)
- ✅ **Downtime:** Zero (configuração online)
- ✅ **Complexidade:** Baixa (5 minutos)
- ✅ **Ganho:** Reduz consumo de IPs em ~15-20%
- ✅ **Reversível:** Sim, facilmente

**Contras:**
- ⚠️ **Ganho limitado:** Libera apenas 4-5 IPs em subnet /27
- ⚠️ **Necessita reciclagem de nodes:** Para efeito imediato
- ⚠️ **Não escala:** Solução paliativa, não resolve crescimento futuro

**Passo a Passo:**

```bash
# 1. Aplicar configuração otimizada no AWS VPC CNI
kubectl set env daemonset aws-node -n kube-system \
  WARM_ENI_TARGET=0 \
  WARM_IP_TARGET=5 \
  MINIMUM_IP_TARGET=10

# 2. Verificar rollout
kubectl rollout status daemonset aws-node -n kube-system --timeout=3m

# 3. Confirmar configuração aplicada
kubectl get daemonset aws-node -n kube-system -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WARM_ENI_TARGET")].value}' && echo
kubectl get daemonset aws-node -n kube-system -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WARM_IP_TARGET")].value}' && echo

# 4. OPCIONAL: Reciclar nodes para efeito imediato (ou aguardar liberação natural)
# ATENÇÃO: Isto causará recriação dos nodes e reagendamento de todos os pods

# 4a. Obter lista de nodes
kubectl get nodes -o wide

# 4b. Obter IDs das instâncias EC2 dos nodes
aws ec2 describe-instances \
    --filters "Name=tag:eks:cluster-name,Values=eks-devopsproject-cluster-<YOUR_ACCOUNT>" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress]' \
    --output table \
    --profile terraform

# 4c. Terminar as instâncias (ASG criará novas automaticamente com CNI otimizado)
aws ec2 terminate-instances \
    --instance-ids i-xxxxxxxxx i-yyyyyyyyy i-zzzzzzzzz \
    --profile terraform

# 4d. Aguardar novos nodes (2-3 minutos)
watch kubectl get nodes

# 5. Validar IPs liberados (após 3-5 minutos)
aws ec2 describe-subnets \
    --subnet-ids subnet-xxxxxxxxx \
    --query 'Subnets[0].AvailableIpAddressCount' \
    --profile terraform
```

**Resultado esperado:** De 1-2 IPs disponíveis para 5-7 IPs disponíveis (ganho de +400%)

**Reverter (se necessário):**
```bash
kubectl set env daemonset aws-node -n kube-system \
  WARM_ENI_TARGET=1 \
  WARM_IP_TARGET- \
  MINIMUM_IP_TARGET-
```

---

#### **OPÇÃO 2: Expandir Subnet para /26 ou /25 (SOLUÇÃO DEFINITIVA)** ⭐⭐⭐

**Quando usar:** Produção, staging, ou qualquer ambiente que precisará escalar

**Prós:**
- ✅ **Ganho significativo:** /26 = 59 IPs úteis (+118%) | /25 = 123 IPs úteis (+355%)
- ✅ **Escalabilidade:** Suporta crescimento futuro
- ✅ **Estabilidade:** Solução definitiva, não paliativa
- ✅ **Sem reconfigurações:** Não precisa otimizar CNI

**Contras:**
- ⚠️ **Requer recriação da subnet:** Necessário destruir e recriar Stack 01 e seguintes
- ⚠️ **Downtime:** ~30-40 minutos (destruição + recriação)
- ⚠️ **Trabalhoso:** Precisa recriar todas as stacks dependentes
- ⚠️ **Perda de dados temporários:** Pods e volumes efêmeros são perdidos

**Passo a Passo:**

```bash
# 1. Destruir stacks (ordem inversa)
# Certifique-se de estar na raiz do projeto
cd ./05-monitoring && terraform destroy -auto-approve
cd ../04-security && terraform destroy -auto-approve
cd ../03-karpenter-auto-scaling && terraform destroy -auto-approve
cd ../02-eks-cluster && terraform destroy -target=helm_release.external_dns -auto-approve
cd ../02-eks-cluster && terraform destroy -target=helm_release.load_balancer_controller -auto-approve
cd ../02-eks-cluster && terraform destroy -auto-approve
cd ../01-networking && terraform destroy -auto-approve

# 2. Editar arquivo de subnets privadas
# Abrir: 01-networking/vpc.private-subnets.tf
# Alterar os CIDRs das 3 subnets privadas:

# DE (subnet /27 = 27 IPs úteis):
# private-subnet-us-east-1a = "10.0.0.32/27"   # 10.0.0.32 - 10.0.0.63
# private-subnet-us-east-1b = "10.0.0.96/27"   # 10.0.0.96 - 10.0.0.127
# private-subnet-us-east-1c = "10.0.0.160/27"  # 10.0.0.160 - 10.0.0.191

# PARA /26 (59 IPs úteis - RECOMENDADO PARA STAGING):
# private-subnet-us-east-1a = "10.0.1.0/26"    # 10.0.1.0 - 10.0.1.63
# private-subnet-us-east-1b = "10.0.1.64/26"   # 10.0.1.64 - 10.0.1.127
# private-subnet-us-east-1c = "10.0.1.128/26"  # 10.0.1.128 - 10.0.1.191

# OU PARA /25 (123 IPs úteis - RECOMENDADO PARA PRODUÇÃO):
# private-subnet-us-east-1a = "10.0.2.0/25"    # 10.0.2.0 - 10.0.2.127
# private-subnet-us-east-1b = "10.0.2.128/25"  # 10.0.2.128 - 10.0.2.255
# private-subnet-us-east-1c = "10.0.3.0/25"    # 10.0.3.0 - 10.0.3.127

# 3. Recriar todas as stacks (seguir sequência de deploy completa)
cd ../01-networking && terraform init && terraform apply -auto-approve
cd ../02-eks-cluster && terraform init && terraform apply -auto-approve
# ... continuar com stacks 03, 04, 05

# 4. Validar capacidade da nova subnet
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private-subnet-us-east-1b*" \
    --query 'Subnets[].[SubnetId,CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform
```

**Resultado esperado:**
- /26: ~55-57 IPs disponíveis (de 27 para 59 IPs úteis)
- /25: ~119-121 IPs disponíveis (de 27 para 123 IPs úteis)

---

#### **OPÇÃO 3: Adicionar Mais Availability Zones (MÉDIA COMPLEXIDADE)**

**Quando usar:** Precisa de alta disponibilidade em múltiplas AZs, mas não quer recriar subnets

**Prós:**
- ✅ **Aumenta capacidade total:** Distribui carga entre mais subnets
- ✅ **Alta disponibilidade:** Mais AZs = mais resiliência
- ✅ **Mantém subnets existentes:** Não precisa destruir stacks

**Contras:**
- ⚠️ **Não resolve subnet específica:** Se us-east-1b está cheia, continua cheia
- ⚠️ **Custo:** +$32/mês por NAT Gateway adicional
- ⚠️ **Complexidade moderada:** Requer edição de múltiplos arquivos

**Passo a Passo:**

```bash
# 1. Adicionar us-east-1d, us-east-1e, ou us-east-1f em:
#    - 01-networking/vpc.private-subnets.tf
#    - 01-networking/vpc.public-subnets.tf  
#    - 01-networking/vpc.nat-gateways.tf
#    - 01-networking/vpc.private-route-tables.tf

# 2. Aplicar mudanças
cd ./01-networking && terraform apply -auto-approve

# 3. Node Group do EKS automaticamente distribuirá nodes nas novas subnets
```

**Resultado esperado:** Carga distribuída, mas custo adicional de ~$32/mês por AZ

---

### 🎯 Matriz de Decisão: Qual Opção Escolher?

| Cenário | Opção Recomendada | Justificativa |
|---------|-------------------|---------------|
| **Dev/Testes com poucos pods** | Opção 1 (CNI) | Rápido, grátis, resolve temporariamente |
| **Staging com crescimento** | Opção 2 (/26) | Balanceia capacidade e custo |
| **Produção crítica** | Opção 2 (/25) + Opção 1 | Máxima capacidade + otimização |
| **Multi-região HA** | Opção 3 + Opção 1 | Resiliência + eficiência |
| **Orçamento zero** | Opção 1 (CNI) | Única opção sem custo |
| **Problema urgente** | Opção 1 (CNI) | Resolve em 5 minutos |

---

Após aplicar qualquer opção, valide:

```bash
# ✅ 1. Subnet tem IPs suficientes (>40 com /26)
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private-subnet*" \
    --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform

# ✅ 2. Todos os nodes estão Ready
kubectl get nodes

# ✅ 3. Todos os pods estão Running (nenhum ContainerCreating)
kubectl get pods -A | grep -v Running | grep -v Completed
```

---

## 🙏 Créditos

Este projeto é um fork do trabalho original de **[Kenerry Serain](https://github.com/kenerry-serain)**, desenvolvido como material do curso **DevOps na Nuvem**.

Agradecimentos especiais pela estrutura e conhecimento compartilhado que tornou este projeto possível.

**Repositório Original:** [kenerry-serain (GitHub)](https://github.com/kenerry-serain)

---

## 📄 Licença

Este projeto é fornecido como material educacional. Uso livre para fins de estudo e desenvolvimento pessoal.

---

**Desenvolvido com ❤️ para aprendizado de DevOps e Infraestrutura como Código**

