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

> ⚠️ **IMPORTANTE:** Se você **JÁ** tem AWS CLI configurado e funcionando, **PULE esta seção**!
> 
> Teste primeiro:
> ```bash
> aws sts get-caller-identity --profile terraform
> ```
> 
> ✅ Se retornar sucesso com `assumed-role/terraform-role`, suas credenciais JÁ ESTÃO CORRETAS.  
> ❌ **NÃO** execute os comandos abaixo, pois isso **sobrescreverá** sua configuração funcional!
>
> Caso já esteja configurado continue direto para a seção 5 (Substituições nos arquivos).

---

#### 4.1. **PRIMEIRO:** Configure as credenciais do usuário IAM

Você precisa das **Access Keys** do usuário IAM criado no passo 1.

**Opção A - Se já tem Access Keys:**

```bash
aws configure --profile default
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: us-east-1
# Default output format: json
```

**Opção B - Se precisa criar Access Keys:**

1. Via AWS Console:
   ```
   AWS Console → IAM → Users → <YOUR_USER> → Security credentials
   → Create access key → CLI → Create
   ```

2. Ou via AWS CLI (se já está logado):
   ```bash
   aws iam create-access-key --user-name <YOUR_USER>
   ```

3. Anote o `AccessKeyId` e `SecretAccessKey` e configure:
   ```bash
   aws configure --profile default
   ```

**Teste as credenciais básicas:**

```bash
aws sts get-caller-identity --profile default
# Deve retornar: UserId, Account, Arn do seu usuário IAM
```

---

#### 4.2. Configure o profile terraform (assume role)

Agora configure o profile `terraform` que assume a role criada no passo 2:

**Atenção:** Substitua `<YOUR_ACCOUNT>` pelo ID da sua conta AWS.

```bash
aws configure set role_arn arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role --profile terraform
aws configure set source_profile default --profile terraform
aws configure set external_id 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a --profile terraform
aws configure set region us-east-1 --profile terraform
```

**Teste a configuração da role:**

```bash
aws sts get-caller-identity --profile terraform
# Deve retornar: UserId com "AssumedRole", Account, Arn com "terraform-role"
```

**❌ Se aparecer erro "InvalidClientTokenId":**
- Suas credenciais do profile `default` estão inválidas ou ausentes
- Volte ao passo 4.1 e configure as Access Keys corretamente
- Verifique: `cat ~/.aws/credentials` (deve ter [default] com keys)

**❌ Se aparecer erro "Access Denied":**
- A role `terraform-role` não foi criada (volte ao passo 2)
- Ou o usuário IAM não tem permissão para assumir a role
- Ou o External ID está incorreto

---

## 🔧 Substituições Necessárias nos Arquivos

> 🚨 **ATENÇÃO CRÍTICA:** Execute este passo **ANTES** de qualquer `terraform init/apply`!  
> Caso contrário, o Terraform tentará usar recursos da conta AWS errada e falhará.

### 5.1. Substituir `<YOUR_ACCOUNT>` pelo seu Account ID

**⚠️ OBRIGATÓRIO:** Todos os arquivos `.tf` contêm o placeholder `<YOUR_ACCOUNT>` que **DEVE** ser substituído pelo ID da sua conta AWS **ANTES de executar qualquer comando Terraform**.

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