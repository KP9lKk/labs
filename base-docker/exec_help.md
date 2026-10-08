# Справка для Windows: где вы и что выполняется

Вы работаете с **Windows**, терминал — **PowerShell** (или CMD).  
Docker Desktop запускает **Linux-контейнеры** через WSL2. Поэтому есть три разные среды:

| Среда | Приглашение | Что тут работает | Примеры |
|---|---|---|---|
| **Windows-хост** | `PS C:\Users\student>` | Docker и команды Windows | `docker ps`, `cd`, `dir`, `mkdir`, `$env:PGHOST="localhost"` |
| **Bash внутри контейнера** | `root@a1b2c3d4:/#` | Linux-команды и запуск `psql` | `ls`, `cd`, `cat`, `echo`, `nano`, `psql -U postgres`, `exit` |
| **psql** | `postgres=#` | SQL и метакоманды `\...` | `SELECT`, `CREATE`, `\dt`, `\c`, `\q` |

**Главное правило:**
- `docker ...` — только с Windows-хоста.
- `bash` — внутри Linux-контейнера.
- `psql` — внутри PostgreSQL-клиента.
- `\...` — это psql, не bash и не Windows.
- `$env:...` — это PowerShell.
- `export ...` — это Linux/bash.

---

## 1. Windows-хост (PowerShell)

Здесь вы запускаете Docker и подключаетесь к контейнерам.

```powershell
# Посмотреть контейнеры
docker ps -a

# Запустить PostgreSQL
docker run -d --name my-postgres -e POSTGRES_PASSWORD=mysecretpassword -p 5432:5432 postgres

# Зайти в bash контейнера
docker exec -it my-postgres bash

# Сразу зайти в psql
docker exec -it my-postgres psql -U postgres

# Посмотреть логи
docker logs my-postgres
```

**Windows-особенности:**
- Пути: `C:\Users\student\pgdata_bind` или `${PWD}\pgdata_bind`.
- Переменные окружения:
  ```powershell
  $env:PGHOST="localhost"
  $env:PGPORT="5432"
  $env:PGUSER="postgres"
  $env:PGPASSWORD="mysecretpassword"
  $env:PGDATABASE="bind_test"
  ```
- Сброс переменных:
  ```powershell
  Remove-Item Env:PGHOST
  ```
- `mkdir ~/pgdata_bind` в PowerShell может сработать, но надёжнее:
  ```powershell
  mkdir $HOME\pgdata_bind
  ```

---

## 2. Bash внутри контейнера

Вы попадаете сюда после:
```powershell
docker exec -it my-postgres bash
```

Приглашение становится примерно таким:
```text
root@a1b2c3d4:/#
```

Здесь работают **Linux-команды**:
```bash
ls
cd /var/lib/postgresql/data
cat postgresql.conf
echo "work_mem = '24MB'" >> conf.d/work_mem.conf
nano ~/.psqlrc
psql -U postgres
exit
```

Выйти обратно на Windows:
```bash
exit
```

---

## 3. psql

Запускается либо из bash внутри контейнера:
```bash
psql -U postgres
```
либо сразу с Windows-хоста:
```powershell
docker exec -it my-postgres psql -U postgres
```

Приглашение:
```text
postgres=#
```

Здесь работают SQL и метакоманды psql:
```sql
CREATE DATABASE dev_db;
\c dev_db
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));
SELECT * FROM users;
\dt
\q
```

Выйти из psql:
```text
\q
```

---

## Как понять, где вы находитесь?

| Признак | Где вы |
|---|---|
| `PS C:\...>` | Windows-хост, PowerShell |
| Команда начинается с `docker ` | Windows-хост |
| `root@container:/#` | Bash внутри контейнера |
| `postgres=#` | psql |
| Команда начинается с `\` | psql |
| Ошибка `CREATE: command not found` | Вы в bash или PowerShell, но вводите SQL |
| Ошибка `docker: command not found` | Вы внутри контейнера |
| Ошибка `export: command not found` | Вы в PowerShell, а не в Linux |

---

## Типичные переходы

```powershell
# Windows PowerShell
docker ps

# Зайти в Linux-контейнер
docker exec -it my-postgres bash

# Внутри bash зайти в psql
psql -U postgres

# Внутри psql выйти в bash
\q

# Внутри bash выйти на Windows
exit
```

Или сразу:
```powershell
docker exec -it my-postgres psql -U postgres
```

---

## Что где делать

| Задача | Где | Пример |
|---|---|---|
| Запустить контейнер | Windows | `docker run -d --name my-postgres ...` |
| Посмотреть контейнеры | Windows | `docker ps -a` |
| Зайти в контейнер | Windows | `docker exec -it my-postgres bash` |
| Посмотреть файлы контейнера | Bash внутри | `ls /var/lib/postgresql/data` |
| Создать `.psqlrc` | Bash внутри | `nano ~/.psqlrc` |
| Запустить psql | Bash внутри или Windows | `psql -U postgres` |
| Создать БД | psql | `CREATE DATABASE dev_db;` |
| Посмотреть таблицы | psql | `\dt` |
| Подключиться из DBeaver | Windows | `localhost:5432`, БД `dev_db` |

---

## Частые ошибки на Windows

1. **SQL в PowerShell**
   ```powershell
   CREATE DATABASE dev_db;
   ```
   Ошибка. Сначала зайдите в `psql`.

2. **Docker внутри контейнера**
   ```bash
   docker ps
   ```
   Ошибка: `docker: command not found`. Выйдите из контейнера: `exit`.

3. **`export` в PowerShell**
   ```powershell
   export PGHOST=localhost
   ```
   Ошибка. В PowerShell:
   ```powershell
   $env:PGHOST="localhost"
   ```

4. **Путают `\q` и `exit`**
    - `\q` — выход из psql.
    - `exit` — выход из bash контейнера на Windows.

5. **Пути для bind mount**
   В PowerShell лучше использовать абсолютный путь:
   ```powershell
   -v C:\Users\student\pgdata_bind:/var/lib/postgresql/data
   ```
   или
   ```powershell
   -v ${PWD}/pgdata_bind:/var/lib/postgresql/data
   ```

---

## Мини-шпаргалка

```text
Windows (PowerShell) — docker и команды Windows.
Bash в контейнере    — Linux: файлы, каталоги, запуск psql.
psql                 — SQL и \метакоманды.
```

Смотрите на приглашение:
- `PS C:\...>` → Windows;
- `root@container:/#` → bash внутри контейнера;
- `postgres=#` → psql.