#!/bin/bash

BASHRC_FILE="$HOME/.bashrc"
GHPS_ALIAS='alias ghps="$HOME/app/github_scripts/ghps"'
GHPL_ALIAS='alias ghpl="$HOME/app/github_scripts/ghpl"'

# Проверяем и добавляем alias для ghps
if ! grep -qF "$GHPS_ALIAS" "$BASHRC_FILE"; then
    echo "$GHPS_ALIAS" >> "$BASHRC_FILE"
    echo "✅ Alias 'ghps' успешно добавлен в $BASHRC_FILE"
else
    echo "ℹ️ Alias 'ghps' уже существует в $BASHRC_FILE"
fi

# Проверяем и добавляем alias для ghpl
if ! grep -qF "$GHPL_ALIAS" "$BASHRC_FILE"; then
    echo "$GHPL_ALIAS" >> "$BASHRC_FILE"
    echo "✅ Alias 'ghpl' успешно добавлен в $BASHRC_FILE"
else
    echo "ℹ️ Alias 'ghpl' уже существует в $BASHRC_FILE"
fi

echo ""
echo "🎉 Настройка завершена!"
echo "Чтобы изменения вступили в силу прямо сейчас, выполните команду:"
echo "source ~/.bashrc"
