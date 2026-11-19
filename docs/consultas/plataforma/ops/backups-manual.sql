-- 1. Crear el backup de la base original
BACKUP DATABASE internaEmpaqplast 
TO DISK = N'C:\Backups\Temp_Clone.bak' 
WITH FORMAT, INIT, NAME = N'Copia para Clonar';

-- 2. Restaurar con el nuevo nombre usando los nombres lógicos reales
RESTORE DATABASE internaEmpaqplast_pruebas1422026
FROM DISK = N'C:\Backups\Temp_Clone.bak'
WITH REPLACE,
-- Usamos 'empaqplastInterna' porque es el LogicalName real detectado
MOVE 'empaqplastInterna'     TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\internaEmpaqplast_pruebas1422026.mdf',
MOVE 'empaqplastInterna_log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\internaEmpaqplast_pruebas1422026_log.ldf';

-- 3. Habilitar el acceso a la nueva base
ALTER DATABASE internaEmpaqplast_pruebas1422026 SET MULTI_USER;

RESTORE FILELISTONLY FROM DISK = N'C:\Backups\Temp_Clone.bak';