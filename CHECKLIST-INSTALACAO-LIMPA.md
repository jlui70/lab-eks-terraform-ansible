# ✅ Checklist de Instalação Limpa - EKS DevOps Project

## 🎯 Objetivo
Validar que todas as stacks Terraform funcionam corretamente + Ansible + Grafana/Prometheus após as otimizações de capacidade.

---

## 📋 PRÉ-INSTALAÇÃO

- [ ] **Git commit realizado** (alterações salvas)
- [ ] **AWS CLI profile `terraform` configurado**
  ```bash
  aws sts get-caller-identity --profile terraform
  ```
- [ ] **Ambiente atual será destruído**
  ```bash
  ./destroy-all.sh
  ```

---

## 🚀 INSTALAÇÃO LIMPA - STACKS TERRAFORM

### Stack 00 - Backend (S3 + DynamoDB)
```bash
cd 00-backend
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 3 recursos criados (S3 bucket, versioning, DynamoDB table)
- [ ] Tempo: < 1 minuto

---

### Stack 01 - Networking (VPC + Subnets)
```bash
cd ../01-networking
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 21 recursos criados
- [ ] **CRÍTICO:** Verificar CIDRs das subnets privadas:
  ```bash
  aws ec2 describe-subnets \
      --filters "Name=tag:Name,Values=*private-subnet*" \
      --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock]' \
      --output table \
      --profile terraform
  ```
  **Esperado:**
  - `private-subnet-us-east-1a`: `10.0.1.0/26` ✅
  - `private-subnet-us-east-1b`: `10.0.1.64/26` ✅

- [ ] Tempo: 2-3 minutos

---

### Stack 02 - EKS Cluster
```bash
cd ../02-eks-cluster
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 21-22 recursos criados (inclui vpc-cni addon)
- [ ] **CRÍTICO:** Verificar addon vpc-cni foi criado:
  ```bash
  aws eks list-addons --cluster-name eks-devopsproject-cluster --profile terraform
  ```
  **Esperado:** Lista deve incluir `vpc-cni` ✅

- [ ] **CRÍTICO:** Verificar configuração CNI:
  ```bash
  aws eks describe-addon \
      --cluster-name eks-devopsproject-cluster \
      --addon-name vpc-cni \
      --profile terraform \
      --query 'addon.configurationValues' \
      --output text
  ```
  **Esperado:** JSON com `WARM_ENI_TARGET=0`, `WARM_IP_TARGET=5`, `MINIMUM_IP_TARGET=10` ✅

- [ ] **Configurar kubectl:**
  ```bash
  aws eks update-kubeconfig \
      --name eks-devopsproject-cluster \
      --region us-east-1 \
      --profile terraform
  ```

- [ ] **Nodes prontos:**
  ```bash
  kubectl get nodes
  # Esperado: 3 nodes Ready
  ```

- [ ] **Pods do sistema rodando:**
  ```bash
  kubectl get pods -n kube-system
  # Esperado: aws-load-balancer-controller (2/2), external-dns (1/1), aws-node otimizado
  ```

- [ ] Tempo: 15-20 minutos

---

### Stack 03 - Karpenter
```bash
cd ../03-karpenter-auto-scaling
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 10 recursos criados
- [ ] Karpenter pods rodando:
  ```bash
  kubectl get pods -n kube-system | grep karpenter
  # Esperado: karpenter-xxxxx  2/2  Running
  ```
- [ ] NodePool e EC2NodeClass criados:
  ```bash
  kubectl get nodepools
  kubectl get ec2nodeclasses
  ```
- [ ] Tempo: 3-5 minutos

---

### Stack 04 - Security (WAF) - OPCIONAL
```bash
cd ../04-security
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 1 recurso criado (WAF WebACL)
- [ ] Tempo: 30 segundos

---

### Stack 05 - Monitoring (Prometheus + Grafana)
```bash
cd ../05-monitoring
terraform init
terraform apply -auto-approve
```
**✅ Validação:**
- [ ] 7 recursos criados
- [ ] **Outputs importantes salvos:**
  ```bash
  terraform output -raw grafana_workspace_url > grafana-url.txt
  terraform output -raw prometheus_workspace_endpoint > prometheus-endpoint.txt
  terraform output -raw grafana_workspace_id > grafana-id.txt
  ```
- [ ] Tempo: 20-25 minutos

---

## 🤖 ANSIBLE - AUTOMAÇÃO

### Playbook 01 - Configurar Grafana
**PRÉ-REQUISITO:** Usuário SSO criado e promovido para ADMIN no Grafana Workspace

```bash
cd ../ansible
ansible-playbook playbooks/01-configure-grafana.yml
```
**✅ Validação:**
- [ ] Data Source Prometheus configurado automaticamente
- [ ] Dashboard Node Exporter Full (1860) importado
- [ ] Tempo: ~2 minutos

---

### Playbook 02 - Deploy E-commerce (OPCIONAL)
```bash
ansible-playbook playbooks/03-deploy-ecommerce.yml
```
**✅ Validação:**
- [ ] Namespace `ecommerce` criado
- [ ] 7 microserviços deployados
- [ ] Ingress criado e ALB provisionado
- [ ] Tempo: ~3 minutos

---

### Playbook 03 - Monitoramento E-commerce (OPCIONAL)
```bash
ansible-playbook playbooks/04-configure-ecommerce-monitoring.yml
```
**✅ Validação:**
- [ ] Dashboards Grafana importados
- [ ] Tempo: ~2 minutos

---

## 📊 VALIDAÇÃO FINAL - CAPACIDADE DE IPs

### Verificar IPs Disponíveis nas Subnets
```bash
aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private-subnet*" \
    --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],CidrBlock,AvailableIpAddressCount]' \
    --output table \
    --profile terraform
```

**✅ Esperado:**
- [ ] `private-subnet-us-east-1a` (10.0.1.0/26): **~50-55 IPs disponíveis** ✅
- [ ] `private-subnet-us-east-1b` (10.0.1.64/26): **~50-55 IPs disponíveis** ✅

**🔴 Se IPs < 40:** Algo está errado com a otimização CNI

---

## 📈 VALIDAÇÃO GRAFANA + PROMETHEUS

### 1. Acessar Grafana
```bash
# Obter URL
cat 05-monitoring/grafana-url.txt
```
- [ ] Login via AWS SSO funciona
- [ ] Usuário tem permissão ADMIN

### 2. Verificar Data Source Prometheus
- [ ] Menu → Connections → Data sources
- [ ] Prometheus aparece com status verde (working)

### 3. Verificar Dashboard Node Exporter Full
- [ ] Menu → Dashboards
- [ ] Dashboard "Node Exporter Full" existe
- [ ] Gráficos mostram métricas dos 3 nodes
- [ ] CPU, Memória, Disco, Rede com dados populados

### 4. Testar Queries PromQL
No menu Explore, executar:
```promql
up
```
- [ ] Retorna ~15+ instâncias (nodes + pods de sistema)

```promql
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```
- [ ] Retorna % de memória disponível por node

---

## 🎉 CRITÉRIOS DE SUCESSO

✅ **SUCESSO TOTAL** se:
- [ ] Todas as 5 stacks Terraform deployadas sem erros
- [ ] Subnets privadas usando CIDRs /26 (10.0.1.x)
- [ ] Addon vpc-cni instalado com configuração otimizada
- [ ] ~50+ IPs disponíveis em cada subnet privada
- [ ] Ansible configurou Grafana automaticamente
- [ ] Data Source Prometheus funcionando
- [ ] Dashboard mostrando métricas dos nodes
- [ ] **ZERO configuração manual necessária** (exceto usuário SSO)

---

## 🚨 TROUBLESHOOTING

### Problema: Subnet ainda usando CIDR antigo (10.0.0.x)
**Causa:** Git pull não trouxe as mudanças ou arquivo não foi commitado

**Solução:**
```bash
cd 01-networking
cat variables.tf | grep "10.0.1"
# Se não aparecer nada, o arquivo não foi atualizado
git pull
```

---

### Problema: Addon vpc-cni não foi criado
**Causa:** Possível conflito com vpc-cni não-gerenciado

**Solução:**
```bash
# Verificar se vpc-cni existe como DaemonSet não-gerenciado
kubectl get daemonset aws-node -n kube-system

# Se existir, o Terraform pode ter falhado silenciosamente
# Verificar logs do Terraform apply
```

---

### Problema: IPs ainda baixos (< 20 disponíveis)
**Causa:** CNI não aplicou configuração otimizada

**Solução:**
```bash
# Verificar configuração do addon
aws eks describe-addon \
    --cluster-name eks-devopsproject-cluster \
    --addon-name vpc-cni \
    --profile terraform

# Se configurationValues está vazio, reaplique:
cd 02-eks-cluster
terraform apply -target=aws_eks_addon.vpc_cni -auto-approve
```

---

### Problema: Grafana Data Source com erro 404
**Causa:** URL do Prometheus com `/api/v1/query` duplicado

**Solução:**
Use URL base sem path:
```
https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-xxxxx
```
(Sem `/api/v1/query` no final)

---

## 📝 NOTAS FINAIS

- **Tempo total estimado:** 40-55 minutos (Terraform) + 5-7 minutos (Ansible)
- **Custo:** ~$0.50 para 30 minutos de teste
- **Lembre-se:** Execute `./destroy-all.sh` após validação para evitar cobranças contínuas

**Boa sorte! 🚀**
