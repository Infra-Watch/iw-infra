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
# Criação de diretórios
# ----------------------------
echo "Criando diretórios..."
mkdir -p /infraweb/banco
mkdir -p /infraweb/app-node
chmod -R 770 /infraweb

# ----------------------------
# Permissões e ACL
# ----------------------------
echo "Atribuindo permissões..."
apt install -y acl
chmod 770 /infraweb/banco
chmod 770 /infraweb/app-node
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
    echo "Usuário $usuario criado com sucesso!"
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

echo "Usuários atribuídos aos grupos."

# ----------------------------
# Dependências principais
# ----------------------------
echo "Instalando dependências básicas..."
apt install -y docker.io git

# ----------------------------
# Docker
# ----------------------------
echo "Verificando Docker..."
if systemctl is-active --quiet docker; then
  echo "Docker já está ativo."
else
  echo "Iniciando e habilitando Docker..."
  systemctl start docker
  systemctl enable docker
fi

# ----------------------------
# Container MySQL
# ----------------------------
echo "Verificando container MySQL..."
if [ ! "$(docker ps -aq -f name=iw-mysql)" ]; then
  echo "Baixando imagem MySQL e criando container..."
  docker pull mysql:8
  docker run -d -p 3306:3306 \
    --name iw-mysql \
    -e "MYSQL_DATABASE=infrawatch" \
    -e "MYSQL_ROOT_PASSWORD=urubu100" \
    mysql:8
else
  echo "Container iw-mysql já existe."
fi

# ----------------------------
# Projeto Node
# ----------------------------
echo "Preparando diretório do projeto Node..."
mkdir -p /infraweb/app-node
chmod -R 777 /infraweb/app-node

echo "Baixando repositório do projeto..."
cd /infraweb/app-node
if [ ! -d "iw-appweb" ]; then
  git clone https://github.com/Infra-Watch/iw-appweb.git
else
  echo "Repositório iw-appweb já existe, atualizando..."
  cd iw-appweb && git pull
fi

# ----------------------------
# Dockerfile do projeto Node
# ----------------------------
echo "Criando Dockerfile do projeto Node..."
cat << EOF > /infraweb/app-node/iw-appweb/Dockerfile
FROM node:latest
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3333
CMD ["npm", "start"]
EOF

# ----------------------------
# Build da imagem Node
# ----------------------------
echo "Verificando se imagem iw-node:v1 já existe..."
cd /infraweb/app-node/iw-appweb
if [ "$(docker images -q iw-node:v1)" ]; then
  echo "Imagem iw-node:v1 já existe, pulando build."
else
  echo "Construindo imagem Docker..."
  docker build -t iw-node:v1 .
fi

# ----------------------------
# Container do site
# ----------------------------
echo "Verificando container do site..."
if [ "$(docker ps -aq -f name=iw-site)" ]; then
  echo "Recriando container iw-site com nova imagem..."
  docker rm -f iw-site
  docker run -d --name iw-site -p 3333:3333 iw-node:v1
else
  echo "Criando container iw-site..."
  docker run -d --name iw-site -p 3333:3333 iw-node:v1
fi

# ----------------------------
# Finalização
# ----------------------------
echo "✅ Infraestrutura (Node + MySQL + Docker) configurada com sucesso!"
