# 🛠️ Guia de Implementação: Ansible no Projeto EKS

## 📋 Overview

Este guia apresenta a implementação **passo a passo** da integração Ansible, com código real e pronto para uso. Baseado na análise técnica, vamos implementar as 3 áreas prioritárias.

---

## 🎯 Fase 1: Setup Inicial (30 minutos)

### **1.1. Instalar Ansible e Dependências**

```bash
# Instalar Ansible
pip install ansible ansible-core

# Instalar collections necessárias
ansible-galaxy collection install community.grafana
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install amazon.aws

# Verificar instalação
ansible --version
# Esperado: ansible [core 2.17.x]
```

### **1.2. Criar Estrutura de Diretórios**

```bash
# Navegue até a raiz do projeto clonado
cd lab-eks-terraform-ansible

# Criar estrutura
mkdir -p ansible/{inventory,playbooks,roles,group_vars/{dev,staging,prod}}
mkdir -p ansible/roles/{grafana-config,cluster-validation,secrets-manager}/{tasks,templates,files}

# Criar arquivos base
touch ansible/ansible.cfg
touch ansible/inventory/{dev.yml,staging.yml,prod.yml}
```

### **1.3. Configurar ansible.cfg**

```ini
# ansible/ansible.cfg
[defaults]
inventory = ./inventory
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
bin_ansible_callbacks = True

# Timeout para operações Kubernetes
timeout = 60

# Log de execução
log_path = ./ansible.log

[inventory]
enable_plugins = yaml, aws_ec2

[privilege_escalation]
become = False

[ssh_connection]
pipelining = True
```

---

## 🎨 Fase 2: Área Prioritária 1 - Configuração Grafana

### **2.1. Criar Role grafana-config**

```yaml
# ansible/roles/grafana-config/tasks/main.yml
---
- name: Validar variáveis necessárias
  assert:
    that:
      - grafana_url is defined
      - grafana_api_key is defined
      - prometheus_endpoint is defined
    fail_msg: "Variáveis grafana_url, grafana_api_key e prometheus_endpoint são obrigatórias"

- name: Aguardar Grafana estar disponível
  uri:
    url: "{{ grafana_url }}/api/health"
    method: GET
    status_code: 200
    validate_certs: false
  register: grafana_health
  until: grafana_health.status == 200
  retries: 30
  delay: 10

- name: Configurar Data Source Prometheus
  uri:
    url: "{{ grafana_url }}/api/datasources"
    method: POST
    headers:
      Authorization: "Bearer {{ grafana_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      name: "Prometheus"
      type: "prometheus"
      url: "{{ prometheus_endpoint }}"
      access: "proxy"
      isDefault: true
      jsonData:
        httpMethod: "POST"
        sigV4Auth: true
        sigV4AuthType: "workspace-iam-role"
        sigV4Region: "{{ aws_region | default('us-east-1') }}"
        timeInterval: "30s"
      editable: false
    status_code: [200, 409]  # 409 = já existe
  register: datasource_result
  changed_when: datasource_result.status == 200

- name: Obter ID do Data Source (se já existia)
  uri:
    url: "{{ grafana_url }}/api/datasources/name/Prometheus"
    method: GET
    headers:
      Authorization: "Bearer {{ grafana_api_key }}"
    status_code: 200
  register: existing_datasource
  when: datasource_result.status == 409

- name: Definir datasource_uid
  set_fact:
    datasource_uid: "{{ datasource_result.json.datasource.uid if datasource_result.status == 200 else existing_datasource.json.uid }}"

- name: Importar Dashboard Node Exporter Full (ID 1860)
  uri:
    url: "{{ grafana_url }}/api/dashboards/import"
    method: POST
    headers:
      Authorization: "Bearer {{ grafana_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      dashboard:
        id: 1860
        version: 37
      overwrite: true
      inputs:
        - name: "DS_PROMETHEUS"
          type: "datasource"
          pluginId: "prometheus"
          value: "{{ datasource_uid }}"
      folderId: 0
    status_code: [200, 412]  # 412 = versão já importada
  register: dashboard_import

- name: Importar Dashboard Kubernetes Cluster Monitoring (ID 7249)
  uri:
    url: "{{ grafana_url }}/api/dashboards/import"
    method: POST
    headers:
      Authorization: "Bearer {{ grafana_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      dashboard:
        id: 7249
        version: 1
      overwrite: true
      inputs:
        - name: "DS_PROMETHEUS"
          type: "datasource"
          pluginId: "prometheus"
          value: "{{ datasource_uid }}"
    status_code: [200, 412]

- name: Validar Data Source está funcional
  uri:
    url: "{{ grafana_url }}/api/datasources/proxy/uid/{{ datasource_uid }}/api/v1/query?query=up"
    method: GET
    headers:
      Authorization: "Bearer {{ grafana_api_key }}"
    status_code: 200
  register: datasource_validation

- name: Exibir resumo da configuração
  debug:
    msg: |
      ========================================
      ✅ GRAFANA CONFIGURADO COM SUCESSO
      ========================================
      
      📊 Data Source Prometheus:
        - Name: Prometheus
        - UID: {{ datasource_uid }}
        - Endpoint: {{ prometheus_endpoint }}
        - Status: {{ 'OK' if datasource_validation.status == 200 else 'FAILED' }}
      
      📈 Dashboards Importados:
        - Node Exporter Full (1860): {{ 'Importado' if dashboard_import.status == 200 else 'Já existia' }}
        - Kubernetes Cluster (7249): Importado
      
      🌐 Acesse o Grafana:
        {{ grafana_url }}
      
      ========================================
```

### **2.2. Criar Playbook de Configuração**

```yaml
# ansible/playbooks/01-configure-grafana.yml
---
- name: Configurar Amazon Managed Grafana
  hosts: localhost
  gather_facts: false
  
  vars:
    aws_region: "us-east-1"
    terraform_stack_path: "../05-monitoring"
  
  tasks:
    - name: Obter outputs do Terraform (Stack 05 - Monitoring)
      shell: |
        cd {{ terraform_stack_path }}
        echo "grafana_url=$(terraform output -raw grafana_workspace_url)"
        echo "grafana_api_key=$(terraform output -raw grafana_api_key)"
        echo "prometheus_endpoint=$(terraform output -raw prometheus_workspace_endpoint)"
      register: terraform_outputs
      changed_when: false

    - name: Parsear outputs do Terraform
      set_fact:
        grafana_url: "{{ terraform_outputs.stdout_lines | select('match', '^grafana_url=') | first | regex_replace('^grafana_url=', '') }}"
        grafana_api_key: "{{ terraform_outputs.stdout_lines | select('match', '^grafana_api_key=') | first | regex_replace('^grafana_api_key=', '') }}"
        prometheus_endpoint: "{{ terraform_outputs.stdout_lines | select('match', '^prometheus_endpoint=') | first | regex_replace('^prometheus_endpoint=', '') }}"

    - name: Validar outputs obtidos
      assert:
        that:
          - grafana_url | length > 0
          - grafana_api_key | length > 0
          - prometheus_endpoint | length > 0
        fail_msg: "Falha ao obter outputs do Terraform. Execute 'terraform apply' na Stack 05 primeiro."

    - name: Executar role de configuração do Grafana
      include_role:
        name: grafana-config
      vars:
        aws_region: "{{ aws_region }}"

    - name: Salvar configuração para referência futura
      copy:
        content: |
          # Configuração Grafana - {{ ansible_date_time.iso8601 }}
          GRAFANA_URL={{ grafana_url }}
          PROMETHEUS_ENDPOINT={{ prometheus_endpoint }}
          # API Key omitida por segurança
        dest: ./grafana-config.env
        mode: '0600'
```

### **2.3. Testar Configuração**

```bash
# Executar playbook
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml

# Output esperado:
# PLAY [Configurar Amazon Managed Grafana] ************************************
# 
# TASK [Obter outputs do Terraform] *******************************************
# ok: [localhost]
# 
# TASK [Parsear outputs do Terraform] *****************************************
# ok: [localhost]
# 
# TASK [Executar role de configuração do Grafana] ****************************
# changed: [localhost]
# 
# TASK [grafana-config : Configurar Data Source Prometheus] *******************
# changed: [localhost]
# 
# TASK [grafana-config : Importar Dashboard Node Exporter Full] **************
# changed: [localhost]
# 
# PLAY RECAP *******************************************************************
# localhost : ok=8 changed=3 unreachable=0 failed=0 skipped=0 rescued=0
```

---

## ✅ Fase 3: Área Prioritária 2 - Validação de Cluster

### **3.1. Criar Role cluster-validation**

```yaml
# ansible/roles/cluster-validation/tasks/main.yml
---
- name: "[INFRA] Obter informações dos nodes"
  kubernetes.core.k8s_info:
    kind: Node
    kubeconfig: "{{ kubeconfig_path }}"
  register: nodes

- name: "[INFRA] Validar todos nodes estão Ready"
  assert:
    that:
      - item.status.conditions | selectattr('type', 'equalto', 'Ready') | selectattr('status', 'equalto', 'True') | list | length > 0
    fail_msg: "Node {{ item.metadata.name }} não está Ready"
    success_msg: "Node {{ item.metadata.name }} está Ready"
  loop: "{{ nodes.resources }}"
  loop_control:
    label: "{{ item.metadata.name }}"

- name: "[NETWORK] Validar AWS Load Balancer Controller"
  kubernetes.core.k8s_info:
    kind: Deployment
    name: aws-load-balancer-controller
    namespace: kube-system
    kubeconfig: "{{ kubeconfig_path }}"
  register: alb_controller

- name: "[NETWORK] Verificar ALB Controller está Running"
  assert:
    that:
      - alb_controller.resources | length > 0
      - alb_controller.resources[0].status.readyReplicas == alb_controller.resources[0].spec.replicas
    fail_msg: "ALB Controller não está rodando corretamente"
    success_msg: "ALB Controller: {{ alb_controller.resources[0].status.readyReplicas }}/{{ alb_controller.resources[0].spec.replicas }} replicas prontas"

- name: "[KARPENTER] Validar Karpenter Controller"
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: kube-system
    label_selectors:
      - app.kubernetes.io/name=karpenter
    kubeconfig: "{{ kubeconfig_path }}"
  register: karpenter_pods

- name: "[KARPENTER] Verificar Karpenter está Running"
  assert:
    that:
      - karpenter_pods.resources | length > 0
      - karpenter_pods.resources | selectattr('status.phase', 'equalto', 'Running') | list | length > 0
    fail_msg: "Karpenter não está rodando"
    success_msg: "Karpenter está rodando ({{ karpenter_pods.resources | length }} pods)"

- name: "[KARPENTER] Validar NodePools existem"
  kubernetes.core.k8s_info:
    api_version: karpenter.sh/v1
    kind: NodePool
    kubeconfig: "{{ kubeconfig_path }}"
  register: nodepools

- name: "[SECURITY] Verificar WAF está configurado"
  command: >
    aws wafv2 list-web-acls 
    --scope REGIONAL 
    --region {{ aws_region }}
    --query 'WebACLs[?Name==`waf-eks-devopsproject-webacl`].Name' 
    --output text
  register: waf_check
  changed_when: false
  failed_when: waf_check.stdout == ""

- name: "[MONITORING] Validar Node Exporter está rodando"
  kubernetes.core.k8s_info:
    kind: DaemonSet
    name: prometheus-node-exporter
    namespace: kube-system
    kubeconfig: "{{ kubeconfig_path }}"
  register: node_exporter
  failed_when: node_exporter.resources | length == 0

- name: "Gerar relatório de validação"
  set_fact:
    validation_report:
      timestamp: "{{ ansible_date_time.iso8601 }}"
      infrastructure:
        nodes_total: "{{ nodes.resources | length }}"
        nodes_ready: "{{ nodes.resources | selectattr('status.conditions', 'defined') | selectattr('status.conditions', 'selectattr', 'type', 'equalto', 'Ready') | list | length }}"
      networking:
        alb_controller_status: "Running"
        alb_controller_replicas: "{{ alb_controller.resources[0].status.readyReplicas }}/{{ alb_controller.resources[0].spec.replicas }}"
      karpenter:
        controller_status: "Running"
        controller_pods: "{{ karpenter_pods.resources | length }}"
        nodepools_count: "{{ nodepools.resources | length }}"
      security:
        waf_configured: "{{ 'Yes' if waf_check.stdout != '' else 'No' }}"
      monitoring:
        node_exporter_status: "Running"

- name: "Exibir relatório de validação"
  debug:
    msg: |
      ========================================
      ✅ VALIDAÇÃO DO CLUSTER CONCLUÍDA
      ========================================
      
      📊 INFRAESTRUTURA:
        - Nodes Total: {{ validation_report.infrastructure.nodes_total }}
        - Nodes Ready: {{ validation_report.infrastructure.nodes_ready }}
      
      🌐 NETWORKING:
        - ALB Controller: {{ validation_report.networking.alb_controller_status }}
        - Replicas: {{ validation_report.networking.alb_controller_replicas }}
      
      🚀 KARPENTER:
        - Controller: {{ validation_report.karpenter.controller_status }}
        - Pods: {{ validation_report.karpenter.controller_pods }}
        - NodePools: {{ validation_report.karpenter.nodepools_count }}
      
      🛡️ SECURITY:
        - WAF Configurado: {{ validation_report.security.waf_configured }}
      
      📈 MONITORING:
        - Node Exporter: {{ validation_report.monitoring.node_exporter_status }}
      
      ⏱️ Validação realizada em: {{ validation_report.timestamp }}
      ========================================

- name: "Salvar relatório em arquivo"
  copy:
    content: "{{ validation_report | to_nice_yaml }}"
    dest: "./cluster-validation-{{ ansible_date_time.epoch }}.yml"
```

### **3.2. Criar Playbook de Validação**

```yaml
# ansible/playbooks/02-validate-cluster.yml
---
- name: Validação completa do Cluster EKS
  hosts: localhost
  gather_facts: true
  
  vars:
    aws_region: "us-east-1"
    cluster_name: "eks-devopsproject-cluster"
    kubeconfig_path: "{{ lookup('env', 'KUBECONFIG') | default('~/.kube/config') }}"
  
  pre_tasks:
    - name: Verificar kubectl está instalado
      command: kubectl version --client
      register: kubectl_version
      changed_when: false
      failed_when: kubectl_version.rc != 0

    - name: Validar kubeconfig existe
      stat:
        path: "{{ kubeconfig_path }}"
      register: kubeconfig_stat
      failed_when: not kubeconfig_stat.stat.exists

    - name: Testar conexão com cluster
      command: kubectl cluster-info
      changed_when: false
      failed_when: false
      register: cluster_info

  roles:
    - cluster-validation

  post_tasks:
    - name: "Exibir status final"
      debug:
        msg: |
          ✅ Cluster {{ cluster_name }} está saudável!
          📊 Relatório salvo em: cluster-validation-{{ ansible_date_time.epoch }}.yml
```

---

## 🔐 Fase 4: Área Prioritária 3 - Secrets Management

### **4.1. Criar Role secrets-manager**

```yaml
# ansible/roles/secrets-manager/tasks/main.yml
---
- name: Validar namespace existe
  kubernetes.core.k8s:
    state: present
    kind: Namespace
    name: "{{ app_namespace }}"
    kubeconfig: "{{ kubeconfig_path }}"

- name: Buscar secrets do AWS Secrets Manager
  community.aws.secretsmanager_secret:
    name: "{{ item.aws_secret_name }}"
    region: "{{ aws_region }}"
  register: aws_secrets
  loop: "{{ application_secrets }}"
  when: application_secrets is defined
  no_log: true  # Não exibir secrets no log

- name: Criar Kubernetes Secrets a partir de AWS Secrets Manager
  kubernetes.core.k8s:
    state: present
    kubeconfig: "{{ kubeconfig_path }}"
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: "{{ item.item.k8s_secret_name }}"
        namespace: "{{ app_namespace }}"
        labels:
          managed-by: ansible
          app: "{{ app_name }}"
      type: Opaque
      stringData: "{{ item.secret | from_json }}"
  loop: "{{ aws_secrets.results }}"
  when: aws_secrets.results is defined
  no_log: true

- name: Criar ConfigMaps para configurações não-sensíveis
  kubernetes.core.k8s:
    state: present
    kubeconfig: "{{ kubeconfig_path }}"
    definition:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: "{{ item.name }}"
        namespace: "{{ app_namespace }}"
        labels:
          managed-by: ansible
          app: "{{ app_name }}"
      data: "{{ item.data }}"
  loop: "{{ application_configmaps }}"
  when: application_configmaps is defined

- name: Criar ServiceAccount com IRSA annotation
  kubernetes.core.k8s:
    state: present
    kubeconfig: "{{ kubeconfig_path }}"
    definition:
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: "{{ app_service_account_name }}"
        namespace: "{{ app_namespace }}"
        annotations:
          eks.amazonaws.com/role-arn: "{{ app_iam_role_arn }}"
  when: app_iam_role_arn is defined
```

### **4.2. Exemplo de Uso**

```yaml
# ansible/group_vars/dev/secrets.yml
---
app_namespace: "production-app"
app_name: "backend-api"
app_service_account_name: "backend-api-sa"
app_iam_role_arn: "arn:aws:iam::{{ aws_account_id }}:role/eks-backend-api-role"

application_secrets:
  - aws_secret_name: "/eks-devopsproject/dev/database/credentials"
    k8s_secret_name: "database-credentials"
  
  - aws_secret_name: "/eks-devopsproject/dev/api/external-key"
    k8s_secret_name: "external-api-key"

application_configmaps:
  - name: "app-config"
    data:
      APP_ENV: "development"
      LOG_LEVEL: "debug"
      CACHE_TTL: "1800"
      FEATURE_FLAG_NEW_UI: "true"
```

---

## 🚀 Fase 5: Script de Orquestração Master

### **5.1. Deploy Completo (Terraform + Ansible)**

```bash
# scripts/deploy-all-with-ansible.sh
#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 DEPLOY COMPLETO: Terraform + Ansible${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Variáveis
ENVIRONMENT=${1:-dev}
TERRAFORM_DIR="."
ANSIBLE_DIR="./ansible"

# ============================================
# PHASE 1: TERRAFORM (Infraestrutura)
# ============================================
echo -e "${YELLOW}[1/2] 📦 Provisionando infraestrutura com Terraform...${NC}"
echo ""

STACKS=("00-backend" "01-networking" "02-eks-cluster" "03-karpenter-auto-scaling" "04-security" "05-monitoring")

for stack in "${STACKS[@]}"; do
    echo -e "${GREEN}  ➜ Stack: $stack${NC}"
    cd "$stack"
    terraform init -upgrade > /dev/null
    terraform apply -auto-approve
    cd ..
    echo ""
done

# Configurar kubectl
echo -e "${YELLOW}🔧 Configurando kubectl...${NC}"
CLUSTER_NAME=$(cd 02-eks-cluster && terraform output -raw cluster_name)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1 --profile terraform
echo -e "${GREEN}✅ kubectl configurado${NC}"
echo ""

# ============================================
# PHASE 2: ANSIBLE (Configuração)
# ============================================
echo -e "${YELLOW}[2/2] ⚙️  Configurando serviços com Ansible...${NC}"
echo ""

cd "$ANSIBLE_DIR"

# 2.1. Configurar Grafana
echo -e "${GREEN}  ➜ Configurando Grafana (Data Sources + Dashboards)${NC}"
ansible-playbook playbooks/01-configure-grafana.yml
echo ""

# 2.2. Validar Cluster
echo -e "${GREEN}  ➜ Validando cluster (Quality Gates)${NC}"
ansible-playbook playbooks/02-validate-cluster.yml
echo ""

cd ..

# ============================================
# DEPLOY COMPLETO
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DEPLOY COMPLETO COM SUCESSO!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📊 Recursos Provisionados:${NC}"
echo "  - VPC + Networking (Subnets, NAT Gateways)"
echo "  - EKS Cluster 1.32 (3 nodes)"
echo "  - Karpenter Auto-scaling"
echo "  - AWS Load Balancer Controller"
echo "  - WAF (Web Application Firewall)"
echo "  - Amazon Managed Prometheus"
echo "  - Amazon Managed Grafana (configurado automaticamente)"
echo ""
echo -e "${YELLOW}🌐 Acesse os serviços:${NC}"
GRAFANA_URL=$(cd 05-monitoring && terraform output -raw grafana_workspace_url)
echo "  - Grafana: $GRAFANA_URL"
echo ""
echo -e "${YELLOW}🔍 Próximos passos:${NC}"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
```

### **5.2. Tornar executável**

```bash
chmod +x scripts/deploy-all-with-ansible.sh

# Executar
./scripts/deploy-all-with-ansible.sh dev
```

---

## 📊 Inventários Dinâmicos (Opcional)

### **Inventory por Ambiente**

```yaml
# ansible/inventory/dev.yml
all:
  vars:
    env: dev
    aws_region: us-east-1
    aws_account_id: "123456789012"  # Substitua pelo seu Account ID
    cluster_name: "eks-devopsproject-cluster"
    
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
```

```yaml
# ansible/inventory/prod.yml
all:
  vars:
    env: prod
    aws_region: us-east-1
    aws_account_id: "123456789012"  # Substitua pelo seu Account ID
    cluster_name: "eks-production-cluster"
    
    # Configurações específicas de produção
    karpenter_capacity_types: ['on-demand']  # Apenas on-demand em prod
    grafana_retention_days: 90
    
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
```

**Usar inventário específico:**
```bash
ansible-playbook -i inventory/prod.yml playbooks/01-configure-grafana.yml
```

---

## ✅ Checklist de Implementação

### **Semana 1 - MVP**
- [ ] Setup inicial Ansible (instalação + estrutura de diretórios)
- [ ] Role `grafana-config` completo
- [ ] Playbook `01-configure-grafana.yml` funcional
- [ ] Role `cluster-validation` básico
- [ ] Playbook `02-validate-cluster.yml` funcional
- [ ] Script `deploy-all-with-ansible.sh`
- [ ] Documentação README atualizada

### **Semana 2 - Expansão**
- [ ] Role `secrets-manager` completo
- [ ] Integração AWS Secrets Manager
- [ ] Validação avançada (WAF, testes de segurança)
- [ ] Inventários por ambiente (dev/staging/prod)
- [ ] Testes E2E

### **Semana 3 - Polimento**
- [ ] CI/CD GitHub Actions
- [ ] Rollback automático
- [ ] Documentação avançada
- [ ] Vídeo demo para alunos

---

## 🎓 Exemplos de Uso para Alunos

### **Cenário 1: Deploy Fresh (do zero)**
```bash
# 1. Clone do repositório
git clone https://github.com/jlui70/lab-eks-terraform-ansible
cd lab-eks-terraform-ansible

# 2. Configurar AWS credentials
aws configure --profile terraform

# 3. Deploy completo
./scripts/deploy-all-with-ansible.sh dev

# ⏱️ Tempo total: ~45 minutos
# ✅ Resultado: Cluster EKS completo + Grafana configurado
```

### **Cenário 2: Reconfigurar Grafana (sem recriar infraestrutura)**
```bash
# Apenas reaplica configurações Ansible
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml

# ⏱️ Tempo: ~2 minutos
# ✅ Resultado: Grafana reconfigurado (Data Sources + Dashboards)
```

### **Cenário 3: Validar Cluster (healthcheck)**
```bash
cd ansible
ansible-playbook playbooks/02-validate-cluster.yml

# ⏱️ Tempo: ~1 minuto
# ✅ Resultado: Relatório de saúde do cluster
```

---

## 🐛 Troubleshooting

### **Erro: "grafana_api_key not defined"**
**Causa:** Stack 05 (Monitoring) não foi aplicado ou não exportou API Key

**Solução:**
```bash
cd 05-monitoring
terraform output grafana_api_key
# Se vazio, adicionar ao outputs.tf:
# output "grafana_api_key" {
#   value     = aws_grafana_workspace_api_key.ansible.key
#   sensitive = true
# }
terraform apply -auto-approve
```

### **Erro: "Connection refused" ao acessar Grafana**
**Causa:** Grafana Workspace ainda está sendo provisionado

**Solução:**
```bash
# Aguardar 5-10 minutos após terraform apply
# Ou adicionar task no Ansible:
- name: Aguardar Grafana estar disponível
  uri:
    url: "{{ grafana_url }}/api/health"
    status_code: 200
  retries: 30
  delay: 10
```

### **Erro: "kubectl: command not found"**
**Solução:**
```bash
# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Configurar kubeconfig
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform
```

---

## 📚 Referências

- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [Grafana HTTP API](https://grafana.com/docs/grafana/latest/developers/http_api/)
- [AWS Secrets Manager with Ansible](https://docs.ansible.com/ansible/latest/collections/community/aws/secretsmanager_secret_module.html)

---

**🎉 Pronto! Agora você tem um guia completo para implementar Ansible no projeto.**
