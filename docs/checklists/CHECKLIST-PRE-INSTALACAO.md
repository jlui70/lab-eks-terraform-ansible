╔══════════════════════════════════════════════════════════════════════════════════╗
║                                                                                  ║
║     ✅ CHECKLIST PRÉ-INSTALAÇÃO - EKS EXPRESS LAB                               ║
║     Use este checklist ANTES de começar o deployment                            ║
║                                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════╝

📋 PRÉ-REQUISITOS DE SOFTWARE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] AWS CLI instalado (versão 2.x)
      Verificar: aws --version
      Deve retornar: aws-cli/2.x.x ou superior

  [ ] Terraform instalado (versão 1.12.x ou superior)
      Verificar: terraform version
      Deve retornar: Terraform v1.12.x ou superior

  [ ] kubectl instalado
      Verificar: kubectl version --client
      Compatível com EKS 1.32

  [ ] Helm instalado (versão 3.x)
      Verificar: helm version
      Deve retornar: version.BuildInfo{Version:"v3.x.x"...}

  [ ] Python 3 instalado (para Ansible - opcional)
      Verificar: python3 --version
      Necessário: 3.8 ou superior

  [ ] Ansible instalado (opcional - para automação)
      Verificar: ansible --version
      Recomendado: 2.14 ou superior


💳 PRÉ-REQUISITOS AWS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] Conta AWS com Paid Plan ou créditos
      ⚠️  Free Tier NÃO suporta instâncias t3.medium
      ⚠️  Custo estimado: $0.50 (30 min) até $8 (8h estudo)

  [ ] Permissões administrativas na conta
      Verificar: aws sts get-caller-identity
      Deve retornar seu User/Role

  [ ] IAM User criado para Terraform
      Nome sugerido: terraform-deploy
      Comando: aws iam create-user --user-name terraform-deploy

  [ ] IAM Role 'terraform-role' criada
      ARN: arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role
      External ID: 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a

  [ ] AdministratorAccess anexado à terraform-role
      Comando: aws iam attach-role-policy --role-name terraform-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

  [ ] AWS CLI Profile 'terraform' configurado
      
      PASSO 1 - Configure credenciais do usuário IAM primeiro:
      aws configure --profile default
      (Informe Access Key ID e Secret Access Key)
      
      PASSO 2 - Configure profile terraform (assume role):
      aws configure set role_arn arn:aws:iam::<YOUR_ACCOUNT>:role/terraform-role --profile terraform
      aws configure set source_profile default --profile terraform
      aws configure set external_id 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a --profile terraform
      aws configure set region us-east-1 --profile terraform
      
      Verificar: 
      - aws sts get-caller-identity --profile default (deve funcionar PRIMEIRO)
      - aws sts get-caller-identity --profile terraform (AssumedRole)


🔐 PRÉ-REQUISITOS SSO (Para Grafana)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] IAM Identity Center (SSO) habilitado
      Console AWS → IAM Identity Center → Enable

  [ ] Usuário SSO criado
      Console AWS → IAM Identity Center → Users → Add user

  [ ] Região correta: us-east-1
      ⚠️  IMPORTANTE: Projeto configurado para us-east-1
      Alterar região requer ajustes em TODOS os arquivos


📂 PRÉ-REQUISITOS DO CÓDIGO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] Repositório clonado
      git clone https://github.com/jlui70/lab-eks-terraform-ansible.git
      cd lab-eks-terraform-ansible

  [ ] Account ID obtido
      Comando: aws sts get-caller-identity --query Account --output text --profile terraform
      Anote o número (ex: 123456789012)

  [ ] Placeholders <YOUR_ACCOUNT> substituídos
      
      🐧 Linux/WSL:
      find . -type f -name "*.tf" -exec sed -i 's|<YOUR_ACCOUNT>|123456789012|g' {} +
      
      🍎 MacOS:
      find . -type f -name "*.tf" -exec sed -i '' 's|<YOUR_ACCOUNT>|123456789012|g' {} +
      
      ⚠️  Substitua 123456789012 pelo seu Account ID real!

  [ ] Placeholders no Ansible substituídos (se for usar Ansible)
      
      🐧 Linux/WSL:
      find ansible/ -type f -name "*.yml" -exec sed -i 's|<YOUR_ACCOUNT>|123456789012|g' {} +
      
      🍎 MacOS:
      find ansible/ -type f -name "*.yml" -exec sed -i '' 's|<YOUR_ACCOUNT>|123456789012|g' {} +

  [ ] Verificar que NÃO há Account IDs hardcoded
      grep -r "620958830769" . --exclude-dir=".git" --exclude-dir=".terraform" --exclude="*.log"
      ✅ Deve retornar vazio ou apenas em SECURITY.md/validate-pre-commit.sh


🎯 VALIDAÇÃO FINAL ANTES DE INICIAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] Teste de credenciais AWS
      aws sts get-caller-identity --profile terraform
      Deve retornar: UserId com "AssumedRole" e "terraform-role"

  [ ] Verificar permissões S3
      aws s3 ls --profile terraform
      Não deve retornar erro de permissões

  [ ] Verificar região configurada
      aws configure get region --profile terraform
      Deve retornar: us-east-1

  [ ] Verificar External ID na config
      cat ~/.aws/config | grep -A 1 terraform
      Deve conter: external_id = 3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a


📝 CHECKLIST DE DEPLOYMENT (Ordem recomendada)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [ ] 1. Stack 00 - Backend (S3 + DynamoDB)
      cd 00-backend
      terraform init
      terraform apply -auto-approve
      Tempo: ~1 minuto

  [ ] 2. Stack 01 - Networking (VPC)
      cd ../01-networking
      terraform init
      terraform apply -auto-approve
      Tempo: ~2-3 minutos

  [ ] 3. Stack 02 - EKS Cluster
      cd ../02-eks-cluster
      terraform init
      terraform apply -auto-approve
      Tempo: ~15-20 minutos ⏳

  [ ] 4. Configurar kubectl
      aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform
      Testar: kubectl get nodes

  [ ] 5. Stack 03 - Karpenter
      cd ../03-karpenter-auto-scaling
      terraform init
      terraform apply -auto-approve
      Tempo: ~3-5 minutos

  [ ] 6. Stack 04 - Security (WAF) - OPCIONAL
      cd ../04-security
      terraform init
      terraform apply -auto-approve
      Tempo: ~1 minuto
      ⚠️  Requer aplicação com Ingress para funcionar

  [ ] 7. Stack 05 - Monitoring (Grafana + Prometheus)
      cd ../05-monitoring
      terraform init
      terraform apply -auto-approve
      Tempo: ~20-25 minutos ⏳

  [ ] 8. Configurar SSO Grafana
      ⚠️  CRÍTICO: Atribuir usuário SSO ao workspace
      ⚠️  CRÍTICO: Alterar permissão para ADMIN (não Editor)
      Console AWS → Amazon Managed Grafana → Assign users → Permissions: ADMIN

  [ ] 9. Configurar Grafana Data Source (Ansible recomendado)
      
      OPÇÃO A - Ansible (2 minutos):
      cd ../../ansible
      ansible-playbook playbooks/01-configure-grafana.yml
      
      OPÇÃO B - Manual (10-15 minutos):
      Seguir seção "Configuração Manual Grafana" do README

  [ ] 10. (OPCIONAL) Deploy E-commerce App
      
      OPÇÃO A - Ansible (3 minutos):
      ansible-playbook playbooks/03-deploy-ecommerce.yml
      ansible-playbook playbooks/04-configure-ecommerce-monitoring.yml
      
      OPÇÃO B - Manual (20 minutos):
      Seguir seção "Stack 06" do README


🚨 TROUBLESHOOTING COMUM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ❌ "The specified instance type is not eligible for Free Tier"
     → Upgrade para AWS Paid Plan ou use créditos

  ❌ "S3 bucket eks-devopsproject-state-files does not exist"
     → Você esqueceu de substituir <YOUR_ACCOUNT> nos arquivos .tf
     → Execute novamente o comando find + sed da seção "Código"

  ❌ "the server has asked for the client to provide credentials" (kubectl)
     → Verifique: aws sts get-caller-identity --profile terraform
     → Deve retornar AssumedRole com terraform-role
     → Atualize kubeconfig: aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile terraform

  ❌ "403 Forbidden" no Ansible Grafana
     → Usuário SSO DEVE ser ADMIN (não Editor)
     → Console → Grafana Workspace → Assign users → Change to ADMIN

  ❌ VPC não deleta ao executar destroy
     → Execute: ./pre-destroy-check.sh (informativo)
     → Execute: ./destroy-all.sh (aguarda ENIs automaticamente)
     → Se falhar: ./cleanup-vpc-final.sh (aguarde 5-10min pelas ENIs)


💰 ESTIMATIVA DE CUSTOS (Lembre-se de destruir após testes!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  30 minutos (teste rápido):    ~$0.50 USD
  2 horas (deploy + validação): ~$2.00 USD
  8 horas (dia de estudo):      ~$8.00 USD
  
  24/7 por 1 mês (sem destruir): ~$280 USD ⚠️

  💡 IMPORTANTE: Execute ./destroy-all.sh imediatamente após terminar os testes!


🎉 PRONTO PARA COMEÇAR?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Se você marcou TODOS os checkboxes acima, está pronto para iniciar o deployment!

  📖 Consulte o README.md para instruções detalhadas de cada stack.
  🆘 Em caso de dúvidas, verifique a seção "Troubleshooting" do README.
  🔄 Para destruir tudo após os testes: ./destroy-all.sh

  ✅ Boa sorte com o laboratório!
