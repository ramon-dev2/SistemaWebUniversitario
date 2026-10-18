---
name: dotnet-university-backend
description: Diseña, estructura, implementa y revisa el backend .NET del Sistema Web Universitario de Admisiones y Consultas Académicas. Úsala para APIs, entidades, servicios, repositorios, EF Core, SQL Server, autenticación, reglas de negocio, pruebas, manejo de errores y estructura de solución. Debe aplicar arquitectura por capas con librerías de clases, Repository Pattern, Unit of Work, middleware global de excepciones y FriendlyException. No usar para frontend ni proyectos no-.NET.
---

# .NET University Backend

## Propósito

Desarrollar el backend del **Sistema Web Universitario de Admisiones y Consultas Académicas** con una arquitectura clara, mantenible y consistente.

Stack base:

- .NET 10.
- ASP.NET Core Web API.
- Entity Framework Core.
- SQL Server.
- Controllers.
- Dependency Injection nativa.
- Repository Pattern.
- Unit of Work.
- Middleware global de excepciones.
- `FriendlyException` para errores esperados.
- `ProblemDetails` para respuestas de error.
- `async/await` y `CancellationToken`.

No introducir CQRS, MediatR, AutoMapper, Redis, mensajería u otras dependencias/patrones salvo que el requerimiento lo justifique.

---

## 1. Arquitectura obligatoria

Usar proyectos separados mediante librerías de clases:

```text
UniversityAdmissions.sln

src/
├── UniversityAdmissions.Api/
│   ├── Controllers/
│   ├── Middleware/
│   ├── Extensions/
│   ├── Contracts/
│   ├── Program.cs
│   └── appsettings.json
│
├── UniversityAdmissions.Application/
│   ├── Abstractions/
│   │   ├── Persistence/
│   │   └── Services/
│   ├── DTOs/
│   ├── Services/
│   ├── Exceptions/
│   ├── Validators/
│   └── DependencyInjection.cs
│
├── UniversityAdmissions.Domain/
│   ├── Entities/
│   ├── Enums/
│   ├── ValueObjects/
│   ├── Rules/
│   └── Common/
│
└── UniversityAdmissions.Infrastructure/
    ├── Persistence/
    │   ├── ApplicationDbContext.cs
    │   ├── Configurations/
    │   ├── Repositories/
    │   └── Migrations/
    ├── Services/
    └── DependencyInjection.cs

tests/
├── UniversityAdmissions.UnitTests/
└── UniversityAdmissions.IntegrationTests/
```

### Responsabilidad por capa

**Domain**
- Entidades.
- Enums.
- Value Objects.
- Invariantes.
- Reglas centrales del negocio.
- No depende de ASP.NET Core, EF Core, Application ni Infrastructure.

**Application**
- Casos de uso.
- DTOs.
- Servicios.
- Interfaces de repositorios.
- `IUnitOfWork`.
- Validaciones.
- `FriendlyException`.
- Solo depende de Domain.

**Infrastructure**
- EF Core.
- SQL Server.
- `ApplicationDbContext`.
- Configuraciones de entidades.
- Repositorios.
- Unit of Work.
- Servicios externos.
- Depende de Application y Domain.

**Api**
- Controllers.
- Middleware.
- Autenticación/autorización.
- Configuración y composición de dependencias.
- Depende de Application e Infrastructure.
- No contiene reglas de negocio.

### Dependencias permitidas

```text
Api ─────────────► Application ─────────────► Domain
 │                       ▲
 └──────► Infrastructure ┘
             │
             └──────────────────────────────► Domain
```

Nunca permitir:

```text
Domain -> Infrastructure
Domain -> Api
Application -> Api
Application -> EF Core
Controller -> DbContext
Controller -> Repository
```

---

## 2. Repository Pattern

Las interfaces viven en:

```text
UniversityAdmissions.Application/Abstractions/Persistence/
```

Implementaciones:

```text
UniversityAdmissions.Infrastructure/Persistence/Repositories/
```

Repositorio genérico mínimo:

```csharp
public interface IRepository<TEntity>
    where TEntity : class
{
    Task<TEntity?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default);

    Task AddAsync(
        TEntity entity,
        CancellationToken cancellationToken = default);

    void Update(TEntity entity);

    void Remove(TEntity entity);
}
```

Crear repositorios específicos para consultas de negocio:

```csharp
public interface IAdmissionApplicationRepository
{
    Task<AdmissionApplication?> GetByTrackingCodeAsync(
        string trackingCode,
        CancellationToken cancellationToken = default);

    Task<bool> TrackingCodeExistsAsync(
        string trackingCode,
        CancellationToken cancellationToken = default);

    Task AddAsync(
        AdmissionApplication application,
        CancellationToken cancellationToken = default);
}
```

Reglas:

- Usar `AsNoTracking()` en lecturas.
- No devolver `IQueryable` fuera de Infrastructure.
- No exponer `DbSet`.
- No llamar `SaveChangesAsync()` dentro de cada repositorio.
- Evitar `GetAll()` sin filtro/paginación.
- Crear métodos específicos para consultas específicas.
- Propagar `CancellationToken`.

---

## 3. Unit of Work

Definir en Application:

```csharp
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(
        CancellationToken cancellationToken = default);
}
```

Implementar en Infrastructure usando `ApplicationDbContext`.

Reglas:

- El repositorio prepara cambios.
- El servicio de Application controla el commit.
- Preferir un `SaveChangesAsync()` por operación lógica.
- Usar transacciones explícitas solo cuando sean necesarias.

---

## 4. Servicios de Application

Los casos de uso deben vivir en servicios de Application.

Ejemplos:

```text
Application/Services/Admissions/AdmissionService.cs
Application/Services/Students/StudentAcademicService.cs
Application/Services/Grades/GradeService.cs
```

Un servicio debe:

1. recibir DTOs/parámetros;
2. validar;
3. consultar repositorios;
4. aplicar reglas;
5. modificar entidades;
6. llamar `IUnitOfWork`;
7. retornar DTOs;
8. lanzar `FriendlyException` ante errores esperados.

No devolver entidades EF desde Application hacia Api.

---

## 5. FriendlyException

Ubicación:

```text
UniversityAdmissions.Application/Exceptions/
```

Base:

```csharp
public abstract class FriendlyException : Exception
{
    protected FriendlyException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}
```

Tipos:

```text
FriendlyException
├── NotFoundFriendlyException
├── ValidationFriendlyException
├── ConflictFriendlyException
├── ForbiddenFriendlyException
└── BusinessRuleFriendlyException
```

Mapeo HTTP:

```text
NotFoundFriendlyException       -> 404
ValidationFriendlyException     -> 400
ConflictFriendlyException       -> 409
ForbiddenFriendlyException      -> 403
BusinessRuleFriendlyException   -> 422
UnauthorizedAccessException     -> 401
Exception desconocida           -> 500
```

Ejemplo:

```csharp
throw new NotFoundFriendlyException(
    "student.not_found",
    "No se encontró el estudiante solicitado.");
```

```csharp
throw new ConflictFriendlyException(
    "admission.already_exists",
    "Ya existe una solicitud de admisión activa para este aspirante.");
```

```csharp
throw new BusinessRuleFriendlyException(
    "admission.documents_required",
    "Debe completar los documentos requeridos antes de aprobar la solicitud.");
```

No incluir status codes HTTP dentro de Domain.

---

## 6. Middleware global de excepciones

Ubicación:

```text
UniversityAdmissions.Api/Middleware/ExceptionHandlingMiddleware.cs
```

Todos los errores deben pasar por el middleware.

No repetir `try/catch` en controllers.

Ejemplo base:

```csharp
public sealed class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(
        RequestDelegate next,
        ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception exception)
        {
            await HandleExceptionAsync(context, exception);
        }
    }

    private async Task HandleExceptionAsync(
        HttpContext context,
        Exception exception)
    {
        var (status, title, code) = exception switch
        {
            NotFoundFriendlyException ex =>
                (404, "Recurso no encontrado", ex.Code),

            ValidationFriendlyException ex =>
                (400, "Error de validación", ex.Code),

            ConflictFriendlyException ex =>
                (409, "Conflicto", ex.Code),

            ForbiddenFriendlyException ex =>
                (403, "Operación no permitida", ex.Code),

            BusinessRuleFriendlyException ex =>
                (422, "Regla de negocio", ex.Code),

            UnauthorizedAccessException =>
                (401, "No autorizado", "authorization.unauthorized"),

            _ =>
                (500, "Error interno", "server.internal_error")
        };

        var friendly = exception is FriendlyException;

        if (friendly)
        {
            _logger.LogWarning(
                "Handled error {Code}. TraceId: {TraceId}",
                code,
                context.TraceIdentifier);
        }
        else
        {
            _logger.LogError(
                exception,
                "Unhandled exception. TraceId: {TraceId}",
                context.TraceIdentifier);
        }

        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = friendly
                ? exception.Message
                : "Ha ocurrido un error interno. Intente nuevamente.",
            Instance = context.Request.Path
        };

        problem.Extensions["code"] = code;
        problem.Extensions["traceId"] = context.TraceIdentifier;

        context.Response.StatusCode = status;
        context.Response.ContentType = "application/problem+json";

        await context.Response.WriteAsJsonAsync(problem);
    }
}
```

Registrar:

```csharp
app.UseMiddleware<ExceptionHandlingMiddleware>();
```

No exponer en producción:

- stack traces;
- SQL;
- connection strings;
- rutas del servidor;
- inner exceptions;
- secretos/tokens;
- detalles internos de `DbUpdateException`.

---

## 7. Contrato de error

Usar `ProblemDetails`.

Ejemplo:

```json
{
  "type": "https://httpstatuses.com/404",
  "title": "Recurso no encontrado",
  "status": 404,
  "detail": "No se encontró el estudiante solicitado.",
  "instance": "/api/students/123",
  "code": "student.not_found",
  "traceId": "00-a1b2c3..."
}
```

Códigos sugeridos:

```text
admission.not_found
admission.already_exists
admission.documents_required
admission.invalid_status_transition
student.not_found
grade.not_found
grade.already_exists
grade.invalid_value
period.not_found
authorization.forbidden
validation.failed
```

Los códigos deben ser estables aunque cambie el texto del mensaje.

---

## 8. Controllers

Los controllers deben ser delgados.

Pueden:

- recibir la petición HTTP;
- usar model binding;
- llamar Application;
- aplicar autorización;
- retornar el resultado.

No pueden:

- acceder a `DbContext`;
- contener reglas de negocio;
- escribir queries EF;
- llamar repositorios directamente;
- tener `try/catch` globales;
- devolver entidades del dominio.

Ejemplo:

```csharp
[ApiController]
[Route("api/admissions")]
public sealed class AdmissionsController : ControllerBase
{
    private readonly IAdmissionService _service;

    public AdmissionsController(IAdmissionService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<ActionResult<AdmissionResponse>> Create(
        CreateAdmissionRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _service.CreateAsync(
            request,
            cancellationToken);

        return Created(string.Empty, result);
    }
}
```

---

## 9. DTOs

No exponer entidades.

```text
HTTP Request -> Request DTO -> Application -> Domain
Domain -> Application -> Response DTO -> HTTP Response
```

Preferir `record` para contratos simples:

```csharp
public sealed record CreateAdmissionRequest(
    string FirstName,
    string LastName,
    string Email);
```

Mapeo manual mientras el proyecto sea pequeño.

No agregar AutoMapper por defecto.

---

## 10. Entity Framework Core

Ubicación:

```text
Infrastructure/Persistence/
```

Estructura:

```text
Persistence/
├── ApplicationDbContext.cs
├── Configurations/
│   ├── AdmissionApplicationConfiguration.cs
│   ├── StudentConfiguration.cs
│   └── GradeConfiguration.cs
├── Repositories/
└── Migrations/
```

Usar `IEntityTypeConfiguration<TEntity>`.

Reglas:

- claves primarias explícitas;
- longitudes máximas;
- índices;
- índices únicos donde corresponda;
- relaciones configuradas con Fluent API;
- `DateTimeOffset` en UTC para fechas técnicas;
- `decimal` para notas con decimales;
- migraciones en Infrastructure.

Índices sugeridos:

```text
AdmissionApplication.TrackingCode -> UNIQUE
Student.StudentNumber             -> UNIQUE
User.Email                         -> UNIQUE
Grade(StudentId, CourseId, AcademicPeriodId) -> UNIQUE
```

---

## 11. Modelo inicial

Entidades sugeridas:

```text
Applicant
AdmissionApplication
AdmissionDocument
Student
AcademicPeriod
Course
Grade
User
Role
```

Estado de admisión:

```csharp
public enum AdmissionStatus
{
    Pending = 1,
    Approved = 2,
    Rejected = 3
}
```

Reglas principales:

- toda solicitud inicia `Pending`;
- tracking code único;
- no aprobar sin documentos requeridos;
- solo personal autorizado cambia estado;
- estudiante solo consulta sus notas;
- nota pertenece a estudiante + asignatura + período;
- evitar nota duplicada;
- auditar cambios sensibles.

---

## 12. Validación

Validar en Application:

- requeridos;
- longitudes;
- formatos;
- rangos;
- reglas de negocio.

No confiar solo en frontend.

Si ya existe FluentValidation, usarlo.

Si no existe, no agregarlo automáticamente: proponerlo primero o utilizar las herramientas existentes.

---

## 13. Autenticación y autorización

Cuando aplique:

- JWT Bearer o mecanismo definido;
- autorización por roles/policies;
- identidad obtenida desde `HttpContext.User`;
- no confiar en rol enviado por el request;
- proteger endpoints administrativos y de notas;
- verificar ownership para estudiantes.

Roles sugeridos:

```text
Administrator
AdmissionsStaff
AcademicStaff
Student
```

No guardar passwords en texto plano.

---

## 14. Logging

Usar `ILogger<T>` y logs estructurados:

```csharp
_logger.LogInformation(
    "Admission {ApplicationId} approved by {UserId}",
    application.Id,
    userId);
```

No usar interpolación para logs estructurados.

No registrar:

- passwords;
- access tokens;
- refresh tokens;
- connection strings;
- documentos sensibles completos.

---

## 15. Dependency Injection

Cada capa registra sus servicios.

Application:

```csharp
services.AddApplication();
```

Infrastructure:

```csharp
services.AddInfrastructure(configuration);
```

Mantener `Program.cs` pequeño.

---

## 16. API HTTP

Ejemplos:

```text
POST   /api/admissions
GET    /api/admissions/{trackingCode}/status

GET    /api/admin/admissions
GET    /api/admin/admissions/{id}
PATCH  /api/admin/admissions/{id}/status

GET    /api/students/me/grades
GET    /api/students/me/grades?periodId={id}
GET    /api/students/me/academic-history

POST   /api/grades
PUT    /api/grades/{id}
```

Códigos:

```text
200 OK
201 Created
204 No Content
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
409 Conflict
422 Unprocessable Entity
500 Internal Server Error
```

No devolver `200` para todos los resultados.

---

## 17. Seguridad técnica

Aplicar:

- HTTPS;
- parametrización de EF Core;
- autorización;
- validación de archivos;
- límite de tamaño;
- lista permitida de MIME/extensiones;
- nombres generados por servidor;
- secretos fuera del código;
- mínimo privilegio;
- protección de datos personales.

---

## 18. Pruebas

### Unit Tests

Probar Application y reglas:

- crear solicitud;
- aprobar sin documentos;
- solicitud inexistente;
- tracking code;
- nota duplicada;
- acceso académico.

### Integration Tests

Probar:

- repositorios EF Core;
- middleware de excepciones;
- endpoints;
- autorización;
- códigos HTTP;
- persistencia.

No usar EF Core InMemory como única prueba de comportamiento relacional.

---

## 19. Flujo obligatorio para cada feature

Cuando se solicite implementar algo:

1. Inspeccionar la solución existente.
2. Respetar convenciones actuales.
3. Identificar reglas de negocio.
4. Identificar capas afectadas.
5. Modificar Domain si cambia el modelo/regla.
6. Crear DTOs, interfaces y servicio en Application.
7. Implementar repositorios/configuración EF en Infrastructure.
8. Crear/actualizar endpoint en Api.
9. Usar `FriendlyException` en errores esperados.
10. Mantener el middleware como único manejador global.
11. Agregar pruebas.
12. Ejecutar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`
13. Corregir errores.
14. Resumir qué archivos fueron cambiados y por qué.

---

## 20. Reglas de código

Siempre:

- nullable reference types;
- `sealed` cuando no se necesita herencia;
- `CancellationToken`;
- async para I/O;
- nombres claros;
- métodos pequeños;
- DTOs;
- controllers delgados;
- manejo global de errores;
- código compilable.

Evitar:

- `catch (Exception)` dispersos;
- repositorios gigantes;
- lógica de negocio en controller;
- dependencias circulares;
- service locator;
- acceso directo al DbContext desde Api;
- entidades como responses;
- `async void`;
- `.Result`;
- `.Wait()`;
- abstraer por abstraer.

---

## 21. Decisiones ante ambigüedad

Si una decisión puede inferirse sin cambiar el comportamiento funcional, escoger la opción más simple y coherente.

Preguntar solo cuando falte una decisión importante sobre:

- autenticación;
- proveedor de base de datos;
- almacenamiento de documentos;
- escala de calificaciones;
- política de aprobación;
- integración externa;
- contrato API ya consumido.

No sobrearquitecturar el proyecto académico.

---

## 22. Checklist final

Antes de terminar:

- [ ] Capas y referencias correctas.
- [ ] Controller sin lógica de negocio.
- [ ] Api no accede al DbContext.
- [ ] Repository Pattern aplicado.
- [ ] Unit of Work controla `SaveChangesAsync`.
- [ ] I/O asíncrono.
- [ ] `CancellationToken`.
- [ ] FriendlyExceptions para errores esperados.
- [ ] Middleware global funcionando.
- [ ] 500 sin información interna.
- [ ] Códigos HTTP correctos.
- [ ] No se exponen entidades.
- [ ] `AsNoTracking` en lecturas.
- [ ] Autorización/ownership validados.
- [ ] Pruebas agregadas.
- [ ] `dotnet build` exitoso.
- [ ] `dotnet test` exitoso.
