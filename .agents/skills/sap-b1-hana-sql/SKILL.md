---
name: sap-b1-hana-sql
description: >-
  Escribe y optimiza SQL sobre SAP Business One en SAP HANA (EMPAQPLAST_PROD):
  vistas SB1_VIEW_*, Transaction Notifications SQLScript, UDFs y reportes B1.
  Usar cuando la consulta va en hana/, mencione OITM/OINV/OPOR, columnas entre
  comillas dobles, HANA, SAP B1 o esquema EMPAQPLAST_PROD.
---

# SAP B1 — SQL en HANA

## Verificación obligatoria

Antes de escribir o modificar SQL:

1. MCP `user-hana-sap-b1-produccion`: `hana_describe_table`, `hana_execute_query`
2. Probar `SELECT COUNT(*)` con los mismos filtros de la consulta final
3. Ubicar scripts existentes en repo: `hana/{dominio}/`

## Sintaxis Empaqplast (no negociable)

```sql
-- Tablas B1: MAYÚSCULAS, sin comillas
SELECT T0."ItemCode", T0."ItemName"
FROM OITM T0
INNER JOIN OITW T1 ON T0."ItemCode" = T1."ItemCode"
WHERE T0."validFor" = 'Y';

-- Objetos de esquema propio
CREATE OR REPLACE VIEW EMPAQPLAST_PROD.SB1_VIEW_EJEMPLO AS
SELECT ...
```

| Elemento | Regla |
|----------|-------|
| Columnas B1 | Comillas dobles, case-sensitive: `"DocEntry"`, `"ItemCode"` |
| Tablas B1 | Sin comillas: `OITM`, `OINV`, `INV1` |
| Esquema prod | `EMPAQPLAST_PROD` |
| Vistas alerta | Prefijo `SB1_VIEW_*` |
| Alias en SELECT | Preferir alias en SELECT; evitar renombrar en CREATE VIEW y SELECT a la vez |

## Mejores prácticas de rendimiento (HANA)

Basado en [SAP HANA Performance Guide](https://help.sap.com/doc/05b8cb60dfd94c82b86828ee77f7e0d9/2.0.07/en-US/SAP_HANA_Performance_Developer_Guide_en.pdf) y [SAP Community modeling](https://community.sap.com/t5/technology-blog-posts-by-members/hana-modelling-consolidated-best-practices-for-better-performance/ba-p/13306060):

1. **Filtrar pronto** — `WHERE` con fechas, `DocStatus`, `CANCELED='N'` antes de JOINs pesados
2. **Evitar SELECT *** — solo columnas necesarias; reduce I/O en column store
3. **Joins en enteros/fechas** — preferir claves numéricas (`DocEntry`, `LineNum`) sobre NVARCHAR
4. **Evitar funciones en columnas filtradas** — no `WHERE YEAR("DocDate")=2026`; usar rango de fechas
5. **Índices** — HANA indexa PK; índices secundarios solo en columnas muy selectivas usadas en filtros
6. **Mismo tipo en joins** — evitar casting implícito entre tipos distintos
7. **Vistas SQL puras** — preferir SQL estándar sobre SQLScript salvo Transaction Notifications
8. **Agregar arriba** — calcular sobre conjuntos ya filtrados/agregados, no fila a fila

## Transaction Notifications (SQLScript)

```sql
ALTER PROCEDURE SBO_SP_TransactionNotification_XXX (
    in object_type nvarchar(30),
    in transaction_type nchar(1),  -- A/U/D/C
    in num_of_cols_in_key int,
    in list_of_key_cols_tab_del nvarchar(255),
    in list_of_cols_val_tab_del nvarchar(255),
    inout error int,
    inout error_message nvarchar(200)
)
LANGUAGE SQLSCRIPT
```

- Validar `object_type` (17=ORDR, etc.) y `transaction_type` antes de lógica
- Mensajes de error claros en `error_message`; `error := -NNN` según convención B1
- Guardar en `hana/validaciones/`

## Dominios y tablas frecuentes

| Dominio | Carpeta repo | Tablas |
|---------|--------------|--------|
| Cartera | `hana/cartera/` | `OCRD`, `OINV`, `INV1`, `ORIN`, `JDT1` |
| Inventario | `hana/inventario/` | `OITM`, `OITW`, `OINM`, `OWHS` |
| Compras | `hana/compras/` | `OPOR`, `POR1`, `OPDN` |
| Ventas | `hana/ventas/` | `OINV`, `INV1`, `OCRD` |
| Producción | `hana/produccion/` | `OWOR`, `WOR1`, `OIGE`, `IGE1` |
| Logística | `hana/logistica/` | `OWTR`, `WTR1`, `ODLN`, `OWTQ` |
| Supply | `hana/supply/` | `OITM`, `OITW`, vistas stock |

## UDFs Empaqplast

- `U_EMPA_*` — campos personalizados producción/inventario
- `U_EMPA_BLOQ_CARTER` — bloqueo cartera (`'Y'`/`'N'`)
- `U_EMPA_S_T` — enlace traslado → salida mercancía

## Plantilla cabecera

```sql
/* =========================================================================
   SB1_VIEW_NOMBRE
   Esquema: EMPAQPLAST_PROD | Motor: SAP HANA
   Propósito: ...
   Supuestos verificados (fecha): ...
   Despliegue: CREATE VIEW → GRANT SELECT → (AlertasB1) → (Python)
   ========================================================================= */
```

## Checklist

- [ ] Columnas verificadas con `hana_describe_table`
- [ ] Filtros de negocio (`CANCELED`, fechas, series) en WHERE
- [ ] COUNT(*) probado con filtros reales
- [ ] Archivo en `hana/{dominio}/`
- [ ] Sin números mágicos ni ajustes manuales sin documentar

## Referencia extendida

Rendimiento y anti-patrones: [referencias/performance-tuning.md](referencias/performance-tuning.md)
