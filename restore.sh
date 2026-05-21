#!/bin/bash
# Start SQL Server in the background
/opt/mssql/bin/sqlservr &
SQLSERVER_PID=$!

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to start..."
for i in {1..60}; do
    /opt/mssql-tools18/bin/sqlcmd -S localhost,1999 -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -No -C > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SQL Server is ready."
        break
    fi
    echo "Attempt $i: SQL Server not ready yet, waiting 2s..."
    sleep 2
done

# Restore the database
echo "Restoring AdventureWorksLT2025..."
/opt/mssql-tools18/bin/sqlcmd -S localhost,1999 -U sa -P "$MSSQL_SA_PASSWORD" -No -C -Q "
RESTORE DATABASE [AdventureWorksLT2025]
FROM DISK = '/var/opt/mssql/backup/AdventureWorksLT2025.bak'
WITH MOVE 'AdventureWorksLT2022_Data' TO '/var/opt/mssql/data/AdventureWorksLT2025.mdf',
     MOVE 'AdventureWorksLT2022_Log'  TO '/var/opt/mssql/data/AdventureWorksLT2025.ldf',
     REPLACE, STATS = 10;
"

echo "Restore complete."
wait $SQLSERVER_PID
