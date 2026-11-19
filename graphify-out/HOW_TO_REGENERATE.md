# Cómo regenerar `graphify-out/`

> Este archivo y `graph.json` son el índice topológico de §2.2 de `AGENTS.md`.
> `graph.json` es **generado**: no se edita a mano (§5). Si el grafo dice algo que
> contradice tu suposición, el grafo gana hasta que la lectura de un archivo lo
> desmienta; si el grafo está mal, se corrige `scripts/graphify.py` y se regenera.

## Comando exacto

```powershell
python scripts/graphify.py
```

Verificar si está desactualizado sin escribir nada (exit 1 si cambió):

```powershell
python scripts/graphify.py --check
```

- **Herramienta:** `scripts/graphify.py` (generador propio del repo, sin dependencias externas: solo librería estándar).
- **Versión del intérprete:** Python 3.14.6 (la usada el 2026-11-19).
- **Última regeneración:** 2026-11-19.
- **`"generator"` en el JSON:** `agent-derived` — lo escribió un agente, no una herramienta de análisis de dependencias de terceros.

## Por qué un generador propio

La escalera de §2.2 se recorrió así:

1. Comando de grafo en §7 de `AGENTS.md` — estaba en blanco.
2. Script del repo (`npm run graph*`, `Makefile`, `scripts/graphify.*`) — no existía ninguno; el repo no tiene `package.json`, `pyproject.toml` ni `Makefile`.
3. Generador del entorno (`madge`, `dependency-cruiser`, `pydeps`, analizador .NET) — no aplica: 62 de los 65 nodos son `.sql`, y ninguna de esas herramientas entiende dependencias entre vistas y procedimientos.
4. **Derivación propia** — la opción tomada.

Desde esta sesión, el escalón 2 ya aplica: la próxima vez basta `python scripts/graphify.py`.

## Qué significa cada cosa en `graph.json`

Aquí no hay imports: las dependencias son **objetos de base de datos**.

| Clave | Contenido |
|---|---|
| `nodes` | Un nodo por archivo `.sql` o `.py` fuera de `.agents/`, con motor, líneas, objetos que crea, objetos que referencia y linked servers que usa. |
| `edges` | `kind: "sql-object"` cuando un archivo referencia un objeto creado por otro archivo del repo; `kind: "sql-file"` cuando un script Python ejecuta un `.sql` del repo por su ruta. |
| `public_surface` | Objetos que el repo **crea** (vistas, SP, funciones, tablas, triggers) y en qué archivo se definen. Si un objeto aparece en dos archivos, hay dos definiciones de la misma verdad: revísalo. |
| `external_references` | Objetos referenciados que el repo **no** crea: tablas de SAP B1 (`OITM`, `OITW`, `OCRD`…), de TimeControl (`tbl_asistencia`, `viewEmpleados`…), etc. Es la superficie de la que el repo depende y no controla. |
| `entrypoints` | Nodos sin aristas entrantes, con su conjunto alcanzable (`reaches`). En este repo son los reportes de consumo final y los scripts de automatización. |
| `cycles` | Ciclos de dependencia detectados por DFS. |

## Limitaciones conocidas

- El emparejamiento usa el **último segmento** del nombre en mayúsculas, así que dos objetos homónimos en esquemas distintos colisionarían.
- No resuelve SQL dinámico armado por concatenación, salvo el caso ya cubierto de `OPENQUERY(SERVIDOR, '...')` y el de un nombre de objeto guardado en una constante de Python y ejecutado por f-string.
- Las CTE se excluyen por patrón (`WITH x AS (`); una CTE declarada de forma muy inusual podría aparecer como referencia externa.

## Git

`graphify-out/` está en `.gitignore`: §7 de `AGENTS.md` fija `Commit generated indexes?: no`. `scripts/graphify.py` sí se versiona.
