# MedControl-deploy

Этот репозиторий содержит конфигурацию для локального запуска MedControl по HTTPS. Docker Compose собирает приложение из соседней папки с исходным кодом, запускает PostgreSQL, применяет миграции Prisma и поднимает nginx. После запуска приложение доступно на [https://medcontrol.localhost](https://medcontrol.localhost).

## 1. Установите инструменты

Инструкция рассчитана на Windows и PowerShell.

- Установите и откройте [Docker Desktop для Windows](https://docs.docker.com/desktop/setup/install/windows-install/). Дождитесь запуска Docker Engine.
- Установите [Git для Windows](https://git-scm.com/install/windows), если будете скачивать репозитории через `git clone`.
- Установите [mkcert](https://github.com/FiloSottile/mkcert) для выпуска локального сертификата.

Если на компьютере доступен `winget`, mkcert можно установить из PowerShell:

```powershell
winget install --id FiloSottile.mkcert --exact
```

Откройте новое окно PowerShell и проверьте установку:

```powershell
docker info
docker compose version
mkcert -version
git --version
```

Node.js, npm и PostgreSQL устанавливать на Windows не нужно. Они используются внутри Docker.

## 2. Скачайте оба репозитория

Откройте PowerShell в общей папке, где будут храниться оба репозитория. Скопируйте HTTPS-адреса на GitHub через **Code → HTTPS** и вставьте их при запросе:

```powershell
$appRepo = Read-Host 'Вставьте HTTPS-адрес основного репозитория MedControl'
git clone $appRepo MedControl

$deployRepo = Read-Host 'Вставьте HTTPS-адрес этого репозитория MedControl-deploy'
git clone $deployRepo MedControl-deploy

Set-Location .\MedControl-deploy
```

Если этот репозиторий уже скачан, клонируйте только основной репозиторий в соседнюю папку `MedControl`. При скачивании через **Code → Download ZIP** распакуйте оба архива и переименуйте распакованные папки в `MedControl` и `MedControl-deploy`.

Проверьте, что файлы лежат на этих уровнях:

```text
Общая папка/
├── MedControl/
│   ├── backend/Dockerfile.prod
│   └── frontend/Dockerfile.prod
└── MedControl-deploy/
    ├── .env.example
    ├── docker-compose.yml
    ├── init-local.ps1
    └── nginx.conf
```

Используйте версию основного проекта, в которой уже есть оба `Dockerfile.prod` и поддержка настройки `VITE_API_URL=/api` во фронтенде. Путь по умолчанию — `PROJECT_DIR=../MedControl`. Если папка с исходниками называется иначе, исправьте `PROJECT_DIR` в локальном `.env` после следующего шага и перед сборкой. Путь задаётся относительно папки `MedControl-deploy`.

## 3. Подготовьте окружение и запустите приложение

Из папки **`MedControl-deploy`** выполните:

```powershell
powershell -ExecutionPolicy Bypass -File .\init-local.ps1
```

Скрипт создаёт `.env` из `.env.example`, если файла ещё нет, генерирует пароль PostgreSQL и секрет JWT, а затем устанавливает локальный центр сертификации mkcert и создаёт сертификат для `medcontrol.localhost`. Если Windows запросит подтверждение установки сертификата mkcert, подтвердите его. Если скрипт вывел ошибку, устраните её перед запуском Compose.

```powershell
docker compose up --build -d
docker compose ps --all
```

Первая сборка скачивает базовые образы и зависимости, поэтому может занять несколько минут. Оставьте `.env` и созданные сертификаты и ключи из `certs/` у себя на компьютере.

## 4. Проверьте запуск

1. В выводе `docker compose ps --all` сервисы `nginx`, `frontend` и `backend` должны быть запущены, а `db` — иметь статус `healthy`. Для одноразового сервиса `migrate` ожидается `Exited (0)`.
2. Откройте [проверку API и базы](https://medcontrol.localhost/api/health/db). При успешном подключении API возвращает JSON со статусом `ok` и значением `database: connected`.
3. Откройте [MedControl](https://medcontrol.localhost), зарегистрируйте тестовую учётную запись и войдите. При первом запуске используется новая локальная база, поэтому учётные записи с другого компьютера в ней отсутствуют.

## Повторный запуск, обновление и остановка

Выполняйте команды из папки `MedControl-deploy`.

| Действие | Команда |
|---|---|
| Запустить уже собранное приложение | `docker compose up -d` |
| Пересобрать после обновления исходников | `docker compose up --build -d` |
| Посмотреть состояние сервисов | `docker compose ps --all` |
| Посмотреть последние сообщения сервисов | `docker compose logs --tail=100 db migrate backend frontend nginx` |
| Остановить приложение с сохранением базы | `docker compose down` |

Если репозитории клонированы через Git, обновить их и пересобрать приложение можно так:

```powershell
git -C ..\MedControl pull
git pull
docker compose up --build -d
```

## Если приложение не запускается

| Симптом | Что проверить |
|---|---|
| Docker сообщает, что не может подключиться к демону | Откройте Docker Desktop, дождитесь запуска движка и повторите `docker info`. |
| Compose не находит `Dockerfile.prod` или папку сборки | Сверьте расположение обеих папок, значение `PROJECT_DIR` и наличие `Dockerfile.prod` в основном проекте. |
| Compose сообщает, что порты 80 или 443 заняты | Остановите другой локальный веб-сервер или контейнер, использующий эти порты, затем повторите запуск. |
| Браузер не доверяет сертификату | Повторите запуск `init-local.ps1`, подтвердите установку локального сертификата mkcert и перезапустите браузер. |
| Сборка сообщает об ошибке DNS при скачивании образов | Проверьте подключение к интернету и повторите `docker compose up --build -d`. |
| Страница открывается, а запросы к API идут на `localhost:3001` | Обновите основной репозиторий до версии с поддержкой `VITE_API_URL` и пересоберите фронтенд через `docker compose up --build -d`. |
| API возвращает `502` или сервис `migrate` завершился с ошибкой | Посмотрите `docker compose logs --tail=100 db migrate backend nginx`. Бэкенд запускается после успешного применения миграций. |
