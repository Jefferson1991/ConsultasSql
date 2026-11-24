DECLARE @anio    INT = 2026;
DECLARE @periodo INT = 7;

DECLARE @fecha_inicial DATE;
DECLARE @fecha_final   DATE;

SELECT @fecha_inicial = fecha_inicial,
       @fecha_final   = fecha_final
FROM dbo.TBL_PERIODO
WHERE anio = @anio AND periodo = @periodo;

-- VALIDAR ANTES
SELECT p.E_EMPID, ve.NOMINA_COD, p.E_FINICIO, p.E_FPAG
FROM dbo.TBL_PERM_AUS p
INNER JOIN dbo.TBL_CAT_DETALLE cd
    ON cd.CD_ID = p.E_TIPOP AND cd.CD_CAT = p.E_TIPOM
INNER JOIN dbo.ViewEmpleados ve ON ve.NOMINA_ID = p.E_EMPID
WHERE cd.CD_NOM = 'PERMISO SIN PAGA'
  AND p.E_TIPOP = 'SP'
  AND p.E_FPAG = 1
  AND p.E_FINICIO BETWEEN @fecha_inicial AND @fecha_final;

-- APLICAR (deberían ser 5 filas en período 6)
BEGIN TRANSACTION;

UPDATE p
SET p.E_FPAG = 0
FROM dbo.TBL_PERM_AUS p
INNER JOIN dbo.TBL_CAT_DETALLE cd
    ON cd.CD_ID = p.E_TIPOP AND cd.CD_CAT = p.E_TIPOM
WHERE cd.CD_NOM = 'PERMISO SIN PAGA'
  AND p.E_TIPOP = 'SP'
  AND p.E_FPAG = 1
  AND p.E_FINICIO BETWEEN @fecha_inicial AND @fecha_final;

SELECT @@ROWCOUNT AS filas_actualizadas;  -- esperado: 5

COMMIT;

ROLLBACK;  -- usar si el conteo no cuadra