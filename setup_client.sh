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
groupadd -f back-end
groupadd -f devops
echo "Grupos criados com sucesso!"

echo "Criando diretórios..."
mkdir -p /home/infra
mkdir -p /home/infra/app-python
mkdir -p /home/infra/app-java
echo "Diretórios criados em /home/infra"

echo "Atribuindo permissões..."
apt install acl -y
chmod 777 /home/infra/app-python
chmod 777 /home/infra/app-java
setfacl -m g:infrawatch:r-x /home/infra/app-python
setfacl -m g:infrawatch:r-x /home/infra/app-java

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
criar_usuario daniela daniela123
criar_usuario malu malu123
criar_usuario anthony anthony123

usermod -aG DBA machado
usermod -aG back-end daniela
usermod -aG devops davi
usermod -aG devops anthony
usermod -aG DBA davi
usermod -aG back-end malu
usermod -aG infrawatch machado
usermod -aG infrawatch daniela
usermod -aG infrawatch davi
usermod -aG infrawatch malu
usermod -aG infrawatch anthony
echo "Usuários atribuídos aos grupos."

echo "Verificando instalação do Java..."
if java -version &>/dev/null; then
  echo "Java já instalado."
else
  echo "Instalando OpenJDK 21..."
  apt install openjdk-21-jre -y
fi

echo "Baixando repositório do appclient-java..."
cd /home/infra/app-java
if [ ! -d "iw-appclient-java" ]; then
  git clone https://github.com/Infra-Watch/iw-appclient-java.git
else
  echo "Repositório iw-appclient-java já existe, atualizando..."
  cd iw-appclient-java && git pull
fi

echo "Iniciando executável .jar..."
nohup java -jar /home/infra/app-java/iw-appclient-java/iw-appclient-java-1.0-SNAPSHOT.jar &
echo ""

echo "Verificando instalação do Python..."
if python3 --version &>/dev/null; then
  echo "Python já instalado."
else
  echo "Instalando Python 3..."
  apt install python3 -y
fi
echo "Instalando dependência python3-venv..."
apt install python3-venv -y


cd /home/infra/app-python
if [ ! -d "iw-appclient-python" ]; then
  git clone https://github.com/Infra-Watch/iw-appclient-python.git
fi
cd iw-appclient-python  
git pull || true
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "Iniciando script python..."
nohup /home/infra/app-python/iw-appclient-python/venv/bin/python3 /home/infra/app-python/iw-appclient-python/app/main.py &
echo ""

echo "✅ Ambiente de aplicações (Java/Python) configurado com sucesso! Sua máquina já está sendo monitorada!"