# MedControl-deploy

Конфигурация для запуска MedControl на Windows через Docker Compose. Фронтенд, бэкенд и nginx запускаются локально. В основном режиме Prisma подключается к PostgreSQL в Supabase. Сайт доступен по адресу [https://medcontrol.localhost](https://medcontrol.localhost) на компьютере, где запущен Docker.

## 1. Установите инструменты

- Установите и запустите [Docker Desktop для Windows](https://docs.docker.com/desktop/setup/install/windows-install/).
- Установите [Git для Windows](https://git-scm.com/install/windows), если будете скачивать репозитории через `git clone`.
- Установите [mkcert](https://github.com/FiloSottile/mkcert) для локального HTTPS. Если доступен `winget`, выполните команду ниже и откройте новое окно PowerShell.

```powershell
winget install --id FiloSottile.mkcert --exact
```

Проверьте, что Docker запущен и команды доступны:

```powershell
docker info
docker compose version
mkcert -version
```

Для этого способа запуска отдельно устанавливать Node.js, npm или PostgreSQL на Windows не нужно.

## 2. Скачайте оба репозитория

На GitHub откройте **Code → HTTPS** в каждом репозитории. В PowerShell из общей папки выполните команды и вставьте адреса при запросе:

```powershell
$appRepo = Read-Host 'HTTPS-адрес репозитория MedControl'
git clone $appRepo MedControl

$deployRepo = Read-Host 'HTTPS-адрес репозитория MedControl-deploy'
git clone $deployRepo MedControl-deploy

Set-Location .\MedControl-deploy
```

Если скачиваете архивы через **Download ZIP**, распакуйте их в соседние папки `MedControl` и `MedControl-deploy`. В папке деплоя должны находиться `docker-compose.yml`, `compose.supabase.yml`, `init-local.ps1` и `nginx.conf`. В исходниках приложения нужны `backend/Dockerfile.prod` и `frontend/Dockerfile.prod`.

## 3. Подготовьте локальное окружение

Откройте терминал в **`MedControl-deploy`**. При первой настройке выполните:

```powershell
powershell -ExecutionPolicy Bypass -File .\init-local.ps1
```

Скрипт создаёт `.env` из `.env.example`, если файла ещё нет, и выпускает сертификат для `medcontrol.localhost`. Если Windows предложит доверять локальному центру сертификации mkcert, подтвердите установку. Оставьте рабочий `.env` и ключи из `certs/` на компьютере.

В `.env` проверьте `PROJECT_DIR=../MedControl`. Если папка исходников называется иначе, укажите её путь относительно `MedControl-deploy`. Оставьте сгенерированные `JWT_SECRET` и `POSTGRES_PASSWORD`. Если у вас уже настроена отправка писем, сохраните существующие настройки SMTP.

## 4. Подключите Supabase

1. Откройте существующий проект MedControl в Supabase. Для новой установки создайте проект и сохраните его **Database Password**. В **Integrations → Data API** оставьте **Enable Data API** выключенным. Бэкенд подключается к базе напрямую через Prisma. [Настройки Data API](https://supabase.com/docs/guides/api/securing-your-api#disable-the-data-api)
2. В проекте нажмите **Connect → Direct → Session pooler**. Скопируйте строку подключения с портом **5432**. [Способы подключения к PostgreSQL](https://supabase.com/docs/guides/database/connecting-to-postgres)
3. В `MedControl-deploy/.env` добавьте строку ниже, подставив свою строку подключения и пароль базы. Если пароль содержит специальные символы, закодируйте только пароль для URL. Если у строки уже есть другие параметры, добавьте `sslmode=require` через `&`. [Формат URL подключения Prisma](https://www.prisma.io/docs/orm/v6/overview/databases/postgresql)

```dotenv
SUPABASE_DATABASE_URL='postgresql://postgres.PROJECT_REF:DATABASE_PASSWORD@POOLER_HOST:5432/postgres?sslmode=require'
```

## 5. Запустите и проверьте приложение

Из папки `MedControl-deploy` выполните:

```powershell
docker compose -f docker-compose.yml -f compose.supabase.yml config -q
docker compose -f docker-compose.yml -f compose.supabase.yml up --build -d
docker compose -f docker-compose.yml -f compose.supabase.yml ps --all
```

`config -q` проверяет конфигурацию. Сервис `migrate` применяет ожидающие миграции Prisma к Supabase. Бэкенд запускается после успешного завершения миграций.

1. Убедитесь, что `backend`, `frontend` и `nginx` запущены, а `migrate` завершился со статусом `Exited (0)`.
2. Откройте [проверку подключения к базе](https://medcontrol.localhost/api/health/db). Ожидаемый ответ — `{"status":"ok","database":"connected"}`.
3. Откройте [MedControl](https://medcontrol.localhost). Если вы подключили базу с перенесёнными данными, войдите в существующую учётную запись. Если база создана с нуля, зарегистрируйте тестовую учётную запись. Миграции создают таблицы, а перенос записей из локальной базы выполняется отдельно.

## Ежедневные команды для Supabase

Выполняйте команды из папки `MedControl-deploy`. Повторно запускать `init-local.ps1` при обычном старте не требуется.

| Действие | Команда |
|---|---|
| Запустить приложение | `docker compose -f docker-compose.yml -f compose.supabase.yml up -d` |
| Пересобрать после изменений в коде | `docker compose -f docker-compose.yml -f compose.supabase.yml up --build -d` |
| Проверить состояние | `docker compose -f docker-compose.yml -f compose.supabase.yml ps --all` |
| Посмотреть логи | `docker compose -f docker-compose.yml -f compose.supabase.yml logs --tail=100 migrate backend frontend nginx` |
| Остановить приложение | `docker compose -f docker-compose.yml -f compose.supabase.yml down` |

После остановки приложения данные остаются в Supabase.

## Запуск с локальной базой PostgreSQL

Для этого режима используйте только базовый файл `docker-compose.yml`. Если приложение сейчас запущено с Supabase, сначала остановите его командой `down` из таблицы выше.

```powershell
docker compose up --build -d
docker compose ps --all
```

В локальном режиме запускается контейнер `db`, а данные хранятся в томе `postgres_data`. Данные локального PostgreSQL и Supabase ведутся раздельно. Если вы уже перешли на Supabase и старый контейнер базы ещё работает, его можно остановить командой `docker compose stop db`. Данные в локальном томе сохранятся.

## Если приложение не запускается

| Симптом | Что проверить |
|---|---|
| Docker недоступен | Откройте Docker Desktop и повторите `docker info`. |
| Compose не находит `Dockerfile.prod` | Проверьте расположение обеих папок и значение `PROJECT_DIR`. |
| Prisma не подключается к Supabase | Проверьте строку из **Session pooler**, порт 5432, пароль базы и кодирование спецсимволов. Посмотрите логи `migrate` и `backend` командой из таблицы. |
| Браузер показывает `ERR_CONNECTION_REFUSED` | Проверьте статус `nginx` и наличие порта 443 в выводе `ps --all`. Запустите nginx командой `docker compose -f docker-compose.yml -f compose.supabase.yml up -d nginx`. |
| Браузер не доверяет сертификату | Повторите `init-local.ps1` и подтвердите установку сертификата mkcert. |
| После пересборки приложение показывает `502` | Убедитесь, что `backend` и `frontend` запущены. Затем перезапустите nginx командой `docker compose -f docker-compose.yml -f compose.supabase.yml restart nginx`. |
