# Опушка — заметки для Claude

Перед работой прочитай **`docs/JOURNAL.md`**: устройство игры, договорённости с владельцем,
хроника, отложенное и грабли. После заметного изменения — допиши туда запись.

Коротко:
- Игра на **Godot 4.3**, GDScript, рендер `gl_compatibility` (старые телефоны, и так её
  можно рисовать здесь через Xvfb для скриншотов).
- Ветка `main`. Пуш в `main` → GitHub Actions собирает APK → релиз `build-N`.
  Ссылка: `https://github.com/nonedeity-dotcom/Opushka/releases/download/build-N/opushka.apk`
  Когда сборка готова — **самому прислать ссылку** владельцу.
- Перед пушем: `godot --headless -s tests/run.gd` (Godot лежит в `~/.cache/godot/`,
  если нет — скачать 4.3-stable linux zip с GitHub releases).
- Общение по-русски, простыми словами. Большие перемены интерфейса — сначала скриншоты.
