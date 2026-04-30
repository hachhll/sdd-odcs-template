# Используем стабильную и легкую базу
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Устанавливаем SSH, утилиты для IDE и пару инструментов аналитика
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    git \
    curl \
    wget \
    jq \
    sqlite3 \
    && mkdir -p /var/run/sshd

# Создаем стандартного пользователя
RUN useradd -m -s /bin/bash developer && \
    echo "developer:password123" | chpasswd && \
    adduser developer sudo

# Разрешаем вход по SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

USER root
WORKDIR /home/developer/app

# Открываем порт только для SSH
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
