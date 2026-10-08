-- 1. Limpiar la columna
UPDATE dbo.cargaTurnosSLPC 
SET codigoEmpleadoSLPC = NULL;

-- 2. Cargar con NOMINA_ID (el código tipo "000046")
UPDATE c
SET c.codigoEmpleadoSLPC = n.NOMINA_ID
FROM dbo.cargaTurnosSLPC c
INNER JOIN [ONLYC].[ONLYCONTROL].[dbo].[NOMINA] n
    ON LTRIM(RTRIM(c.nombresSLPC)) = LTRIM(RTRIM(n.NOMINA_APE)) + ' ' + LTRIM(RTRIM(n.NOMINA_NOM));

-- 3. Verificar
SELECT TOP 20 nombresSLPC, codigoEmpleadoSLPC 
FROM dbo.cargaTurnosSLPC;

-- 4. Ver sin match
SELECT nombresSLPC FROM dbo.cargaTurnosSLPC 
WHERE codigoEmpleadoSLPC IS NULL;


CREATE PROCEDURE sp_ActualizarCodigoEmpleadoSLPC
AS
BEGIN
    UPDATE c
    SET c.codigoEmpleadoSLPC = n.NOMINA_ID
    FROM dbo.cargaTurnosSLPC c
    INNER JOIN [ONLYC].[ONLYCONTROL].[dbo].[NOMINA] n
        ON LTRIM(RTRIM(c.nombresSLPC)) = LTRIM(RTRIM(n.NOMINA_APE)) + ' ' + LTRIM(RTRIM(n.NOMINA_NOM))
    WHERE c.codigoEmpleadoSLPC IS NULL;
END
