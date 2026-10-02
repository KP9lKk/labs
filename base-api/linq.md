# Краткий справочник по LINQ для задач о покемонах

```csharp
using System.Linq;
using Microsoft.EntityFrameworkCore;
```

## 1. Фильтрация — `Where`

```csharp
db.Pokemons.Where(p => p.Height < 10);
db.Pokemons.Where(p => p.Weight > 100 && p.Name != null);
db.Pokemons.Where(p => p.Name.StartsWith("P"));
```

## 2. Сортировка — `OrderBy`, `OrderByDescending`, `ThenBy`

```csharp
.OrderBy(p => p.Name)
.OrderByDescending(p => p.Weight)
.OrderBy(p => p.Name).ThenByDescending(p => p.Weight)
```

## 3. Проекция — `Select`

```csharp
.Select(p => p.Name)

.Select(p => new { p.Name, p.Weight })

.Select(p => new
{
    Name = p.Name,
    Value = p.Weight
})

.Select(p => new
{
    p.Name,
    Items = p.Links.Select(l => l.Target.Name).ToList()
})
```

## 4. Первый элемент / максимум

```csharp
.FirstOrDefault()
.FirstOrDefault(p => p.Weight > 100)

.MaxBy(p => p.Weight)          // .NET 6+
.OrderByDescending(p => p.Weight).FirstOrDefault()

.SingleOrDefault(p => p.Id == id)
```

## 5. Агрегаты

```csharp
.Count()
.Count(p => p.Weight > 100)

.Sum(p => p.Value)
.Average(p => p.Value)
.Min(p => p.Value)
.Max(p => p.Value)
```

## 6. Проверка наличия — `Any`, `All`

```csharp
.Any()
.Any(p => p.IsHidden)
.All(p => p.Weight > 0)
```

Для проверки «есть ли хотя бы один» лучше использовать `Any()`, а не `Count() > 0`.

## 7. Связанные сущности: `Any`, `Count`, `Sum`

```csharp
.Where(p => p.Links.Any(l => l.Target.Name == "X"))
.Where(p => p.Links.Any(l => l.Flag == true))
.Where(p => p.Links.Count() == 2)

.Count(l => l.Flag == true)
.Sum(s => s.Value)
```

Пример для many-to-many через связующую сущность:

```csharp
.Where(p => p.PokemonTypes.Any(pt =>
    pt.Type.Name == "SomeType" && pt.Slot == 1))
```

## 8. Группировка — `GroupBy`

```csharp
.GroupBy(p => p.Category)
.Select(g => new
{
    Key = g.Key,
    Count = g.Count()
})
```

Группировка по вычисляемому признаку:

```csharp
.GroupBy(p => p.Links.Count())
.Select(g => new
{
    TypesCount = g.Key,
    PokemonsCount = g.Count()
})
```

## 9. Ограничение выборки — `Take`, `Skip`

```csharp
.Take(3)
.Skip(2).Take(3)
```

## 10. EF Core: загрузка навигации

```csharp
.Include(p => p.Links)
    .ThenInclude(l => l.Target)
```

При проекции через `Select` `Include` обычно не нужен — нужные поля подтягиваются в проекцию.

## 11. Материализация

```csharp
.ToList()
.ToArray()
.AsEnumerable()
```

## 12. Общий шаблон запроса

```csharp
var result = db.Pokemons
    .Where(p => ...)
    .OrderByDescending(p => ...)
    .Select(p => new { ... })
    .Take(3)
    .ToList();
```


