# AdventureWorksDemo — Setup Guide

This guide sets up two Docker SQL Server 2025 instances and a Flyway CLI project from scratch.

---

## Prerequisites

- Docker Desktop installed and running (Windows 11)
- Flyway CLI installed (v12+) and on PATH
- SQL Server Management Studio (SSMS 19+)
- `AdventureWorksLT2025.bak` backup file

---

## Setup reference material:

## Description: restore.sh

This script starts SQL Server and automatically restores the AdventureWorks backup on first boot.

File: `C:\Flyway\AdventureWorksDemo\restore.sh`

> **Note:** The logical file names in this .bak are `AdventureWorksLT2022_Data` / `AdventureWorksLT2022_Log`.
> If you use a different .bak, verify the names first with:
> `RESTORE FILELISTONLY FROM DISK = '/var/opt/mssql/backup/AdventureWorksLT2025.bak'`

---

## Description: init.sh

Simple startup script for the target (deployment) container.

File: `C:\Flyway\AdventureWorksDemo\init.sh`

---

## Description: docker-compose.yml

File: `C:\Flyway\AdventureWorksDemo\docker-compose.yml`

> **Why `user: root`?** SQL Server 2025 containers run as the `mssql` user by default, which cannot
> initialise a fresh named volume on Docker Desktop for Windows due to file permission restrictions.
>
> **Why SQL Server 2025?** The `AdventureWorksLT2025.bak` was created on database version 998.
> SQL Server 2022 only supports up to version 958 and will reject the restore.
>
> **Why custom ports?** Ports 1999 (source) and 1989 (target) avoid conflicts with any local SQL Server
> instance already running on the default port 1433.

---

## Step 1 — Create the project folder if not created already

```powershell
mkdir C:\Flyway\AdventureWorksDemo
```

Place `AdventureWorksLT2025.bak` in that folder (if not present already).

---

## Step 2 — Start the containers

```powershell
cd C:\Flyway\AdventureWorksDemo
docker compose up -d
```

Wait ~30 seconds for the source container to restore AdventureWorks, then verify both are healthy:

```powershell
docker compose ps
```

Both containers should show `(healthy)`.

---

## Step 3 — Connect with SSMS (optional verification)

| Instance | Server name      | Login | Password    |
|----------|------------------|-------|-------------|
| Source   | `localhost,1999` | sa    | Flyway2025! |
| Target   | `localhost,1989` | sa    | Flyway2025! |

In the SSMS connection dialog: **Options >> Connection Properties >> Trust server certificate: ✓**

> Do NOT use `C:\...` Windows paths when browsing for files in SSMS — the containers only see
> their own internal filesystem. The restore is handled automatically at container startup.

---

## Step 4 — Create the Flyway project

```powershell
mkdir C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway
cd C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway
flyway init "-init.projectName=AdventureWorksDemo" "-init.databaseType=sqlserver"
md callbacks ##Bug where folder does not get created
```

> **PowerShell note:** Parameters containing dots (`.`) must be wrapped in double quotes, otherwise
> PowerShell misinterprets them. This applies to all `flyway` commands below.

---

## Step 5 — Configure environments

Add the three environment blocks to `flyway.toml` (passwords are kept separate):

```toml
[environments.development]
url = "jdbc:sqlserver://localhost:1999;databaseName=AdventureWorksLT2025;encrypt=true;trustServerCertificate=true"
user = "sa"

[environments.target]
url = "jdbc:sqlserver://localhost:1989;databaseName=AdventureWorksLT2025;encrypt=true;trustServerCertificate=true"
user = "sa"

[environments.shadow]
url = "jdbc:sqlserver://localhost:1989;databaseName=FlywayShadow;encrypt=true;trustServerCertificate=true"
user = "sa"
```

Create (or populate) `flyway.user.toml` with passwords — this file is gitignored by default:

```toml
[environments.development]
password = "Flyway2025!"

[environments.target]
password = "Flyway2025!"

[environments.shadow]
password = "Flyway2025!"
```

| Environment | Container                    | Database             | Purpose                             |
|-------------|------------------------------|----------------------|-------------------------------------|
| development | adventureworks-source (1999) | AdventureWorksLT2025 | Source of truth, developer sandbox  |
| target      | adventureworks-target (1989) | AdventureWorksLT2025 | Deployment target                   |
| shadow      | adventureworks-target (1989) | FlywayShadow         | Flyway drift detection              |

---

## Step 6 — Activate Flyway Enterprise

The `diff`, `model`, `snapshot`, and `generate` commands require Flyway Enterprise or Teams.

Authenticate with your Redgate account:

```powershell
flyway auth -IAgreeToTheEula
```

If no Enterprise license is allocated to your account in the Redgate portal, start a free 28-day trial:

```powershell
flyway auth -startEnterpriseTrial -IAgreeToTheEula
```

---

## Step 7 — Import the existing database into the schema model

Diff the development database against the empty schema model to detect all objects, then write them out as individual SQL files:

```powershell
cd C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway
flyway diff "-diff.source=development" "-diff.target=schemaModel" "-environment=development"
flyway model "-diff.artifactFilename=%temp%\flyway.artifact.diff"
```

This populates the `schema-model\` directory with one `.sql` file per database object — tables, views,
functions, stored procedures, types, schemas, etc.

---

## Step 8 — Generate the baseline migration

Diff the schema model against empty to produce a create-everything script, then generate the baseline migration:

```powershell
flyway diff "-diff.source=schemaModel" "-diff.target=empty"
flyway generate "-generate.types=baseline" "-generate.description=AdventureWorksLT2025_Baseline"
```

This creates `migrations\B001_<timestamp>__AdventureWorksLT2025_Baseline.sql`.

Also create the callbacks folder to avoid a harmless warning from flyway.toml:

```powershell
mkdir C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\callbacks
```

---

## Step 9 — Create the target database and deploy

Flyway cannot create a SQL Server database automatically — create it first:

```powershell
docker exec adventureworks-target bash -c "/opt/mssql-tools18/bin/sqlcmd -S 'localhost,1989' -U sa -P 'Flyway2025!' -No -C -Q 'CREATE DATABASE AdventureWorksLT2025'"
```

Then run the migration:

```powershell
cd C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway
flyway migrate "-environment=target"
```

Flyway will create the `flyway_schema_history` tracking table, run the baseline migration, and build
the full AdventureWorks schema on the target from scratch.

---

## Step 10 — Apply a schema change and migrate to target

This step demonstrates the full Flyway migration workflow using `Demo-NewTable-Source.sql`, which
creates a new table on the source database.

### 10a — Apply the change to source

Copy the script into the source container and run it:

```powershell
docker cp "C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\Demo-NewTable-Source.sql" adventureworks-source:/tmp/Demo-NewTable-Source.sql

docker exec adventureworks-source bash -c "/opt/mssql-tools18/bin/sqlcmd -S 'localhost,1999' -U sa -P 'Flyway2025!' -No -C -i '/tmp/Demo-NewTable-Source.sql'"
```

Or run `Demo-NewTable-Source.sql` directly from SSMS connected to `localhost,1999`.

### 10b — Detect the change

Compare the development database against the schema model:

```powershell
cd C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway
flyway diff "-diff.source=development" "-diff.target=schemaModel" "-environment=development"
```

The new table should appear as **Add** in the output.

### 10c — Update the schema model

```powershell
flyway model "-diff.artifactFilename=%temp%\flyway.artifact.diff"
```

### 10d — Confirm what target is missing

```powershell
flyway diff "-diff.source=schemaModel" "-diff.target=target" "-environment=target"
```

### 10e — Generate the versioned migration

```powershell
flyway generate "-generate.types=versioned,undo" "-generate.description=Add_ThisIsANewTableForFlywayDemo"
```

This creates `migrations\V002_<timestamp>__Add_ThisIsANewTableForFlywayDemo.sql`.

### 10f — Deploy to target

```powershell
flyway migrate "-environment=target"
```

### 10g — Verify

```powershell
flyway info "-environment=target"
```

---

## Result

| What               | Where                                                                           |
|--------------------|---------------------------------------------------------------------------------|
| Source SQL Server  | `localhost,1999` — AdventureWorksLT2025 (from .bak)                            |
| Target SQL Server  | `localhost,1989` — AdventureWorksLT2025 (from Flyway)                          |
| Flyway project     | `C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\`                            |
| Schema model       | `...\AdventureWorksFlyway\schema-model\`                                        |
| Baseline migration | `...\AdventureWorksFlyway\migrations\B001_*__AdventureWorksLT2025_Baseline.sql` |

To restart from scratch at any time:

```powershell
cd C:\Flyway\AdventureWorksDemo
docker compose down -v
docker compose up -d
del AdventureworksFlyway
```

Then re-run Step 9 to recreate the target database and deploy.
