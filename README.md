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

### 5.1. Substituir Account ID em TODOS os arquivos

**CRÍTICO:** Substitua `620958830769` pelo ID da sua conta AWS em **todos** os arquivos `.tf`:

#### 🐧 **(WSL/Linux)**

```bash
find . -type f -name "*.tf" -exec sed -i \
    's|620958830769|<YOUR_ACCOUNT>|g' {} +
```

#### 🍎 **(MacOS)**

```bash
find . -type f -name "*.tf" -exec sed -i '' \
    's|620958830769|<YOUR_ACCOUNT>|g' {} +
```

---

### 5.2. Atualizar Nome do Bucket S3 Backend

O nome do bucket S3 precisa ser **único globalmente** e incluir o ID da sua conta:

#### 🐧 **(WSL/Linux)**

```bash
find . -type f -name "*.tf" -exec sed -i \
    's|eks-devopsproject-state-files-620958830769|eks-devopsproject-state-files-<YOUR_ACCOUNT>|g' {} +
```

#### 🍎 **(MacOS)**

```bash
find . -type f -name "*.tf" -exec sed -i '' \
    's|eks-devopsproject-state-files-620958830769|eks-devopsproject-state-files-<YOUR_ACCOUNT>|g' {} +
```

---

### 5.3. Configurar Usuário IAM no locals.tf (Stack 02)

**OBRIGATÓRIO:** Edite o arquivo `02-eks-cluster/locals.tf` e substitua o nome do usuário IAM:

```hcl
locals {
  bash_user_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/<YOUR_USER>"
  console_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_xxxxx"
  eks_oidc_url     = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}
```

Substitua:
- `<YOUR_USER>` pelo nome do usuário IAM criado no passo 1
- `console_user_arn` pelo ARN do seu SSO role (se aplicável), ou comente a linha se não usar SSO

---

### 5.4. Adicionar terraform-role ao EKS Access (Stack 02)

**CRÍTICO:** O arquivo `02-eks-cluster/eks.cluster.access.tf` **deve** conter o access entry para a terraform-role, caso contrário `kubectl` não funcionará:

Verifique se o arquivo contém:

```hcl
# Terraform Role Access
resource "aws_eks_access_entry" "terraform_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_role" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role"

  access_scope {
    type = "cluster"
  }
}
```

> ⚠️ **ATENÇÃO:** Sem este access entry, você receberá erro `"the server has asked for the client to provide credentials"` ao tentar usar kubectl.

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

1. Edite `02-eks-cluster/locals.tf` e configure seu usuário IAM (veja seção 5.3)
2. Verifique `02-eks-cluster/eks.cluster.access.tf` contém terraform-role access entry (veja seção 5.4)
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

### Stack 04 - Security (WAF)

Habilite o Web Application Firewall para filtrar requisições do Application Load Balancer.

> ⚠️ **ATENÇÃO - SEQUÊNCIA CRÍTICA:** A associação do WAF com o ALB requer uma sequência específica de passos. Siga exatamente esta ordem:

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

Antes de associar o WAF ao ALB, é necessário que o ALB exista. Crie um deployment de teste:

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

### Stack 05 - Monitoring (Prometheus + Grafana)

Configure Amazon Managed Prometheus e Amazon Managed Grafana para monitorar o Cluster EKS.

**ANTES DE APLICAR:**

1. Verifique se `05-monitoring/data.cluster.remote-state.tf` usa o bucket correto com seu Account ID
2. Se não tiver AWS SSO configurado, certifique-se que `05-monitoring/grafana.workspace.tf` use:
   ```hcl
   authentication_providers = ["SAML"]  # ou ["AWS_SSO"] se tiver SSO
   ```

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

| Stack | Recursos | Tempo Estimado |
|-------|----------|----------------|
| 00 - Backend | 3 | < 1 min |
| 01 - Networking | 21 | 2-3 min |
| 02 - EKS Cluster | 21 | 15-20 min |
| 03 - Karpenter | 10 | 3-5 min |
| 04 - Security/WAF | 2 | 1 min |
| 05 - Monitoring | 7 | 20-25 min |
| **TOTAL** | **64** | **~40-55 min** |

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

### Erro 6: "InvalidParameterException: bash_user_arn not found"

**Causa:** Nome de usuário IAM em `locals.tf` não foi atualizado.

**Solução:**
1. Edite `02-eks-cluster/locals.tf`
2. Substitua `user/<YOUR_USER>` pelo nome do seu usuário IAM
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

## 🗑️ Destruir Infraestrutura

Para destruir os recursos provisionados, siga **EXATAMENTE** esta ordem para evitar erros de dependência:

### Ordem de Destruição

```bash
# Stack 05 - Monitoring
cd ./05-monitoring
terraform destroy -auto-approve

# Stack 04 - Security (WAF)
cd ../04-security
terraform destroy -auto-approve

# Stack 03 - Karpenter
cd ../03-karpenter-auto-scaling
terraform destroy -auto-approve

# Stack 02 - EKS Cluster (ORDEM IMPORTANTE)
cd ../02-eks-cluster

# Primeiro: Destruir External DNS
terraform destroy -target=helm_release.external_dns -auto-approve

# Segundo: Destruir ALB Controller
terraform destroy -target=helm_release.load_balancer_controller -auto-approve

# Terceiro: Destruir resto do cluster
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
- Sempre siga a ordem inversa do deployment
- Aguarde cada comando concluir antes de executar o próximo
- Se houver erro, verifique se há recursos dependentes (ex: ALBs criados por Ingress) e delete-os manualmente

**⏱️ Tempo total de destruição:** ~15-20 minutos

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

## 📊 Configuração do Grafana (Stack 05)

> ⚠️ **IMPORTANTE:** O Grafana é provisionado **vazio**. Após obter acesso, você precisará **manualmente**:
> 1. Configurar o Data Source Prometheus (Passo 7)
> 2. Importar dashboards (Passo 8)
> 
> O Terraform **não** configura automaticamente data sources ou dashboards no workspace Grafana.

### Pré-requisitos

Após fazer o deploy da Stack 05 (Monitoring), você precisará configurar o acesso ao Grafana manualmente via AWS SSO.

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

### Passo 5: Alterar Permissão para ADMIN

1. Na mesma aba **"Authentication"**, localize o usuário na tabela
2. Selecione o usuário (marque o checkbox ao lado do nome)
3. Clique no botão **"Actions"** (no topo da tabela)
4. Selecione **"Make admin"**
5. Confirme a alteração

> 📝 **Nota:** A interface AWS foi atualizada. Se você ainda vê os 3 pontinhos **[...]**, use essa opção. Caso contrário, use o botão **Actions** → **Make admin**.

### Passo 6: Acessar o Grafana

1. Acesse o **AWS Access Portal** (você recebeu por e-mail ou encontre em IAM Identity Center)
   - Formato: `https://d-xxxxxxxxxx.awsapps.com/start`
2. Faça login com o usuário SSO criado
3. Você verá um card **"Amazon Managed Grafana"**
4. Clique nele para acessar o Grafana

### Passo 7: Configurar Data Source Prometheus

**Obter endpoint do Prometheus** (execute antes de configurar):
```bash
cd 05-monitoring
terraform output -raw prometheus_workspace_endpoint
```

**Dentro do Grafana:**

1. **Menu lateral** → **Connections** → **Data sources**
2. Clique em **"Add data source"**
3. Selecione **"Prometheus"**
4. Configure:
   ```
   Name: Prometheus
   
   URL: <COLE_AQUI_O_ENDPOINT_DO_PROMETHEUS>
   ```
   **Exemplo:**
   ```
   URL: https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-12345678-abcd-1234-efgh-123456789012
   ```
   > ⚠️ **ATENÇÃO:** Cole o endpoint **exatamente** como retornado pelo `terraform output` (sem barra `/` no final)

5. **Auth**: Marque **☑ SigV4 auth**
6. **SigV4 Auth Details**:
   - **Authentication Provider**: `Workspace IAM Role`
   - **Default Region**: `us-east-1`
   - **Service**: `aps`
7. Role até o final e clique em **"Save & test"**
8. Deve aparecer: ✅ **"Successfully queried the Prometheus API."**

### Passo 8: Importar Dashboard Node Exporter

1. **Menu lateral** → **Dashboards**
2. Clique em **"New"** → **"Import"**
3. Digite o ID: **1860**
4. Clique em **"Load"**
5. Clique em **"Import"** (o data source Prometheus será selecionado automaticamente)

> 📝 **Nota:** Para o dashboard 1860 (Node Exporter Full), após clicar em "Load", o Grafana detecta automaticamente o data source Prometheus configurado no Passo 7. Não é necessário selecionar manualmente.

🎉 **Pronto!** Agora você tem:
- ✅ Dashboard Node Exporter Full funcionando
- ✅ Métricas de CPU, Memória, Disco, Rede dos nodes
- ✅ Grafana com autenticação SSO
- ✅ Monitoramento completo do cluster

### Métricas Disponíveis no Dashboard

O **Node Exporter Full** mostra:
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

### Arquivos de Exemplo

O projeto inclui arquivos de exemplo para testes:

- **`02-eks-cluster/samples/csi-sample-deployment.yml`**: Deployment de teste com EBS CSI
- **`02-eks-cluster/samples/ingress-sample-deployment.yml`**: Deployment nginx com Ingress e ALB
- **`03-karpenter-auto-scaling/samples/karpenter-nginx-deployment.yml`**: Deployment para testar Karpenter auto-scaling

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

## ⚠️ PROBLEMA COMUM: Esgotamento de IPs na Subnet

### 🔴 Sintoma

Após o deploy completo, você pode receber um ou mais destes erros/avisos:

**1. Alerta no Console EKS:**
```
InsufficientFreeAddresses
One or more of the subnets associated with your cluster does not have enough 
available IP addresses for Amazon EKS to perform cluster management operations. 
Free up addresses in the subnet(s), or associate different subnets to your 
cluster using the Amazon EKS update-cluster-config API.
```

**2. Erro ao provisionar instâncias EC2:**
```
InsufficientFreeAddresses - We currently do not have sufficient IP addresses 
in the subnet subnet-xxxxxxxxx (10.0.0.96/27) to launch the instance.
```

**3. Pods travados em ContainerCreating:**
```
Failed to create pod sandbox: plugin type="aws-cni" failed (add): 
failed to assign an IP address to container
```

**Causa Raiz:** AWS VPC CNI com configuração padrão pré-aloca ENIs com até 6 IPs secundários por node, consumindo rapidamente os 27 IPs úteis de uma subnet /27.

---

### 📊 Análise do Problema

#### Diagnóstico Rápido

Verifique quantos IPs estão disponíveis na subnet problemática (normalmente `private-subnet-us-east-1b`):

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

### 🛠️ Opções de Solução

Você tem **3 opções** para resolver este problema. Escolha baseado no seu cenário:

---

#### **OPÇÃO 1: Otimização AWS VPC CNI (RECOMENDADA)** ⭐

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
cd /home/luiz7/Projects/eks-express-iac-nova-conta
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

### 📋 Checklist de Validação Pós-Solução

Após aplicar qualquer opção, valide:

```bash
# ✅ 1. Subnet tem IPs suficientes (>10)
aws ec2 describe-subnets \
    --subnet-ids subnet-xxxxxxxxx \
    --query 'Subnets[0].AvailableIpAddressCount' \
    --profile terraform

# ✅ 2. Todos os nodes estão Ready
kubectl get nodes

# ✅ 3. Todos os pods estão Running (nenhum ContainerCreating)
kubectl get pods -A | grep -v Running | grep -v Completed

# ✅ 4. CNI está configurado corretamente (se usou Opção 1)
kubectl get daemonset aws-node -n kube-system \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WARM_ENI_TARGET")].value}' && echo

# ✅ 5. Não há alertas AWS sobre IPs
# Verificar CloudWatch ou AWS Personal Health Dashboard
```

---

### 💡 Lições Aprendidas e Melhores Práticas

1. **Dimensionamento de Subnets:**
   - Dev: /27 (27 IPs) - Suficiente para 2-3 nodes + CNI otimizado
   - Staging: /26 (59 IPs) - Suporta 5-8 nodes confortavelmente
   - Produção: /25 (123 IPs) - Recomendado para escalabilidade

2. **Monitoramento Proativo:**
   ```bash
   # Criar alarme CloudWatch para IPs < 10
   aws cloudwatch put-metric-alarm \
       --alarm-name subnet-low-ips \
       --metric-name AvailableIpAddressCount \
       --namespace AWS/EC2 \
       --statistic Average \
       --period 300 \
       --evaluation-periods 1 \
       --threshold 10 \
       --comparison-operator LessThanThreshold \
       --profile terraform
   ```

3. **Otimização CNI como Padrão:**
   - Sempre aplique Opção 1 (CNI otimizado) **mesmo** com subnets /26 ou /25
   - Reduz desperdício e aumenta eficiência em qualquer cenário

4. **Planejamento de Capacidade:**
   - Calcule: `(Nodes × 10 IPs/node) + 5 IPs reserva`
   - Exemplo: 5 nodes = mínimo 55 IPs = subnet /26

---

### 🔍 Troubleshooting Adicional

**Problema:** Após otimizar CNI, IPs não foram liberados

**Solução:**
```bash
# 1. Verificar se configuração foi aplicada
kubectl get daemonset aws-node -n kube-system -o yaml | grep -A3 "WARM_"

# 2. Restart pods aws-node
kubectl delete pods -n kube-system -l k8s-app=aws-node

# 3. Aguardar 5 minutos e verificar novamente
sleep 300
aws ec2 describe-subnets --subnet-ids subnet-xxxxxxxxx \
    --query 'Subnets[0].AvailableIpAddressCount' \
    --profile terraform

# 4. Se ainda não liberou, reciclar nodes (Opção 1, passo 4)
```

**Problema:** Pods ficam `ContainerCreating` mesmo com IPs disponíveis

**Solução:**
```bash
# 1. Verificar eventos do pod
kubectl describe pod <pod-name> -n <namespace>

# 2. Verificar logs do aws-node no node específico
kubectl logs -n kube-system -l k8s-app=aws-node --all-containers=true | grep ERROR

# 3. Deletar pod para forçar reagendamento
kubectl delete pod <pod-name> -n <namespace>
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

