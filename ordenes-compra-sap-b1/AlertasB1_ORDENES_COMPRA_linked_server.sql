/* =========================================================================
   AlertasB1 -- Órdenes de Compra abiertas sobre el linked server HANAODBC
   Servidor: SRV-APP\SQLEXPRESS   |   Base: AlertasB1

   Mismo patrón que STOCK_MINIMO / STOCK_NECESARIO / STOCK_CRITICO_CLIENTES:
       CREATE VIEW <nombre> AS
       SELECT * FROM OPENQUERY(HANAODBC, 'SELECT * FROM EMPAQPLAST_PROD.SB1_VIEW_...')

   Requisito previo: crear en HANA la vista SB1_VIEW_ORDENES_COMPRA
   (archivo SB1_VIEW_ORDENES_COMPRA.sql).

   ALCANCE: serie OCNAC (nacionales) y sólo documentos y líneas ABIERTOS. Los
   dos filtros viven en la vista de HANA, no aquí. Resultado: ~376 líneas en
   ~197 OC (foto del 2026-08-06; el dato es vivo).

   POR QUÉ UNA SOLA VISTA
   ----------------------
   OPENQUERY no empuja el WHERE de SQL Server hacia HANA: si se filtra por
   fuera, SQL Server trae primero todo lo que devuelve la vista remota y
   recién ahí filtra. Medido contra producción el 2026-08-06 sobre el
   histórico completo (67.525 líneas): filtro fuera 5.445 ms contra 76 ms
   con el filtro dentro del OPENQUERY.

   Como la vista de HANA ya viene filtrada a lo abierto, lo que viaja son
   ~376 filas y ese costo desaparece: no hace falta una vista por caso de
   uso. Los recortes del reporte (atrasadas, del día) los hace el Python
   sobre este conjunto chico.

   OJO si algún día se amplía el alcance de la vista de HANA (histórico,
   cerradas, ambas series): ahí vuelve a convenir una vista por caso de uso
   con el WHERE dentro de la cadena del OPENQUERY.
   ========================================================================= */

USE AlertasB1;
GO

IF OBJECT_ID('dbo.ORDENES_COMPRA', 'V') IS NOT NULL
    DROP VIEW dbo.ORDENES_COMPRA;
GO

CREATE VIEW dbo.ORDENES_COMPRA AS
SELECT
    *
FROM
    OPENQUERY(HANAODBC,
    'SELECT * FROM EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA');
GO


/* =========================================================================
   Verificación
   ========================================================================= */
-- SELECT COUNT(*) FROM dbo.ORDENES_COMPRA;                      -- ~376
-- SELECT DISTINCT Serie FROM dbo.ORDENES_COMPRA;                -- sólo OCNAC
-- SELECT COUNT(*) FROM dbo.ORDENES_COMPRA WHERE Cantidad_Pendiente <= 0;  -- 0

-- Top de atrasadas por valor pendiente:
-- SELECT TOP 20 Numero_OC, Nombre_Proveedor, Codigo_Articulo, Descripcion,
--        Cantidad_Pendiente, Valor_Pendiente, Fecha_Entrega_Linea, Dias_Atraso
--   FROM dbo.ORDENES_COMPRA
--  WHERE Dias_Atraso > 0
--  ORDER BY Valor_Pendiente DESC;

-- Resumen por proveedor:
-- SELECT Nombre_Proveedor,
--        COUNT(DISTINCT Numero_OC) AS OCs,
--        SUM(Valor_Pendiente)      AS Valor_Pendiente,
--        MAX(Dias_Atraso)          AS Max_Dias_Atraso
--   FROM dbo.ORDENES_COMPRA
--  GROUP BY Nombre_Proveedor
--  ORDER BY Valor_Pendiente DESC;
