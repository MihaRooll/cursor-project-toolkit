---
name: install-harness-scripts
description: Скопировать papercuts shim и hook scripts в текущий проект (если нет bootstrap).
---

# Install harness scripts into project

Plugin даёт rules/skills/hooks. Для shim на диске проекта:

1. Из toolkit (предпочтительно):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <toolkit>\scripts\bootstrap-into-project.ps1 -TargetPath <this-repo> -Mode Essential
```

2. Или вручную скопируй из plugin `scripts/papercuts.ps1` → `scripts/papercuts.ps1` в корне проекта.

3. Проверь: `powershell -File scripts/papercuts.ps1 add "plugin install smoke" -Tag smoke`
