# Consultas — Empaqplast

Carpeta de consultas, vistas y scripts de automatización sobre SAP B1 (HANA),
SQL Server y Fracttal.

## Regla de organización (obligatoria)

**Cada pedido nuevo va en su propia carpeta.** Antes de escribir el primer archivo
de un pedido, crear la carpeta y trabajar dentro de ella. No dejar archivos sueltos
en la raíz.

- **Nombre de carpeta:** kebab-case, descriptivo del tema, en español y sin fechas
  (`ordenes-compra-sap-b1`, `traslado-vs-salida-mercancia`, `activos-fracttal`).
  El nombre describe **el asunto**, no el tipo de archivo ni el sistema origen.
- **Un pedido = una carpeta**, con todo lo suyo adentro: `.sql`, `.py`, `.xlsx` de
  salida, notas y archivos intermedios que valga la pena conservar.
- **Si el pedido nuevo es continuación** de uno existente (corregir, ampliar o
  versionar algo que ya está), va **en la carpeta existente**, no en una nueva.
  Ante la duda, preguntar antes de crear una carpeta nueva.
- **Se queda en la raíz** solo lo que aplica a todo: `CLAUDE.md`,
  `Consultas.code-workspace`, `.claude/`.
- **No dejar residuos:** `__pycache__`, archivos temporales de pruebas y borradores
  descartados se borran al terminar. Lo temporal va al scratchpad de la sesión,
  no a esta carpeta.
- Cada carpeta debe poder entenderse sola: si el script necesita un orden de
  despliegue o supuestos no obvios, van en el comentario de cabecera del archivo.

## Catálogo e inventario

| Recurso | Qué contiene |
|---|---|
| `catalogo-consultas/guia-consultas.html` | Guía HTML interactiva: inventario por sistema → dominio → tipo, búsqueda, filtros y mapa de arquitectura. |
| `~/.agents/skills/consultas-sql-empaqplast/` | Agent Skill con convenciones HANA, SQL Server, alertas OPENQUERY y flujo de trabajo. |

## Contenido actual

Cada fila es una carpeta de pedido en la raíz. Todo el material antes en `Scripts/` fue migrado aquí.

| Carpeta | Motor | Qué contiene |
|---|---|---|
| `ordenes-compra-sap-b1/` | HANA + SQL Server + Python | OC abiertas OCNAC: `SB1_VIEW_ORDENES_COMPRA`, vista AlertasB1, alerta Python. |
| `traslado-vs-salida-mercancia/` | HANA | Traslado vs salida con promedio ponderado y asiento contable. |
| `status-retencion-cartera/` | HANA | `SB1_VIEW_STATUS_RETENCION_CARTERA` sobre `EMPAQPLAST::STATUSRETENCION`. |
| `facturas-pricing-revenueos/` | HANA + Python | Facturas OINV/INV1 → plantilla RevenueOS. |
| `cartera-sap-b1/` | HANA | Bloqueos, facturas vencidas, SP Transaction Notification cartera. |
| `inventario-revision-stock/` | HANA | `SB1_VIEW_REVISION_STOCK_V2` y ALTER de despliegue. |
| `inventario-ubicaciones-upc/` | HANA | `SB1_VIEW_UBICACIONES_UPC`. |
| `inventario-entrada-mercancias-ot/` | HANA | Entradas de mercancía ligadas a OT. |
| `produccion-inventario-plantas/` | HANA | Stock y movimientos UIO/GYE. |
| `produccion-transformados/` | HANA | Vista transformados y kg eficiencia energética. |
| `analisis-moldes/` | HANA | Vista, hechos y validación análisis moldes. |
| `stock-critico-clientes/` | HANA + SQL Server + Python | Vista, SP, reporte y alerta stock crítico. |
| `eficiencia-energetica-combustible/` | HANA | Reporte combustible. |
| `admin-sap-b1/` | HANA | Inventario vistas, licencias, Query Manager. |
| `usuario-ia-bdd/` | HANA | Creación usuario BD para IA. |
| `reporte-pallets-automatizacion/` | HANA | Guías ODLN + transferencias OWTR (n8n). |
| `sp-transaction-notification-lvs/` | HANA | SP Transaction Notification LVS. |
| `hana-diagnostico-conexiones/` | HANA | Diagnóstico `SYS.M_CONNECTIONS`. |
| `vm-atrasos-tcontrol/` | SQL Server | Vista `vm_atrasos` y derivados, festivos 2026. |
| `dashboard-rrhh-powerbi/` | SQL Server | Consultas Power BI RRHH + documentación. |
| `tcontrol-asistencia-turnos/` | SQL Server | Asistencia, cumplimiento turnos, SP empleado. |
| `permisos-con-paga-tcontrol/` | SQL Server | Permisos con/sin paga, catálogo y correcciones. |
| `carga-rotacion-etl/` | SQL Server | ETL rotación incremental. |
| `backups-sqlserver/` | SQL Server | Backups manuales. |
| `postgres-app-empaqplast/` | PostgreSQL | Auth app Empaqplast y DDL infra. |
| `nps-campana-semestral/` | PostgreSQL | Campañas NPS semestrales. |
| `activos-fracttal/` | Fracttal | Estadísticas activos exportados. |
| `catalogo-consultas/` | Docs | Guía HTML interactiva del inventario. |

## Convenciones técnicas

- **SAP B1 sobre HANA:** los nombres de columna son sensibles a mayúsculas y van
  entre comillas dobles (`SELECT "ItemCode" FROM OITM`). Los nombres de tabla de B1
  van en mayúsculas y sin comillas. Esquema de producción: `EMPAQPLAST_PROD`.
- **Alertas por correo:** la cadena es vista HANA `SB1_VIEW_*` →
  vista en `AlertasB1` con `OPENQUERY(HANAODBC, ...)` → Python con `sqlcmd`,
  `xlsxwriter` y SMTP. El `WHERE` va **dentro** del OPENQUERY: filtrar por fuera
  trae el histórico completo antes de filtrar.
- **SQL de origen:** código magro; se omite el `AS` cuando la vista ya trae alias.
- **Python de automatización:** `sqlcmd` para los comandos de base de datos.
- Verificar el esquema real contra el servidor antes de escribir una consulta;
  nunca asumir nombres de columna.
