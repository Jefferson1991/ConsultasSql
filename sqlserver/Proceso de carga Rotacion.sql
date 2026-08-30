USE dispensarioMedico;

/* 1) Vista de transformación: de filas nuevas -> formato legacy */
CREATE OR ALTER VIEW dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC
AS
WITH base AS (
    SELECT
        re.Id,
        re.NombreEmpleado,
        re.Coordinador,
        re.Bez,                 -- posible equivalente de maquinaSLPC
        ar.Nombre AS ActividadNombre,
        re.FechaInicio,
        re.FechaFin,
        re.Horario,
        re.idEmpleado
    FROM internaEmpaqplast.eo.RotacionEmpleado re
    INNER JOIN internaEmpaqplast.eo.ActividadRotacion ar
        ON ar.Id = re.ActividadId
    WHERE re.Estado = 1
),
agrupado AS (
    SELECT
        b.NombreEmpleado,
        b.Coordinador,
        b.Bez,
        b.FechaInicio,
        b.FechaFin,
        b.Horario,
        b.idEmpleado,
        STRING_AGG(b.ActividadNombre, ', ') 
            WITHIN GROUP (ORDER BY b.ActividadNombre) AS actividadSLPC
    FROM base b
    GROUP BY
        b.NombreEmpleado, b.Coordinador, b.Bez,
        b.FechaInicio, b.FechaFin, b.Horario, b.idEmpleado
)
SELECT
    g.NombreEmpleado AS nombresSLPC,
    g.Coordinador    AS coordinadorSLPC,
    g.Bez       AS maquinaSLPC,
    g.actividadSLPC,
    CONVERT(varchar(10), g.FechaInicio, 103) + ' - ' +
    CONVERT(varchar(10), g.FechaFin, 103)    AS fechaRegistroSLPC,
    REPLACE(g.Horario, '-', '/')             AS horarioSLPC,
    LEFT(g.idEmpleado, 15)               AS codigoEmpleadoSLPC
FROM agrupado g;


/* 2) Carga incremental sin duplicados (upsert) */
MERGE dbo.cargaTurnosSLPC AS tgt
USING (
    SELECT
        nombresSLPC,
        coordinadorSLPC,
        maquinaSLPC,
        actividadSLPC,
        fechaRegistroSLPC,
        horarioSLPC,
        codigoEmpleadoSLPC
    FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC
) AS src
ON  ISNULL(tgt.codigoEmpleadoSLPC,'') = ISNULL(src.codigoEmpleadoSLPC,'')
AND ISNULL(tgt.fechaRegistroSLPC,'')  = ISNULL(src.fechaRegistroSLPC,'')
AND ISNULL(tgt.horarioSLPC,'')        = ISNULL(src.horarioSLPC,'')
AND ISNULL(tgt.maquinaSLPC,'')        = ISNULL(src.maquinaSLPC,'')
AND ISNULL(tgt.coordinadorSLPC,'')    = ISNULL(src.coordinadorSLPC,'')
WHEN MATCHED AND (
       ISNULL(tgt.nombresSLPC,'')   <> ISNULL(src.nombresSLPC,'')
    OR ISNULL(tgt.actividadSLPC,'') <> ISNULL(src.actividadSLPC,'')
)
THEN UPDATE SET
    tgt.nombresSLPC   = src.nombresSLPC,
    tgt.actividadSLPC = src.actividadSLPC
WHEN NOT MATCHED BY TARGET
THEN INSERT (
    nombresSLPC, coordinadorSLPC, maquinaSLPC, actividadSLPC,
    fechaRegistroSLPC, horarioSLPC, codigoEmpleadoSLPC
)
VALUES (
    src.nombresSLPC, src.coordinadorSLPC, src.maquinaSLPC, src.actividadSLPC,
    src.fechaRegistroSLPC, src.horarioSLPC, src.codigoEmpleadoSLPC
);



USE dispensarioMedico;


CREATE TABLE dbo.LogCargasTurnosSLPC (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    FechaInicio     DATETIME      NOT NULL DEFAULT GETDATE(),
    FechaFin        DATETIME      NULL,
    DuracionSeg     AS DATEDIFF(SECOND, FechaInicio, FechaFin),
    FilasInsertadas INT           NULL,
    FilasActualizadas INT         NULL,
    FilasOrigen     INT           NULL,
    Estado          VARCHAR(20)   NOT NULL,  -- 'OK', 'ERROR'
    MensajeError    NVARCHAR(4000) NULL,
    EjecutadoPor    NVARCHAR(128) NULL DEFAULT SUSER_SNAME(),
    Origen          NVARCHAR(50)  NULL       -- 'Python', 'Manual', 'Agent', etc.
);


USE dispensarioMedico;

CREATE OR ALTER PROCEDURE dbo.usp_CargarTurnosSLPC
    @Origen NVARCHAR(50) = 'Manual'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @LogId INT;
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;
    DECLARE @FilasOrigen INT = 0;
    
    -- Tabla temporal para capturar acciones del MERGE
    DECLARE @AccionesMerge TABLE (Accion NVARCHAR(10));
    
    -- 1) Registrar inicio en el log
    INSERT INTO dbo.LogCargasTurnosSLPC (Estado, Origen)
    VALUES ('EN_PROCESO', @Origen);
    
    SET @LogId = SCOPE_IDENTITY();
    
    BEGIN TRY
        BEGIN TRAN;
        
        -- Contar filas de la vista (para auditoría)
        SELECT @FilasOrigen = COUNT(*) 
        FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC;
        
        -- 2) Ejecutar MERGE con OUTPUT para contar acciones
        MERGE dbo.cargaTurnosSLPC AS tgt
        USING (
            SELECT nombresSLPC, coordinadorSLPC, maquinaSLPC, actividadSLPC,
                   fechaRegistroSLPC, horarioSLPC, codigoEmpleadoSLPC
            FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC
        ) AS src
        ON  ISNULL(tgt.codigoEmpleadoSLPC,'') = ISNULL(src.codigoEmpleadoSLPC,'')
        AND ISNULL(tgt.fechaRegistroSLPC,'')  = ISNULL(src.fechaRegistroSLPC,'')
        AND ISNULL(tgt.horarioSLPC,'')        = ISNULL(src.horarioSLPC,'')
        AND ISNULL(tgt.maquinaSLPC,'')        = ISNULL(src.maquinaSLPC,'')
        AND ISNULL(tgt.coordinadorSLPC,'')    = ISNULL(src.coordinadorSLPC,'')
        WHEN MATCHED AND (
               ISNULL(tgt.nombresSLPC,'')   <> ISNULL(src.nombresSLPC,'')
            OR ISNULL(tgt.actividadSLPC,'') <> ISNULL(src.actividadSLPC,'')
        )
        THEN UPDATE SET
            tgt.nombresSLPC   = src.nombresSLPC,
            tgt.actividadSLPC = src.actividadSLPC
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            nombresSLPC, coordinadorSLPC, maquinaSLPC, actividadSLPC,
            fechaRegistroSLPC, horarioSLPC, codigoEmpleadoSLPC
        )
        VALUES (
            src.nombresSLPC, src.coordinadorSLPC, src.maquinaSLPC, src.actividadSLPC,
            src.fechaRegistroSLPC, src.horarioSLPC, src.codigoEmpleadoSLPC
        )
        OUTPUT $action INTO @AccionesMerge;
        
        -- 3) Contar acciones
        SELECT @Inserted = SUM(CASE WHEN Accion = 'INSERT' THEN 1 ELSE 0 END),
               @Updated  = SUM(CASE WHEN Accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM @AccionesMerge;
        
        COMMIT;
        
        -- 4) Actualizar el log con éxito
        UPDATE dbo.LogCargasTurnosSLPC
        SET FechaFin = GETDATE(),
            FilasInsertadas = ISNULL(@Inserted, 0),
            FilasActualizadas = ISNULL(@Updated, 0),
            FilasOrigen = @FilasOrigen,
            Estado = 'OK'
        WHERE Id = @LogId;
        
        -- Devolver resumen al cliente (Python lo recibe)
        SELECT 
            @LogId          AS LogId,
            ISNULL(@Inserted, 0)  AS FilasInsertadas,
            ISNULL(@Updated, 0)   AS FilasActualizadas,
            @FilasOrigen    AS FilasOrigen,
            'OK'            AS Estado;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrProc NVARCHAR(128) = ISNULL(ERROR_PROCEDURE(), 'N/A');
        
        -- Registrar error en el log
        UPDATE dbo.LogCargasTurnosSLPC
        SET FechaFin = GETDATE(),
            Estado = 'ERROR',
            MensajeError = CONCAT('Línea ', @ErrLine, ' en ', @ErrProc, ': ', @ErrMsg)
        WHERE Id = @LogId;
        
        -- Re-lanzar el error para que Python lo capture
        THROW;
    END CATCH
END;





USE dispensarioMedico;


ALTER TABLE dbo.LogCargasTurnosSLPC
ADD FilasDuplicadas INT NULL;

CREATE TABLE dbo.LogCargasTurnosSLPC_Duplicados (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    LogId           INT NOT NULL,   -- FK al log principal
    FechaDeteccion  DATETIME NOT NULL DEFAULT GETDATE(),
    codigoEmpleadoSLPC VARCHAR(50),
    fechaRegistroSLPC  VARCHAR(50),
    horarioSLPC        VARCHAR(50),
    maquinaSLPC        VARCHAR(100),
    coordinadorSLPC    VARCHAR(100),
    nombresSLPC        VARCHAR(200),
    actividadSLPC      VARCHAR(500),
    CONSTRAINT FK_LogDup_Log FOREIGN KEY (LogId) 
        REFERENCES dbo.LogCargasTurnosSLPC(Id)
);





USE dispensarioMedico;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarTurnosSLPC
    @Origen NVARCHAR(50) = 'Manual'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @LogId INT;
    DECLARE @Inserted INT = 0;
    DECLARE @Updated INT = 0;
    DECLARE @Duplicados INT = 0;
    DECLARE @FilasOrigen INT = 0;
    
    DECLARE @AccionesMerge TABLE (Accion NVARCHAR(10));
    
    -- 1) Registrar inicio
    INSERT INTO dbo.LogCargasTurnosSLPC (Estado, Origen)
    VALUES ('EN_PROCESO', @Origen);
    
    SET @LogId = SCOPE_IDENTITY();
    
    BEGIN TRY
        BEGIN TRAN;
        
        -- Filas en origen
        SELECT @FilasOrigen = COUNT(*) 
        FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC;
        
        -- 2) MERGE con OUTPUT
        MERGE dbo.cargaTurnosSLPC AS tgt
        USING (
            SELECT nombresSLPC, coordinadorSLPC, maquinaSLPC, actividadSLPC,
                   fechaRegistroSLPC, horarioSLPC, codigoEmpleadoSLPC
            FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC
        ) AS src
        ON  ISNULL(tgt.codigoEmpleadoSLPC,'') = ISNULL(src.codigoEmpleadoSLPC,'')
        AND ISNULL(tgt.fechaRegistroSLPC,'')  = ISNULL(src.fechaRegistroSLPC,'')
        AND ISNULL(tgt.horarioSLPC,'')        = ISNULL(src.horarioSLPC,'')
        AND ISNULL(tgt.maquinaSLPC,'')        = ISNULL(src.maquinaSLPC,'')
        AND ISNULL(tgt.coordinadorSLPC,'')    = ISNULL(src.coordinadorSLPC,'')
        WHEN MATCHED AND (
               ISNULL(tgt.nombresSLPC,'')   <> ISNULL(src.nombresSLPC,'')
            OR ISNULL(tgt.actividadSLPC,'') <> ISNULL(src.actividadSLPC,'')
        )
        THEN UPDATE SET
            tgt.nombresSLPC   = src.nombresSLPC,
            tgt.actividadSLPC = src.actividadSLPC
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            nombresSLPC, coordinadorSLPC, maquinaSLPC, actividadSLPC,
            fechaRegistroSLPC, horarioSLPC, codigoEmpleadoSLPC
        )
        VALUES (
            src.nombresSLPC, src.coordinadorSLPC, src.maquinaSLPC, src.actividadSLPC,
            src.fechaRegistroSLPC, src.horarioSLPC, src.codigoEmpleadoSLPC
        )
        OUTPUT $action INTO @AccionesMerge;
        
        -- 3) Contar acciones
        SELECT 
            @Inserted = SUM(CASE WHEN Accion = 'INSERT' THEN 1 ELSE 0 END),
            @Updated  = SUM(CASE WHEN Accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM @AccionesMerge;
        
        SET @Inserted = ISNULL(@Inserted, 0);
        SET @Updated  = ISNULL(@Updated, 0);
        
        -- 4) Calcular duplicados (filas que coincidieron pero NO se actualizaron)
        SET @Duplicados = @FilasOrigen - @Inserted - @Updated;
        IF @Duplicados < 0 SET @Duplicados = 0;
        
        -- 5) Guardar el DETALLE de los duplicados en la tabla auxiliar
        -- (filas que existen en origen Y en destino con los mismos valores en TODAS las columnas relevantes)
        INSERT INTO dbo.LogCargasTurnosSLPC_Duplicados (
            LogId, codigoEmpleadoSLPC, fechaRegistroSLPC, horarioSLPC,
            maquinaSLPC, coordinadorSLPC, nombresSLPC, actividadSLPC
        )
        SELECT 
            @LogId,
            src.codigoEmpleadoSLPC,
            src.fechaRegistroSLPC,
            src.horarioSLPC,
            src.maquinaSLPC,
            src.coordinadorSLPC,
            src.nombresSLPC,
            src.actividadSLPC
        FROM dbo.vw_RotacionEmpleado_A_CargaTurnosSLPC src
        INNER JOIN dbo.cargaTurnosSLPC tgt
            ON  ISNULL(tgt.codigoEmpleadoSLPC,'') = ISNULL(src.codigoEmpleadoSLPC,'')
            AND ISNULL(tgt.fechaRegistroSLPC,'')  = ISNULL(src.fechaRegistroSLPC,'')
            AND ISNULL(tgt.horarioSLPC,'')        = ISNULL(src.horarioSLPC,'')
            AND ISNULL(tgt.maquinaSLPC,'')        = ISNULL(src.maquinaSLPC,'')
            AND ISNULL(tgt.coordinadorSLPC,'')    = ISNULL(src.coordinadorSLPC,'')
            AND ISNULL(tgt.nombresSLPC,'')        = ISNULL(src.nombresSLPC,'')
            AND ISNULL(tgt.actividadSLPC,'')      = ISNULL(src.actividadSLPC,'');
        
        COMMIT;
        
        -- 6) Actualizar log principal
        UPDATE dbo.LogCargasTurnosSLPC
        SET FechaFin = GETDATE(),
            FilasInsertadas = @Inserted,
            FilasActualizadas = @Updated,
            FilasDuplicadas = @Duplicados,
            FilasOrigen = @FilasOrigen,
            Estado = 'OK'
        WHERE Id = @LogId;
        
        -- 7) Devolver resumen al cliente
        SELECT 
            @LogId          AS LogId,
            @Inserted       AS FilasInsertadas,
            @Updated        AS FilasActualizadas,
            @Duplicados     AS FilasDuplicadas,
            @FilasOrigen    AS FilasOrigen,
            'OK'            AS Estado;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrProc NVARCHAR(128) = ISNULL(ERROR_PROCEDURE(), 'N/A');
        
        UPDATE dbo.LogCargasTurnosSLPC
        SET FechaFin = GETDATE(),
            Estado = 'ERROR',
            MensajeError = CONCAT('Línea ', @ErrLine, ' en ', @ErrProc, ': ', @ErrMsg)
        WHERE Id = @LogId;
        
        THROW;
    END CATCH
END;



SELECT 
    Id, 
    FechaInicio, 
    FilasOrigen, 
    FilasInsertadas, 
    FilasDuplicadas, 
    Estado
FROM dbo.LogCargasTurnosSLPC 
WHERE Origen = 'Python'
ORDER BY Id DESC;


SELECT * FROM internaEmpaqplast.eo.RotacionEmpleado 
WHERE FechaInicio = '2026-06-01' OR FechaInicio = '2026-06-06';


SELECT * FROM vw_RotacionEmpleado_A_CargaTurnosSLPC WHERE fechaRegistroSLPC = '01/06/2026 - 06/06/2026'



SELECT * FROM cargaTurnosSLPC WHERE fechaRegistroSLPC = '01/06/2026 - 06/06/2026'




SELECT fechaRegistroSLPC,
       (SELECT COUNT(*) FROM vw_RotacionEmpleado_A_CargaTurnosSLPC v
        WHERE v.fechaRegistroSLPC = p.fechaRegistroSLPC) AS vista,
       (SELECT COUNT(*) FROM cargaTurnosSLPC t
        WHERE t.fechaRegistroSLPC = p.fechaRegistroSLPC) AS tabla
FROM (SELECT DISTINCT fechaRegistroSLPC
      FROM vw_RotacionEmpleado_A_CargaTurnosSLPC) p;