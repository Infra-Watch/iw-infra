#!/bin/bash
set -e

# ----------------------------
# Validação de permissão
# ----------------------------
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root ou com sudo."
  exit 1
fi

# ----------------------------
# Atualização do sistema
# ----------------------------
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# ----------------------------
# Criação de grupos
# ----------------------------
echo "Criando grupos..."
groupadd -f infrawatch
groupadd -f DBA
groupadd -f front-end
groupadd -f devops

# ----------------------------
# Diretórios e ACL
# ----------------------------
echo "Criando diretórios..."
mkdir -p /infraweb/banco
mkdir -p /infraweb/app-node
chmod -R 770 /infraweb

echo "Setando ACL..."
apt install -y acl
setfacl -m g:infrawatch:r-x /infraweb/banco
setfacl -m g:infrawatch:r-x /infraweb/app-node

# ----------------------------
# Criação de usuários
# ----------------------------
echo "Criando usuários..."
criar_usuario() {
  usuario=$1
  senha=$2
  if id "$usuario" &>/dev/null; then
    echo "Usuário $usuario já existe, ignorando..."
  else
    useradd -m "$usuario"
    echo "$usuario:$senha" | chpasswd
  fi
}

criar_usuario machado machado123
criar_usuario davi davi123
criar_usuario anthony anthony123

usermod -aG DBA machado
usermod -aG DBA davi
usermod -aG front-end machado
usermod -aG front-end anthony
usermod -aG devops davi
usermod -aG devops anthony
usermod -aG infrawatch machado
usermod -aG infrawatch davi
usermod -aG infrawatch anthony

# ----------------------------
# Instalação do Docker
# ----------------------------
echo "Instalando Docker..."
apt install -y docker.io
systemctl enable docker
systemctl start docker

# ----------------------------
# Instalação do Docker Compose
# ----------------------------
echo "Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Rodando serviços com Docker Compose..."

cd /home/ubuntu/iw-infra   

docker-compose up -d

echo "Containers ativos:"
docker ps

echo "✅ Infraestrutura configurada com sucesso!"
