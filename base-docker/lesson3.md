# Лабораторная работа № 3

## Тема: Конфигурирование сервера PostgreSQL

---

## 1. Краткие теоретические сведения

### 1.1. Параметры конфигурации

PostgreSQL управляется большим количеством параметров, которые влияют на:
- потребление ресурсов (память, диск, CPU);
- поведение серверных процессов;
- журналирование и мониторинг;
- безопасность и подключения.

Параметры можно устанавливать на нескольких уровнях:
1. **Уровень экземпляра** — через файлы конфигурации (`postgresql.conf`, `postgresql.auto.conf`, подключаемые файлы).
2. **Уровень базы данных или роли** — через `ALTER DATABASE ... SET` и `ALTER ROLE ... SET`.
3. **Уровень сеанса** — через `SET` и `set_config()`.

Полный список параметров: https://postgrespro.ru/docs/postgresql/16/runtime-config

### 1.2. Файлы конфигурации

**Основной файл — `postgresql.conf`:**
- Расположен в каталоге данных (`PGDATA`) или в другом месте (зависит от дистрибутива).
- Формат: `параметр = значение`.
- Может подключать дополнительные файлы через `include`, `include_dir`, `include_if_exists`.
- При изменении требуется **перечитать конфигурацию** (`pg_reload_conf()` или `pg_ctl reload`).
- Некоторые параметры требуют **перезапуска сервера** (context = `postmaster`).

**Файл `postgresql.auto.conf`:**
- Расположен всегда в `PGDATA`.
- Управляется командой `ALTER SYSTEM`.
- Считывается **после** `postgresql.conf` (имеет приоритет).
- Не редактируется вручную.

### 1.3. Представления для работы с конфигурацией

- **`pg_settings`** — действующие значения всех параметров. Ключевые столбцы:
    - `name`, `setting`, `unit` — имя, текущее значение, единица измерения;
    - `boot_val` — значение по умолчанию;
    - `reset_val` — значение, которое будет установлено при `RESET`;
    - `source` — источник текущего значения (`default`, `configuration file`, `database`, `session`, `override` и т.д.);
    - `sourcefile`, `sourceline` — файл и строка, где задан параметр;
    - `pending_restart` — `true`, если значение изменено в файле, но требуется перезапуск;
    - `context` — что нужно для применения: `internal`, `postmaster`, `sighup`, `superuser`, `user`.

- **`pg_file_settings`** — строки из всех файлов конфигурации. Ключевые столбцы:
    - `sourcefile`, `sourceline` — где найдена строка;
    - `name`, `setting` — параметр и значение;
    - `applied` — будет ли применено (`t`/`f`);
    - `error` — текст ошибки, если строка некорректна.

### 1.4. Команды для управления параметрами

**Изменение для всего экземпляра:**
```sql
ALTER SYSTEM SET параметр = 'значение';   -- запись в postgresql.auto.conf
ALTER SYSTEM RESET параметр;              -- удаление из postgresql.auto.conf
ALTER SYSTEM RESET ALL;
SELECT pg_reload_conf();                  -- перечитать конфигурацию
```

**Изменение для базы данных:**
```sql
ALTER DATABASE имя_базы SET параметр = 'значение';
ALTER DATABASE имя_базы RESET параметр;
```

**Изменение для роли:**
```sql
ALTER ROLE имя_роли SET параметр = 'значение';
ALTER ROLE имя_роли RESET параметр;
```

**Изменение для текущего сеанса:**
```sql
SET параметр = 'значение';                -- до конца сеанса
SET LOCAL параметр = 'значение';          -- до конца транзакции
RESET параметр;                           -- сброс к значению по умолчанию
SHOW параметр;                            -- показать значение
SELECT current_setting('параметр');       -- то же, но в запросе
SELECT set_config('параметр', 'значение', false);
```

### 1.5. Просмотр конфигурации

```sql
SHOW work_mem;
\config work_mem                -- метакоманда psql
SELECT * FROM pg_settings WHERE name = 'work_mem';
SELECT * FROM pg_file_settings;
```

### 1.6. Примеры важных параметров

| Параметр | Назначение | Контекст |
|----------|-----------|----------|
| `max_connections` | Максимальное число подключений | postmaster |
| `shared_buffers` | Размер буферного кеша | postmaster |
| `work_mem` | Память на операцию сортировки/хеширования | user |
| `maintenance_work_mem` | Память для VACUUM, CREATE INDEX | user |
| `wal_level` | Уровень детализации WAL | postmaster |
| `log_min_duration_statement` | Логировать запросы дольше N мс | superuser |
| `log_destination` | Куда писать логи | sighup |
| `logging_collector` | Включить сборщик логов | postmaster |
| `timezone` | Часовой пояс | user |
| `lc_messages` | Язык сообщений | superuser |
| `default_text_search_config` | Конфигурация полнотекстового поиска | user |

---

## 2. Порядок выполнения работы

Все задания выполняются в терминале и внутри контейнера PostgreSQL.

**Подготовка.** Запустите контейнер с PostgreSQL и примонтируйте каталог данных на хост, чтобы можно было редактировать файлы конфигурации:

```bash
mkdir -p ~/pg_config_lab
docker run -d --name pg-config \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  -v ~/pg_config_lab:/var/lib/postgresql/data \
  postgres:latest
```

> **Примечание.** В новых версиях образа `postgres` данные располагаются в `/var/lib/postgresql/data` (или `/var/lib/postgresql`, если используется `PGDATA`). Если после запуска в `~/pg_config_lab` ничего нет — проверьте путь внутри контейнера командой `docker exec pg-config ls /var/lib/postgresql`.

---

### Задание 1. Знакомство с `pg_settings` и `pg_file_settings`

**Цель:** научиться получать информацию о параметрах и их источниках.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres
   ```
2. Посмотрите все параметры с источником `configuration file`:
   ```sql
   SELECT name, setting, unit, source, sourcefile, sourceline
   FROM pg_settings
   WHERE source = 'configuration file'
   ORDER BY sourcefile, sourceline
   LIMIT 20;
   ```
3. Посмотрите параметры, для которых нужен перезапуск:
   ```sql
   SELECT name, setting, unit
   FROM pg_settings
   WHERE context = 'postmaster'
   ORDER BY name;
   ```
   Запишите 5–7 параметров из этого списка.
4. Посмотрите содержимое всех файлов конфигурации:
   ```sql
   SELECT sourcefile, sourceline, name, setting, applied, error
   FROM pg_file_settings
   ORDER BY sourcefile, sourceline
   LIMIT 30;
   ```
5. Для параметра `work_mem` выведите подробную информацию:
   ```sql
   SELECT name, setting, unit, boot_val, reset_val, source, sourcefile, sourceline, pending_restart, context
   FROM pg_settings
   WHERE name = 'work_mem';
   ```
6. Выйдите из psql.

**Ожидаемый результат:** вы понимаете, откуда берутся значения параметров и какие из них требуют перезапуска.

---

### Задание 2. Изменение параметра через `ALTER SYSTEM`

**Цель:** научиться менять параметры экземпляра через SQL.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres
   ```
2. Посмотрите текущее значение `work_mem`:
   ```sql
   SHOW work_mem;
   ```
3. Измените его на 16 МБ:
   ```sql
   ALTER SYSTEM SET work_mem = '16MB';
   ```
4. Проверьте, что значение **ещё не применилось**:
   ```sql
   SHOW work_mem;
   ```
5. Перечитайте конфигурацию:
   ```sql
   SELECT pg_reload_conf();
   ```
6. Убедитесь, что параметр применился:
   ```sql
   SHOW work_mem;
   ```
7. Посмотрите, куда записалось значение:
   ```sql
   SELECT sourcefile, sourceline, name, setting, applied
   FROM pg_file_settings
   WHERE name = 'work_mem';
   ```
   Файл должен быть `postgresql.auto.conf`.
8. Сбросьте параметр:
   ```sql
   ALTER SYSTEM RESET work_mem;
   SELECT pg_reload_conf();
   SHOW work_mem;
   ```
9. Выйдите из psql.

**Ожидаемый результат:** параметр изменился, применился после `pg_reload_conf()`, а затем сбросился.

---

### Задание 3. Изменение параметра в файле `postgresql.conf` и подключение дополнительных файлов

**Цель:** научиться редактировать основной файл конфигурации и использовать `include_dir`.

#### Техническое задание:
1. Войдите в контейнер:
   ```bash
   docker exec -it pg-config bash
   ```
2. Найдите путь к `postgresql.conf`:
   ```bash
   psql -U postgres -c "SHOW config_file;"
   ```
3. Посмотрите конец файла — там должны быть директивы `include_dir` и `include`:
   ```bash
   tail -n 20 /var/lib/postgresql/data/postgresql.conf
   ```
   (или путь, который вы получили в п.2).
4. Создайте каталог `conf.d`, если его нет, и файл с настройкой:
   ```bash
   mkdir -p /var/lib/postgresql/data/conf.d
   echo "work_mem = '24MB'" >> /var/lib/postgresql/data/conf.d/work_mem.conf
   ```
5. Убедитесь, что `include_dir` указывает на этот каталог. Если нет — добавьте в конец `postgresql.conf` строку:
   ```
   include_dir = 'conf.d'
   ```
6. Выйдите из контейнера и перечитайте конфигурацию:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SELECT pg_reload_conf();"
   ```
7. Проверьте значение:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SHOW work_mem;"
   ```
8. Посмотрите `pg_file_settings` — там должна появиться строка из `work_mem.conf`:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SELECT sourcefile, sourceline, name, setting, applied FROM pg_file_settings WHERE name = 'work_mem';"
   ```

**Ожидаемый результат:** параметр `work_mem` установлен в `24MB` через дополнительный файл.

---

### Задание 4. Ошибка в конфигурационном файле и её диагностика

**Цель:** научиться находить ошибки в конфигурации и восстанавливать работоспособность сервера.

#### Техническое задание:
1. Войдите в контейнер и добавьте **некорректное** значение параметра `max_connections` в отдельный файл:
   ```bash
   docker exec -it pg-config bash
   echo "max_connections = abc" > /var/lib/postgresql/data/conf.d/max_connections.conf
   ```
2. Выйдите из контейнера и попробуйте перечитать конфигурацию:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SELECT pg_reload_conf();"
   ```
3. Посмотрите на `pg_file_settings` — там должна быть ошибка:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SELECT sourcefile, sourceline, name, setting, applied, error FROM pg_file_settings WHERE name = 'max_connections';"
   ```
4. Теперь попробуйте **перезапустить** контейнер — сервер не должен стартовать из-за ошибки в конфигурации:
   ```bash
   docker restart pg-config
   docker logs pg-config
   ```
   В логах должна быть ошибка вида `invalid value for parameter "max_connections"`.
5. Исправьте ошибку — приведите файл к корректному значению (так как контейнер не запущен, редактируйте файл на хосте через bind mount):
   ```bash
   echo "max_connections = 50" > ~/pg_config_lab/conf.d/max_connections.conf
   ```
6. Запустите контейнер:
   ```bash
   docker start pg-config
   ```
7. Проверьте, что параметр применился:
   ```bash
   docker exec -it pg-config psql -U postgres -c "SHOW max_connections;"
   ```

**Ожидаемый результат:** вы научились находить ошибки в конфигурации через `pg_file_settings` и логи, а также исправлять их.

---

### Задание 5. Установка параметров на уровне базы данных и роли

**Цель:** освоить установку параметров для конкретной базы данных или роли.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres
   ```
2. Создайте базу `cfg_db` и роль `cfg_user`:
   ```sql
   CREATE DATABASE cfg_db;
   CREATE ROLE cfg_user LOGIN PASSWORD 'userpass';
   ```
3. Установите параметр `work_mem` для базы `cfg_db`:
   ```sql
   ALTER DATABASE cfg_db SET work_mem = '32MB';
   ```
4. Установите параметр `search_path` для роли `cfg_user`:
   ```sql
   ALTER ROLE cfg_user SET search_path = public, app;
   ```
5. Подключитесь к базе `cfg_db` под пользователем `cfg_user` (из командной строки):
   ```bash
   docker exec -it pg-config psql -U cfg_user -d cfg_db
   ```
   (пароль `userpass`; при запросе введите его).
6. Проверьте параметры:
   ```sql
   SHOW work_mem;
   SHOW search_path;
   ```
   `work_mem` должен быть `32MB` (из настройки БД), `search_path` — `public, app` (из настройки роли).
7. Посмотрите, где хранятся эти настройки:
   ```sql
   SELECT * FROM pg_db_role_setting;
   ```
8. Сбросьте настройки:
   ```sql
   ALTER DATABASE cfg_db RESET work_mem;
   ALTER ROLE cfg_user RESET search_path;
   ```
9. Выйдите из psql.

**Ожидаемый результат:** параметры применились только к указанной базе/роли.

---

### Задание 6. Установка параметров в текущем сеансе

**Цель:** научиться менять параметры в рамках сеанса и транзакции.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres -d cfg_db
   ```
2. Посмотрите текущее значение `work_mem`:
   ```sql
   SHOW work_mem;
   ```
3. Установите значение для сеанса:
   ```sql
   SET work_mem = '64MB';
   SHOW work_mem;
   ```
4. Откройте транзакцию и установите значение **только для транзакции**:
   ```sql
   BEGIN;
   SET LOCAL work_mem = '128MB';
   SHOW work_mem;
   ```
5. Зафиксируйте транзакцию и проверьте, что значение вернулось к сеансовому:
   ```sql
   COMMIT;
   SHOW work_mem;
   ```
6. Сбросьте сеансовое значение:
   ```sql
   RESET work_mem;
   SHOW work_mem;
   ```
7. Проверьте, что откат транзакции отменяет `SET` (не `SET LOCAL`):
   ```sql
   BEGIN;
   SET work_mem = '256MB';
   SHOW work_mem;
   ROLLBACK;
   SHOW work_mem;
   ```
8. Выйдите из psql.

**Ожидаемый результат:** вы понимаете разницу между `SET`, `SET LOCAL` и `RESET`, а также влияние транзакций.

---

### Задание 7. Пользовательские параметры

**Цель:** научиться создавать собственные параметры в сеансе.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres
   ```
2. Создайте пользовательский параметр с точкой в имени:
   ```sql
   SELECT set_config('myapp.currency_code', 'RUB', false);
   ```
3. Прочитайте его:
   ```sql
   SELECT current_setting('myapp.currency_code');
   ```
4. Используйте его в запросе:
   ```sql
   SELECT current_setting('myapp.currency_code') AS currency;
   ```
5. Установите пользовательский параметр в файле конфигурации (в `postgresql.auto.conf`):
   ```sql
   ALTER SYSTEM SET myapp.version = '1.0';
   SELECT pg_reload_conf();
   ```
6. Проверьте, что параметр доступен:
   ```sql
   SHOW myapp.version;
   ```
7. Сбросьте:
   ```sql
   ALTER SYSTEM RESET myapp.version;
   SELECT pg_reload_conf();
   ```
8. Выйдите из psql.

**Ожидаемый результат:** пользовательские параметры работают как в сеансе, так и через файл конфигурации.

---

### Задание 8. Изучение категорий параметров и контекста

**Цель:** научиться анализировать категории параметров и их контекст.

#### Техническое задание:
1. Подключитесь к psql:
   ```bash
   docker exec -it pg-config psql -U postgres
   ```
2. Посмотрите список всех категорий параметров:
   ```sql
   SELECT DISTINCT category
   FROM pg_settings
   ORDER BY category;
   ```
3. Для каждой из следующих категорий выведите количество параметров:
   ```sql
   SELECT category, count(*)
   FROM pg_settings
   GROUP BY category
   ORDER BY category;
   ```
4. Посмотрите параметры категории `Connections and Authentication`:
   ```sql
   SELECT name, setting, unit, context
   FROM pg_settings
   WHERE category = 'Connections and Authentication'
   ORDER BY name;
   ```
5. Посмотрите параметры, которые может менять любой пользователь (context = `user`):
   ```sql
   SELECT name, setting, unit, category
   FROM pg_settings
   WHERE context = 'user'
   ORDER BY category, name
   LIMIT 20;
   ```
6. Выйдите из psql.

**Ожидаемый результат:** вы умеете классифицировать параметры по категориям и контексту.

---

### Задание 9. Настройка сервера как в продуктовой среде

**Цель:** рассчитать и установить оптимальные параметры PostgreSQL в соответствии с ресурсами контейнера и рекомендациями для продуктивных систем.

#### Техническое задание:

**Шаг 1. Определите ресурсы контейнера.**
1. Узнайте количество CPU:
   ```bash
   docker exec pg-config nproc
   ```
2. Узнайте объём оперативной памяти (в МБ):
   ```bash
   docker exec pg-config free -m | grep Mem | awk '{print $2}'
   ```
   Запишите полученные значения: `CPU = ____`, `RAM = ____ MB`.

**Шаг 2. Рассчитайте рекомендуемые значения параметров.**
Используйте следующие формулы (для выделенного сервера под OLTP-нагрузку):

| Параметр | Формула |
|----------|---------|
| `shared_buffers` | RAM × 0.25 |
| `effective_cache_size` | RAM × 0.75 |
| `work_mem` | (RAM − shared_buffers) / (16 × CPU) |
| `maintenance_work_mem` | 0.15 × (RAM − shared_buffers) / 3, но не более 1024 МБ |
| `max_connections` | GREATEST(4 × CPU, 100) |
| `random_page_cost` | 1.1 (для SSD) |
| `effective_io_concurrency` | 200 (для SSD) |
| `wal_buffers` | 16 МБ |
| `max_wal_size` | 4 ГБ |
| `min_wal_size` | 1 ГБ |
| `checkpoint_completion_target` | 0.9 |

Выполните расчёты и запишите итоговые значения.

**Шаг 3. Примените параметры через `ALTER SYSTEM`.**
Подключитесь к psql и выполните команды, подставив свои значения:
```sql
ALTER SYSTEM SET shared_buffers = '<значение>MB';
ALTER SYSTEM SET effective_cache_size = '<значение>MB';
ALTER SYSTEM SET work_mem = '<значение>MB';
ALTER SYSTEM SET maintenance_work_mem = '<значение>MB';
ALTER SYSTEM SET max_connections = <значение>;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
```

**Шаг 4. Примените изменения.**
- Для параметров с контекстом `postmaster` (например, `shared_buffers`, `max_connections`) требуется перезапуск:
  ```bash
  docker restart pg-config
  ```
- Остальные параметры можно применить перечитыванием конфигурации:
  ```sql
  SELECT pg_reload_conf();
  ```

**Шаг 5. Проверьте результат.**
Подключитесь к psql и выведите значения установленных параметров:
```sql
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN (
  'shared_buffers', 'effective_cache_size', 'work_mem',
  'maintenance_work_mem', 'max_connections', 'random_page_cost',
  'effective_io_concurrency', 'wal_buffers', 'max_wal_size',
  'min_wal_size', 'checkpoint_completion_target'
)
ORDER BY name;
```
Убедитесь, что `source` равно `configuration file`, а значения соответствуют расчётным.

**Шаг 6. Сравните с рекомендациями pgTune.**
1. Откройте в браузере https://pgtune.leopard.in.ua/ .
2. Укажите:
    - DB Version: 16
    - OS Type: Linux
    - DB Type: Online Transaction Processing System (OLTP)
    - Total Memory (RAM): ваше значение
    - Number of CPUs: ваше значение
    - Number of Connections: ваше значение `max_connections`
    - Data Storage: SSD
3. Нажмите **Generate** и сравните полученные параметры с теми, что вы установили. Запишите различия (если есть) и объясните их причину.

**Ожидаемый результат:** сервер настроен в соответствии с ресурсами и рекомендациями для продуктивной среды; вы умеете рассчитывать и применять ключевые параметры.

---

## 3. Уборка

Остановите и удалите контейнер и данные:

```bash
docker stop pg-config
docker rm pg-config
rm -rf ~/pg_config_lab
```

---
