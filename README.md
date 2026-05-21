## Project Summary
This solution will bring 2 SQL instances online in Docker, then restore AdventureWorks database to the source instance. 
Subsequently, you can use Flyway to: 
  - Create a snapshot of the source AdventureWorks database
  - Create a schema-model of the database on disk
  - Apply the snapshot to a newly created target database
  - You can then go ahead and perform another migration, using Flyway-My1stMigration on the source SQL instance

## See INSTRUCTIONS.md for details and prerequisites
https://github.com/HugoduToit-Redgate/FlywayAdventureWorksDemo/blob/master/INSTRUCTIONS.md
