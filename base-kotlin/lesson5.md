# Лабораторная работа № 4

## Тема: Коллекции в Kotlin (`List`, `MutableList`, `Set`, `Map`) и функциональные операции над ними в Pokémon TCG

**Цель работы:** Освоить создание и наполнение неизменяемых (`List`, `Set`, `Map`) и изменяемых (`MutableList`) коллекций, работу с индексами и методами `add` / `remove`, перебор элементов в цикле `for`, а также базовые функциональные операции преобразования коллекций (`filter`, `map`, `sortedBy`, `count`, `sumOf`, `joinToString`).

---

### 1. Краткие теоретические сведения

Коллекции в Kotlin делятся на **неизменяемые** (интерфейсы `List`, `Set`, `Map` — только чтение) и **изменяемые** (`MutableList`, `MutableSet`, `MutableMap` — можно добавлять и удалять элементы после создания).

#### **A. Списки — `List` и `MutableList`**

Список хранит элементы в порядке добавления и допускает дубликаты. Доступ к элементу — по индексу с `[ ]` (нумерация с нуля).

```kotlin
// Неизменяемый список (read-only)
val deck: List<String> = listOf("Pikachu", "Charmander", "Squirtle")
println(deck[0])        // Pikachu
println(deck.size)      // 3
println(deck.last())    // Squirtle

// Изменяемый список — можно менять содержимое
val hand: MutableList<String> = mutableListOf("Potion", "Switch")
hand.add("Energy")            // добавить в конец
hand.remove("Potion")         // удалить по значению
hand.removeAt(0)              // удалить по индексу
println(hand.contains("Energy")) // true
```

> Важно: `val` для коллекции означает невозможность **переприсвоить переменную**, но `MutableList` под `val` всё равно можно изменять по содержимому.

#### **Б. Множества — `Set` и словари — `Map`**

`Set` хранит только уникальные элементы (дубликаты игнорируются), `Map` — пары «ключ–значение».

```kotlin
val prizePool = setOf("Pikachu", "Pikachu", "Charmander")
println(prizePool.size)   // 2 — дубликат отброшен

val cardCount: Map<String, Int> = mapOf("Potion" to 3, "Switch" to 2)
println(cardCount["Potion"])         // 3
println(cardCount.containsKey("Energy")) // false
```

#### **В. Перебор коллекций в цикле `for`**

```kotlin
// По элементам
for (card in hand) {
    println("В руке: $card")
}

// По индексам
for (i in deck.indices) {
    println("$i -> ${deck[i]}")
}

// По парам «индекс–значение»
for ((index, card) in hand.withIndex()) {
    println("Слот $index: $card")
}

// По записям Map
for ((name, count) in cardCount) {
    println("$name x$count")
}
```

#### **Г. Функциональные операции преобразования**

Операции вида `filter` / `map` не меняют исходную коллекцию — они возвращают **новую**.

```kotlin
val hand = listOf("Pikachu", "Fire Energy", "Potion", "Water Energy")

// filter — отобрать по условию
val energies = hand.filter { it.endsWith("Energy") }

// map — преобразовать каждый элемент
val upperNames = hand.map { it.uppercase() }  // [PIKACHU, FIRE ENERGY, ...]

// sortedBy — отсортировать
val byAlphabet = hand.sortedBy { it }         // по алфавиту

// count — посчитать элементы по условию
val energyCount = hand.count { it.endsWith("Energy") }  // 2

// sumOf — свернуть в число
val totalLength = hand.sumOf { it.length }    // 36

// joinToString — красивый вывод
println(byAlphabet.joinToString(separator = ", "))
```

---

### 2. Порядок выполнения работы

Напишите программу на языке Kotlin (`Main.kt`), выполняющую следующий сценарий:

#### **Часть 1. Колода как `MutableList`**

1. Создайте пустую изменяемую коллекцию `deck` (`MutableList<String>`).
2. В цикле `repeat(3)` считайте с консоли названия карт и добавляйте их в колоду методом `add()`.
3. Считайте название карты `discardedCard` и удалите её из колоды методом `remove()` (метод возвращает `Boolean` — сохраните его в `val wasDiscarded` и выведите результат проверки).

#### **Часть 2. Анализ руки через `filter` и `map`**

1. Инициализируйте словарь «название карты → тип карты»:

```kotlin
val hand = mapOf(
    "Pikachu" to "Pokemon",
    "Potion" to "Trainer",
    "Fire Energy" to "Energy",
    "Professor's Research" to "Trainer"
)
```

2. С помощью `filter` отберите только карты типа `"Trainer"` и сохраните результат в `val trainerCards` (проверка типа — через `it.value`).
3. С помощью `map` получите список названий всех карт руки и выведите его одной строкой через `joinToString(", ")`.
4. С помощью `count` посчитайте, сколько карт типа `"Energy"` находится в руке, и выведите результат.

#### **Часть 3. Учет ресурсов через `Map`**

1. Считайте с консоли целое число `energyToAttach` и добавьте её в словарь ресурсов:

```kotlin
val resources = mutableMapOf("Trainer" to 2, "Energy" to 1)
resources["Energy"] = resources.getValue("Energy") + energyToAttach
```

2. В цикле `for ((type, count) in resources)` выведите сводку ресурсов в формате `Тип: N шт.`.

---

### 3. Эталонный консольный диалог

```text
=== ФОРМИРОВАНИЕ КОЛОДЫ ===
Введите карту №1: Pikachu
Введите карту №2: Potion
Введите карту №3: Switch
Колода собрана (3 карт): Pikachu, Potion, Switch

Какую карту сбросить? Potion
✔ Карта 'Potion' сброшена. Осталось: 2

=== АНАЛИЗ РУКИ ===
Карт Тренеров в руке: 2 (Potion, Professor's Research)
Карт энергии в руке: 1
Содержимое руки: Pikachu, Potion, Fire Energy, Professor's Research

=== УЧЕТ РЕСУРСОВ ===
Сколько энергии прикрепить? 2
Ресурсы на столе:
Trainer: 2 шт.
Energy: 3 шт.

========================================
ИТОГ: Колода: 2 карт | Рука: 4 карт | Энергия на столе: 3
========================================

```

---

### 4. Критерии оценки (3-балльная шкала)

#### **Оценка «5» (Отлично)**

* Продемонстрированы и `MutableList` (с `add` / `remove` / `removeAt`), и read-only `listOf` / `mapOf` / `setOf`.
* Результат `filter` и `map` сохраняется в `val` без явных циклов.
* Использованы `count`, `sumOf` или `sortedBy` с лямбда-параметром `it`.
* Перебор коллекции выполнен циклом `for (x in collection)`, для `Map` — по парам `(key, value)`.
* Итоговый вывод отформатирован шаблонами строк `$` и `joinToString`.

#### **Оценка «4» (Хорошо)**

* Код компилируется и работает без ошибок.
* Присутствуют недочеты:
  * Вместо `filter` / `map` использован ручной перебор в цикле `for` с временным списком.
  * Изменение `MutableList` выполнено через пересоздание списка вместо методов `add` / `remove`.
  * Нарушено форматирование итогового отчета относительно эталонного макета.

#### **Оценка «3» (Удовлетворительно)**

* Коллекции создаются, но:
  * Попытка изменять read-only `List` (ошибка компиляции обходится некорректно).
  * Игнорируется результат `remove()` (Boolean), подсчет карт через `count` выполнен вручную отдельным циклом.
  * Доступ по индексу выходит за границы (`IndexOutOfBoundsException`) на граничных данных.

#### **Оценка «2» / Не зачтено**

* Программа не компилируется или студент не может объяснить отличие `List` от `MutableList` и назначение операций `filter` / `map`.
