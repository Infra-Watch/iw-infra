#!/bin/bash
# Atualiza o sistema
echo "Atualizando o sistema..."
sudo apt update && sudo apt upgrade -y
# Verifica se o Java está instalado
echo "Verificando se o Java está instalado..."
java -version &> /dev/null
if [ $? -eq 0 ]; then
    echo "Java já está instalado"
else
    echo "Java não está instalado"
    echo "Gostaria de instalar o Java? [s/n]"
    read get
    if [ "$get" == "s" ]; then
        sudo apt install openjdk-17-jre -y
    fi
fi
# Verifica se o Python está instalado
echo "Verificando se o Python está instalado..."
python3 --version &> /dev/null
if [ $? -eq 0 ]; then
    echo "Python já está instalado"
else
    echo "Python não está instalado"
    echo "Gostaria de instalar o Python? [s/n]"
    read get
    if [ "$get" == "s" ]; then
        sudo apt install python3 -y
    fi
fi
# Verifica se o Docker está instalado
echo "Verificando se o Docker está instalado..."
docker --version &> /dev/null
if [ $? -eq 0 ]; then
    echo "Docker já está instalado"
else
    echo "Docker não está instalado"
    echo "Gostaria de instalar o Docker? [s/n]"
    read get
    if [ "$get" == "s" ]; then
        sudo apt install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
fi
# Baixa a imagem do MySQL
echo "Baixando a imagem do MySQL..."
sudo docker pull mysql:8
# Executa o container MySQL
echo "Executando o container MySQL..."
sudo docker run -d -p 3306:3306 --name ContainerBD -e "MYSQL_DATABASE=banco1" -e "MYSQL_ROOT_PASSWORD=urubu100" mysql:8
# Verifica se o diretório do projeto existe
if [ ! -d "/usr/src/app" ]; then
    sudo mkdir -p /usr/src/app
fi
sudo mkdir -p /usr/src/app/web-data-viz
sudo chmod -R 777 /usr/src/app/web-data-viz
# Cria o Dockerfile para o projeto Node (em tempo de execução)
echo "Criando Dockerfile para o projeto Node..."
cat << EOF > /usr/src/app/web-data-viz/Dockerfile
FROM node:latest
WORKDIR /usr/src/app
RUN git clone https://github.com/BandTec/web-data-viz
WORKDIR /usr/src/app/web-data-viz
RUN npm install
EXPOSE 3333
CMD ["npm", "start"]
EOF
# Construção da imagem Docker para o projeto Node
echo "Construindo a imagem Docker para o projeto Node..."
cd /usr/src/app/web-data-viz
sudo docker build -t imagem-node:v1 .
# Executa o container do projeto Node
echo "Executando o container do projeto Node..."
sudo docker run -d --name ContainerSite -p 3333:3333 imagem-node:v1
echo "Script executado com sucesso!"
