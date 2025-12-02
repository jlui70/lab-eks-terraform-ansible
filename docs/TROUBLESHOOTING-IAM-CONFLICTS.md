# Troubleshooting: IAM Roles/Policies Already Exist

## 🔴 PROBLEMA

Ao executar `terraform apply` em uma **reinstalação** do lab (após destroy), você recebe erros:

```
Error: creating IAM Role (AmazonEKS_EFS_CSI_DriverRole): EntityAlreadyExists: 
Role with name AmazonEKS_EFS_CSI_DriverRole already exists.

Error: creating IAM Policy (AWSLoadBalancerControllerIAMPolicy): EntityAlreadyExists:
A policy called AWSLoadBalancerControllerIAMPolicy already exists.
```

---

## ⚠️ CAUSA RAIZ

IAM Roles/Policies são recursos **globais** (não são deletados automaticamente com o cluster EKS).

### Cenários que causam o problema:

1. **Destroy incompleto:**
   - Executou `terraform destroy` mas IAM roles ficaram órfãs
   - Cancelou o destroy no meio do processo

2. **Múltiplos projetos:**
   - Tem 2+ labs EKS na mesma conta AWS
   - Usou nomes de roles iguais em ambos

3. **Reinstalação rápida:**
   - Fez `destroy` e logo após `apply`
   - AWS IAM tem eventual consistency (~5-10s)

4. **Usuário alterou nomes no variables.tf:**
   - Mudou `role_name` depois de criar recursos
   - Terraform tenta criar nova role mas antiga ainda existe

---

## ✅ SOLUÇÃO 1: Usar destroy-all.sh (RECOMENDADO)

O script `destroy-all.sh` foi **atualizado (v3.1)** para deletar IAM roles automaticamente:

```bash
# Destruir tudo corretamente (incluindo IAM)
./destroy-all.sh
```

**O que o script faz:**
- ✅ Deleta namespaces K8s (ALBs via Ingress)
- ✅ Aguarda ENIs do Prometheus serem liberadas
- ✅ **Deleta IAM roles/policies órfãas ANTES de tentar terraform destroy**
- ✅ Ordem reversa correta: Stack 05 → 00

---

## ✅ SOLUÇÃO 2: Limpeza Manual (se destroy-all.sh falhou)

Execute o script de limpeza específico:

```bash
# Deletar roles/policies órfãs manualmente
bash cleanup-iam-orphans.sh
```

Ou comando manual:

```bash
# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform)

# Deletar roles órfãas (Stack 02)
aws iam delete-role --role-name AmazonEKS_EFS_CSI_DriverRole --profile terraform
aws iam delete-role --role-name aws-load-balancer-controller --profile terraform
aws iam delete-role --role-name eks-devopsproject-node-group-role --profile terraform
aws iam delete-role --role-name eks-devopsproject-cluster-role --profile terraform

# Deletar policies órfãs
aws iam delete-policy \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --profile terraform

aws iam delete-policy \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterControllerPolicy" \
  --profile terraform
```

⚠️ **Se der erro "cannot be deleted until detached":**

```bash
# Listar e detach policies da role
ROLE_NAME="aws-load-balancer-controller"

aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --profile terraform \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text | \
while read policy_arn; do
  aws iam detach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$policy_arn" \
    --profile terraform
done

# Agora deletar a role
aws iam delete-role --role-name "$ROLE_NAME" --profile terraform
```

---

## ✅ SOLUÇÃO 3: Terraform Import (AVANÇADO - NÃO RECOMENDADO)

Se você quer **manter as roles existentes** em vez de deletá-las:

```bash
cd 02-eks-cluster

# Importar roles para o Terraform state
terraform import aws_iam_role.container_storage_interface AmazonEKS_EFS_CSI_DriverRole
terraform import aws_iam_role.load_balancer_controller aws-load-balancer-controller
terraform import aws_iam_role.eks_cluster_node_group eks-devopsproject-node-group-role

# Importar policies
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform)
terraform import aws_iam_policy.load_balancer_controller \
  "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

# Verificar state
terraform plan
```

⚠️ **CUIDADO:** Isso é complexo e pode causar drift entre código e state.

---

## 🛡️ PREVENÇÃO: Evitar o Problema no Futuro

### 1. **Sempre usar destroy-all.sh**

```bash
# ✅ Correto
./destroy-all.sh

# ❌ Errado (deixa IAM órfão)
cd 02-eks-cluster && terraform destroy
```

---

### 2. **Adicionar sufixo único às roles (BEST PRACTICE)**

Modifique `02-eks-cluster/variables.tf` para usar sufixo com timestamp ou random:

```hcl
# Antes (hardcoded - causa conflitos)
variable "eks_cluster" {
  default = {
    node_group = {
      role_name = "eks-devopsproject-node-group-role"
    }
  }
}

# Depois (dinâmico - evita conflitos)
variable "eks_cluster" {
  default = {
    node_group = {
      role_name = "eks-devopsproject-node-group-role-${formatdate("YYYYMMDDhhmmss", timestamp())}"
    }
  }
}
```

⚠️ **PROBLEMA:** Terraform recria a role a cada `plan` (timestamp muda).

**SOLUÇÃO MELHOR:** Usar sufixo fixo do Account ID:

```hcl
# No locals.tf (criar se não existir)
locals {
  account_id = data.aws_caller_identity.current.account_id
  
  # Sufixo único por conta
  resource_suffix = substr(local.account_id, -6, 6)
}

# Adicionar data source
data "aws_caller_identity" "current" {}

# No eks.cluster.node-group.iam.tf
resource "aws_iam_role" "eks_cluster_node_group" {
  name = "${var.eks_cluster.node_group.role_name}-${local.resource_suffix}"
  # ...
}
```

**Vantagem:** Mesmo nome sempre, mas único por conta AWS.

---

### 3. **Usar Terraform Lifecycle para prevenção**

Adicione em **TODAS** as IAM roles:

```hcl
resource "aws_iam_role" "eks_cluster_node_group" {
  name = var.eks_cluster.node_group.role_name
  
  # Ignora se role já existe (não tenta recriar)
  lifecycle {
    ignore_changes = [name]
  }
  
  # ...
}
```

⚠️ **CUIDADO:** Isso **NÃO resolve** o problema de conflict, apenas ignora mudanças.

---

## 📚 REFERÊNCIAS

- [AWS IAM Eventual Consistency](https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_general.html#troubleshoot_general_eventual-consistency)
- [Terraform Import](https://developer.hashicorp.com/terraform/cli/import)
- [destroy-all.sh](../destroy-all.sh) - Script de destruição completa

---

## 🎯 RESUMO - O QUE FAZER

| Situação | Ação Recomendada |
|----------|------------------|
| **Erro "EntityAlreadyExists" ao apply** | Executar `./cleanup-iam-orphans.sh` |
| **Vai destruir tudo** | Usar `./destroy-all.sh` (já inclui limpeza IAM) |
| **Múltiplas reinstalações** | Sempre usar `destroy-all.sh` antes de `rebuild-all.sh` |
| **Prevenção futura** | Adicionar sufixo Account ID nos nomes de IAM roles |

---

**Data:** 02 de Dezembro de 2025  
**Versão:** 1.0  
**Autor:** Lab EKS DevOps Project
