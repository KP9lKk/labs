# Лабораторная работа №6: `NULL` и особенности работы с ним

## 1. Контекст

Продолжение ЛР №4 (JOIN) и ЛР №5 (агрегаты). База данных Pokémon TCG уже наполнена. В этой работе — только `NULL`: как он ведёт себя в сравнениях, агрегатах, соединениях, `GROUP BY`, `ORDER BY`, `DISTINCT`, и как писать запросы, которые «не теряют» строки из-за `NULL`.

**Тема работы — `NULL`.** Подзапросы, `UPDATE`/`DELETE` — в следующих лабораторных.

---

## 2. Порядок выполнения

1. Убедиться, что база заполнена (ЛР №3, шаги 1–7).
2. Проработать раздел 3 (справка) и раздел 4 (примеры на `TEMP`-таблицах) — обязательно выполнить в DBeaver.
3. Написать `queries.sql` — 8 запросов (раздел 5).
4. Ответить на индивидуальный вопрос (раздел 6).

---

## 3. Справка по `NULL`

### 3.1. Что такое `NULL`

`NULL` — это не `0` и не пустая строка `''`. Это «значение неизвестно / отсутствует». Поэтому:

- `NULL` не равен ничему — даже самому себе.
- Любая арифметика с `NULL` даёт `NULL`.
- Любое сравнение с `NULL` (кроме `IS NULL` / `IS NOT NULL`) даёт `NULL`.

```sql
SELECT NULL = NULL    AS eq,          -- NULL
       NULL <> NULL   AS neq,         -- NULL
       NULL = 5       AS eq_5,        -- NULL
       NULL + 1       AS sum_null,    -- NULL
       NULL || 'x'    AS concat_null, -- NULL (конкатенация строк)
       NULL IS NULL   AS is_null,     -- TRUE
       NULL IS NOT NULL AS is_nn;     -- FALSE
```

| eq | neq | eq_5 | sum_null | concat_null | is_null | is_nn |
|---|---|---|---|---|---|---|
| NULL | NULL | NULL | NULL | NULL | TRUE | FALSE |

### 3.2. Трёхзначная логика

В SQL три значения истинности: `TRUE`, `FALSE`, **`UNKNOWN`**. `NULL` в логических выражениях даёт `UNKNOWN`, а `WHERE` оставляет только `TRUE` (не `UNKNOWN`, не `FALSE`).

| `a` | `b` | `a = b` | `a AND b` | `a OR b` | `NOT a` |
|---|---|---|---|---|---|
| TRUE | TRUE | TRUE | TRUE | TRUE | FALSE |
| TRUE | FALSE | FALSE | FALSE | TRUE | FALSE |
| TRUE | NULL | **NULL** | **NULL** | TRUE | **NULL** |
| FALSE | FALSE | TRUE | FALSE | FALSE | TRUE |
| FALSE | NULL | **NULL** | FALSE | **NULL** | TRUE |
| NULL | NULL | **NULL** | **NULL** | **NULL** | **NULL** |

Главное следствие: **строка с `NULL` в условии отфильтровывается**, если результат = `NULL`. Отсюда «карта была в таблице, но пропала из результата».

### 3.3. Как проверять `NULL`

Только `IS NULL` / `IS NOT NULL`:

```sql
-- Плохо: NULL = NULL → NULL, строка не попадёт
WHERE pokemon_hp = NULL

-- Хорошо:
WHERE pokemon_hp IS NULL
WHERE pokemon_hp IS NOT NULL
```

`COALESCE(a, b, c, ...)` — первое не-`NULL` из списка:

```sql
COALESCE(pokemon_hp, 0)              -- HP или 0
COALESCE(pokemon_stage, '—')         -- стадия или прочерк
COALESCE(a, b, c, 'default')         -- первое не-NULL; если все NULL — 'default'
```

`NULLIF(a, b)` — вернуть `NULL`, если `a = b`. Часто вместе с `COALESCE`:

```sql
NULLIF(link_damage_value, 0)          -- 0 → NULL
COALESCE(NULLIF(link_damage_value, 0), 1)  -- 0 → NULL → 1
```

### 3.4. `NULL` в агрегатах

| Функция | Поведение с `NULL` | На пустом множестве |
|---|---|---|
| `COUNT(*)` | считает **все** строки, включая `NULL` | `0` (если строк нет) |
| `COUNT(col)` | считает **не-NULL** значения | `0` |
| `COUNT(DISTINCT col)` | считает **уникальные не-NULL** | `0` |
| `SUM(col)` | пропускает `NULL` | **`NULL`** (не `0`!) |
| `AVG(col)` | пропускает `NULL` в числителе **и** знаменателе | `NULL` |
| `MIN(col)` / `MAX(col)` | пропускают `NULL` | `NULL` |

Пример:

```sql
-- Таблица t_pokemon: HP = 60, 90, 70, 120, NULL
SELECT COUNT(*)              AS total,       -- 5
       COUNT(pokemon_hp)     AS hp_not_null, -- 4
       SUM(pokemon_hp)       AS total_hp,    -- 340
       AVG(pokemon_hp)       AS avg_hp,      -- 85.0 (делён на 4, не на 5!)
       COALESCE(SUM(pokemon_hp), 0) AS safe_sum  -- 340
FROM t_pokemon;
```

**Важно**: `AVG` делит на число не-`NULL` значений, а не на общее число строк. Это правильно статистически, но может удивить.

### 3.5. `NULL` в `JOIN`

- `INNER JOIN`: строка с `NULL` в ключе соединения **не соединится ни с чем** — `NULL = что-угодно` = `NULL`.
- `LEFT JOIN`: строка останется, но правая часть будет `NULL`.
- `FULL OUTER JOIN`: то же самое для обеих сторон.

```sql
-- evolves_from = NULL (базовые формы) не присоединятся к card_name (даже NULL)
SELECT a.pokemon_card_id, a.evolves_from, b.card_name AS parent
FROM pokemon_card a
LEFT JOIN pokemon_card b ON a.pokemon_evolves_from = b.card_name;
```

### 3.6. Ошибка: фильтр в `WHERE` после `LEFT JOIN`

```sql
-- Плохо: NULL > 50 = NULL = «не TRUE» → строки выброшены
SELECT c.card_name, pc.pokemon_hp
FROM card c
LEFT JOIN pokemon_card pc ON pc.pokemon_card_id = c.card_id
WHERE pc.pokemon_hp > 50;
```

Фактически получился `INNER JOIN`.

**Правило безопасного `LEFT JOIN`:**

> Фильтр по **правой** таблице, если нужно сохранить все строки левой, — в `ON`. Фильтр по **левой** — можно в `WHERE`.

```sql
-- Хорошо: все карты в результате; у кого нет HP > 50 — pokemon_hp = NULL
SELECT c.card_name, pc.pokemon_hp
FROM card c
LEFT JOIN pokemon_card pc
       ON pc.pokemon_card_id = c.card_id
      AND pc.pokemon_hp > 50;
```

### 3.7. NULL-safe сравнение

Если нужно сравнить две «возможно-NULL» колонки так, чтобы `NULL` считался значением:

**NULL-safe равенство** (`a` совпадает с `b`, даже если оба `NULL`):

```sql
WHERE ( a =  b )
   OR ( a IS NULL AND b IS NULL )
```

**NULL-safe неравенство** (`a` различается с `b`, даже если одно из них `NULL`):

```sql
WHERE ( a <> b )
   OR ( a IS NULL     AND b IS NOT NULL )
   OR ( a IS NOT NULL AND b IS NULL     )
```

В `JOIN ... ON` — то же самое, только условие переносится в `ON`.

**Таблица истинности** (NULL-safe равенство):

| `a` | `b` | `a = b` | `a IS NULL AND b IS NULL` | Итог |
|---|---|---|---|---|
| NULL | NULL | NULL | TRUE | TRUE |
| NULL | 5 | NULL | FALSE | NULL → «не проходит» |
| 5 | NULL | NULL | FALSE | NULL → «не проходит» |
| 5 | 5 | TRUE | FALSE | TRUE |
| 5 | 6 | FALSE | FALSE | FALSE |

> Примечание. В случаях «NULL vs значение» результат — `NULL`, а не `FALSE`. В `WHERE` / `ON` это эквивалентно `FALSE`. Но если выражение попадает в `SELECT` и нужен строго `FALSE`, оберните в `COALESCE(..., FALSE)`.

### 3.8. `NOT IN` и `NULL`

`NOT IN` с `NULL` в подзапросе возвращает **пустой результат**. Почему: `x NOT IN (1, 2, NULL)` разворачивается в `x <> 1 AND x <> 2 AND x <> NULL` = `... AND NULL` = `NULL` для любой строки.

```sql
-- Плохо: может вернуть 0 строк, если в подзапросе есть NULL
SELECT c.card_name FROM card c
WHERE c.card_id NOT IN (SELECT pokemon_card_id FROM pokemon_card);

-- Хорошо: всегда корректно
SELECT c.card_name FROM card c
WHERE NOT EXISTS (
    SELECT 1 FROM pokemon_card pc WHERE pc.pokemon_card_id = c.card_id
);
```

### 3.9. `NULL` в `GROUP BY`

`NULL` в колонке группировки — это **отдельная группа**, со всеми `NULL` вместе:

```sql
SELECT pokemon_stage, COUNT(*)
FROM pokemon_card
GROUP BY pokemon_stage;
```

Если 3 покемона с `pokemon_stage IS NULL` — в результате будет строка с `pokemon_stage = NULL` и `COUNT = 3`. `GROUP BY` **не** пропускает `NULL`, в отличие от агрегатов над колонками.

### 3.10. `NULL` в `DISTINCT`

`DISTINCT` **считает все `NULL` равными друг другу** — в результате будет одна строка `NULL`, а не несколько:

```sql
SELECT DISTINCT pokemon_stage FROM pokemon_card;
-- если 3 строки с pokemon_stage = NULL, в результате всё равно 1 NULL
```

Это единственное место в SQL, где `NULL = NULL` неявно трактуется как «совпадает».

### 3.11. `NULL` в `ORDER BY`

По умолчанию в PostgreSQL:

- `ORDER BY col ASC` — `NULL` **в конце** (`NULLS LAST`).
- `ORDER BY col DESC` — `NULL` **в начале** (`NULLS FIRST`).

Можно управлять явно:

```sql
ORDER BY pokemon_hp ASC  NULLS FIRST    -- NULL в начале
ORDER BY pokemon_hp DESC NULLS LAST     -- NULL в конце
```

### 3.12. `NULL` в ограничениях

- `PRIMARY KEY` **не может** быть `NULL` — всегда `NOT NULL`.
- `UNIQUE` **разрешает** несколько `NULL` (как будто они все разные). Это часто удивляет.
- `NOT NULL` — явное ограничение; проверяйте, где оно есть в схеме.

### 3.13. Мини-шпаргалка

| Хочу | Пиши |
|---|---|
| проверить отсутствие значения | `col IS NULL` |
| проверить наличие значения | `col IS NOT NULL` |
| заменить `NULL` дефолтом | `COALESCE(col, default)` |
| превратить `0` в `NULL` | `NULLIF(col, 0)` |
| сумма без `NULL` на пустом множестве | `COALESCE(SUM(col), 0)` |
| сохранить все строки левой + фильтр по правой | фильтр в `ON` |
| исключить значения из списка безопасно | `NOT EXISTS (...)` вместо `NOT IN` |
| сравнить два «возможно-NULL» значения | `(a = b) OR (a IS NULL AND b IS NULL)` |
| `NULL` в конце сортировки | `ORDER BY col ASC NULLS LAST` |
| `NULL` в начале сортировки | `ORDER BY col DESC NULLS FIRST` |

---

## 4. Примеры на `TEMP`-таблицах

```sql
CREATE TEMP TABLE t_card (
    card_id   INTEGER PRIMARY KEY,
    card_name TEXT,
    card_type TEXT
);
INSERT INTO t_card VALUES
    (1, 'Pikachu',       'Pokemon'),
    (2, 'Raichu',        'Pokemon'),
    (3, 'Korrina',       'Trainer'),
    (4, 'Strong Energy', 'Energy'),
    (5, 'Froakie',       'Pokemon'),
    (6, NULL,            'Pokemon');     -- «безымянная» карта

CREATE TEMP TABLE t_pokemon (
    pokemon_card_id INTEGER PRIMARY KEY,
    pokemon_hp      INTEGER,
    pokemon_stage   TEXT,
    evolves_from    TEXT                 -- NULL = базовая форма
);
INSERT INTO t_pokemon VALUES
    (1,  60,  'Basic',   NULL),
    (2,  90,  'Stage 1', 'Pikachu'),
    (5,  70,  'Basic',   NULL),
    (6, 120,  'Basic',   NULL),
    (7,  50,  'Basic',   NULL);
```

### 4.1. Маленькие тесты на `NULL`

```sql
SELECT NULL = NULL           AS "eq",
       NULL <> 5             AS "neq",
       NULL IS NULL          AS "is_null",
       NULL IS NOT NULL      AS "is_not_null",
       NULL + 1              AS "sum_null",
       NULL || 'x'           AS "concat_null";
```

| eq | neq | is_null | is_not_null | sum_null | concat_null |
|---|---|---|---|---|---|
| NULL | NULL | TRUE | FALSE | NULL | NULL |

### 4.2. `NULL` в `WHERE`

```sql
SELECT * FROM t_pokemon WHERE pokemon_hp = NULL;      -- 0 строк
SELECT * FROM t_pokemon WHERE pokemon_hp IS NULL;     -- 1 строка (card_id=6? нет, у 6 hp=120 → 0)
SELECT * FROM t_pokemon WHERE pokemon_hp > 50;        -- 3 строки (1, 2, 5, 6 — все с hp > 50)
SELECT * FROM t_pokemon WHERE pokemon_hp <= 50;       -- 1 строка (7: hp=50)
SELECT * FROM t_pokemon WHERE NOT (pokemon_hp > 50);  -- 1 строка (7)
```

### 4.3. `COALESCE` и `NULLIF`

```sql
SELECT pokemon_card_id,
       pokemon_hp,
       COALESCE(pokemon_hp, 0)                    AS hp_or_zero,
       COALESCE(pokemon_stage, '—')               AS stage_or_dash,
       COALESCE(NULLIF(pokemon_hp, 0), 1)         AS hp_or_one
FROM t_pokemon
ORDER BY pokemon_card_id;
```

| pokemon_card_id | pokemon_hp | hp_or_zero | stage_or_dash | hp_or_one |
|---:|---:|---:|---|---:|
| 1 | 60 | 60 | Basic | 60 |
| 2 | 90 | 90 | Stage 1 | 90 |
| 5 | 70 | 70 | Basic | 70 |
| 6 | 120 | 120 | Basic | 120 |
| 7 | 50 | 50 | Basic | 50 |

### 4.4. `NULL` в агрегатах

```sql
SELECT COUNT(*)              AS total,       -- 5
       COUNT(pokemon_hp)     AS hp_not_null, -- 5 (все hp заполнены)
       SUM(pokemon_hp)       AS total_hp,    -- 390
       AVG(pokemon_hp)       AS avg_hp,      -- 78.00
       MIN(pokemon_hp)       AS min_hp,      -- 50
       MAX(pokemon_hp)       AS max_hp       -- 120
FROM t_pokemon;
```

В нашей `t_pokemon` нет `NULL` в `pokemon_hp` — специально, чтобы вы видели: **агрегаты над полностью заполненной колонкой ведут себя обычно**. Добавим `NULL`:

```sql
INSERT INTO t_pokemon VALUES (8, NULL, 'Basic', NULL);
```

Тогда:

| total | hp_not_null | total_hp | avg_hp | min_hp | max_hp |
|---:|---:|---:|---:|---:|---:|
| 6 | 5 | 390 | 78.00 | 50 | 120 |

`COUNT(*)` = 6 (включая строку 8), `COUNT(pokemon_hp)` = 5 (без строки 8), `AVG` делит на 5, а не на 6.

**Пустое множество**:

```sql
-- Все строки с pokemon_hp = NULL
SELECT COUNT(*)         AS cnt,          -- 1 (строка 8)
       COUNT(pokemon_hp) AS cnt_hp,      -- 0
       SUM(pokemon_hp)   AS sum_hp,      -- NULL (не 0!)
       COALESCE(SUM(pokemon_hp), 0) AS safe_sum -- 0
FROM t_pokemon
WHERE pokemon_hp IS NULL;
```

### 4.5. `NULL` в `JOIN`

```sql
-- evolves_from = NULL (базовые формы) не присоединятся — обычное равенство
SELECT a.pokemon_card_id, a.evolves_from, b.card_name AS parent
FROM t_pokemon a
LEFT JOIN t_card b ON a.evolves_from = b.card_name
ORDER BY a.pokemon_card_id;
```

| pokemon_card_id | evolves_from | parent |
|---:|---|---|
| 1 | NULL | NULL |
| 2 | Pikachu | Pikachu |
| 5 | NULL | NULL |
| 6 | NULL | NULL |
| 7 | NULL | NULL |
| 8 | NULL | NULL |

**NULL-safe**:

```sql
SELECT a.pokemon_card_id, a.evolves_from, b.card_id AS parent_id
FROM t_pokemon a
LEFT JOIN t_card b
       ON ( a.evolves_from = b.card_name )
       OR ( a.evolves_from IS NULL AND b.card_name IS NULL )
ORDER BY a.pokemon_card_id;
```

Теперь базовые формы находят «безымянную» карту `card_id = 6`:

| pokemon_card_id | evolves_from | parent_id |
|---:|---|---:|
| 1 | NULL | 6 |
| 2 | Pikachu | 1 |
| 5 | NULL | 6 |
| 6 | NULL | 6 |
| 7 | NULL | 6 |
| 8 | NULL | 6 |

### 4.6. `NULL` в `GROUP BY`

```sql
SELECT pokemon_stage, COUNT(*) AS cnt
FROM t_pokemon
GROUP BY pokemon_stage
ORDER BY pokemon_stage;
```

| pokemon_stage | cnt |
|---|---:|
| Basic | 5 |
| Stage 1 | 1 |

Добавим в `t_pokemon` строку с `NULL` в `pokemon_stage`:

```sql
INSERT INTO t_pokemon VALUES (9, 100, NULL, NULL);
```

Тогда:

| pokemon_stage | cnt |
|---|---:|
| NULL | **1** |
| Basic | 5 |
| Stage 1 | 1 |

`NULL` — отдельная группа, не пропал.

### 4.7. `NULL` в `DISTINCT`

```sql
INSERT INTO t_pokemon VALUES (10, 40, NULL, NULL);

SELECT DISTINCT pokemon_stage FROM t_pokemon ORDER BY pokemon_stage;
```

| pokemon_stage |
|---|
| NULL |
| Basic |
| Stage 1 |

Две строки с `NULL` (9, 10) в `DISTINCT` — **одна** `NULL`. Это единственное исключение: `DISTINCT` считает все `NULL` равными.

### 4.8. `NULL` в `ORDER BY`

```sql
SELECT pokemon_card_id, pokemon_hp
FROM t_pokemon
ORDER BY pokemon_hp ASC;   -- NULL в конце
```

| pokemon_card_id | pokemon_hp |
|---:|---:|
| 7 | 50 |
| 1 | 60 |
| 5 | 70 |
| 2 | 90 |
| 9 | 100 |
| 6 | 120 |
| 8 | NULL |

```sql
SELECT pokemon_card_id, pokemon_hp
FROM t_pokemon
ORDER BY pokemon_hp ASC NULLS FIRST;   -- NULL в начале
```

| pokemon_card_id | pokemon_hp |
|---:|---:|
| 8 | NULL |
| 7 | 50 |
| 1 | 60 |
| ... | ... |

### 4.9. `NOT IN` vs `NOT EXISTS`

```sql
-- Плохо: если в подзапросе есть NULL, NOT IN вернёт 0 строк
SELECT c.card_id, c.card_name
FROM t_card c
WHERE c.card_id NOT IN (SELECT pokemon_card_id FROM t_pokemon);
-- 3, 4 — их нет в t_pokemon

-- Хорошо: NOT EXISTS
SELECT c.card_id, c.card_name
FROM t_card c
WHERE NOT EXISTS (
    SELECT 1 FROM t_pokemon pc WHERE pc.pokemon_card_id = c.card_id
);
-- тот же результат — 3, 4
```

В нашей `t_pokemon` `pokemon_card_id` — `PRIMARY KEY`, `NULL` не бывает. Но правило важно: **если в подзапросе может быть `NULL`, `NOT IN` опасен**.

### 4.10. Уборка

```sql
DROP TABLE IF EXISTS t_pokemon, t_card;
```

---

## 5. Задание: 8 запросов (сохранить в `queries.sql`)

Каждый запрос — с комментарием `-- Запрос N` и кратким пояснением (1 строка).

**Запрос 1 — `IS NULL` / `IS NOT NULL`.**
Вывести `card_name`, `pokemon_hp` всех покемонов, у которых `pokemon_hp IS NULL`. Отсортировать по `card_name`.
_В комментарии: что вернёт `WHERE pokemon_hp = NULL` и почему._

**Запрос 2 — `COALESCE` и `NULLIF`.**
Вывести `card_name`, `pokemon_hp`, `pokemon_stage`. Вместо `NULL` в `pokemon_hp` — `0`, в `pokemon_stage` — `'Unknown'`. Плюс колонка `hp_or_one` через `COALESCE(NULLIF(pokemon_hp, 0), 1)`. Сортировка по `card_name`.

**Запрос 3 — `NULL` в агрегатах.**
Для всех покемонов вывести `COUNT(*)`, `COUNT(pokemon_hp)`, `SUM(pokemon_hp)`, `COALESCE(SUM(pokemon_hp), 0)`, `ROUND(AVG(pokemon_hp), 2)`.
_В комментарии: почему `COUNT(*)` и `COUNT(pokemon_hp)` могут различаться; почему `SUM` может вернуть `NULL`._

**Запрос 4 — пустое множество.**
Вывести агрегаты по покемонам, у которых `pokemon_hp IS NULL` (если таких нет — результат должен показать разницу между `COUNT(*)`, `SUM` и `COALESCE(SUM, 0)`).
_В комментарии: что вернёт `COUNT(*)` и `SUM` на пустом множестве — и почему._

**Запрос 5 — `LEFT JOIN` + фильтр в `WHERE` (ошибка).**
Вывести `card_name`, `card_type`, `pokemon_hp` для всех карт с фильтром `WHERE pc.pokemon_hp > 80`. Запустить, посмотреть результат.
_В комментарии: почему часть карт «пропала» и что нужно изменить._

**Запрос 6 — `LEFT JOIN` + фильтр в `ON` (исправление).**
То же самое, но фильтр в `ON`:
```sql
LEFT JOIN pokemon_card pc
       ON pc.pokemon_card_id = c.card_id
      AND pc.pokemon_hp > 80
```
Сравнить число строк с Запросом 5 и с `SELECT COUNT(*) FROM card`. Объяснить в комментарии.

**Запрос 7 — NULL-safe сравнение через `OR` + `IS NULL`.**
Вывести `set_name`, `set_logo_url`, `set_symbol_url` из `card_set`, где `set_logo_url` совпадает с `set_symbol_url` по NULL-safe правилу:
```sql
WHERE ( set_logo_url =  set_symbol_url )
   OR ( set_logo_url IS NULL AND set_symbol_url IS NULL )
```
В комментарии — что даёт обычное `WHERE set_logo_url = set_symbol_url` (0 строк) и почему числа различаются.

**Запрос 8 — `NOT IN` vs `NOT EXISTS`.**
Написать два запроса, которые ищут карты без дочерней записи в `pokemon_card`:
- вариант А — через `NOT IN`;
- вариант Б — через `NOT EXISTS`.
Запустить оба, сравнить результаты.
_В комментарии: когда результаты совпадают и когда `NOT IN` «ломается»._

---

## 6. Индивидуальный вопрос (1 вариант на студента)

1. Чем `NULL` отличается от `0` и `''`? Почему `NULL = NULL` не даёт `TRUE`?
2. Почему `WHERE pokemon_hp = NULL` возвращает 0 строк? Как правильно проверить отсутствие значения?
3. Что такое «трёхзначная логика» и как `UNKNOWN` влияет на `WHERE`?
4. Почему `COUNT(*)` и `COUNT(col)` могут давать разные числа? Приведи пример.
5. Почему `SUM(col)` при всех `NULL` даёт `NULL`, а `COUNT(col)` — `0`? Как получить `0` для суммы?
6. Почему `AVG(col)` пропускает `NULL` и в числителе, и в знаменателе? К чему это приводит?
7. Зачем нужен `COALESCE`? Приведи 2 примера, где без него результат «неудобный».
8. Зачем нужен `NULLIF`? Приведи пример, где `NULLIF` + `COALESCE` дают нужный результат.
9. Почему после `LEFT JOIN` фильтр по правой таблице в `WHERE` «съедает» часть строк? Как исправить?
10. Почему `NULL` в `JOIN`-ключе не соединяется? Как это исправить (NULL-safe)?
11. Почему `GROUP BY` не пропускает `NULL` (в отличие от агрегатов над колонками)?
12. Почему `DISTINCT` считает все `NULL` равными друг другу, хотя `NULL = NULL` даёт `NULL`?
13. Как `ORDER BY` сортирует `NULL` по умолчанию в PostgreSQL? Как это изменить (`NULLS FIRST` / `NULLS LAST`)?
14. Почему `NOT IN` с `NULL` в подзапросе возвращает пустой результат? Замени на `NOT EXISTS` и покажи, что стало корректно.
15. Чем `(a = b)` отличается от `(a = b) OR (a IS NULL AND b IS NULL)`? Приведи пример из `t_card` / `t_pokemon`.
16. Почему `(a = b) OR (a IS NULL AND b IS NULL)` в `SELECT`-выражении может вернуть `NULL`, а не `FALSE`? Как получить строго `FALSE`?
17. Может ли `PRIMARY KEY` быть `NULL`? А `UNIQUE`? Сколько `NULL` разрешает `UNIQUE`?
18. Замени в Запросе 5 обычный `LEFT JOIN` на NULL-safe вариант — изменилось ли число строк? Почему? Запусти оба варианта и сравни.
