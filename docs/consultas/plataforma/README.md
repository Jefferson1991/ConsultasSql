# Plataforma

Lo que no es un reporte de negocio: administración de SAP B1, validaciones y
operación de los servidores.

## sap-b1/

| Archivo | Motor | Qué hace |
|---|---|---|
| [sap-b1/licencias-usuarios.sql](sap-b1/licencias-usuarios.sql) | HANA | Usuarios activos (`Locked = 'N'`) con su licencia asignada. |
| [sap-b1/query-manager-reportes.sql](sap-b1/query-manager-reportes.sql) | HANA | Crea `Fact_Reporte_Query_Manager`: los reportes del Query Manager con categoría y área. El área se infiere **solo** por las tablas y vistas que aparecen en el `QString`. |
| [sap-b1/vistas-clasificacion.sql](sap-b1/vistas-clasificacion.sql) | HANA | Crea `Fact_Vistas_BDD`: las vistas `SB1_VIEW_*` clasificadas por área según sus tablas base, leídas de `OBJECT_DEPENDENCIES`. |
| [sap-b1/transaction-notification-lvs.sql](sap-b1/transaction-notification-lvs.sql) | HANA | `SBO_SP_TransactionNotification_LVS`: todas las validaciones de documentos de B1. **Un cambio aquí afecta a toda la operación de B1**, porque corre en cada alta, cambio, baja y cierre. |
| [sap-b1/busquedas-formateadas.txt](sap-b1/busquedas-formateadas.txt) | HANA | Búsquedas formateadas de B1 (`$[OPCH."CardCode"]`): no son consultas sueltas, se pegan en el campo correspondiente de la interfaz. |

## ops/

| Archivo | Motor | Qué hace |
|---|---|---|
| [ops/diagnostico-conexiones-hana.sql](ops/diagnostico-conexiones-hana.sql) | HANA | Conexiones vivas con host, puerto, usuario e IP del cliente. Para cuando algo tiene tomada la base. |
| [ops/backups-manual.sql](ops/backups-manual.sql) | SQL Server (`internaEmpaqplast`) | Respaldo y restauración con otro nombre, para clonar la base a un entorno de pruebas. |
| [ops/creacion-usuario-ia.sql](ops/creacion-usuario-ia.sql) | HANA | Crea el usuario `USR_IA` con `SELECT` sobre `EMPAQPLAST_PROD`. |

## Aviso de seguridad sobre `ops/creacion-usuario-ia.sql`

Ese archivo tiene la **contraseña en claro** dentro del `CREATE USER`. §5 de
`AGENTS.md` lo prohíbe, y el archivo ya está en el historial de git, así que
borrar la línea no retira la credencial del repositorio. Lo correcto, en este
orden:

1. Rotar la contraseña de `USR_IA` en HANA.
2. Recién entonces reemplazar el literal por una variable o un marcador en el archivo.
3. Decidir si se purga el historial, con el costo que eso tiene en un repo compartido.

Mientras el paso 1 no ocurra, tratar esa credencial como comprometida.
