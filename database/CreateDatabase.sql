USE [master];
GO
IF DB_ID(N'UniversityAdmissions') IS NULL
BEGIN
    CREATE DATABASE [UniversityAdmissions];
END;
GO
