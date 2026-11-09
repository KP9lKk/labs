# Лабораторная работа №5: Агрегация данных (`GROUP BY`, `HAVING`, агрегатные функции)

## 1. Контекст

Продолжение ЛР №4. База данных Pokémon TCG уже наполнена, `JOIN`-ы освоены. В этой работе — только агрегация: как считать «сколько», «сколько в среднем», «сколько всего» с группировкой по категориям.

**Тема работы — только агрегаты.** Подробная работа с `NULL` (NULL-safe сравнение, `COALESCE`, `NOT IN` vs `NOT EXISTS`) — в следующей лабораторной. Здесь мы лишь отметим базовые факты о `NULL` в агрегатах, без углубления.

---

## 2. Порядок выполнения

1. Убедиться, что база заполнена (ЛР №3, шаги 1–7).
2. Проработать раздел 3 (справка) и раздел 4 (примеры на `TEMP`-таблицах) — обязательно выполнить в DBeaver.
3. Написать `queries.sql` — 7 запросов (раздел 5).
4. Ответить на индивидуальный вопрос (раздел 6).

---

## 3. Справка по агрегатам

### 3.1. Зачем нужны агрегаты

`JOIN` даёт «одна строка = одна карта с атакой», «одна строка = одна карта с HP». Но часто нужен ответ вида «сколько карт в каждом наборе», «средний HP по стадиям», «сколько всего атак у каждой карты». Для этого нужны агрегатные функции и группировка.

### 3.2. Пять агрегатных функций

| Функция | Что делает | Возвращает на пустом множестве |
|---|---|---|
| `COUNT(*)` | число **строк** | `0` |
| `COUNT(col)` | число **не-NULL** значений в колонке | `0` |
| `COUNT(DISTINCT col)` | число **уникальных** не-NULL значений | `0` |
| `SUM(col)` | сумма | `NULL` (не `0`!) |
| `AVG(col)` | среднее | `NULL` |
| `MIN(col)` / `MAX(col)` | минимум / максимум | `NULL` |

**Про `NULL` (кратко, подробно — в следующей лабе):**

- `COUNT(*)` считает все строки; `COUNT(col)` — только строки, где `col IS NOT NULL`. Поэтому числа могут различаться.
- `SUM(col)` по пустому множеству возвращает `NULL`, а не `0`. Если нужен `0` — обернуть в `COALESCE(SUM(col), 0)` (детали — в ЛР №6).

### 3.3. Синтаксис `GROUP BY`

```sql
SELECT колонка_группировки,
       агрегатная_функция(другая_колонка) AS alias
FROM таблица
WHERE условие_до_группировки
GROUP BY колонка_группировки
HAVING условие_после_группировки
ORDER BY alias ASC|DESC;
```

Порядок важен: **`SELECT` → `FROM` → `JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `ORDER BY` → `LIMIT`**.

**Правило**: все колонки в `SELECT`, которые не обёрнуты в агрегатную функцию, должны быть перечислены в `GROUP BY`. Иначе — ошибка.

```sql
-- Правильно
SELECT card_type, COUNT(*) AS cnt
FROM card
GROUP BY card_type;

-- Ошибка: card_name не в GROUP BY и не в агрегате
SELECT card_type, card_name, COUNT(*)
FROM card
GROUP BY card_type;
```

### 3.4. `WHERE` vs `HAVING`

- `WHERE` фильтрует **строки** до группировки — работает с колонками таблиц.
- `HAVING` фильтрует **группы** после агрегации — работает с результатами агрегатов.

```sql
-- Плохо: агрегат в WHERE — синтаксическая ошибка
SELECT pokemon_stage, AVG(pokemon_hp) FROM pokemon_card
WHERE AVG(pokemon_hp) > 80 GROUP BY pokemon_stage;

-- Хорошо: фильтр по агрегату — в HAVING
SELECT pokemon_stage, AVG(pokemon_hp) FROM pokemon_card
GROUP BY pokemon_stage
HAVING AVG(pokemon_hp) > 80;
```

`WHERE` и `HAVING` можно комбинировать:

```sql
SELECT pokemon_stage, AVG(pokemon_hp) AS avg_hp
FROM pokemon_card
WHERE pokemon_stage IS NOT NULL         -- фильтр строк
GROUP BY pokemon_stage
HAVING AVG(pokemon_hp) > 80             -- фильтр групп
ORDER BY avg_hp DESC;
```

### 3.5. Несколько колонок в `GROUP BY`

Можно группировать по нескольким колонкам — тогда группы получаются по комбинациям значений:

```sql
SELECT card_type, card_rarity, COUNT(*) AS cnt
FROM card
GROUP BY card_type, card_rarity
ORDER BY card_type, card_rarity;
```

### 3.6. `COUNT(DISTINCT ...)`

Считает уникальные значения, а не строки:

```sql
-- Сколько разных стадий покемонов в базе
SELECT COUNT(DISTINCT pokemon_stage) AS stage_kinds
FROM pokemon_card;
```

### 3.7. `ROUND` для `AVG`

`AVG(integer)` возвращает `numeric`, поэтому для красоты результата часто используют `ROUND`:

```sql
ROUND(AVG(pokemon_hp), 1)   -- 1 знак после запятой
ROUND(AVG(pokemon_hp), 0)   -- целое
```

### 3.8. Агрегаты + `JOIN`

Типичный паттерн — «посчитать дочерние строки для каждой родительской»:

```sql
-- Сколько атак у каждой карты
SELECT c.card_name, COUNT(pal.link_id) AS attacks_count
FROM card c
JOIN pokemon_attack_link pal ON pal.link_pokemon_card_id = c.card_id
GROUP BY c.card_name
ORDER BY attacks_count DESC;
```

`INNER JOIN` + `GROUP BY` покажет только карты **с атаками** — карты без атак в результат не попадут (у них нет совпадений в правой таблице).

`LEFT JOIN` + `GROUP BY` покажет **все** карты, а у карт без атак `COUNT(...)` даст `0`:

```sql
-- Все карты, у кого нет атак — attacks_count = 0
SELECT c.card_name, COUNT(pal.link_id) AS attacks_count
FROM card c
LEFT JOIN pokemon_attack_link pal ON pal.link_pokemon_card_id = c.card_id
GROUP BY c.card_name
ORDER BY attacks_count ASC, c.card_name;
```

> Разница между `INNER` и `LEFT` здесь — ключевая: `LEFT` показывает «нулевые» категории, `INNER` — только непустые.

### 3.9. Типичные ошибки

| Ошибка | Что происходит | Как избежать |
|---|---|---|
| Колонка в `SELECT`, но не в `GROUP BY` и не в агрегате | Синтаксическая ошибка | Все неагрегированные колонки — в `GROUP BY` |
| Агрегат в `WHERE` | Синтаксическая ошибка | Агрегаты — только в `HAVING` |
| `SUM(col)` на пустом множестве | `NULL`, а не `0` | `COALESCE(SUM(col), 0)` |
| `COUNT(*)` вместо `COUNT(col)` в `LEFT JOIN` | Считает «пустые» строки как 1 | Использовать `COUNT(правая_col)` |
| `INNER JOIN` + `GROUP BY` | Пропадают «нулевые» категории | `LEFT JOIN`, если нужны нули |

### 3.10. Мини-шпаргалка

| Хочу | Пиши |
|---|---|
| число строк в группе | `COUNT(*)` |
| число не-NULL значений в группе | `COUNT(col)` |
| число уникальных значений | `COUNT(DISTINCT col)` |
| сумма | `SUM(col)` |
| среднее с округлением | `ROUND(AVG(col), 1)` |
| минимум / максимум | `MIN(col)` / `MAX(col)` |
| фильтр по строкам | `WHERE ...` |
| фильтр по группам | `HAVING ...` |
| «нули» для пустых категорий | `LEFT JOIN` + `GROUP BY` |

---

## 4. Примеры на `TEMP`-таблицах

Создадим временные таблицы (`TEMP` исчезнут после отключения сессии). Они маленькие — на них удобно увидеть, как ведут себя агрегаты.

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
    (5, 'Froakie',       'Pokemon');

CREATE TEMP TABLE t_pokemon (
    pokemon_card_id INTEGER PRIMARY KEY,
    pokemon_hp      INTEGER,
    pokemon_stage   TEXT
);
INSERT INTO t_pokemon VALUES
    (1,  60, 'Basic'),
    (2,  90, 'Stage 1'),
    (5,  70, 'Basic');

CREATE TEMP TABLE t_attack (
    link_id         INTEGER PRIMARY KEY,
    link_card_id    INTEGER,             -- ссылка на t_card.card_id
    link_damage     INTEGER
);
INSERT INTO t_attack VALUES
    (1, 1, 20),   -- Pikachu
    (2, 1, 40),   -- Pikachu
    (3, 2, 60);   -- Raichu
    -- у Korrina, Strong Energy, Froakie атак нет
```

| `t_card` | | |  | `t_pokemon` | | |  | `t_attack` | | |
|---:|---|---|---|---:|---:|---|---|---:|---:|---:|
| 1 | Pikachu | Pokemon |  | 1 | 60 | Basic |  | 1 | 1 | 20 |
| 2 | Raichu | Pokemon |  | 2 | 90 | Stage 1 |  | 2 | 1 | 40 |
| 3 | Korrina | Trainer |  | 5 | 70 | Basic |  | 3 | 2 | 60 |
| 4 | Strong Energy | Energy |  |  |  |  |  |  |  |  |
| 5 | Froakie | Pokemon |  |  |  |  |  |  |  |  |

### 4.1. `COUNT` + `GROUP BY` — карт по типам

```sql
SELECT card_type, COUNT(*) AS cnt
FROM t_card
GROUP BY card_type
ORDER BY cnt DESC, card_type;
```

| card_type | cnt |
|---|---:|
| Pokemon | 3 |
| Energy | 1 |
| Trainer | 1 |

### 4.2. `COUNT` + `HAVING` — типы, которых больше одной карты

```sql
SELECT card_type, COUNT(*) AS cnt
FROM t_card
GROUP BY card_type
HAVING COUNT(*) > 1;
```

| card_type | cnt |
|---|---:|
| Pokemon | 3 |

### 4.3. `AVG` / `MIN` / `MAX` + `GROUP BY` — HP по стадиям

```sql
SELECT pokemon_stage,
       COUNT(*)                  AS n,
       ROUND(AVG(pokemon_hp), 1) AS avg_hp,
       MIN(pokemon_hp)           AS min_hp,
       MAX(pokemon_hp)           AS max_hp
FROM t_pokemon
GROUP BY pokemon_stage
ORDER BY avg_hp DESC;
```

| pokemon_stage | n | avg_hp | min_hp | max_hp |
|---|---:|---:|---:|---:|
| Stage 1 | 1 | 90.0 | 90 | 90 |
| Basic | 2 | 65.0 | 60 | 70 |

### 4.4. `SUM` + `GROUP BY` — суммарный урон по картам

```sql
SELECT link_card_id,
       COUNT(*)        AS attacks_count,
       SUM(link_damage) AS total_damage
FROM t_attack
GROUP BY link_card_id
ORDER BY total_damage DESC;
```

| link_card_id | attacks_count | total_damage |
|---:|---:|---:|
| 2 | 1 | 60 |
| 1 | 2 | 60 |

У карт `3`/`4`/`5` атак нет — их нет в результате (нет строк в `t_attack`).

### 4.5. `INNER JOIN` + `GROUP BY` — только карты с атаками

```sql
SELECT c.card_name, COUNT(a.link_id) AS attacks_count
FROM t_card c
JOIN t_attack a ON a.link_card_id = c.card_id
GROUP BY c.card_name
ORDER BY attacks_count DESC, c.card_name;
```

| card_name | attacks_count |
|---|---:|
| Pikachu | 2 |
| Raichu | 1 |

Карт `Korrina`, `Strong Energy`, `Froakie` нет — у них не было совпадений.

### 4.6. `LEFT JOIN` + `GROUP BY` — все карты, у «пустых» — 0

```sql
SELECT c.card_name, COUNT(a.link_id) AS attacks_count
FROM t_card c
LEFT JOIN t_attack a ON a.link_card_id = c.card_id
GROUP BY c.card_name
ORDER BY attacks_count DESC, c.card_name;
```

| card_name | attacks_count |
|---|---:|
| Pikachu | 2 |
| Raichu | 1 |
| Froakie | 0 |
| Korrina | 0 |
| Strong Energy | 0 |

Все 5 карт на месте. `COUNT(a.link_id)` для карт без атак даёт `0` — потому что `link_id` = `NULL`, а `COUNT(col)` не считает `NULL`.

Сравнение: `COUNT(*)` дал бы для всех 1 (одна «пустая» строка на карту), а `COUNT(a.link_id)` — правильно `0`. Это важное правило для `LEFT JOIN` + `GROUP BY`.

### 4.7. `COUNT(DISTINCT ...)` — уникальные значения

```sql
SELECT COUNT(DISTINCT pokemon_stage) AS stage_kinds
FROM t_pokemon;
```

| stage_kinds |
|---:|
| 2 |

### 4.8. Уборка

```sql
DROP TABLE IF EXISTS t_attack, t_pokemon, t_card;
```

---

## 5. Задание: 7 запросов (сохранить в `queries.sql`)

Каждый запрос — с комментарием `-- Запрос N` и кратким пояснением (1 строка).

**Запрос 1 — `COUNT` + `GROUP BY` + `ORDER BY`.**
Для каждого набора из `card_set` вывести `set_name` и число карт в нём (наборы без карт — с `0`). Использовать `LEFT JOIN` и `COALESCE`. Отсортировать по числу карт по убыванию, затем по имени.

**Запрос 2 — `AVG` / `MIN` / `MAX` + `GROUP BY` + `HAVING`.**
Для каждой стадии (`pokemon_stage`) вывести `pokemon_stage`, `COUNT(*)`, `ROUND(AVG(pokemon_hp), 1)`, `MIN(pokemon_hp)`, `MAX(pokemon_hp)`. Оставить только стадии, где **больше 1** покемона. Отсортировать по `avg_hp` по убыванию.
_В комментарии: почему строк с `pokemon_stage IS NULL` может не оказаться в результате (при `GROUP BY`)._

**Запрос 3 — `COUNT` + `HAVING`.**
Вывести `card_name` и `attacks_count` для карт, у которых **больше одной** атаки. Отсортировать по числу атак по убыванию, затем по имени.

**Запрос 4 — `COUNT(DISTINCT ...)`.**
Вывести `COUNT(DISTINCT card_rarity) AS rarity_kinds` и `COUNT(DISTINCT card_type) AS type_kinds` для всех карт. В комментарии — что вернёт запрос и почему важно `DISTINCT` (иначе — число карт, а не видов).

**Запрос 5 — `SUM` + `GROUP BY`.**
Для каждой карты с атаками вывести `card_name`, `attacks_count`, `total_damage` = суммарный урон атак (из `link_damage_value`). Отсортировать по `total_damage` по убыванию, затем по `card_name`.

**Запрос 6 — `SUM` + `LEFT JOIN` + `GROUP BY`.**
Для каждого типа энергии (`energy_type`) вывести `energy_type_name`, `attack_uses` = число атак, где этот тип используется, и `total_cards_used = COALESCE(SUM(cost_quantity), 0)`. Использовать `LEFT JOIN`. Отсортировать по `total_cards_used` по убыванию, затем по имени.
_В комментарии: почему `LEFT JOIN`, а не `INNER JOIN` — что даст каждый вариант._

**Запрос 7 — два варианта «COUNT vs SUM на `LEFT JOIN`».**
Один и тот же `LEFT JOIN` карт с атаками, но:
- вариант А: `COUNT(*)` в `SELECT`;
- вариант Б: `COUNT(pal.link_id)` в `SELECT`.

Запустить оба и в комментарии объяснить, почему для карт без атак вариант А даёт `1`, а вариант Б — `0`.

---

## 6. Индивидуальный вопрос (1 вариант на студента)

1. Чем `COUNT(*)` отличается от `COUNT(col)`? Приведи пример, где результаты различаются.
2. Чем `COUNT(col)` отличается от `COUNT(DISTINCT col)`? Приведи пример.
3. Зачем нужен `GROUP BY`? Что произойдёт, если его пропустить, но использовать `COUNT(*)`?
4. Почему все колонки в `SELECT`, не обёрнутые в агрегат, должны быть в `GROUP BY`?
5. Чем `WHERE` отличается от `HAVING`? Приведи пример, где результат будет разным.
6. Почему `SUM(col)` на пустом множестве даёт `NULL`, а `COUNT(col)` — `0`? Как получить `0` для суммы?
7. Что делает `ROUND(AVG(col), 1)`? Зачем `ROUND` для `AVG`?
8. Почему `INNER JOIN` + `GROUP BY` и `LEFT JOIN` + `GROUP BY` дают разное число строк? Приведи пример.
9. Почему `COUNT(*)` в `LEFT JOIN` + `GROUP BY` даёт для карт без атак `1`, а `COUNT(правая_col)` — `0`? Что это меняет на практике?
10. Можно ли использовать `GROUP BY` без агрегатных функций? Что тогда вернёт запрос?
11. Можно ли использовать `HAVING` без `GROUP BY`? Что это даст?
12. Что произойдёт, если в `GROUP BY` указать колонку, которой нет в `SELECT`? А наоборот?
13. Почему `COUNT(DISTINCT col)` пропускает `NULL`? Приведи пример, где `COUNT(DISTINCT col)` и `COUNT(col)` различаются.
14. Почему `LEFT JOIN` + `GROUP BY` — стандартный паттерн для отчётов вида «категория → число элементов, включая пустые»? Приведи пример на данных БД.
15. В каком порядке SQL выполняет `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`? Почему это важно для понимания, где можно использовать агрегат, а где — нет?
16. Можно ли сортировать по агрегату через `ORDER BY COUNT(*) DESC`? А через псевдоним `ORDER BY cnt DESC`? Приведи оба варианта.
