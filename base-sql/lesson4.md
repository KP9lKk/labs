# Лабораторная работа №4: Соединения таблиц (`JOIN`)

## 1. Контекст

Продолжение ЛР №3. База данных Pokémon TCG уже наполнена: 10 наборов в `card_set`, 111 карт XY3 в `card`, дочерние таблицы для 4 карт (`pokemon_card`, `trainer_card`, `energy_card`, `pokemon_attack_link`, `attack_energy_cost`, `pokemon_attribute`).

**Тема работы — только `JOIN`.** Работа с `NULL` (NULL-safe сравнение, `COALESCE`, обработка «неизвестных» значений) — в следующей лабораторной.

---

## 2. Порядок выполнения

1. Убедиться, что база заполнена (ЛР №3, шаги 1–7).
2. Проработать раздел 3 (справка) и раздел 4 (примеры на `TEMP`-таблицах) — обязательно выполнить в DBeaver.
3. Написать `queries.sql` — 6 запросов (раздел 5).
4. Ответить на индивидуальный вопрос (раздел 6).

---

## 3. Справка по `JOIN`

### 3.1. Зачем нужны соединения

Данные разложены по таблицам: имя карты — в `card`, HP — в `pokemon_card`, атаки — в `pokemon_attack_link`. Чтобы получить «одна строка = одна карта с HP и атакой», таблицы соединяют.

### 3.2. Типы соединений

| Тип | Что возвращает | Когда использовать |
|---|---|---|
| `INNER JOIN` | только строки, у которых есть совпадение в обеих таблицах | связь обязательна (покемон → HP) |
| `LEFT JOIN` | все строки левой таблицы + совпадения справа (там, где нет совпадения — `NULL`) | нужны «все карты», даже без дочерних данных |
| `RIGHT JOIN` | все строки правой таблицы + совпадения слева | редко; обычно переписывают через `LEFT JOIN` |
| `FULL OUTER JOIN` | все строки обеих таблиц | «симметричная» сверка |
| `CROSS JOIN` | декартово произведение (N×M) | осознанно, для генерации комбинаций |

### 3.3. Синтаксис

```sql
SELECT c.card_name, pc.pokemon_hp
FROM card c
JOIN pokemon_card pc ON pc.pokemon_card_id = c.card_id;
```

- `JOIN` без префикса = `INNER JOIN`.
- Условие соединения — всегда в `ON`.
- Псевдонимы (`c`, `pc`) — обязательны при длинных именах.

### 3.4. Многотабличное соединение

```sql
SELECT c.card_name, an.attack_name_title, pal.link_damage_value,
       et.energy_type_name, aec.cost_quantity
FROM card c
JOIN pokemon_card pc         ON pc.pokemon_card_id     = c.card_id
JOIN pokemon_attack_link pal ON pal.link_pokemon_card_id = pc.pokemon_card_id
JOIN attack_name an          ON an.attack_name_id      = pal.link_attack_name_id
JOIN attack_energy_cost aec  ON aec.cost_link_id       = pal.link_id
JOIN energy_type et          ON et.energy_type_id      = aec.cost_energy_type_id
ORDER BY c.card_name, an.attack_name_title;
```

**Правило**: каждое следующее `JOIN` присоединяет следующее звено цепочки через `ON <fk> = <pk>`.

### 3.5. Карта связей

```
card_set      --< card --< pokemon_card --< pokemon_attack_link --< attack_energy_cost >-- energy_type
                |      --< trainer_card          |
                |      --< energy_card           -- > attack_name
                |
                --< pokemon_card --< pokemon_attribute >-- energy_type
                                   -- > pokemon_species, pokemon_sub_type
                     trainer_card -- > trainer_printed_type
                     energy_card  -- > energy_type
```

`--<` означает «одна-ко-многим», `>--` — «многие-к-одной».

### 3.6. Типичные ошибки

| Ошибка | Что происходит | Как избежать |
|---|---|---|
| Забыли `ON` | `CROSS JOIN`, N×M строк | Всегда указывать `ON` |
| Условие в `WHERE` вместо `ON` | Для `LEFT JOIN` ломает семантику → фактически `INNER` | Переносить в `ON` |
| Дубликаты после `JOIN` | Карта с 2 атаками → 2 строки | Это нормально; группируйте или агрегируйте |
| `NULL` в `JOIN`-колонке | Строка не присоединится (`NULL = NULL` → unknown) | `IS NULL` / `LEFT JOIN` |
| Сравнение `integer` и `text` | Ошибка типов | `::text` / `CAST` |

### 3.7. Безопасный `LEFT JOIN`: где ставить фильтр

**Проблема.** Добавили `WHERE` по колонке правой таблицы — и `LEFT JOIN` превратился в `INNER JOIN`, все «пустые» строки левой таблицы пропали.

```sql
-- Плохо: LEFT JOIN + фильтр по правой таблице в WHERE
SELECT c.card_name, pc.pokemon_hp
FROM card c
LEFT JOIN pokemon_card pc ON pc.pokemon_card_id = c.card_id
WHERE pc.pokemon_hp > 50;   -- карты без HP выброшены
```

**Правило безопасного `LEFT JOIN`:**

> Фильтр по **правой** таблице, если хочется сохранить все строки левой, — переносится в `ON`. Фильтр по **левой** таблице — можно оставить в `WHERE`.

```sql
-- Хорошо: фильтр по правой — в ON: «присоединить только подходящих»
SELECT c.card_name, pc.pokemon_hp
FROM card c
LEFT JOIN pokemon_card pc
       ON pc.pokemon_card_id = c.card_id
      AND pc.pokemon_hp > 50;
-- все карты в результате; у кого нет HP>50 — pokemon_hp = NULL
```

```sql
-- Хорошо: фильтр по левой — можно в WHERE: карты остаются картами
SELECT c.card_name, pc.pokemon_hp
FROM card c
LEFT JOIN pokemon_card pc ON pc.pokemon_card_id = c.card_id
WHERE c.card_type = 'Pokemon';
-- только покемоны, включая тех, у кого нет записи в pokemon_card
```

**Как проверить, что `LEFT JOIN` не «сломался»**: сравните число строк с `SELECT COUNT(*) FROM <левая таблица>`. Если результат меньше — фильтр «съел» часть строк левой таблицы.

```sql
SELECT COUNT(*) FROM card;                    -- например, 111
-- результат предыдущего запроса должен быть >= этого числа
-- (или = при фильтре только по левой)
```

---

## 4. Примеры на `TEMP`-таблицах

Создадим временные таблицы (`TEMP` исчезнут после отключения сессии). Они повторяют структуру связей рабочей БД, но маленькие — на них удобно увидеть разницу между `JOIN`-ами.

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
    (4, 'Strong Energy', 'Energy');

CREATE TEMP TABLE t_pokemon (
    pokemon_card_id INTEGER PRIMARY KEY,
    pokemon_hp      INTEGER,
    pokemon_stage   TEXT
);
INSERT INTO t_pokemon VALUES
    (1,  60, 'Basic'),
    (2,  90, 'Stage 1'),
    (5, 110, 'Basic');    -- «висячий» FK: card_id=5 не существует
```

| `t_card` | | |  | `t_pokemon` | | |
|---:|---|---|---|---:|---:|---|
| 1 | Pikachu | Pokemon |  | 1 | 60 | Basic |
| 2 | Raichu | Pokemon |  | 2 | 90 | Stage 1 |
| 3 | Korrina | Trainer |  | 5 | 110 | Basic |
| 4 | Strong Energy | Energy |  |  |  |  |

### 4.1. `INNER JOIN` — только совпадения

```sql
SELECT c.card_id, c.card_name, pc.pokemon_hp
FROM t_card c
JOIN t_pokemon pc ON pc.pokemon_card_id = c.card_id
ORDER BY c.card_id;
```

| card_id | card_name | pokemon_hp |
|---:|---|---:|
| 1 | Pikachu | 60 |
| 2 | Raichu | 90 |

2 строки. Карты `3`/`4` (нет справа) и `pokemon_card_id = 5` (нет слева) — не попадают.

### 4.2. `LEFT JOIN` — все строки левой

```sql
SELECT c.card_id, c.card_name, pc.pokemon_hp
FROM t_card c
LEFT JOIN t_pokemon pc ON pc.pokemon_card_id = c.card_id
ORDER BY c.card_id;
```

| card_id | card_name | pokemon_hp |
|---:|---|---:|
| 1 | Pikachu | 60 |
| 2 | Raichu | 90 |
| 3 | Korrina | NULL |
| 4 | Strong Energy | NULL |

4 строки; у `3`/`4` — `NULL` в правых колонках. Строка `5` не попадёт (её нет в левой таблице).

### 4.3. `RIGHT JOIN` — все строки правой

```sql
SELECT c.card_id, c.card_name, pc.pokemon_card_id, pc.pokemon_hp
FROM t_card c
RIGHT JOIN t_pokemon pc ON pc.pokemon_card_id = c.card_id
ORDER BY pc.pokemon_card_id;
```

| card_id | card_name | pokemon_card_id | pokemon_hp |
|---:|---|---:|---:|
| 1 | Pikachu | 1 | 60 |
| 2 | Raichu | 2 | 90 |
| NULL | NULL | 5 | 110 |

3 строки; карты `3`/`4` отсутствуют.

### 4.4. `FULL OUTER JOIN` — все строки обеих

```sql
SELECT c.card_id, c.card_name, pc.pokemon_card_id, pc.pokemon_hp
FROM t_card c
FULL OUTER JOIN t_pokemon pc ON pc.pokemon_card_id = c.card_id
ORDER BY c.card_id NULLS LAST, pc.pokemon_card_id;
```

| card_id | card_name | pokemon_card_id | pokemon_hp |
|---:|---|---:|---:|
| 1 | Pikachu | 1 | 60 |
| 2 | Raichu | 2 | 90 |
| 3 | Korrina | NULL | NULL |
| 4 | Strong Energy | NULL | NULL |
| NULL | NULL | 5 | 110 |

5 строк — видны все несовпадения.

### 4.5. `CROSS JOIN` — N×M (4 × 3 = 12)

```sql
SELECT c.card_name, pc.pokemon_hp FROM t_card c CROSS JOIN t_pokemon pc;
```

12 строк. Чаще всего `CROSS JOIN` получается случайно — если забыть `ON`:

```sql
SELECT COUNT(*) FROM t_card c JOIN t_pokemon pc;  -- 12 (забыли ON)
```

### 4.6. Сводная таблица

| Тип | Строк | `card_id=1,2` | `card_id=3,4` | `pokemon_card_id=5` |
|---|---:|---|---|---|
| `INNER JOIN` | 2 | да | нет | нет |
| `LEFT JOIN`  | 4 | да | да (`NULL` справа) | нет |
| `RIGHT JOIN` | 3 | да | нет | да (`NULL` слева) |
| `FULL OUTER JOIN` | 5 | да | да | да |
| `CROSS JOIN` | 12 | да, ×3 | да, ×3 | да, ×4 |

### 4.7. Ошибка: `WHERE` по правой таблице после `LEFT JOIN`

```sql
-- Плохо: LEFT JOIN + фильтр по правой таблице в WHERE
SELECT c.card_id, c.card_name, pc.pokemon_hp
FROM t_card c
LEFT JOIN t_pokemon pc ON pc.pokemon_card_id = c.card_id
WHERE pc.pokemon_hp > 50;
```

| card_id | card_name | pokemon_hp |
|---:|---|---:|
| 1 | Pikachu | 60 |
| 2 | Raichu | 90 |

`Korrina` и `Strong Energy` исчезли — `NULL > 50` = `NULL` = «не TRUE». Это уже не `LEFT JOIN`, а `INNER`.

**Исправление — фильтр в `ON`:**

```sql
-- Хорошо: сохраняет все строки левой таблицы
SELECT c.card_id, c.card_name, pc.pokemon_hp
FROM t_card c
LEFT JOIN t_pokemon pc
       ON pc.pokemon_card_id = c.card_id
      AND pc.pokemon_hp > 50;
```

| card_id | card_name | pokemon_hp |
|---:|---|---:|
| 1 | Pikachu | 60 |
| 2 | Raichu | 90 |
| 3 | Korrina | NULL |
| 4 | Strong Energy | NULL |

### 4.8. Уборка

```sql
DROP TABLE IF EXISTS t_pokemon, t_card;
```

---

## 5. Задание: 6 запросов (сохранить в `queries.sql`)

Каждый запрос — с комментарием `-- Запрос N` и указанием типа `JOIN`.

**Запрос 1 — `INNER JOIN` (2 таблицы).**
Вывести `card_name`, `pokemon_hp`, `pokemon_stage` всех покемонов. Сортировка: `pokemon_hp DESC`, затем `card_name`.

**Запрос 2 — `LEFT JOIN` (все карты + атаки).**
Вывести `card_name`, `card_type`, `attack_name_title`, `link_damage_value` для всех карт. У карт без атак — `NULL` в полях атаки. Сортировка: `card_type`, `card_name`, `attack_name_title`.
_В комментарии: сколько строк вернулось, сколько всего карт в `card`; объяснить, почему числа отличаются._

**Запрос 3 — многотабличный `JOIN` (5 таблиц).**
Вывести `card_name`, `attack_name_title`, `link_damage_value`, `energy_type_name`, `cost_quantity`. Соединить `card` → `pokemon_attack_link` → `attack_name` → `attack_energy_cost` → `energy_type`. Сортировка: `card_name`, `attack_name_title`, `energy_type_name`.

**Запрос 4 — `LEFT JOIN` + безопасный фильтр в `ON`.**
Вывести `card_name`, `card_type`, `pokemon_hp` всех карт, но присоединить `pokemon_card` только для тех, у кого `pokemon_hp > 80`. У остальных — `NULL`. Сортировка: `card_type`, `card_name`.
_В комментарии: почему фильтр в `ON`, а не в `WHERE`._

**Запрос 5 — `LEFT JOIN` + `IS NULL` (поиск «сирот»).**
Вывести `card_name`, `card_type` карт, у которых нет записи в `pokemon_card`, `trainer_card` и `energy_card` одновременно (т.е. «нигде не дочерняя»). Использовать `LEFT JOIN` на все три дочерние таблицы + `WHERE ... IS NULL`.
_Подсказка: `WHERE pc.pokemon_card_id IS NULL AND tc.trainer_card_id IS NULL AND ec.energy_card_id IS NULL`._

**Запрос 6 — `FULL OUTER JOIN` на рабочих таблицах.**
Соединить `card_set` и `card` через `FULL OUTER JOIN` по `set_id`. В комментарии: какие «сироты» с каждой стороны видны (если сирот нет — объяснить, почему).

---

## 6. Индивидуальный вопрос (1 вариант на студента)

1. Чем `INNER JOIN` отличается от `LEFT JOIN`? Покажи на `TEMP`-таблицах.
2. Чем `LEFT JOIN` отличается от `RIGHT JOIN`? Когда результат совпадает по числу строк, но различается по содержимому?
3. Почему `FULL OUTER JOIN` может вернуть больше строк, чем `LEFT` и `RIGHT` по отдельности? Покажи на `TEMP`-таблицах.
4. Что произойдёт, если в `JOIN` забыть `ON`? Как это обнаружить по числу строк?
5. Почему `WHERE pc.pokemon_hp > 50` после `LEFT JOIN` превращает его в `INNER`? Как исправить?
6. Когда фильтр по правой таблице нужно ставить в `ON`, а когда — в `WHERE`?
7. Почему `CROSS JOIN` появляется случайно? Как это заметить по `COUNT(*)`?
8. Можно ли соединить таблицу саму с собой? Приведи пример (например, «все покемоны, у которых HP больше, чем у Пикачу») — и объясни, зачем нужны два псевдонима.
9. Как найти карты без дочерних записей через `LEFT JOIN` + `IS NULL`? Почему `NOT IN` здесь опасен?
10. Почему после `JOIN` карт с атаками число строк может быть больше, чем карт? Что делать, чтобы получить «одна карта = одна строка»?
11. Чем `LEFT JOIN` отличается от `LEFT JOIN` + `WHERE правая IS NULL`? Приведи пример и объясни, что именно возвращает каждый вариант.
12. В каком порядке нужно перечислять таблицы в цепочке `JOIN` для связи `card` → `pokemon_attack_link` → `attack_name`? Почему порядок не влияет на результат `INNER JOIN`, но влияет на `LEFT JOIN`?
