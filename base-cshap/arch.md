# Методичка: архитектура C#-проекта на соревнованиях

**Версия 2.0** · С полными примерами кода для каждого слоя

Домен примера: **«Библиотека»** — читатели берут и возвращают книги. Достаточно простой, чтобы понять за 5 минут, и достаточно полный, чтобы показать все слои.

---

## Оглавление

1. [Общая идея и структура](#1-общая-идея-и-структура)
2. [Domain — предметная область](#2-domain--предметная-область)
3. [Application — сценарии](#3-application--сценарии)
4. [Infrastructure — реализация](#4-infrastructure--реализация)
5. [Contracts — DTO](#5-contracts--dto)
6. [Client.Core — общая обвязка клиентов](#6-clientcore--общая-обвязка-клиентов)
7. [Web — клиент студента](#7-web--клиент-студента)
8. [Desktop — клиент жюри](#8-desktop--клиент-жюри)
9. [Mobile — клиент зрителя](#9-mobile--клиент-зрителя)
10. [Тесты](#10-тесты)
11. [DI и стартовые файлы](#11-di-и-стартовые-файлы)
12. [Чек-лист и типичные ошибки](#12-чек-лист-и-типичные-ошибки)

---

## 1. Общая идея и структура

```
MyApp.sln
│
├── src/
│   ├── MyApp.Domain/            ← модели и правила
│   ├── MyApp.Application/       ← сценарии
│   ├── MyApp.Infrastructure/    ← БД / файлы / API
│   ├── MyApp.Contracts/         ← DTO
│   ├── MyApp.Client.Core/       ← общая обвязка клиентов
│   ├── MyApp.Web/               ← Blazor (читатель)
│   ├── MyApp.Desktop/           ← Avalonia (библиотекарь)
│   └── MyApp.Mobile/            ← MAUI (зритель)
│
└── tests/
    ├── MyApp.Domain.Tests/
    └── MyApp.Application.Tests/
```

**Правила ссылок:** клиенты → Application/Contracts/Client.Core → Domain. Никогда наоборот.

---

## 2. Domain — предметная область

**Что тут:** сущности, value-объекты, enum'ы, доменные исключения, правила. **Никаких** атрибутов EF, JSON, HTTP.

### `Domain/Enums/BookStatus.cs`

```csharp
namespace MyApp.Domain.Enums;

public enum BookStatus
{
    Available = 0,
    Loaned = 1,
    Lost = 2
}
```

### `Domain/Exceptions/DomainException.cs`

```csharp
namespace MyApp.Domain.Exceptions;

public class DomainException : Exception
{
    public DomainException(string message) : base(message) { }
}
```

### `Domain/ValueObjects/Isbn.cs`

```csharp
using MyApp.Domain.Exceptions;

namespace MyApp.Domain.ValueObjects;

public sealed record Isbn
{
    public string Value { get; }

    private Isbn(string value) => Value = value;

    public static Isbn Create(string value)
    {
        var digits = new string((value ?? "").Where(char.IsDigit).ToArray());
        if (digits.Length is not (10 or 13))
            throw new DomainException("ISBN должен содержать 10 или 13 цифр");
        return new Isbn(digits);
    }

    public override string ToString() => Value;
}
```

### `Domain/Models/Book.cs`

```csharp
using MyApp.Domain.Enums;
using MyApp.Domain.Exceptions;
using MyApp.Domain.ValueObjects;

namespace MyApp.Domain.Models;

public class Book
{
    public Guid Id { get; private set; }
    public string Title { get; private set; } = default!;
    public string Author { get; private set; } = default!;
    public Isbn Isbn { get; private set; } = default!;
    public BookStatus Status { get; private set; }
    public Guid? LoanedToReaderId { get; private set; }
    public DateTime? LoanedAt { get; private set; }

    private Book() { } // для репозиториев

    public Book(Guid id, string title, string author, Isbn isbn)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new DomainException("Название книги обязательно");
        if (string.IsNullOrWhiteSpace(author))
            throw new DomainException("Автор обязателен");

        Id = id;
        Title = title.Trim();
        Author = author.Trim();
        Isbn = isbn;
        Status = BookStatus.Available;
    }

    public void Loan(Guid readerId)
    {
        if (Status != BookStatus.Available)
            throw new DomainException($"Книга недоступна: {Status}");
        Status = BookStatus.Loaned;
        LoanedToReaderId = readerId;
        LoanedAt = DateTime.UtcNow;
    }

    public void Return()
    {
        if (Status != BookStatus.Loaned)
            throw new DomainException("Книга не была выдана");
        Status = BookStatus.Available;
        LoanedToReaderId = null;
        LoanedAt = null;
    }

    public void MarkLost()
    {
        if (Status != BookStatus.Loaned)
            throw new DomainException("Потерять можно только выданную книгу");
        Status = BookStatus.Lost;
    }
}
```

### `Domain/Models/Reader.cs`

```csharp
using MyApp.Domain.Exceptions;

namespace MyApp.Domain.Models;

public class Reader
{
    private readonly List<Guid> _borrowedBookIds = new();

    public Guid Id { get; private set; }
    public string FullName { get; private set; } = default!;
    public string Email { get; private set; } = default!;
    public IReadOnlyCollection<Guid> BorrowedBookIds => _borrowedBookIds;

    private Reader() { }

    public Reader(Guid id, string fullName, string email)
    {
        if (string.IsNullOrWhiteSpace(fullName))
            throw new DomainException("Имя читателя обязательно");
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            throw new DomainException("Некорректный email");

        Id = id;
        FullName = fullName.Trim();
        Email = email.Trim();
    }

    public void AttachBook(Guid bookId) => _borrowedBookIds.Add(bookId);
    public void DetachBook(Guid bookId) => _borrowedBookIds.Remove(bookId);
}
```

**Проверка:** `Domain` не ссылается ни на один другой проект. Правила — внутри методов (`Loan`, `Return`, `MarkLost`).

---

## 3. Application — сценарии

**Что тут:** команды, запросы, обработчики, интерфейсы репозиториев. **Никаких** `DbContext`, `HttpClient`, UI.

### `Application/Abstractions/IBookRepository.cs`

```csharp
using MyApp.Domain.Models;

namespace MyApp.Application.Abstractions;

public interface IBookRepository
{
    Task<Book?> GetByIdAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<Book>> GetAllAsync(CancellationToken ct);
    Task AddAsync(Book book, CancellationToken ct);
    Task UpdateAsync(Book book, CancellationToken ct);
}
```

### `Application/Abstractions/IReaderRepository.cs`

```csharp
using MyApp.Domain.Models;

namespace MyApp.Application.Abstractions;

public interface IReaderRepository
{
    Task<Reader?> GetByIdAsync(Guid id, CancellationToken ct);
    Task AddAsync(Reader reader, CancellationToken ct);
    Task UpdateAsync(Reader reader, CancellationToken ct);
}
```

### `Application/Books/AddBookCommand.cs`

```csharp
namespace MyApp.Application.Books;

public record AddBookCommand(string Title, string Author, string Isbn);
```

### `Application/Books/AddBookHandler.cs`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Models;
using MyApp.Domain.ValueObjects;

namespace MyApp.Application.Books;

public class AddBookHandler
{
    private readonly IBookRepository _books;
    public AddBookHandler(IBookRepository books) => _books = books;

    public async Task<Guid> HandleAsync(AddBookCommand cmd, CancellationToken ct)
    {
        var book = new Book(Guid.NewGuid(), cmd.Title, cmd.Author, Isbn.Create(cmd.Isbn));
        await _books.AddAsync(book, ct);
        return book.Id;
    }
}
```

### `Application/Books/GetBooksQuery.cs` и `Handler`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Models;

namespace MyApp.Application.Books;

public record GetBooksQuery(bool OnlyAvailable = false);

public class GetBooksHandler
{
    private readonly IBookRepository _books;
    public GetBooksHandler(IBookRepository books) => _books = books;

    public async Task<IReadOnlyList<Book>> HandleAsync(GetBooksQuery q, CancellationToken ct)
    {
        var all = await _books.GetAllAsync(ct);
        return q.OnlyAvailable
            ? all.Where(b => b.Status == Domain.Enums.BookStatus.Available).ToList()
            : all;
    }
}
```

### `Application/Loans/LoanBookCommand.cs` и `Handler`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Exceptions;

namespace MyApp.Application.Loans;

public record LoanBookCommand(Guid BookId, Guid ReaderId);

public class LoanBookHandler
{
    private readonly IBookRepository _books;
    private readonly IReaderRepository _readers;

    public LoanBookHandler(IBookRepository books, IReaderRepository readers)
        => (_books, _readers) = (books, readers);

    public async Task HandleAsync(LoanBookCommand cmd, CancellationToken ct)
    {
        var book = await _books.GetByIdAsync(cmd.BookId, ct)
            ?? throw new DomainException("Книга не найдена");
        var reader = await _readers.GetByIdAsync(cmd.ReaderId, ct)
            ?? throw new DomainException("Читатель не найден");

        book.Loan(reader.Id);
        reader.AttachBook(book.Id);

        await _books.UpdateAsync(book, ct);
        await _readers.UpdateAsync(reader, ct);
    }
}
```

### `Application/Loans/ReturnBookCommand.cs` и `Handler`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Exceptions;

namespace MyApp.Application.Loans;

public record ReturnBookCommand(Guid BookId);

public class ReturnBookHandler
{
    private readonly IBookRepository _books;
    private readonly IReaderRepository _readers;

    public ReturnBookHandler(IBookRepository books, IReaderRepository readers)
        => (_books, _readers) = (books, readers);

    public async Task HandleAsync(ReturnBookCommand cmd, CancellationToken ct)
    {
        var book = await _books.GetByIdAsync(cmd.BookId, ct)
            ?? throw new DomainException("Книга не найдена");

        var readerId = book.LoanedToReaderId;
        book.Return();

        if (readerId is Guid rid)
        {
            var reader = await _readers.GetByIdAsync(rid, ct);
            reader?.DetachBook(book.Id);
            if (reader is not null) await _readers.UpdateAsync(reader, ct);
        }

        await _books.UpdateAsync(book, ct);
    }
}
```

### `Application/ApplicationExtensions.cs`

```csharp
using Microsoft.Extensions.DependencyInjection;
using MyApp.Application.Books;
using MyApp.Application.Loans;

namespace MyApp.Application;

public static class ApplicationExtensions
{
    public static IServiceCollection AddApplication(this IServiceCollection s)
    {
        s.AddTransient<AddBookHandler>();
        s.AddTransient<GetBooksHandler>();
        s.AddTransient<LoanBookHandler>();
        s.AddTransient<ReturnBookHandler>();
        return s;
    }
}
```

**Проверка:** Application не знает, где хранятся данные. Только интерфейсы.

---

## 4. Infrastructure — реализация

**Что тут:** конкретные репозитории (InMemory, EF, JSON), внешние сервисы, работа с файлами.

### `Infrastructure/Persistence/InMemoryBookRepository.cs`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Models;

namespace MyApp.Infrastructure.Persistence;

public class InMemoryBookRepository : IBookRepository
{
    private readonly Dictionary<Guid, Book> _store = new();

    public Task<Book?> GetByIdAsync(Guid id, CancellationToken ct)
        => Task.FromResult(_store.TryGetValue(id, out var b) ? b : null);

    public Task<IReadOnlyList<Book>> GetAllAsync(CancellationToken ct)
        => Task.FromResult<IReadOnlyList<Book>>(_store.Values.ToList());

    public Task AddAsync(Book book, CancellationToken ct)
    {
        _store[book.Id] = book;
        return Task.CompletedTask;
    }

    public Task UpdateAsync(Book book, CancellationToken ct)
    {
        _store[book.Id] = book;
        return Task.CompletedTask;
    }
}
```

### `Infrastructure/Persistence/InMemoryReaderRepository.cs`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Domain.Models;

namespace MyApp.Infrastructure.Persistence;

public class InMemoryReaderRepository : IReaderRepository
{
    private readonly Dictionary<Guid, Reader> _store = new();

    public Task<Reader?> GetByIdAsync(Guid id, CancellationToken ct)
        => Task.FromResult(_store.TryGetValue(id, out var r) ? r : null);

    public Task AddAsync(Reader reader, CancellationToken ct)
    {
        _store[reader.Id] = reader;
        return Task.CompletedTask;
    }

    public Task UpdateAsync(Reader reader, CancellationToken ct)
    {
        _store[reader.Id] = reader;
        return Task.CompletedTask;
    }
}
```

### `Infrastructure/InfrastructureExtensions.cs`

```csharp
using Microsoft.Extensions.DependencyInjection;
using MyApp.Application.Abstractions;
using MyApp.Infrastructure.Persistence;

namespace MyApp.Infrastructure;

public static class InfrastructureExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection s)
    {
        s.AddSingleton<IBookRepository, InMemoryBookRepository>();
        s.AddSingleton<IReaderRepository, InMemoryReaderRepository>();
        return s;
    }
}
```

> Если позже захочется БД — заменяется одна строка: `AddSingleton<IBookRepository, EfBookRepository>()`. Application и Domain не тронуты.

---

## 5. Contracts — DTO

**Что тут:** только DTO и enum'ы. Никакой логики.

### `Contracts/BookDto.cs`

```csharp
namespace MyApp.Contracts;

public record BookDto(
    Guid Id,
    string Title,
    string Author,
    string Isbn,
    string Status,
    Guid? LoanedToReaderId,
    DateTime? LoanedAt);
```

### `Contracts/ReaderDto.cs`

```csharp
namespace MyApp.Contracts;

public record ReaderDto(Guid Id, string FullName, string Email, int BorrowedCount);
```

### `Contracts/Requests.cs`

```csharp
namespace MyApp.Contracts;

public record AddBookRequest(string Title, string Author, string Isbn);
public record LoanBookRequest(Guid BookId, Guid ReaderId);
```

---

## 6. Client.Core — общая обвязка клиентов

**Что тут:** инфраструктура клиентов, одинаковая на всех платформах. **Никаких ViewModels.**

### `Client.Core/Services/IAppSettings.cs`

```csharp
namespace MyApp.Client.Core.Services;

public interface IAppSettings
{
    string CurrentUserName { get; }
    string CurrentUserRole { get; }  // Reader / Librarian / Spectator
}
```

### `Client.Core/Services/AppSettings.cs`

```csharp
namespace MyApp.Client.Core.Services;

public class AppSettings : IAppSettings
{
    public string CurrentUserName { get; set; } = "Гость";
    public string CurrentUserRole { get; set; } = "Reader";
}
```

### `Client.Core/Services/IBookCatalogService.cs`

```csharp
using MyApp.Contracts;

namespace MyApp.Client.Core.Services;

public interface IBookCatalogService
{
    Task<IReadOnlyList<BookDto>> GetBooksAsync(bool onlyAvailable, CancellationToken ct = default);
    Task<Guid> AddBookAsync(AddBookRequest req, CancellationToken ct = default);
    Task LoanAsync(LoanBookRequest req, CancellationToken ct = default);
    Task ReturnAsync(Guid bookId, CancellationToken ct = default);
}
```

### `Client.Core/Services/InMemoryBookCatalogService.cs`

> На соревновании быстрее всего работать с теми же handlers, что и сервер. Ниже — вариант «всё локально в одном процессе».

```csharp
using MyApp.Application.Books;
using MyApp.Application.Loans;
using MyApp.Contracts;

namespace MyApp.Client.Core.Services;

public class InMemoryBookCatalogService : IBookCatalogService
{
    private readonly AddBookHandler _addBook;
    private readonly GetBooksHandler _getBooks;
    private readonly LoanBookHandler _loan;
    private readonly ReturnBookHandler _return;

    public InMemoryBookCatalogService(
        AddBookHandler addBook,
        GetBooksHandler getBooks,
        LoanBookHandler loan,
        ReturnBookHandler @return)
        => (_addBook, _getBooks, _loan, _return) = (addBook, getBooks, loan, @return);

    public async Task<IReadOnlyList<BookDto>> GetBooksAsync(bool onlyAvailable, CancellationToken ct = default)
    {
        var books = await _getBooks.HandleAsync(new GetBooksQuery(onlyAvailable), ct);
        return books.Select(b => new BookDto(
            b.Id, b.Title, b.Author, b.Isbn.Value,
            b.Status.ToString(), b.LoanedToReaderId, b.LoanedAt)).ToList();
    }

    public async Task<Guid> AddBookAsync(AddBookRequest req, CancellationToken ct = default)
        => await _addBook.HandleAsync(new AddBookCommand(req.Title, req.Author, req.Isbn), ct);

    public Task LoanAsync(LoanBookRequest req, CancellationToken ct = default)
        => _loan.HandleAsync(new LoanBookCommand(req.BookId, req.ReaderId), ct);

    public Task ReturnAsync(Guid bookId, CancellationToken ct = default)
        => _return.HandleAsync(new ReturnBookCommand(bookId), ct);
}
```

### `Client.Core/ClientCoreExtensions.cs`

```csharp
using Microsoft.Extensions.DependencyInjection;
using MyApp.Application;
using MyApp.Client.Core.Services;
using MyApp.Infrastructure;

namespace MyApp.Client.Core;

public static class ClientCoreExtensions
{
    public static IServiceCollection AddAppClientCore(this IServiceCollection s)
    {
        s.AddApplication();
        s.AddInfrastructure();
        s.AddSingleton<IAppSettings, AppSettings>();
        s.AddSingleton<IBookCatalogService, InMemoryBookCatalogService>();
        return s;
    }
}
```

**Правило:** `AddAppClientCore` регистрирует всё, что одинаково на всех платформах. Клиенты вызывают один метод и не разбираются с деталями.

---

## 7. Web — клиент студента (читателя)

**Роль:** читатель ищет книгу, смотрит каталог, берёт/возвращает. **Не может** добавлять новые книги.

### `Web/ViewModels/CatalogViewModel.cs`

```csharp
using MyApp.Client.Core.Services;
using MyApp.Contracts;

namespace MyApp.Web.ViewModels;

public class CatalogViewModel
{
    private readonly IBookCatalogService _catalog;

    public List<BookDto> Books { get; private set; } = new();
    public bool OnlyAvailable { get; set; }
    public string SearchQuery { get; set; } = "";
    public string? Error { get; private set; }

    public CatalogViewModel(IBookCatalogService catalog) => _catalog = catalog;

    public async Task LoadAsync()
    {
        Error = null;
        try
        {
            var all = await _catalog.GetBooksAsync(OnlyAvailable);
            Books = string.IsNullOrWhiteSpace(SearchQuery)
                ? all.ToList()
                : all.Where(b =>
                    b.Title.Contains(SearchQuery, StringComparison.OrdinalIgnoreCase) ||
                    b.Author.Contains(SearchQuery, StringComparison.OrdinalIgnoreCase)).ToList();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }

    public async Task ReturnAsync(Guid bookId)
    {
        await _catalog.ReturnAsync(bookId);
        await LoadAsync();
    }
}
```

### `Web/Pages/Catalog.razor`

```razor
@page "/catalog"
@using MyApp.Web.ViewModels
@inject CatalogViewModel VM

<h3>Каталог книг</h3>

<div>
    <input @bind="VM.SearchQuery" placeholder="Поиск..." />
    <label>
        <input type="checkbox" @bind="VM.OnlyAvailable" /> Только доступные
    </label>
    <button @onclick="VM.LoadAsync">Найти</button>
</div>

@if (VM.Error is not null) { <p class="error">@VM.Error</p> }

<table>
    <thead><tr><th>Название</th><th>Автор</th><th>Статус</th><th></th></tr></thead>
    <tbody>
    @foreach (var b in VM.Books)
    {
        <tr>
            <td>@b.Title</td>
            <td>@b.Author</td>
            <td>@b.Status</td>
            <td>
                @if (b.Status == "Loaned")
                {
                    <button @onclick="() => VM.ReturnAsync(b.Id)">Вернуть</button>
                }
            </td>
        </tr>
    }
    </tbody>
</table>

@code {
    protected override Task OnInitializedAsync() => VM.LoadAsync();
}
```

### `Web/Program.cs`

```csharp
using MyApp.Client.Core;
using MyApp.Web.ViewModels;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddAppClientCore();
builder.Services.AddScoped<CatalogViewModel>();

var app = builder.Build();
app.MapBlazorHub();
app.MapFallbackToPage("/_Host");
app.Run();
```

**Что видит читатель:** только каталог. Никаких админских кнопок.

---

## 8. Desktop — клиент жюри (библиотекаря)

**Роль:** добавляет книги, выдаёт, помечает потерянными. Полный доступ.

### `Desktop/ViewModels/LibrarianViewModel.cs`

```csharp
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyApp.Client.Core.Services;
using MyApp.Contracts;

namespace MyApp.Desktop.ViewModels;

public partial class LibrarianViewModel : ObservableObject
{
    private readonly IBookCatalogService _catalog;

    [ObservableProperty] private string title = "";
    [ObservableProperty] private string author = "";
    [ObservableProperty] private string isbn = "";
    [ObservableProperty] private string? error;

    public ObservableCollection<BookDto> Books { get; } = new();

    public LibrarianViewModel(IBookCatalogService catalog) => _catalog = catalog;

    [RelayCommand]
    public async Task LoadAsync()
    {
        Books.Clear();
        foreach (var b in await _catalog.GetBooksAsync(false))
            Books.Add(b);
    }

    [RelayCommand]
    public async Task AddAsync()
    {
        Error = null;
        try
        {
            await _catalog.AddBookAsync(new AddBookRequest(Title, Author, Isbn));
            Title = Author = Isbn = "";
            await LoadAsync();
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }

    [RelayCommand]
    public async Task LoanAsync(BookDto book)
    {
        // В реальной программе — диалог выбора читателя
        var readerId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        await _catalog.LoanAsync(new LoanBookRequest(book.Id, readerId));
        await LoadAsync();
    }
}
```

### `Desktop/Views/LibrarianView.axaml`

```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.Desktop.Views.LibrarianView">
  <Grid RowDefinitions="Auto,Auto,*" Margin="12">
    <StackPanel Grid.Row="0" Orientation="Horizontal" Spacing="8">
      <TextBox Watermark="Название" Text="{Binding Title}" Width="200"/>
      <TextBox Watermark="Автор" Text="{Binding Author}" Width="200"/>
      <TextBox Watermark="ISBN" Text="{Binding Isbn}" Width="150"/>
      <Button Content="Добавить" Command="{Binding AddCommand}"/>
    </StackPanel>

    <TextBlock Grid.Row="1" Text="{Binding Error}" Foreground="Red" Margin="0,8"/>

    <DataGrid Grid.Row="2" ItemsSource="{Binding Books}" AutoGenerateColumns="False">
      <DataGrid.Columns>
        <DataGridTextColumn Header="Название" Binding="{Binding Title}"/>
        <DataGridTextColumn Header="Автор" Binding="{Binding Author}"/>
        <DataGridTextColumn Header="Статус" Binding="{Binding Status}"/>
      </DataGrid.Columns>
    </DataGrid>
  </Grid>
</UserControl>
```

### `Desktop/App.axaml.cs`

```csharp
public override void OnFrameworkInitializationCompleted()
{
    var services = new ServiceCollection();
    services.AddAppClientCore();
    services.AddTransient<LibrarianViewModel>();
    services.AddTransient<LibrarianView>();
    var provider = services.BuildServiceProvider();

    if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
    {
        desktop.MainWindow = new MainWindow
        {
            DataContext = provider.GetRequiredService<LibrarianViewModel>()
        };
    }
    base.OnFrameworkInitializationCompleted();
}
```

**Что видит библиотекарь:** форма добавления + полный список + операции. Ничего общего с UI читателя, кроме DTO.

---

## 9. Mobile — клиент зрителя

**Роль:** только просмотр каталога и статуса. Никаких действий.

### `Mobile/ViewModels/SpectatorViewModel.cs`

```csharp
using System.Collections.ObjectModel;
using System.Windows.Input;
using MyApp.Client.Core.Services;
using MyApp.Contracts;

namespace MyApp.Mobile.ViewModels;

public class SpectatorViewModel
{
    private readonly IBookCatalogService _catalog;

    public ObservableCollection<BookDto> AvailableBooks { get; } = new();
    public ICommand RefreshCommand { get; }

    public SpectatorViewModel(IBookCatalogService catalog)
    {
        _catalog = catalog;
        RefreshCommand = new Command(async () => await RefreshAsync());
    }

    public async Task RefreshAsync()
    {
        AvailableBooks.Clear();
        foreach (var b in await _catalog.GetBooksAsync(onlyAvailable: true))
            AvailableBooks.Add(b);
    }
}
```

### `Mobile/Pages/SpectatorPage.xaml`

```xml
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             x:Class="MyApp.Mobile.Pages.SpectatorPage"
             Title="Доступные книги">
  <StackLayout Padding="12">
    <Button Text="Обновить" Command="{Binding RefreshCommand}"/>
    <CollectionView ItemsSource="{Binding AvailableBooks}">
      <CollectionView.ItemTemplate>
        <DataTemplate>
          <Frame Margin="0,4">
            <VerticalStackLayout>
              <Label Text="{Binding Title}" FontAttributes="Bold"/>
              <Label Text="{Binding Author}" FontSize="12"/>
            </VerticalStackLayout>
          </Frame>
        </DataTemplate>
      </CollectionView.ItemTemplate>
    </CollectionView>
  </StackLayout>
</ContentPage>
```

### `Mobile/MauiProgram.cs`

```csharp
public static MauiApp CreateMauiApp()
{
    var builder = MauiApp.CreateBuilder();
    builder.UseMauiApp<App>();

    builder.Services.AddAppClientCore();
    builder.Services.AddTransient<SpectatorViewModel>();
    builder.Services.AddTransient<SpectatorPage>();

    return builder.Build();
}
```

**Что видит зритель:** только список доступных книг. Три таргета — три разных UI, но **один** `IBookCatalogService`.

---

## 10. Тесты

### `Domain.Tests/BookTests.cs`

```csharp
using MyApp.Domain.Enums;
using MyApp.Domain.Exceptions;
using MyApp.Domain.Models;
using MyApp.Domain.ValueObjects;
using Xunit;

public class BookTests
{
    private static Book CreateBook()
        => new(Guid.NewGuid(), "CLR via C#", "Джеффри Рихтер", Isbn.Create("9780735667457"));

    [Fact]
    public void New_book_is_available()
    {
        var book = CreateBook();
        Assert.Equal(BookStatus.Available, book.Status);
    }

    [Fact]
    public void Loan_sets_loaned_status()
    {
        var book = CreateBook();
        var readerId = Guid.NewGuid();

        book.Loan(readerId);

        Assert.Equal(BookStatus.Loaned, book.Status);
        Assert.Equal(readerId, book.LoanedToReaderId);
    }

    [Fact]
    public void Cannot_loan_already_loaned_book()
    {
        var book = CreateBook();
        book.Loan(Guid.NewGuid());

        Assert.Throws<DomainException>(() => book.Loan(Guid.NewGuid()));
    }
}
```

### `Application.Tests/LoanBookHandlerTests.cs`

```csharp
using MyApp.Application.Abstractions;
using MyApp.Application.Loans;
using MyApp.Domain.Models;
using MyApp.Domain.ValueObjects;

public class LoanBookHandlerTests
{
    [Fact]
    public async Task Loan_updates_both_book_and_reader()
    {
        var books = new FakeBookRepo();
        var readers = new FakeReaderRepo();

        var book = new Book(Guid.NewGuid(), "T", "A", Isbn.Create("9780735667457"));
        var reader = new Reader(Guid.NewGuid(), "Иван", "i@e.com");
        await books.AddAsync(book, default);
        await readers.AddAsync(reader, default);

        var handler = new LoanBookHandler(books, readers);
        await handler.HandleAsync(new LoanBookCommand(book.Id, reader.Id), default);

        Assert.Contains(book.Id, reader.BorrowedBookIds);
        Assert.Equal(reader.Id, book.LoanedToReaderId);
    }

    private class FakeBookRepo : IBookRepository
    {
        private readonly Dictionary<Guid, Book> _d = new();
        public Task<Book?> GetByIdAsync(Guid id, CancellationToken ct) => Task.FromResult(_d.GetValueOrDefault(id));
        public Task<IReadOnlyList<Book>> GetAllAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<Book>>(_d.Values.ToList());
        public Task AddAsync(Book b, CancellationToken ct) { _d[b.Id] = b; return Task.CompletedTask; }
        public Task UpdateAsync(Book b, CancellationToken ct) { _d[b.Id] = b; return Task.CompletedTask; }
    }

    private class FakeReaderRepo : IReaderRepository
    {
        private readonly Dictionary<Guid, Reader> _d = new();
        public Task<Reader?> GetByIdAsync(Guid id, CancellationToken ct) => Task.FromResult(_d.GetValueOrDefault(id));
        public Task AddAsync(Reader r, CancellationToken ct) { _d[r.Id] = r; return Task.CompletedTask; }
        public Task UpdateAsync(Reader r, CancellationToken ct) { _d[r.Id] = r; return Task.CompletedTask; }
    }
}
```

> Тесты пишутся **только для Domain и Application**. UI не тестируем на соревновании.

---

## 11. DI и стартовые файлы

### Полная схема регистрации

```
Каждый клиент:
   services.AddAppClientCore();   // ← одна строка
   // + свои ViewModels / Pages
```

`AddAppClientCore()` внутри делает:

```csharp
s.AddApplication();      // handlers
s.AddInfrastructure();   // репозитории
s.AddSingleton<IAppSettings, AppSettings>();
s.AddSingleton<IBookCatalogService, InMemoryBookCatalogService>();
```

### Преимущества такой схемы

- **Одна точка входа.** Студент меняет хранилище в `InfrastructureExtensions` — и всё работает на всех клиентах.
- **Клиенты не знают про handlers.** Только `IBookCatalogService`.
- **Легко заменить реализацию.** InMemory → HTTP → EF: правится один метод.

### Пример перехода на HTTP-клиент

```csharp
// Client.Core/Services/HttpBookCatalogService.cs
public class HttpBookCatalogService : IBookCatalogService
{
    private readonly HttpClient _http;
    public HttpBookCatalogService(HttpClient http) => _http = http;

    public async Task<IReadOnlyList<BookDto>> GetBooksAsync(bool onlyAvailable, CancellationToken ct = default)
        => await _http.GetFromJsonAsync<List<BookDto>>($"api/books?onlyAvailable={onlyAvailable}", ct)
           ?? new List<BookDto>();

    // ...
}
```

Замена в `ClientCoreExtensions`:

```csharp
// было:
s.AddSingleton<IBookCatalogService, InMemoryBookCatalogService>();
// стало:
s.AddHttpClient<IBookCatalogService, HttpBookCatalogService>(c => c.BaseAddress = new Uri("https://localhost:5001/"));
```

Клиенты **не меняются**. Это и есть смысл архитектуры.

---

### Типичные ошибки

| Ошибка | Как исправить |
|--------|---------------|
| Логика в `.razor` / `.axaml.cs` | Перенести в Domain/Application, вызвать через ViewModel |
| Домен ссылается на EF Core | Убрать атрибуты, вынести конфигурации в Infrastructure |
| Общий `BookDto`-с-логикой | Разделить: `BookDto` (данные) и `BookViewModel` (UI) |
| `IBookRepository` в клиенте | Клиент работает только с `IBookCatalogService` |
| Один handler на 5 операций | Один сценарий = один handler |
| `catch (Exception) {}` | Логировать и пробрасывать либо возвращать Result |
| `new HttpClient()` в сервисе | Использовать `IHttpClientFactory` / `AddHttpClient<T>` |
| All-in-one проект | Разбить: минимум Domain + Application + Infrastructure + один клиент |
---
