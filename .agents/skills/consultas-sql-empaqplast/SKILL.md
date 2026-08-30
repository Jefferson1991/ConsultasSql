---
name: consultas-sql-empaqplast
description: >-
  Escribe, revisa y despliega consultas SQL para Empaqplast sobre SAP B1 (HANA),
  SQL Server (TimeControl, OnlyControl, AlertasB1), PostgreSQL y automatizaciones
  Python. Usar cuando el usuario pida consultas, vistas SB1_VIEW_*, alertas por
  correo, OPENQUERY, reportes de inventario/cartera/producción/RRHH, o trabaje
  en el repo Consultas con SQL.
---

# Consultas SQL — Empaqplast

## Antes de escribir SQL

1. **Verificar esquema en vivo** — nunca asumir nombres de columna.
   - HANA/SAP B1: MCP `user-hana-sap-b1-produccion` (`hana_describe_table`, `hana_execute_query`)
   - SQL Server TimeControl: MCP `user-sqlserver-timecontrol`
   - SQL Server OnlyControl: MCP `user-sqlserver-onlycontrol`
   - PostgreSQL: MCP `user-postgres-produccion-empaqplast-cloud` o `user-postgres-local-empaqplast`
2. **Ubicar consultas existentes** — abrir `catalogo-consultas/guia-consultas.html` o buscar en el repo antes de crear algo nuevo.
3. **Seguir reglas de carpeta** — cada pedido nuevo va en su propia carpeta kebab-case en español (ver `README.md` del repo).

## Convenciones obligatorias

| Motor | Regla |
|-------|-------|
| SAP B1 / HANA | Columnas B1 entre comillas dobles y case-sensitive: `"ItemCode"`. Tablas B1 en MAYÚSCULAS sin comillas: `OITM`. Esquema prod: `EMPAQPLAST_PROD`. |
| Vistas alerta | Prefijo `SB1_VIEW_*` en HANA → vista `AlertasB1` con `OPENQUERY(HANAODBC, ...)` → Python (`sqlcmd`, `xlsxwriter`, SMTP). |
| OPENQUERY | El `WHERE` va **dentro** del OPENQUERY; filtrar afuera trae todo el histórico. |
| SQL origen | Código magro; omitir `AS` cuando la vista ya trae alias. |
| Python | `sqlcmd` para comandos de base de datos. |

## Flujo por tipo de entrega

### Consulta ad hoc / reporte
```
Verificar esquema → escribir .sql en carpeta del pedido → probar con MCP → documentar supuestos en cabecera
```

### Vista HANA para consumo externo
```
CREATE VIEW EMPAQPLAST_PROD.SB1_VIEW_* → GRANT SELECT → (opcional) vista AlertasB1 → (opcional) alerta Python
```

### Dashboard Power BI
```
Consulta en sqlserver/ → filtrar por fecha → tablas dim/hechos separadas → documentar relaciones en cabecera
```

## Taxonomía del catálogo

Organizar mentalmente (y en carpetas) por **base de datos → dominio**:

| BDD | Subcarpetas |
|-----|-------------|
| `hana/` | cartera, inventario, produccion, compras, supply, logistica, ventas, admin… |
| `sqlserver/` | alertas-b1, rrhh, supply, etl, ops |
| `postgres/` | app, nps |
| `automatizaciones/` | Python multi-BDD (ordenes-compra, pricing, stock-critico) |

## Cabecera mínima en cada .sql

```sql
/* =========================================================================
   NOMBRE_OBJETO
   Esquema: ... | Motor: ...
   Propósito: una línea clara
   Supuestos verificados: ...
   Despliegue: orden si aplica (vista HANA → linked server → Python)
   ========================================================================= */
```

## Checklist antes de entregar

- [ ] Nombres de columna verificados contra servidor
- [ ] Filtros de fecha/documento explícitos (no full scan accidental)
- [ ] Archivo en carpeta correcta del pedido (no suelto en raíz)
- [ ] Cabecera con supuestos de negocio no obvios
- [ ] Si es alerta: WHERE dentro de OPENQUERY probado con COUNT

## Skills por motor (usar según BDD)

| Motor | Skill |
|-------|-------|
| SAP B1 / HANA | `sap-b1-hana-sql` |
| SQL Server | `sqlserver-tsql-empaqplast` |
| PostgreSQL | `postgres-sql-empaqplast` |

Activar el skill del motor **antes** de escribir SQL en esa BDD.

## Referencias (repo Empaqplast)

- Patrones SAP B1 / HANA: [referencias/sap-b1-hana.md](referencias/sap-b1-hana.md)
- SQL Server, AlertasB1 y TimeControl: [referencias/sqlserver-patrones.md](referencias/sqlserver-patrones.md)
- Flujo completo alertas y organización: [referencias/flujo-trabajo.md](referencias/flujo-trabajo.md)
- Catálogo visual del repo: `catalogo-consultas/guia-consultas.html`
