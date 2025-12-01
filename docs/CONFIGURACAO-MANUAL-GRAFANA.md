# Configuração Manual do Grafana

Este documento descreve o processo **manual** de configuração do Amazon Managed Grafana após o deployment da Stack 05.

> 💡 **RECOMENDAÇÃO:** Use a **automação Ansible** ao invés deste processo manual. Economia de tempo: ~90% (de 10-15 min para 2 min).
>
---

## Quando Usar Este Guia

Use este guia manual apenas se:
- ❌ Você **não pode** ou **não quer** instalar Ansible
- ❌ Você quer entender o processo passo a passo
- ❌ Você está enfrentando problemas com o playbook Ansible

**Caso contrário,** use a automação Ansible:
```bash
cd ansible
ansible-playbook playbooks/01-configure-grafana.yml
```

---

## Pré-requisitos

Antes de começar este guia manual, você **deve** ter completado:

✅ **Stack 05 aplicada:**
```bash
cd 05-monitoring
terraform apply -auto-approve
```

✅ **Autenticação SSO configurada:**
- IAM Identity Center habilitado
- Usuário SSO criado e verificado
- Usuário atribuído ao Grafana Workspace com permissão **ADMIN**

> ⚠️ **IMPORTANTE:** Se você ainda não configurou SSO, volte para o [README.md - ETAPA 1](../README.md#etapa-1-configurar-autenticação-sso-obrigatória-para-ambas-opções) antes de continuar.

---

## Passo 1: Acessar o Grafana

1. Acesse o **AWS Access Portal** (você recebeu o link por e-mail ao criar o usuário SSO)
   - Formato: `https://d-xxxxxxxxxx.awsapps.com/start`
   - Se não encontrar, vá em: https://console.aws.amazon.com/singlesignon → **Settings** → **User portal URL**

2. Faça login com as credenciais do usuário SSO criado:
   - Username: `grafana-admin` (ou o nome que você definiu)
   - Password: senha definida no processo de verificação

3. Após login, você verá um card **"Amazon Managed Grafana"**

4. Clique no card para acessar o Grafana workspace

> 📝 **Nota:** Se não aparecer o card do Grafana, verifique se o usuário foi atribuído ao workspace (veja pré-requisitos acima).

---

## Passo 2: Configurar Data Source Prometheus

### 2.1. Obter Endpoint do Prometheus

Antes de configurar, você precisa obter o endpoint do Prometheus:

```bash
cd 05-monitoring
terraform output -raw prometheus_workspace_endpoint
```

**Exemplo de output:**
```
https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-12345678-abcd-1234-efgh-123456789012
```

**Copie este endpoint** - você usará no próximo passo.

---

### 2.2. Adicionar Data Source no Grafana

Dentro do Grafana workspace:

1. **Menu lateral esquerdo** → **Connections** (ícone de plugin)
   - Ou acesse: `https://g-xxxxxxxxx.grafana-workspace.us-east-1.amazonaws.com/connections/datasources`

2. Clique em **"Add new connection"**

3. Na barra de busca, digite: `Prometheus`

4. Clique no card **"Prometheus"**

5. Clique em **"Add new data source"** (botão azul no topo)

6. Preencha os campos:

   **Name:**
   ```
   Prometheus
   ```

   **URL:**
   ```
   <COLE_AQUI_O_ENDPOINT_COPIADO_NO_PASSO_2.1>
   ```
   
   **Exemplo:**
   ```
   https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-12345678-abcd-1234-efgh-123456789012
   ```

   > ⚠️ **ATENÇÃO:** 
   > - Cole o endpoint **exatamente** como retornado pelo `terraform output`
   > - **NÃO adicione** barra `/` no final
   > - **NÃO adicione** `/api/v1/query` ou qualquer path adicional

7. Role para baixo até **"Auth"**

8. **Marque** a checkbox: **☑ SigV4 auth**

9. Em **"SigV4 Auth Details"** (aparece após marcar SigV4):
   - **Authentication Provider**: Selecione `Workspace IAM Role`
   - **Default Region**: `us-east-1`
   - **Service**: Digite `aps`

10. Role até o final da página e clique em **"Save & test"**

11. Deve aparecer uma mensagem verde: ✅ **"Successfully queried the Prometheus API."**

> ❌ **Se aparecer erro:**
> - **"Missing Authentication Token"**: Verifique se marcou SigV4 auth e preencheu Service: `aps`
> - **"404 Not Found"**: Verifique se a URL está correta (sem `/api/v1/query` no final)
> - **"403 Forbidden"**: Verifique se o usuário SSO tem permissão ADMIN no workspace

---

## Passo 3: Importar Dashboard Node Exporter

1. **Menu lateral esquerdo** → **Dashboards** (ícone de gráfico com 4 quadrados)

2. Clique em **"New"** (botão azul no topo direito) → **"Import"**

3. Em **"Import via grafana.com"**, digite: `1860`
   - Este é o ID oficial do dashboard **Node Exporter Full** no Grafana.com

4. Clique em **"Load"**

5. Na tela de configuração do dashboard:
   - **Name**: `Node Exporter Full` (ou personalize se quiser)
   - **Folder**: `General` (ou crie uma pasta customizada)
   - **Prometheus**: O data source será selecionado automaticamente (deve aparecer `Prometheus`)

6. Clique em **"Import"**

7. Você será redirecionado para o dashboard importado

---

## ✅ Validação Final

Após completar os passos acima, valide se tudo está funcionando:

### 1. Verificar Data Source

1. Menu lateral → **Connections** → **Data sources**
2. Deve aparecer: **Prometheus** com status verde (ativo)
3. Clique nele e teste novamente: **"Save & test"** → Deve retornar sucesso

### 2. Verificar Dashboard

1. Menu lateral → **Dashboards**
2. Deve aparecer: **Node Exporter Full**
3. Clique no dashboard

### 3. Verificar Métricas

No dashboard Node Exporter Full, você deve ver:

- ✅ **3 nodes** listados no dropdown "Host" (os 3 worker nodes do EKS)
- ✅ **Gráficos de CPU** mostrando dados (não vazios)
- ✅ **Gráficos de Memória** mostrando uso/disponível
- ✅ **Gráficos de Disco** mostrando I/O e espaço
- ✅ **Gráficos de Rede** mostrando tráfego RX/TX
- ✅ **Load Average** mostrando valores

**Exemplo de métricas visíveis:**
- CPU Busy: 5-15% (depende da carga)
- Memory Usage: ~30-40% (inclui cache)
- Disk I/O: Valores variáveis
- Network Traffic: RX/TX com picos

> 📝 **Nota:** Se os gráficos estiverem vazios, aguarde 1-2 minutos para o Prometheus coletar dados dos node exporters.

---

## 🎉 Sucesso!

Seu Grafana está 100% configurado e monitorando o cluster EKS!

**Próximos passos sugeridos:**

1. **Explorar métricas:** Teste queries PromQL no **Explore** (menu lateral)
2. **Criar dashboards customizados:** Crie dashboards específicos para suas aplicações
3. **Configurar alertas:** Configure alertas para métricas críticas
4. **Adicionar mais data sources:** Adicione CloudWatch, Loki, etc.

---

## 🔧 Troubleshooting

### Erro: "sso.auth.access-denied" ao acessar Grafana

**Causa:** Usuário SSO não está atribuído ao workspace ou não tem permissão.

**Solução:**
1. Acesse: https://console.aws.amazon.com/grafana/home?region=us-east-1
2. Clique no workspace → aba **"Authentication"**
3. Verifique se seu usuário está na lista:
   - **Se NÃO**: Clique em "Assign new user or group" → adicione o usuário
   - **Se SIM**: Verifique se a role é **ADMIN** (não VIEWER)
4. Se a role for VIEWER:
   - Selecione o usuário → **Actions** → **Make admin**
5. Aguarde 1-2 minutos e tente novamente

---

### Erro: "Missing Authentication Token" ao testar Data Source

**Causa:** SigV4 auth não configurado corretamente.

**Solução:**
1. Edite o Data Source Prometheus
2. Certifique-se de:
   - ✅ Checkbox **SigV4 auth** está **marcada**
   - ✅ **Authentication Provider**: `Workspace IAM Role`
   - ✅ **Service**: `aps` (em minúsculas)
   - ✅ **Default Region**: `us-east-1`
3. Clique em **"Save & test"** novamente

---

### Erro: "404 Not Found" ou "HttpNotFoundException"

**Causa:** URL do Prometheus está incorreta.

**Solução:**
1. Verifique se a URL **NÃO contém**:
   - ❌ `/api/v1/query` no final
   - ❌ Barra `/` extra no final
   - ❌ Espaços ou quebras de linha
2. A URL deve ser **exatamente**:
   ```
   https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
   ```
3. Re-obtenha o endpoint correto:
   ```bash
   cd 05-monitoring
   terraform output -raw prometheus_workspace_endpoint
   ```

---

### Erro: "Page not found" ao importar dashboard

**Causa:** ID do dashboard incorreto.

**Solução:**
1. Certifique-se de usar o ID correto: **1860**
2. Acesse diretamente: https://grafana.com/grafana/dashboards/1860 para confirmar que existe
3. Tente importar via JSON (alternativa):
   - Baixe o JSON: https://grafana.com/api/dashboards/1860/revisions/latest/download
   - Menu → Dashboards → New → Import → Upload JSON file

---

### Dashboards sem dados (gráficos vazios)

**Causa:** Prometheus ainda não coletou métricas ou node-exporter não está rodando.

**Solução:**

1. Verifique se o addon prometheus-node-exporter está ativo:
   ```bash
   aws eks describe-addon \
       --cluster-name eks-devopsproject-cluster \
       --addon-name prometheus-node-exporter \
       --profile terraform
   ```
   - Status deve ser: `ACTIVE`

2. Verifique se os pods estão rodando:
   ```bash
   kubectl get pods -n prometheus-node-exporter
   ```
   - Deve mostrar 3 pods (1 por node) em estado `Running`

3. Aguarde 2-3 minutos para o Prometheus coletar dados

4. Teste uma query PromQL no Explore:
   - Menu → Explore
   - Data Source: Prometheus
   - Query: `up`
   - Deve retornar múltiplas séries com `value=1`

---

### Botão "Add data source" desabilitado ou não visível

**Causa:** Usuário SSO tem permissão VIEWER ao invés de ADMIN.

**Solução:**
1. Acesse: https://console.aws.amazon.com/grafana/home?region=us-east-1
2. Clique no workspace → aba **"Authentication"**
3. Selecione o usuário → **Actions** → **Make admin**
4. Aguarde 1-2 minutos
5. Faça logout do Grafana e login novamente

---

## 📊 Queries PromQL Úteis para Testes

Após configurar o Data Source, teste estas queries no **Explore**:

### CPU Usage por Node
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memória Disponível em %
```promql
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```

### Disco Usado em %
```promql
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

### Load Average (5 minutos)
```promql
node_load5
```

### Tráfego de Rede Recebido (bytes/s)
```promql
rate(node_network_receive_bytes_total[5m])
```

### Tráfego de Rede Enviado (bytes/s)
```promql
rate(node_network_transmit_bytes_total[5m])
```

---

## 🔗 Links Relacionados

- **Documentação Grafana Oficial:** https://docs.aws.amazon.com/grafana/
- **Dashboard Node Exporter Full:** https://grafana.com/grafana/dashboards/1860
- **PromQL Documentation:** https://prometheus.io/docs/prometheus/latest/querying/basics/

---

## 💡 Por Que Usar Ansible Ao Invés Deste Processo Manual?

| Aspecto | Manual (Este Guia) | Ansible Automation |
|---------|-------------------|-------------------|
| **Tempo** | 10-15 minutos | 2 minutos |
| **Passos** | 15+ clicks no console | 1 comando |
| **Erros** | Comum (typos, configuração errada) | Raro (idempotente) |
| **Reprodutibilidade** | Difícil (depende de clicks) | Fácil (código versionado) |
| **Múltiplos ambientes** | 10-15 min × N ambientes | 2 min × N ambientes |
| **Documentação** | Este guia longo | Código auto-documentado |
| **Validação** | Manual | Automática |

**Economia de tempo para 3 ambientes (Dev/Staging/Prod):**
- Manual: 30-45 minutos
- Ansible: 6 minutos
- **Ganho: 75-85% de economia**

---

**Desenvolvido com ❤️ para aprendizado de DevOps e Infraestrutura como Código**
