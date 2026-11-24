# Contabilidad

| Archivo | Motor | Qué hace |
|---|---|---|
| [conciliacion.sql](conciliacion.sql) | SAP B1 / HANA | Conciliación bancaria: enfrenta el Libro Mayor contra el extracto del banco, lado a lado. |

## Conciliación bancaria

Arma dos lados y los une en paralelo:

| Lado | Origen | Qué trae |
|---|---|---|
| **Libro (L)** | `JDT1` | Saldo inicial más los movimientos del mes. El tipo de movimiento se resuelve con `ORCT` (cobros, `TransType` 24), `OVPM` (pagos, 46), `ODPS` (depósitos, 25) y `OCHO` para validar si `Ref3Line` es un número de cheque real. |
| **Extracto (E)** | `OBNK` | Saldo inicial más los movimientos del mes. |

Cada lado numera sus filas con `ROW_NUMBER()`: una secuencia general y otra por
número de referencia, para emparejar partidas que comparten referencia. Las
referencias vacías se agrupan bajo `@@VACIO@@` en vez de quedar nulas, que es lo
que permite compararlas.

La clasificación del movimiento sigue un orden deliberado, y cambiarlo cambia el
resultado: primero anulados, después comisiones (cuenta `7301…` o código `COBN`),
traslados (`TREC`), depósitos (24, 25 y el 30 sobrante del débito) y pagos (46 y
el 30 sobrante del crédito), con un cierre de seguridad para el registro atípico.

> Esta consulta la escribió Jefferson; la descripción de arriba se dedujo leyendo
> el SQL el 2026-11-19, no de una explicación suya. Si algo no corresponde,
> corrígelo aquí.
