# WSL на Windows — стабильность (этот сетап)

> **AI-first.** Host: ~64GB RAM, WSL2, Ubuntu + docker-desktop, Cursor на Windows.

## For agents

**Когда читать:** WSL «падает», DNS/github не резолвится, команды из bash ломают `$env:…` / git auth.

**Применяй:**
- Продуктовые команды (`git push`, `gh`, `papercuts`, `winget`, bootstrap) → **Windows PowerShell**
- WSL → Docker / Linux-only tooling
- После зависания: `powershell -File scripts/stabilize-wsl.ps1` или `wsl --shutdown`
- Не предполагай, что agent bash = стабильный WSL login shell

**Не делай:** тяжёлые сборки только в `/mnt/c/...` без нужды; безлимитный WSL memory на 64GB host.

---

## Что уже настроено

Файл `%USERPROFILE%\.wslconfig`:

| Параметр | Значение | Зачем |
|----------|----------|--------|
| memory | 12GB | Не отдавать WSL половину RAM (при ~40GB уже занято Windows) |
| processors | 6 | Потолок CPU для VM |
| swap | 4GB | Запас без thrash |
| autoMemoryReclaim | gradual | Отдавать простой RAM обратно host |
| networkingMode | mirrored | Стабильнее DNS/VPN |
| dnsTunneling | true | Меньше «Could not resolve host» |
| sparseVhd | true | Диск VHD не раздувается зря |

Перезапуск: `scripts/stabilize-wsl.ps1` (делает `wsl --shutdown`).

## Правильный режим работы

| Задача | Где |
|--------|-----|
| Cursor + toolkit + git/push | Windows |
| Docker containers | WSL / Docker Desktop |
| Файлы проекта | `C:\Users\...\project` |

## Если снова упало

```powershell
wsl --shutdown
# 10 сек
wsl -l -v
# при необходимости запусти Docker Desktop вручную
```

DNS внутри Ubuntu (редко нужно при mirrored):

```bash
cat /etc/resolv.conf
```

## Docker

Resources Docker Desktop не должны быть больше лимита `.wslconfig` (ориентир ≤ 12GB).  
Settings → General: не держать «Start Docker Desktop when you sign in», если WSL нужен редко.
