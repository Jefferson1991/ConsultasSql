-- ============================================================================
-- TABLA DE FESTIVOS ECUADOR 2026 + PROCEDIMIENTO DE CARGA
-- ============================================================================
-- Base de datos: TH (192.168.20.15)
-- Propósito: Soporte para regla de feriados en vm_atrasos
-- Creado: 2026-04-13
-- ============================================================================

-- ============================================================================
-- PASO 1: CREAR TABLA DE FESTIVOS
-- ============================================================================
IF OBJECT_ID('dbo.TBL_FESTIVOS_TALENTO', 'U') IS NOT NULL
    DROP TABLE dbo.TBL_FESTIVOS_TALENTO;
GO

CREATE TABLE dbo.TBL_FESTIVOS_TALENTO (
    FESTIVO_ID INT IDENTITY(1,1) PRIMARY KEY,
    FESTIVO_FECHA DATE NOT NULL,
    FESTIVO_DESCRIPCION VARCHAR(150) NOT NULL,
    FESTIVO_TIPO VARCHAR(50) DEFAULT 'NACIONAL',  -- NACIONAL, LOCAL, RELIGIOSO
    FESTIVO_CIUDAD VARCHAR(10) DEFAULT 'TODAS',   -- TODAS, UIO, GYE
    FESTIVO_APLICA_ROTATIVO BIT DEFAULT 1,         -- Si aplica para rotativos
    FESTIVO_ACTIVO BIT DEFAULT 1,                  -- Para desactivar sin borrar
    FESTIVO_CREATED DATETIME DEFAULT GETDATE(),
    FESTIVO_UPDATED DATETIME DEFAULT GETDATE()
);
GO

-- Índice para búsquedas rápidas
CREATE INDEX IX_FESTIVOS_FECHA ON dbo.TBL_FESTIVOS_TALENTO(FESTIVO_FECHA);
CREATE INDEX IX_FESTIVOS_CIUDAD ON dbo.TBL_FESTIVOS_TALENTO(FESTIVO_CIUDAD);
GO

-- ============================================================================
-- PASO 2: CARGAR FESTIVOS ECUADOR 2026
-- ============================================================================
-- Fuente: Calendario de festivos Ecuador
-- Notas:
-- - Feriados nacionales aplican para TODAS las ciudades
-- - Feriados locales (fundación de ciudades) solo para esa ciudad
-- - Para rotativos: si cae en feriado, cuenta como día hábil
-- ============================================================================

INSERT INTO dbo.TBL_FESTIVOS_TALENTO 
(FESTIVO_FECHA, FESTIVO_DESCRIPCION, FESTIVO_TIPO, FESTIVO_CIUDAD, FESTIVO_APLICA_ROTATIVO)
VALUES
-- ═══════════════════════════════════════════════════════════
-- FESTIVOS NACIONALES 2026 (Aplican para TODO Ecuador)
-- ═══════════════════════════════════════════════════════════

-- ENERO
('2026-01-01', 'Año Nuevo', 'NACIONAL', 'TODAS', 1),

-- FEBRERO
('2026-02-16', 'Carnaval', 'NACIONAL', 'TODAS', 1),
('2026-02-17', 'Carnaval', 'NACIONAL', 'TODAS', 1),

-- MARZO
('2026-03-20', 'Viernes Santo', 'NACIONAL', 'TODAS', 1),
('2026-05-01', 'Día del Trabajo', 'NACIONAL', 'TODAS', 1),

-- MAYO
('2026-05-24', 'Batalla de Pichincha', 'NACIONAL', 'TODAS', 1),

-- AGOSTO
('2026-08-10', 'Primer Grito de Independencia', 'NACIONAL', 'TODAS', 1),

-- OCTUBRE
('2026-10-09', 'Independencia de Guayaquil', 'NACIONAL', 'TODAS', 1),

-- NOVIEMBRE
('2026-11-02', 'Día de Difuntos', 'NACIONAL', 'TODAS', 1),
('2026-11-03', 'Independencia de Cuenca', 'NACIONAL', 'TODAS', 1),

-- DICIEMBRE
('2026-12-25', 'Navidad', 'NACIONAL', 'TODAS', 1),

-- ═══════════════════════════════════════════════════════════
-- FESTIVOS LOCALES QUITO/UIO
-- ═══════════════════════════════════════════════════════════
('2026-12-06', 'Fundación de Quito', 'LOCAL', 'UIO', 1),

-- ═══════════════════════════════════════════════════════════
-- FESTIVOS LOCALES GUAYAQUIL/GYE
-- ═══════════════════════════════════════════════════════════
('2026-07-25', 'Fundación de Guayaquil', 'LOCAL', 'GYE', 1),

-- ═══════════════════════════════════════════════════════════
-- FESTIVOS ADICIONALES (PUENTES, ASUETOS, ETC)
-- ═══════════════════════════════════════════════════════════
-- Agregar aquí según decreto ejecutivo de cada año
('2026-04-06', 'Lunes de Pascua (Asueto)', 'NACIONAL', 'TODAS', 0),
('2026-11-03', 'Asueto Puente Festivo', 'NACIONAL', 'TODAS', 0)

GO

-- ============================================================================
-- PASO 3: CREAR VISTA DE CONSULTA DE FESTIVOS
-- ============================================================================
IF OBJECT_ID('dbo.vw_festivos_activos', 'V') IS NOT NULL
    DROP VIEW dbo.vw_festivos_activos;
GO

CREATE VIEW dbo.vw_festivos_activos AS
-- Festivos activos para consulta
SELECT 
    FESTIVO_FECHA AS fecha,
    FESTIVO_DESCRIPCION AS descripcion,
    FESTIVO_TIPO AS tipo,
    FESTIVO_CIUDAD AS ciudad,
    FESTIVO_APLICA_ROTATIVO AS aplica_rotativo,
    
    -- Día de semana
    DATENAME(WEEKDAY, FESTIVO_FECHA) AS dia_semana,
    DATEPART(WEEKDAY, FESTIVO_FECHA) AS dia_semana_num,
    
    -- Mes
    MONTH(FESTIVO_FECHA) AS mes,
    DATENAME(MONTH, FESTIVO_FECHA) AS nombre_mes

FROM dbo.TBL_FESTIVOS_TALENTO
WHERE FESTIVO_ACTIVO = 1
ORDER BY FESTIVO_FECHA;
GO

-- ============================================================================
-- PASO 4: VERIFICAR CARGA
-- ============================================================================
SELECT 
    YEAR(FESTIVO_FECHA) AS anio,
    MONTH(FESTIVO_FECHA) AS mes,
    COUNT(*) AS cantidad_festivos
FROM dbo.TBL_FESTIVOS_TALENTO
WHERE FESTIVO_ACTIVO = 1
GROUP BY YEAR(FESTIVO_FECHA), MONTH(FESTIVO_FECHA)
ORDER BY anio, mes;
GO

-- Listar todos los festivos
SELECT 
    FESTIVO_FECHA AS fecha,
    DATENAME(WEEKDAY, FESTIVO_FECHA) AS dia,
    FESTIVO_DESCRIPCION AS descripcion,
    FESTIVO_TIPO AS tipo,
    FESTIVO_CIUDAD AS ciudad,
    CASE FESTIVO_APLICA_ROTATIVO 
        WHEN 1 THEN 'Sí' 
        ELSE 'No' 
    END AS aplica_rotativo
FROM dbo.TBL_FESTIVOS_TALENTO
WHERE FESTIVO_ACTIVO = 1
ORDER BY FESTIVO_FECHA;
GO

-- ============================================================================
-- PASO 5: PROCEDIMIENTO PARA AGREGAR FESTIVOS RÁPIDAMENTE
-- ============================================================================
IF OBJECT_ID('dbo.sp_agregar_festivo', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_agregar_festivo;
GO

CREATE PROCEDURE dbo.sp_agregar_festivo
    @fecha DATE,
    @descripcion VARCHAR(150),
    @tipo VARCHAR(50) = 'NACIONAL',
    @ciudad VARCHAR(10) = 'TODAS',
    @aplica_rotativo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si ya existe
    IF EXISTS (SELECT 1 FROM dbo.TBL_FESTIVOS_TALENTO 
               WHERE FESTIVO_FECHA = @fecha AND FESTIVO_CIUDAD IN (@ciudad, 'TODAS'))
    BEGIN
        PRINT '⚠️ El festivo ya existe: ' + @descripcion;
        RETURN;
    END
    
    INSERT INTO dbo.TBL_FESTIVOS_TALENTO 
    (FESTIVO_FECHA, FESTIVO_DESCRIPCION, FESTIVO_TIPO, FESTIVO_CIUDAD, FESTIVO_APLICA_ROTATIVO)
    VALUES (@fecha, @descripcion, @tipo, @ciudad, @aplica_rotativo);
    
    PRINT '✅ Festivo agregado: ' + @descripcion + ' - ' + CAST(@fecha AS VARCHAR);
END
GO

-- Ejemplo de uso:
-- EXEC dbo.sp_agregar_festivo '2026-06-15', 'Feriado Especial', 'NACIONAL', 'TODAS', 1;
GO

-- ============================================================================
-- PASO 6: FUNCIÓN PARA VERIFICAR SI UNA FECHA ES FESTIVO
-- ============================================================================
IF OBJECT_ID('dbo.fn_es_festivo', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_es_festivo;
GO

CREATE FUNCTION dbo.fn_es_festivo (
    @fecha DATE,
    @ciudad VARCHAR(10) = 'TODAS'
)
RETURNS BIT
AS
BEGIN
    DECLARE @resultado BIT = 0;
    
    SELECT @resultado = 1
    FROM dbo.TBL_FESTIVOS_TALENTO
    WHERE FESTIVO_FECHA = @fecha
      AND FESTIVO_ACTIVO = 1
      AND (FESTIVO_CIUDAD = @ciudad OR FESTIVO_CIUDAD = 'TODAS');
    
    RETURN @resultado;
END
GO

-- Ejemplo de uso:
-- SELECT dbo.fn_es_festivo('2026-01-01', 'UIO') AS es_festivo;  -- Retorna 1
-- SELECT dbo.fn_es_festivo('2026-01-02', 'UIO') AS es_festivo;  -- Retorna 0
GO

-- ============================================================================
-- PASO 7: TABLA DE HISTORIAL DE CAMBIOS (AUDITORÍA)
-- ============================================================================
IF OBJECT_ID('dbo.TBL_FESTIVOS_HISTORIAL', 'U') IS NOT NULL
    DROP TABLE dbo.TBL_FESTIVOS_HISTORIAL;
GO

CREATE TABLE dbo.TBL_FESTIVOS_HISTORIAL (
    HISTORIAL_ID INT IDENTITY(1,1) PRIMARY KEY,
    FESTIVO_ID INT,
    ACCION VARCHAR(50),  -- INSERT, UPDATE, DELETE
    CAMPOS_ANTERIORES VARCHAR(MAX),
    CAMPOS_NUEVOS VARCHAR(MAX),
    USUARIO VARCHAR(100) DEFAULT SYSTEM_USER,
    FECHA DATETIME DEFAULT GETDATE()
);
GO

-- ============================================================================
-- PASO 8: TRIGGER PARA AUDITORÍA
-- ============================================================================
IF OBJECT_ID('dbo.tr_festivos_audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.tr_festivos_audit;
GO

CREATE TRIGGER dbo.tr_festivos_audit
ON dbo.TBL_FESTIVOS_TALENTO
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Log de eliminaciones
    INSERT INTO dbo.TBL_FESTIVOS_HISTORIAL (FESTIVO_ID, ACCION, CAMPOS_ANTERIORES)
    SELECT 
        d.FESTIVO_ID,
        'DELETE',
        'Fecha: ' + CAST(d.FESTIVO_FECHA AS VARCHAR) + 
        ' | Descripción: ' + d.FESTIVO_DESCRIPCION +
        ' | Tipo: ' + d.FESTIVO_TIPO +
        ' | Ciudad: ' + d.FESTIVO_CIUDAD
    FROM deleted d;
    
    -- Log de actualizaciones
    INSERT INTO dbo.TBL_FESTIVOS_HISTORIAL (FESTIVO_ID, ACCION, CAMPOS_ANTERIORES, CAMPOS_NUEVOS)
    SELECT 
        d.FESTIVO_ID,
        'UPDATE',
        'Fecha: ' + CAST(d.FESTIVO_FECHA AS VARCHAR) + 
        ' | Descripción: ' + d.FESTIVO_DESCRIPCION +
        ' | Tipo: ' + d.FESTIVO_TIPO +
        ' | Ciudad: ' + d.FESTIVO_CIUDAD,
        'Fecha: ' + CAST(i.FESTIVO_FECHA AS VARCHAR) + 
        ' | Descripción: ' + i.FESTIVO_DESCRIPCION +
        ' | Tipo: ' + i.FESTIVO_TIPO +
        ' | Ciudad: ' + i.FESTIVO_CIUDAD
    FROM deleted d
    INNER JOIN inserted i ON d.FESTIVO_ID = i.FESTIVO_ID;
END
GO

-- ============================================================================
-- NOTAS DE IMPLEMENTACIÓN:
-- ============================================================================
-- 1. Esta tabla resuelve el PENDIENTE de vm_atrasos sobre feriados
-- 
-- 2. Para usar en vm_atrasos, agregar en el WHERE:
--
--    AND NOT EXISTS (
--        SELECT 1 
--        FROM dbo.TBL_FESTIVOS_TALENTO f
--        WHERE f.FESTIVO_FECHA = T1.FECHA_INGRESO
--          AND f.FESTIVO_ACTIVO = 1
--          AND (f.FESTIVO_CIUDAD IN (
--              CASE WHEN T0.EMPE_NOM LIKE '%EMPAQPLAST%' THEN 'UIO'
--                   WHEN T0.EMPE_NOM LIKE '%LOGISTPLAST%' THEN 'GYE'
--                   ELSE 'TODAS'
--              END, 'TODAS')
--          )
--    )
--
-- 3. Para cargar festivos de otros años, ejecutar:
--    - Modificar las fechas en el INSERT
--    - O usar sp_agregar_festivo para agregar uno por uno
--
-- 4. Mantener actualizado:
--    - Revisar decretos ejecutivos cada año
--    - Agregar feriados no previstos
--    - Desactivar en lugar de borrar (FESTIVO_ACTIVO = 0)
-- ============================================================================
