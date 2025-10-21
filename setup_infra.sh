#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root ou com sudo."
  exit 1
fi

echo "Atualizando o sistema..."
apt update && apt upgrade -y

echo "Criando grupos..."
groupadd -f infrawatch
groupadd -f DBA
groupadd -f front-end
groupadd -f devops

echo "Criando diretórios..."
mkdir -p /infraweb/banco
mkdir -p /infraweb/app-node
chmod -R 770 /infraweb

echo "Atribuindo permissões..."
apt install acl -y
chmod 770 /home/infraweb/banco
chmod 770 /home/infraweb/app-node
setfacl -m g:infrawatch:r-x /home/infraweb/banco
setfacl -m g:infrawatch:r-x /home/infraweb/app-node

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

echo "Instalando dependências básicas..."
apt install -y acl docker.io git

echo "Verificando Docker..."
if systemctl is-active --quiet docker; then
  echo "Docker já está ativo."
else
  echo "Iniciando e habilitando Docker..."
  systemctl start docker
  systemctl enable docker
fi

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

echo "Criando Dockerfile do projeto Node..."
cat << EOF > /infraweb/app-node/iw-appweb/Dockerfile
FROM node:latest
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3333
CMD ["npm", "start"]
EOF

echo "Construindo imagem Docker..."
cd /infraweb/app-node/iw-appweb
docker build -t iw-node:v1 .

echo "Verificando container do site..."
if [ ! "$(docker ps -aq -f name=iw-site)" ]; then
  docker run -d --name iw-site -p 3333:3333 iw-node:v1
else
  echo "Container iw-site já existe."
fi

echo "✅ Infraestrutura (Node + MySQL + Docker) configurada com sucesso!"
