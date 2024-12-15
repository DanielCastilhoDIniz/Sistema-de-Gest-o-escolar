# Define a versão do Python a ser usada e a imagem base, baseada no Alpine Linux.
# O Alpine é utilizado por ser uma distribuição leve, ideal para imagens Docker.
ARG PYTHON_VERSION=3.11.3
FROM python:${PYTHON_VERSION}-alpine3.18

# Informações sobre a imagem, como o mantenedor, versão e descrição.
LABEL maintainer="danielcastilho.com" version="1.0" description="Aplicação Django em Docker"

# Define variáveis de ambiente para otimizar o comportamento do Python.
# PYTHONDONTWRITEBYTECODE: Impede a criação de arquivos .pyc, economizando espaço.
ENV PYTHONDONTWRITEBYTECODE=1
# PYTHONUNBUFFERED: Garante que os logs sejam exibidos em tempo real, sem buffer.
ENV PYTHONUNBUFFERED=1

# Copia os arquivos de dependências e scripts para dentro do contêiner.
# requirements.txt: Lista de dependências de produção.
# requirements.dev.txt: Lista de dependências adicionais para desenvolvimento.
COPY requirements.txt /tmp/requirements.txt
COPY requirements.dev.txt /tmp/requirements.dev.txt
# Copia o código-fonte da aplicação para o diretório /sgeapp no contêiner.
COPY ./sgeapp /sgeapp
# Copia os scripts auxiliares para o contêiner.
COPY scripts /scripts

# Verifica se o arquivo requirements.txt existe, para evitar erros durante a construção.
RUN test -f /tmp/requirements.txt || (echo "Arquivo requirements.txt não encontrado" && exit 1)

# Define o diretório de trabalho dentro do contêiner como /sgeapp.
WORKDIR /sgeapp

# Expõe a porta 8000, usada pelo servidor Django para receber requisições.
EXPOSE 8000

# Define uma variável ARG (argumento de construção) para determinar se o ambiente é de desenvolvimento.
# Essa variável será utilizada para instalar dependências de desenvolvimento, se necessário.
ARG DEV=false

# Configuração e instalação de dependências.
RUN python -m venv /venv && \
  /venv/bin/pip install --upgrade pip --no-cache-dir && \
  /venv/bin/pip install pip-audit --no-cache-dir && \
  /venv/bin/pip-audit -r /tmp/requirements.txt || (echo "Falha na auditoria de segurança" && exit 1) && \
  /venv/bin/pip install -r /tmp/requirements.txt --no-cache-dir && \
  if [ "$DEV" = "true" ]; then \
        test -f /tmp/requirements.dev.txt || (echo "Arquivo requirements.dev.txt não encontrado" && exit 1); \
        /venv/bin/pip install -r /tmp/requirements.dev.txt --no-cache-dir; \
    fi && \
  adduser --disabled-password --no-create-home duser && \
  apk add --update --no-cache postgresql-client jpeg-dev && \
  apk add --update --no-cache --virtual .tmp-build-deps \
      build-base postgresql-dev musl-dev zlib zlib-dev linux-headers && \
  rm -rf /tmp && \
  apk del .tmp-build-deps && \
  mkdir -p /data/web/static /data/web/media && \
  chown -R duser:duser /venv /data/web/static /data/web/media && \
  chmod -R 755 /data/web/static /data/web/media && \
  chmod -R +x /scripts

# Adiciona o diretório scripts e o ambiente virtual Python ao PATH, permitindo a execução de seus comandos.
ENV PATH="/scripts:/venv/bin:$PATH"

# Define o usuário padrão como duser, garantindo que o contêiner não seja executado como root.
USER duser

# Especifica o arquivo de script principal que será executado ao iniciar o contêiner.
# ENTRYPOINT ["/scripts/commands.sh"]
CMD ["commands.sh"]