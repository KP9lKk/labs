# Лабораторная работа №3: Наполнение базы данных и базовые SQL-запросы (`INSERT`, `SELECT`)

## 1. Контекст

Используется схема БД `schema.sql`, созданная и проверенная в Лабораторной работе №2.

Задача — наполнить базу данными карточной игры Pokémon TCG и написать 6 аналитических запросов на чтение.

В работе участвуют три источника данных:

| Источник | Что даёт | Куда попадает |
|---|---|---|
| `data.txt` | 10 наборов карт (сеты) | таблица `card_set` |
| `furious_fists_cards_ru.csv` | 111 карт набора XY3 (метаданные) | таблица `card` |
| **pokemontcg.io API** | боевые характеристики, атаки, способности, слабости | дочерние таблицы |

Дочерние таблицы (`pokemon_card`, `trainer_card`, `energy_card`) и связующие (`pokemon_attack_link`, `attack_energy_cost`, `pokemon_attribute`) заполняются **на основе данных, полученных из открытого API**.

---

## 2. Входные данные

### 2.1. Наборы карт (`data.txt`)

```text
'XY Базовый набор', 'XY1', 'XY', 146, '2014-02-05'
'XY Огненная вспышка', 'XY2', 'XY', 106, '2014-05-07'
'XY Яростный кулак', 'XY3', 'XY', 111, '2014-08-13'
'XY Призрачные силы', 'XY4', 'XY', 119, '2014-11-05'
'XY Первобытная дуэль', 'XY5', 'XY', 160, '2015-02-04'
'XY Грохочущие небеса', 'XY6', 'XY', 108, '2015-05-06'
'XY Древние истоки', 'XY7', 'XY', 98, '2015-08-12'
'XY Прорыв', 'XY8', 'XY', 162, '2015-11-04'
'XY Тайное превосходство', 'XY9', 'XY', 122, '2016-02-03'
'XY Столкновение судеб', 'XY10', 'XY', 124, '2016-05-02'
```

### 2.2. Карты набора XY3 (`furious_fists_cards_ru.csv`)

111 карт: 87 покемонов, 15 тренеров, 9 энергий.  
Колонки: `card_id, card_number, card_name, card_rarity, card_type, card_image_url`.

Файл загружается через **импорт CSV в DBeaver**, не через `INSERT`.

### 2.3. API pokemontcg.io

Публичный REST API: `https://api.pokemontcg.io/v2/cards`  
Работает **без ключа** для базовых запросов. Ответ открывается прямо в браузере.

---

## 3. Порядок выполнения работы

1. Выполнить `schema.sql`.
2. Выполнить **часть 1** `data.sql`: заполнить справочники и `card_set`.
3. Импортировать `furious_fists_cards_ru.csv` через DBeaver в staging-таблицу.
4. Перенести данные из staging в `card`.
5. Посмотреть ID карт через `SELECT` — они понадобятся для части 2.
6. Получить данные по картам из pokemontcg.io API через браузер.
7. Выполнить **часть 2** `data.sql`: заполнить дочерние и связующие таблицы для 4 карт.
8. Написать `queries.sql` — 6 запросов на чтение.
9. Сдать работу и ответить на индивидуальный вопрос.

---

## 4. Шаг 1. Импорт CSV через DBeaver

### 4.1. Staging-таблица

```sql
CREATE TABLE staging_furious_fists (
    card_id        INTEGER,
    card_number    TEXT,
    card_name      TEXT,
    card_rarity    TEXT,
    card_type      TEXT,
    card_image_url TEXT
);
```

### 4.2. Импорт в DBeaver

1. Правой кнопкой по `staging_furious_fists` → **Import Data** → **CSV**.
2. Файл `furious_fists_cards_ru.csv`.
3. Encoding: `UTF-8`, Delimiter: `,`, Header: первая строка, Quote: `"`.
4. Сопоставить колонки один-в-один и запустить импорт.

### 4.3. Перенос в `card`

```sql
INSERT INTO card (
    card_number, card_set_id, card_name,
    card_rarity, card_type, card_image_url
)
SELECT
    s.card_number,
    (SELECT set_id FROM card_set WHERE set_code = 'XY3'),
    s.card_name,
    s.card_rarity,
    s.card_type,
    s.card_image_url
FROM staging_furious_fists s
WHERE s.card_type IN ('Pokemon', 'Trainer', 'Energy');

DROP TABLE staging_furious_fists;
```

---

## 5. Шаг 2. Смотрим ID карт

`card_id` — автоинкремент. Чтобы не угадывать значения, выполните:

```sql
SELECT card_id, card_number, card_name, card_type
FROM card
ORDER BY card_id;
```

Например, у Пикачу (`28/111`) может оказаться `card_id = 28`, у Коррины (`88/111`) — `88`.  
**Эти числа вы будете использовать напрямую в `INSERT`-ах части 2.** Никаких сложных подзапросов.

---

## 6. Шаг 3. Получение данных из API через браузер

Выбираем **минимум 4 карты** (3 покемона + 1 тренер или энергия). Для каждой открываем URL в браузере.

### 6.1. Формат URL

```
https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:НОМЕР
```

`НОМЕР` — числитель из `card_number` (для `28/111` → `28`).

### 6.2. Примеры

| Карта | URL |
|---|---|
| Пикачу (28/111) | `https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:28` |
| Райчу (29/111) | `https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:29` |
| Лукарио-EX (54/111) | `https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:54` |
| Коррина (88/111) | `https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:88` |
| Мощная энергия (103/111) | `https://api.pokemontcg.io/v2/cards?q=set.id:xy3%20number:103` |

### 6.3. Что взять из JSON

Пример ответа для Пикачу:

```json
{
  "data": [
    {
      "name": "Pikachu",
      "number": "28",
      "hp": "60",
      "types": ["Lightning"],
      "evolvesFrom": null,
      "attacks": [
        { "name": "Nuzzle",       "cost": ["Lightning"],               "damage": "",    "text": "Your opponent's Active Pokémon is now Paralyzed." },
        { "name": "Quick Attack", "cost": ["Lightning", "Colorless"], "damage": "20+", "text": "Flip a coin. If heads, this attack does 20 more damage." }
      ],
      "weaknesses":  [{ "type": "Fighting", "value": "×2" }],
      "resistances": [{ "type": "Metal",    "value": "-20" }],
      "retreatCost": ["Colorless"],
      "subtypes": ["Basic"]
    }
  ]
}
```

Что куда:

| Поле JSON | Куда |
|---|---|
| `hp` | `pokemon_card.pokemon_hp` |
| `subtypes[0]` | `pokemon_card.pokemon_stage` |
| `evolvesFrom` | `pokemon_card.pokemon_evolves_from` |
| `retreatCost` | `pokemon_card.pokemon_retreat_cost` (длина массива) |
| `attacks[].name` | `attack_name.attack_name_title` |
| `attacks[].damage` | `pokemon_attack_link.link_damage_value` |
| `attacks[].text` | `pokemon_attack_link.link_effect_text` |
| `attacks[].cost[]` | `attack_energy_cost` |
| `weaknesses[]` | `pokemon_attribute` (`Weakness`) |
| `resistances[]` | `pokemon_attribute` (`Resistance`) |

> Если браузер показывает пустой ответ — проверьте, что номер карты без `/111` и что `%20` стоит между `set.id:xy3` и `number:N`.

---

## 7. Требования к `data.sql`

### 7.1. Принцип

Для новичков — **никаких подзапросов внутри `INSERT`**.  
Сначала выполняем `SELECT`, смотрим ID, потом пишем `INSERT` с числами.

### 7.2. Часть 1. Справочники и `card_set`

**`card_set` — все 10 наборов:**

```sql
INSERT INTO card_set (
    set_name, set_code, set_series,
    set_total_cards, set_release_date,
    set_logo_url, set_symbol_url
)
VALUES
    ('XY Базовый набор', 'XY1', 'XY', 146, '2014-02-05', NULL, NULL),
    ('XY Огненная вспышка', 'XY2', 'XY', 106, '2014-05-07', NULL, NULL),
    ('XY Яростный кулак', 'XY3', 'XY', 111, '2014-08-13', NULL, NULL),
    ('XY Призрачные силы', 'XY4', 'XY', 119, '2014-11-05', NULL, NULL),
    ('XY Первобытная дуэль', 'XY5', 'XY', 160, '2015-02-04', NULL, NULL),
    ('XY Грохочущие небеса', 'XY6', 'XY', 108, '2015-05-06', NULL, NULL),
    ('XY Древние истоки', 'XY7', 'XY', 98, '2015-08-12', NULL, NULL),
    ('XY Прорыв', 'XY8', 'XY', 162, '2015-11-04', NULL, NULL),
    ('XY Тайное превосходство', 'XY9', 'XY', 122, '2016-02-03', NULL, NULL),
    ('XY Столкновение судеб', 'XY10', 'XY', 124, '2016-05-02', NULL, NULL);
```

**`energy_type`:**

```sql
INSERT INTO energy_type (energy_type_name, energy_type_icon_url) VALUES
    ('Grass',     NULL),
    ('Fire',      NULL),
    ('Water',     NULL),
    ('Lightning', NULL),
    ('Psychic',   NULL),
    ('Fighting',  NULL),
    ('Darkness',  NULL),
    ('Metal',     NULL),
    ('Fairy',     NULL),
    ('Dragon',    NULL),
    ('Colorless', NULL);
```

**`pokemon_sub_type`:**

```sql
INSERT INTO pokemon_sub_type (
    sub_type_name, sub_type_default_prize_count, sub_type_global_rule_text
) VALUES
    ('Normal', 1, NULL),
    ('EX',     2, 'When a Pokémon-EX is Knocked Out, your opponent takes 2 Prize cards.'),
    ('MEGA',   2, 'When a MEGA Evolution Pokémon is Knocked Out, your opponent takes 2 Prize cards.'),
    ('BREAK',  1, NULL);
```

**`ability_type`:**

```sql
INSERT INTO ability_type (ability_type_name) VALUES
    ('Ability'),
    ('Poké-Power'),
    ('Poké-Body');
```

**`trainer_printed_type`:**

```sql
INSERT INTO trainer_printed_type (printed_type_name) VALUES
    ('Item'),
    ('Supporter'),
    ('Stadium'),
    ('Pokémon Tool');
```

**`attack_name` (по выбранным картам):**

```sql
INSERT INTO attack_name (attack_name_title) VALUES
    ('Nuzzle'),
    ('Quick Attack'),
    ('Circle Circuit'),
    ('Thunder Shock');
```

**`pokemon_species` (для выбранных покемонов):**

```sql
INSERT INTO pokemon_species (
    pokemon_pokedex_number, species_eng_name,
    species_generation, species_height_m, species_weight_kg
) VALUES
    (25,  'Pikachu',  1, 0.4, 6.0),
    (26,  'Raichu',   1, 0.8, 30.0),
    (448, 'Lucario',  4, 1.2, 54.0);
```

### 7.3. Часть 2. Дочерние таблицы

**Сначала посмотрите ID:**

```sql
SELECT card_id, card_number, card_name FROM card ORDER BY card_id;
SELECT energy_type_id, energy_type_name FROM energy_type;
SELECT sub_type_id, sub_type_name FROM pokemon_sub_type;
SELECT attack_name_id, attack_name_title FROM attack_name;
SELECT printed_type_id, printed_type_name FROM trainer_printed_type;
```

Дальше используйте **полученные числа напрямую**.

#### Пример: Пикачу, `card_id = 28`

```sql
-- Карта покемона
INSERT INTO pokemon_card (
    pokemon_card_id,
    pokemon_pokedex_number,
    pokemon_pokedex_entry_id,
    pokemon_hp,
    pokemon_stage,
    pokemon_evolves_from,
    pokemon_retreat_cost,
    pokemon_sub_type_id,
    pokemon_category,
    pokemon_printed_height,
    pokemon_printed_weight
) VALUES
    (28, 25, NULL, 60, 'Basic', NULL, 1, 1, 'Мышонок', '0.4 м', '6.0 кг');

-- Атака 1: Nuzzle
INSERT INTO pokemon_attack_link (
    link_pokemon_card_id, link_attack_name_id,
    link_damage_value, link_effect_text
) VALUES
    (28, 1, '0', 'Your opponent''s Active Pokémon is now Paralyzed.');

-- Атака 2: Quick Attack
INSERT INTO pokemon_attack_link (
    link_pokemon_card_id, link_attack_name_id,
    link_damage_value, link_effect_text
) VALUES
    (28, 2, '20', 'Flip a coin. If heads, this attack does 20 more damage.');

-- Стоимость атаки Nuzzle (link_id смотрим через SELECT)
INSERT INTO attack_energy_cost (cost_link_id, cost_energy_type_id, cost_quantity)
VALUES
    (1, 4, 1);  -- link_id=1, тип Lightning, 1 шт.

-- Стоимость Quick Attack
INSERT INTO attack_energy_cost (cost_link_id, cost_energy_type_id, cost_quantity)
VALUES
    (2, 4, 1),  -- Lightning
    (2, 11, 1); -- Colorless

-- Слабость к Fighting
INSERT INTO pokemon_attribute (
    attribute_pokemon_card_id, attribute_energy_type_id,
    attribute_kind, attribute_modifier_value
) VALUES
    (28, 6, 'Weakness', 'x2');

-- Сопротивление Metal
INSERT INTO pokemon_attribute (
    attribute_pokemon_card_id, attribute_energy_type_id,
    attribute_kind, attribute_modifier_value
) VALUES
    (28, 8, 'Resistance', '-20');
```

> `link_id` для `attack_energy_cost` узнаём так:
> ```sql
> SELECT link_id, link_pokemon_card_id, link_attack_name_id
> FROM pokemon_attack_link
> WHERE link_pokemon_card_id = 28;
> ```

#### Пример: тренер Коррина, `card_id = 88`

```sql
-- Смотрим ID печатного типа
SELECT printed_type_id, printed_type_name FROM trainer_printed_type;
-- Например: Item = 1, Supporter = 2, Stadium = 3, Pokémon Tool = 4

INSERT INTO trainer_card (
    trainer_card_id, trainer_printed_type_id,
    trainer_effect_text, trainer_is_ace_spec
) VALUES
    (88, 2, 'Switch your Active Pokémon with 1 of your Benched Pokémon.', FALSE);
```

#### Пример: Мощная энергия, `card_id = 103`

```sql
-- Смотрим ID типа энергии
SELECT energy_type_id, energy_type_name FROM energy_type;

INSERT INTO energy_card (
    energy_card_id, energy_is_special,
    energy_main_type_id, energy_effect_text
) VALUES
    (103, TRUE, NULL, 'This card provides 1 Fighting energy. When attached, ...');
```

### 7.4. Правила

- Не указывайте столбцы `*_id`, объявленные как `IDENTITY` (кроме тех, что идут от `card` — они у вас уже есть после импорта).
- `pokemon_species.pokemon_pokedex_number` — **натуральный PK**, указывается вручную.
- Текст в одинарных кавычках. Если внутри текста есть `'` — удваивайте: `'opponent''s'`.
- `card_type` строго из `'Pokemon'`, `'Trainer'`, `'Energy'`.

---

## 8. Справка по `SELECT`

### 8.1. Базовый синтаксис

```sql
SELECT список_колонок
FROM имя_таблицы
WHERE условие
ORDER BY колонка ASC|DESC
LIMIT N;
```

Порядок частей важен: `SELECT` → `FROM` → `WHERE` → `ORDER BY` → `LIMIT`.

### 8.2. Выборка колонок

```sql
-- Все колонки
SELECT * FROM card;

-- Конкретные колонки
SELECT card_name, card_type FROM card;
```

### 8.3. Фильтрация (`WHERE`)

| Оператор | Значение | Пример |
|---|---|---|
| `=` | равно | `WHERE card_type = 'Pokemon'` |
| `<>` или `!=` | не равно | `WHERE card_type <> 'Trainer'` |
| `>` `<` `>=` `<=` | сравнение | `WHERE pokemon_hp > 60` |
| `AND` | логическое И | `WHERE hp > 60 AND stage = 'Basic'` |
| `OR` | логическое ИЛИ | `WHERE stage = 'Basic' OR hp > 100` |
| `IN (...)` | входит в список | `WHERE name IN ('Fire', 'Water')` |
| `BETWEEN a AND b` | в диапазоне | `WHERE hp BETWEEN 60 AND 120` |
| `LIKE` / `ILIKE` | поиск по шаблону | `WHERE name ILIKE '%pi%'` |
| `IS NULL` / `IS NOT NULL` | проверка на NULL | `WHERE evolves_from IS NULL` |

**Про `LIKE` / `ILIKE`:**

- `%` — любое количество символов;
- `_` — ровно один символ;
- `LIKE` — регистрозависимый;
- `ILIKE` — регистронезависимый (PostgreSQL).

```sql
WHERE card_name ILIKE '%pi%'   -- найдёт Pikachu, Pidgeot, ...
WHERE card_name LIKE 'P%'      -- имена, начинающиеся с заглавной P
```

### 8.4. Сортировка (`ORDER BY`)

```sql
ORDER BY pokemon_hp ASC      -- по возрастанию (по умолчанию)
ORDER BY pokemon_hp DESC     -- по убыванию
ORDER BY card_name ASC, pokemon_hp DESC  -- сначала по имени, потом по HP
```

### 8.5. Ограничение строк (`LIMIT`)

```sql
LIMIT 2         -- первые 2 строки
LIMIT 10 OFFSET 5  -- пропустить 5, взять 10
```

`LIMIT` почти всегда идёт вместе с `ORDER BY`, иначе строки выбираются в произвольном порядке.
