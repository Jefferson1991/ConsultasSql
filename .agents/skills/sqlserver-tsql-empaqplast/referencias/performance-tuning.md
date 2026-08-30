# SQL Server — Tuning Empaqplast

## Diagnóstico rápido

```sql
-- Plan de ejecución: activar en SSMS (Ctrl+M) o:
SET STATISTICS IO, TIME ON;
-- ... consulta ...
SET STATISTICS IO, TIME OFF;
```

Señales de alerta en el plan: **Table Scan**, **Key Lookup** masivo, **Sort/Hash spill**, parameter sniffing.

## Parameter sniffing

- SQL Server 2022+: habilitar Parameter Sensitive Plan (PSP) optimization
- Alternativa: Query Store hints sin tocar código app
- Evitar `@param = NULL OR col = @param` en tablas enormes sin recompile estratégico

## Índices típicos TimeControl

Columnas candidatas a índice (verificar uso real):

- `TBL_ASISTENCIA (Fecha_Ingreso, EMP_ID)`
- `TBL_PERM_AUS (E_FINICIO, E_EMPID)`

No crear índices sin medir — usar Query Store o planes reales.

## Linked server HANAODBC

- Timeout: consultas pesadas pueden fallar; reducir columnas y filas en HANA antes de traer
- Probar COUNT(*) antes de SELECT * en vistas AlertasB1
- Evitar JOIN entre OPENQUERY y tablas locales sin necesidad

## Permisos y período 21-20

Scripts de corrección (`correccion_permiso_sin_paga.sql`):

1. SELECT de validación con conteo esperado
2. BEGIN TRANSACTION
3. UPDATE
4. Verificar @@ROWCOUNT
5. COMMIT o ROLLBACK

Nunca UPDATE masivo sin SELECT previo documentado.
