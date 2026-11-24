-- =============================================================================
-- STORED PROCEDURE: sp_Stock_Critico_Clientes
-- Base de datos: AlertasB1 (SQL Server)
-- Requiere: Vista STOCK_CRITICO_CLIENTES (OPENQUERY a HANA)
-- =============================================================================
-- Usado por el script Python reporte_stock_critico.py para generar el Excel
-- y enviar por email.
-- =============================================================================

USE AlertasB1;
GO

IF OBJECT_ID('dbo.sp_Stock_Critico_Clientes', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Stock_Critico_Clientes;
GO

CREATE PROCEDURE dbo.sp_Stock_Critico_Clientes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Codigo,
        Codigo_Secundario,
        Item,
        Cliente,
        PR_Dias           AS [PR Dias],
        LeadTime,
        MinLevel,
        UIO_MP,
        UIO_PT,
        UIO_PROD,
        GYE_PT,
        GYE_MP,
        UIO_CONS,
        UIO_MAT,
        Consumo_90_dias,
        [UIO Total],
        [GYE Total],
        STOCK,
        ConsumoPromedioDiario AS [CPD],
        PR_Cantidad,
        DOH,
        Cumplimiento_KR   AS [Cumple],
        Semaforo
    FROM STOCK_CRITICO_CLIENTES
    ORDER BY Cliente ASC, Codigo ASC;
END;
GO
