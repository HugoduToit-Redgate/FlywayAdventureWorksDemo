# My First Flyway Migration — AdventureWorksDemo

This walkthrough applies a schema change to the source (development) database and uses Flyway to detect, script, and deploy that change to the target.

All `flyway` commands run from `C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\`.

> **PowerShell note:** Parameters containing dots must be wrapped in double quotes.

---

## The change

`Demo-NewTable-Source.sql` creates a new table on the source database:

```sql
CREATE TABLE ThisIsANewTableForFlywayDemo (TestColumn INT)
```

It includes a port guard — it only executes if connected to the source instance (`localhost,1999`).

---

## Step 1 — Apply the change to the source database

Run the script against the source SQL Server instance using sqlcmd:

```powershell
docker exec adventureworks-source bash -c "/opt/mssql-tools18/bin/sqlcmd -S 'localhost,1999' -U sa -P 'Flyway2025!' -No -C -d AdventureWorksLT2025 -i '/dev/stdin'" < "C:\Flyway\AdventureWorksDemo\AdventureWorksFlyway\Demo-NewTable-Source.sql"
```

Or run `Demo-NewTable-Source.sql` directly from SSMS connected to `localhost,1999`.

---

## Step 2 — Detect the change (diff dev vs schema model)

Compare the development database against the schema model to see what has changed:

```powershell
flyway diff "-diff.source=development" "-diff.target=schemaModel" "-environment=development"
```

You should see `ThisIsANewTableForFlywayDemo` listed as **Add**.

---

## Step 3 — Update the schema model

Apply the detected change into the `schema-model\` directory:

```powershell
flyway model "-diff.artifactFilename=%temp%\flyway.artifact.diff"
```

This creates `schema-model\Tables\dbo.ThisIsANewTableForFlywayDemo.sql`.

---

## Step 4 — Diff schema model vs target

Compare the schema model (desired state) against the target database (current state) to confirm what needs to be deployed:

```powershell
flyway diff "-diff.source=schemaModel" "-diff.target=target" "-environment=target"
```

You should see `ThisIsANewTableForFlywayDemo` listed as **Add**.

---

## Step 5 — Generate a versioned migration script

Generate the migration script from the diff artifact:

```powershell
flyway generate "-generate.description=Add_ThisIsANewTableForFlywayDemo"
```

This creates a new versioned migration in `migrations\`, e.g.:
`V002_20260521XXXXXX__Add_ThisIsANewTableForFlywayDemo.sql`

---

## Step 6 — Deploy to target

```powershell
flyway migrate "-environment=target"
```

Flyway runs the new versioned migration against the target database and records it in `flyway_schema_history`.

---

## Verify

Check that both the migration ran and the table exists on target:

```powershell
flyway info "-environment=target"
```

Or query the target directly:

```powershell
docker exec adventureworks-target bash -c "/opt/mssql-tools18/bin/sqlcmd -S 'localhost,1989' -U sa -P 'Flyway2025!' -No -C -Q 'SELECT name FROM AdventureWorksLT2025.sys.tables WHERE name = ''ThisIsANewTableForFlywayDemo'''"
```
