# UniversityAdmissions

Estructura inicial de backend ASP.NET Core (.NET 10), sin funcionalidades de negocio.

- Api: controllers, middleware, contratos y composición.
- Application: servicios, DTOs, abstracciones y validaciones.
- Domain: entidades y reglas.
- Infrastructure: persistencia y servicios externos.
- tests: proyectos xUnit para pruebas unitarias y de integración; todavía sin pruebas.

Base de datos vacía: UniversityAdmissions, en (localdb)\MSSQLLocalDB, con autenticación integrada de Windows.
La cadena está en src/UniversityAdmissions.Api/appsettings.Development.json. La conexión EF Core, las tablas y las migraciones quedan pendientes de definir el modelo.
Script de creación idempotente: database/CreateDatabase.sql.

Comandos: dotnet restore, dotnet build, dotnet test.
