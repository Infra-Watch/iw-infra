#!/bin/bash
set -e  # Para o script se algum comando realmente falhar

# Verifica se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root ou com sudo."
  exit 1
fi

# -------------------------
# Atualização do sistema
# -------------------------
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# -------------------------
# Criação dos grupos
# -------------------------
echo "Criando grupos..."
groupadd -f infrawatch
groupadd -f DBA
groupadd -f front-end
groupadd -f back-end
groupadd -f devops
echo "Grupos criados com sucesso!"

# -------------------------
# Criação dos diretórios
# -------------------------
echo "Criando diretórios..."
mkdir -p /home/sistema/aplicacao-java
mkdir -p /home/sistema/aplicacao-python
mkdir -p /home/sistema/banco
mkdir -p /home/sistema/site-institucional
echo "Diretórios criados em /home/sistema"

# -------------------------
# Atribuição de grupos aos diretórios
# -------------------------
echo "Atribuindo diretórios aos grupos..."
chown :infrawatch /home/sistema
chown -R :DBA /home/sistema/banco
chown -R :back-end /home/sistema/aplicacao-python
chown -R :back-end /home/sistema/aplicacao-java
chown -R :front-end /home/sistema/site-institucional
echo "Grupos atribuídos com sucesso!"

# -------------------------
# Permissões
# -------------------------
echo "Configurando permissões..."
apt install acl -y
chmod 770 /home/sistema/aplicacao-java
chmod 770 /home/sistema/aplicacao-python
chmod 770 /home/sistema/site-institucional
chmod 770 /home/sistema/banco
setfacl -m g:infrawatch:r-x /home/sistema/aplicacao-java
setfacl -m g:infrawatch:r-x /home/sistema/aplicacao-python
setfacl -m g:infrawatch:r-x /home/sistema/site-institucional
setfacl -m g:infrawatch:r-x /home/sistema/banco
echo "Permissões configuradas!"

# -------------------------
# Criação dos usuários
# -------------------------
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
criar_usuario anthony anthony123
criar_usuario davi davi123
criar_usuario daniela daniela123
criar_usuario malu malu123

echo "Todos os usuários verificados/criados!"

# -------------------------
# Adicionando usuários aos grupos
# -------------------------
echo "Adicionando usuários aos grupos..."

usermod -aG infrawatch machado
usermod -aG infrawatch anthony
usermod -aG infrawatch daniela
usermod -aG infrawatch malu
usermod -aG infrawatch davi

usermod -aG devops malu
usermod -aG devops daniela
usermod -aG back-end daniela
usermod -aG back-end malu
usermod -aG DBA machado
usermod -aG DBA davi
usermod -aG back-end anthony
usermod -aG back-end davi
usermod -aG front-end machado
usermod -aG front-end anthony

echo "Usuários adicionados aos grupos com sucesso!"

# -------------------------
# Instalação de Java
# -------------------------
echo "Verificando Java..."
if java -version &>/dev/null; then
  echo "Java já está instalado."
else
  echo "Java não está instalado. Instalar agora? [s/n]"
  read get
  if [ "$get" == "s" ]; then
    apt install openjdk-17-jre -y
  fi
fi

# -------------------------
# Instalação de Python
# -------------------------
echo "Verificando Python..."
if python3 --version &>/dev/null; then
  echo "Python já está instalado."
else
  echo "Python não está instalado. Instalar agora? [s/n]"
  read get
  if [ "$get" == "s" ]; then
    apt install python3 -y
  fi
fi

# -------------------------
# Instalação do Docker
# -------------------------
echo "Verificando Docker..."
if docker --version &>/dev/null; then
  echo "Docker já está instalado."
else
  echo "Docker não está instalado. Instalar agora? [s/n]"
  read get
  if [ "$get" == "s" ]; then
    apt install docker.io -y
    systemctl start docker
    systemctl enable docker
  fi
fi

# -------------------------
# Container MySQL
# -------------------------
echo "Verificando container MySQL..."
if [ ! "$(docker ps -aq -f name=ContainerBD)" ]; then
  echo "Baixando imagem e criando container..."
  docker pull mysql:8
  docker run -d -p 3306:3306 --name ContainerBD -e "MYSQL_DATABASE=banco1" -e "MYSQL_ROOT_PASSWORD=urubu100" mysql:8
else
  echo "ContainerBD já existe. Ignorando criação."
fi

# -------------------------
# Projeto Node
# -------------------------
echo "Preparando diretório do projeto Node..."
mkdir -p /usr/src/app/web-data-viz
chmod -R 777 /usr/src/app/web-data-viz

echo "Criando Dockerfile..."
cat << EOF > /usr/src/app/web-data-viz/Dockerfile
FROM node:latest
WORKDIR /usr/src/app
RUN git clone https://github.com/BandTec/web-data-viz
WORKDIR /usr/src/app/web-data-viz
RUN npm install
EXPOSE 3333
CMD ["npm", "start"]
EOF

echo "Construindo imagem Docker..."
cd /usr/src/app/web-data-viz
docker build -t imagem-node:v1 .

echo "Verificando container do site..."
if [ ! "$(docker ps -aq -f name=ContainerSite)" ]; then
  docker run -d --name ContainerSite -p 3333:3333 imagem-node:v1
else
  echo "ContainerSite já existe. Ignorando criação."
fi

echo "✅ Script executado com sucesso!"