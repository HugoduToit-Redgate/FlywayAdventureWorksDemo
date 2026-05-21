# Flyway Commands — AdventureWorksDemo

All commands run from `C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\`.

> **PowerShell note:** Parameters containing dots must be wrapped in double quotes.

---

## Authenticate

```powershell
flyway auth -IAgreeToTheEula
```

Start a free Enterprise trial if no license is allocated:

```powershell
flyway auth -startEnterpriseTrial -IAgreeToTheEula
```

---

## Import existing database into the schema model

Captures all objects from the development database and writes them as individual SQL files under `schema-model\`.

```powershell
flyway diff "-diff.source=development" "-diff.target=schemaModel" "-environment=development"
flyway model "-diff.artifactFilename=%temp%\flyway.artifact.diff"
```

---

## Generate the baseline migration

Produces a `B001_*__AdventureWorksLT2025_Baseline.sql` file in `migrations\` that creates the full schema from scratch.

```powershell
flyway diff "-diff.source=schemaModel" "-diff.target=empty"
flyway generate "-generate.types=baseline" "-generate.description=AdventureWorksLT2025_Baseline"
```

---

## Create the target database

Flyway cannot create a SQL Server database automatically — run this once before the first migrate:

```powershell
docker exec adventureworks-target bash -c "/opt/mssql-tools18/bin/sqlcmd -S 'localhost,1989' -U sa -P 'Flyway2025!' -No -C -Q 'CREATE DATABASE AdventureWorksLT2025'"
```

---

## Deploy to target

```powershell
flyway migrate "-environment=target"
```

---

## Useful extras

Check migration status:
```powershell
flyway info "-environment=target"
```

Validate applied migrations match scripts on disk:
```powershell
flyway validate "-environment=target"
```
