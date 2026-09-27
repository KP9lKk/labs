-- Заполнение справочника типов
INSERT INTO types (type_id, type_name) VALUES
(1, 'grass'),
(2, 'poison'),
(3, 'fire'),
(4, 'water'),
(5, 'flying'),
(6, 'electric');
-- Заполнение справочника способностей
INSERT INTO abilities (ability_id, ability_name, ability_short_effect) VALUES
(1, 'overgrow', 'Powers up Grass-type moves when the Pokemon''s HP is low.'),
(2, 'chlorophyll', 'Boosts the Pokemon''s Speed stat in harsh sunlight.'),
(3, 'blaze', 'Powers up Fire-type moves when the Pokemon''s HP is low.'),
(4, 'solar-power', 'Boosts the Sp. Atk stat in harsh sunlight, but HP decreases every turn.'),
(5, 'torrent', 'Powers up Water-type moves when the Pokemon''s HP is low.'),
(6, 'rain-dish', 'Slightly restores HP in rain.'),
(7, 'static', 'The Pokemon is charged with static electricity, so contact with it may cause paralysis.'),
(8, 'lightning-rod', 'Draws in all Electric-type moves to boost its own Sp. Atk stat.');
-- Заполнение справочника характеристик
INSERT INTO stats (stat_id, stat_name) VALUES
(1, 'hp'),
(2, 'attack'),
(3, 'defense'),
(4, 'special-attack'),
(5, 'special-defense'),
(6, 'speed');
-- Заполнение основной таблицы покемонов
INSERT INTO pokemons (pokemon_id, pokemon_name, pokemon_height, pokemon_weight, pokemon_base_experience) VALUES
(1, 'bulbasaur', 7, 69, 64),
(4, 'charmander', 6, 85, 62),
(7, 'squirtle', 5, 90, 63),
(25, 'pikachu', 4, 60, 112);
-- Привязка покемонов к типам
INSERT INTO pokemon_types (pokemon_id, type_id, pokemon_type_slot) VALUES
(1, 1, 1), -- Bulbasaur - Grass (Слот 1)
(1, 2, 2), -- Bulbasaur - Poison (Слот 2)
(4, 3, 1), -- Charmander - Fire (Слот 1)
(7, 4, 1), -- Squirtle - Water (Слот 1)
(25, 6, 1); -- Pikachu - Electric (Слот 1)
-- Привязка покемонов к их способностям (обычным и скрытым)
INSERT INTO pokemon_abilities (pokemon_id, ability_id, pokemon_ability_is_hidden) VALUES
(1, 1, false), -- Bulbasaur: Overgrow
(1, 2, true),  -- Bulbasaur: Chlorophyll (Скрытая)
(4, 3, false), -- Charmander: Blaze
(4, 4, true),  -- Charmander: Solar-Power (Скрытая)
(7, 5, false), -- Squirtle: Torrent
(7, 6, true),  -- Squirtle: Rain-Dish (Скрытая)
(25, 7, false),-- Pikachu: Static
(25, 8, true); -- Pikachu: Lightning-Rod (Скрытая)
-- Распределение числовых значений базовых характеристик по покемонам
INSERT INTO pokemon_stats (pokemon_id, stat_id, pokemon_stat_base_stat) VALUES
-- Характеристики для Bulbasaur
(1, 1, 45),  -- HP
(1, 2, 49),  -- Attack
(1, 3, 49),  -- Defense
(1, 4, 65),  -- Sp. Atk
(1, 5, 65),  -- Sp. Def
(1, 6, 45),  -- Speed
-- Характеристики для Charmander
(4, 1, 39),  -- HP
(4, 2, 52),  -- Attack
(4, 3, 43),  -- Defense
(4, 4, 60),  -- Sp. Atk
(4, 5, 50),  -- Sp. Def
(4, 6, 65),  -- Speed
-- Характеристики для Squirtle
(7, 1, 44),  -- HP
(7, 2, 48),  -- Attack
(7, 3, 65),  -- Defense
(7, 4, 50),  -- Sp. Atk
(7, 5, 64),  -- Sp. Def
(7, 6, 43),  -- Speed
-- Характеристики для Pikachu
(25, 1, 35), -- HP
(25, 2, 55), -- Attack
(25, 3, 40), -- Defense
(25, 4, 50), -- Sp. Atk
(25, 5, 50), -- Sp. Def
(25, 6, 90); -- Speed