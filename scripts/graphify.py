#!/usr/bin/env python3
"""Deriva graphify-out/graph.json para este repositorio de consultas SQL.

Aqui no hay grafo de imports como en un proyecto de codigo: las dependencias son
objetos de base de datos. Una vista que hace FROM de otra vista es una arista; un
script Python que llama a un SP es una arista. Las referencias a objetos que el
repo no crea (OITM, OITW, tablas de TimeControl) se registran como superficie
externa, no como aristas.

Uso:
    python scripts/graphify.py            # regenera graphify-out/graph.json
    python scripts/graphify.py --check    # compara sin escribir; exit 1 si cambio

Limitaciones conocidas (no corregir a mano el grafo; corregir este script):
  - El match de objetos usa el ultimo segmento del nombre en mayusculas, asi que
    dos objetos homonimos en esquemas distintos colisionarian.
  - No resuelve SQL dinamico armado por concatenacion fuera de OPENQUERY.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "graphify-out"
OUT_FILE = OUT_DIR / "graph.json"

SKIP_DIRS = {".git", ".agents", "graphify-out", "scripts", "__pycache__"}

# Las consultas viven en docs/consultas/<dominio>/... desde la reorganizacion del
# 2026-11-19. El dominio sale de la ruta; el MOTOR ya no, porque un dominio mezcla
# motores (compras = vista HANA + vista SQL Server + script Python). Se deduce del
# contenido, con esta precedencia, y se guarda la evidencia que lo decidio.
CONSULTAS_ROOT = "docs/consultas/"

ENGINE_MARKERS = [
    ("sqlserver", re.compile(r"\bOPENQUERY\s*\(|\bCREATE\s+OR\s+ALTER\b|^\s*USE\s+\w+\s*;|\bdbo\.|\bBACKUP\s+DATABASE\b", re.IGNORECASE | re.MULTILINE)),
    # T0."ItemCode" (alias + columna entre comillas dobles) es la firma de B1 sobre
    # HANA; M_CONNECTIONS y companeras son las vistas de sistema de HANA.
    ("sap-b1-hana", re.compile(r"EMPAQPLAST_PROD|\bADD_DAYS\s*\(|\bDAYS_BETWEEN\s*\(|\bIFNULL\s*\(|SBO_SP_TransactionNotification|\bT\d+\.\"|\bM_[A-Z_]{3,}\b", re.IGNORECASE)),
    ("postgresql", re.compile(r"\bauditorias\.|\bnps\.|OWNER\s+empaqplast|RESTART\s+IDENTITY", re.IGNORECASE)),
]

# Palabras que pueden seguir a FROM/JOIN y no son un objeto.
NOT_OBJECTS = {
    "SELECT", "VALUES", "DUAL", "DUMMY", "LATERAL", "UNNEST", "OPENQUERY",
    "OPENROWSET", "TABLE", "WITH", "SERIES_GENERATE_DATE", "SERIES_GENERATE_INTEGER",
    "STRING_SPLIT", "OPENJSON", "GENERATE_SERIES", "JSON_TABLE", "XMLTABLE",
}

CREATE_RE = re.compile(
    r"\b(?:CREATE|ALTER)\s+(?:OR\s+REPLACE\s+)?"
    r"(?:FORCE\s+)?(?:MATERIALIZED\s+|COLUMN\s+|ROW\s+|GLOBAL\s+TEMPORARY\s+|TEMP\s+)?"
    r"(VIEW|PROCEDURE|PROC|FUNCTION|TABLE|SYNONYM|TRIGGER)\s+"
    r"(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z0-9_.\"\[\]`$#@]+)",
    re.IGNORECASE,
)

REF_RE = re.compile(
    r"\b(?:FROM|JOIN|INTO|UPDATE|MERGE\s+INTO|EXEC|EXECUTE|CALL)\s+"
    r"([A-Za-z0-9_.\"\[\]`$#@]+)",
    re.IGNORECASE,
)

OPENQUERY_RE = re.compile(
    r"OPENQUERY\s*\(\s*\[?([A-Za-z0-9_.\-]+)\]?\s*,\s*(['\"])(.*?)\2\s*\)",
    re.IGNORECASE | re.DOTALL,
)

# Nombres de CTE: "WITH x AS (" / ", x AS (". Se excluyen de las referencias
# porque son locales a la consulta, no objetos de base de datos.
CTE_RE = re.compile(r"(?:\bWITH\s+|,\s*)([A-Za-z0-9_\"\[\]`]+)\s+AS\s*\(", re.IGNORECASE)

PY_SQL_FILE_RE = re.compile(r"['\"]([^'\"\n]+\.sql)['\"]")
PY_IMPORT_RE = re.compile(
    r"^[ \t]*(?:from[ \t]+([A-Za-z0-9_.]+)[ \t]+import|import[ \t]+([A-Za-z0-9_., \t]+))",
    re.MULTILINE,
)
# El SQL de los scripts vive en literales de cadena: solo ahi se buscan objetos,
# para no confundir "from email.mime.base import X" con un FROM de SQL.
PY_STRING_RE = re.compile(
    r'"""(.*?)"""' r"|'''(.*?)'''" r'|"([^"\n]*)"' r"|'([^'\n]*)'",
    re.DOTALL,
)


def strip_sql_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    text = re.sub(r"--[^\n]*", " ", text)
    return text


def strip_string_literals(text: str) -> str:
    return re.sub(r"'(?:[^']|'')*'", " '' ", text)


def normalize(raw: str) -> str:
    name = raw.strip().rstrip(";,)").strip()
    name = name.replace('"', "").replace("[", "").replace("]", "").replace("`", "")
    if not name:
        return ""
    return name.upper()


def bare(name: str) -> str:
    return name.split(".")[-1] if name else ""


def is_object(name: str) -> bool:
    if not name:
        return False
    last = bare(name)
    if last in NOT_OBJECTS or name.upper() in NOT_OBJECTS:
        return False
    if last.startswith("@") or last.startswith("#") or last.startswith("$"):
        return False
    if re.fullmatch(r"T\d+", last) or re.fullmatch(r"\d+", last):
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9_.]+", name))


def parse_sql(text: str) -> dict:
    body = strip_sql_comments(text)

    linked_servers: set[str] = set()
    inner_refs: set[str] = set()
    for srv, _quote, inner in OPENQUERY_RE.findall(body):
        linked_servers.add(srv.upper())
        inner_clean = strip_sql_comments(inner.replace("''", "'"))
        for raw in REF_RE.findall(inner_clean):
            name = normalize(raw)
            if is_object(name):
                inner_refs.add(name)

    body_nostr = strip_string_literals(body)

    creates: set[str] = set()
    create_kinds: dict[str, str] = {}
    for kind, raw in CREATE_RE.findall(body_nostr):
        name = normalize(raw)
        if is_object(name):
            creates.add(name)
            create_kinds[name] = kind.upper().replace("PROC", "PROCEDURE")

    ctes = {normalize(raw) for raw in CTE_RE.findall(body_nostr)}
    ctes |= {normalize(raw) for _s, _q, inner in OPENQUERY_RE.findall(body) for raw in CTE_RE.findall(inner)}
    ctes.discard("")

    refs: set[str] = set()
    for raw in REF_RE.findall(body_nostr):
        name = normalize(raw)
        if is_object(name):
            refs.add(name)
    refs |= inner_refs
    refs -= creates
    refs = {r for r in refs if bare(r) not in ctes}

    return {
        "creates": sorted(creates),
        "create_kinds": create_kinds,
        "references": sorted(refs),
        "linked_servers": sorted(linked_servers),
    }


def parse_python(text: str) -> dict:
    # Separador con ";" para que dos literales sueltos y contiguos (msg["From"] = user)
    # no se lean como un "FROM user" de SQL.
    embedded_sql = "\n;\n".join(
        part for match in PY_STRING_RE.findall(text) for part in match if part
    )
    embedded_sql = strip_sql_comments(embedded_sql)

    # El SQL embebido tambien trae CTEs: se filtran igual que en los .sql
    ctes = {normalize(raw) for raw in CTE_RE.findall(embedded_sql)}
    ctes.discard("")

    refs: set[str] = set()
    for raw in REF_RE.findall(embedded_sql):
        name = normalize(raw)
        if is_object(name) and bare(name) not in ctes:
            refs.add(name)
    imports: set[str] = set()
    for mod_from, mod_import in PY_IMPORT_RE.findall(text):
        if mod_from:
            imports.add(mod_from.split(".")[0])
        for part in (mod_import or "").split(","):
            part = part.strip().split(" ")[0]
            if part:
                imports.add(part.split(".")[0])
    # Nombres de objeto guardados en constantes (SP_NOMBRE = 'sp_x') y ejecutados
    # por f-string: se resuelven despues contra los objetos que el repo crea.
    literals = {
        normalize(part)
        for match in PY_STRING_RE.findall(text)
        for part in match
        if part and re.fullmatch(r"[A-Za-z0-9_.]+", part.strip())
    }
    literals.discard("")

    return {
        "creates": [],
        "create_kinds": {},
        "references": sorted(refs),
        "linked_servers": [],
        "imports": sorted(imports),
        "sql_files": sorted(set(PY_SQL_FILE_RE.findall(text))),
        "literals": sorted(literals),
    }


def collect_files() -> list[Path]:
    files: list[Path] = []
    for path in sorted(REPO.rglob("*")):
        if not path.is_file():
            continue
        rel_parts = path.relative_to(REPO).parts
        if any(part in SKIP_DIRS for part in rel_parts):
            continue
        if path.suffix.lower() in {".sql", ".py"}:
            files.append(path)
    return files


def domain_of(rel: str) -> str:
    """Dominio de negocio: el segmento que sigue a docs/consultas/."""
    if not rel.startswith(CONSULTAS_ROOT):
        return "fuera-de-consultas"
    resto = rel[len(CONSULTAS_ROOT):].split("/")
    return resto[0] if len(resto) > 1 else "raiz"


def engine_of(rel: str, text: str) -> tuple[str, str]:
    """Motor y la evidencia que lo decidio. Nunca se adivina: si nada coincide,
    se declara desconocido para que se vea en el grafo."""
    if rel.endswith(".py"):
        return "python", "extension .py"
    for engine, marker in ENGINE_MARKERS:
        found = marker.search(text)
        if found:
            return engine, found.group(0).strip()[:40]
    return "desconocido", ""


def build_graph() -> dict:
    nodes: list[dict] = []
    produced_by: dict[str, list[str]] = {}

    for path in collect_files():
        rel = path.relative_to(REPO).as_posix()
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            print("ERROR leyendo {}: {}".format(rel, exc), file=sys.stderr)
            continue

        parsed = parse_python(text) if path.suffix.lower() == ".py" else parse_sql(text)
        engine, evidencia = engine_of(rel, text)
        node = {
            "id": rel,
            "domain": domain_of(rel),
            "engine": engine,
            "engine_evidence": evidencia,
            "kind": "python" if path.suffix.lower() == ".py" else "sql",
            "lines": text.count("\n") + 1,
            "creates": [
                {"object": name, "type": parsed["create_kinds"].get(name, "UNKNOWN")}
                for name in parsed["creates"]
            ],
            "references": parsed["references"],
            "linked_servers": parsed["linked_servers"],
        }
        if path.suffix.lower() == ".py":
            node["imports"] = parsed["imports"]
            node["sql_files"] = parsed["sql_files"]
            node["_literals"] = parsed["literals"]
        nodes.append(node)

        for name in parsed["creates"]:
            produced_by.setdefault(bare(name), []).append(rel)

    edges: list[dict] = []
    external: dict[str, list[str]] = {}
    by_basename: dict[str, list[str]] = {}
    for node in nodes:
        by_basename.setdefault(node["id"].split("/")[-1], []).append(node["id"])

    # Segunda pasada en Python: nombres de objeto en constantes y rutas a .sql
    for node in nodes:
        for literal in node.pop("_literals", []):
            if bare(literal) in produced_by and literal not in node["references"]:
                node["references"] = sorted(set(node["references"]) | {literal})
        for sql_file in node.get("sql_files", []):
            for target in by_basename.get(sql_file.split("/")[-1], []):
                if target != node["id"]:
                    edges.append(
                        {"from": node["id"], "to": target, "via": sql_file, "kind": "sql-file"}
                    )

    for node in nodes:
        for ref in node["references"]:
            owners = produced_by.get(bare(ref), [])
            targets = [owner for owner in owners if owner != node["id"]]
            if targets:
                for target in targets:
                    edges.append(
                        {"from": node["id"], "to": target, "via": ref, "kind": "sql-object"}
                    )
            else:
                external.setdefault(bare(ref), []).append(node["id"])

    ids = [n["id"] for n in nodes]
    incoming = {i: 0 for i in ids}
    adj: dict[str, set[str]] = {i: set() for i in ids}
    for edge in edges:
        adj[edge["from"]].add(edge["to"])
        incoming[edge["to"]] += 1

    def reachable(start: str) -> list[str]:
        seen: set[str] = set()
        stack = [start]
        while stack:
            cur = stack.pop()
            for nxt in adj.get(cur, ()):
                if nxt not in seen:
                    seen.add(nxt)
                    stack.append(nxt)
        return sorted(seen)

    entrypoints = [{"id": i, "reaches": reachable(i)} for i in ids if incoming[i] == 0]

    cycles: list[list[str]] = []
    state: dict[str, int] = {}
    path_stack: list[str] = []

    def dfs(node_id: str) -> None:
        state[node_id] = 1
        path_stack.append(node_id)
        for nxt in sorted(adj.get(node_id, ())):
            if state.get(nxt, 0) == 0:
                dfs(nxt)
            elif state.get(nxt) == 1:
                cut = path_stack[path_stack.index(nxt):]
                cycles.append(cut + [nxt])
        path_stack.pop()
        state[node_id] = 2

    for node_id in ids:
        if state.get(node_id, 0) == 0:
            dfs(node_id)

    public_surface = sorted(
        (
            {"object": obj, "defined_in": sorted(set(files))}
            for obj, files in produced_by.items()
        ),
        key=lambda item: item["object"],
    )

    return {
        "generator": "agent-derived",
        "generator_script": "scripts/graphify.py",
        "generated_on": date.today().isoformat(),
        "repo": "Consultas con SQL (Empaqplast)",
        "node_semantics": (
            "un nodo = un archivo .sql o .py; una arista = referencia a un objeto "
            "de BD creado por otro archivo del repo"
        ),
        "counts": {
            "nodes": len(nodes),
            "edges": len(edges),
            "objects_created": len(public_surface),
            "external_references": len(external),
            "entrypoints": len(entrypoints),
            "cycles": len(cycles),
        },
        "nodes": nodes,
        "edges": edges,
        "public_surface": public_surface,
        "external_references": [
            {"object": obj, "referenced_by": sorted(set(files))}
            for obj, files in sorted(external.items())
        ],
        "entrypoints": entrypoints,
        "cycles": cycles,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera el indice topologico del repo.")
    parser.add_argument("--check", action="store_true", help="no escribe; exit 1 si el grafo cambio")
    args = parser.parse_args()

    graph = build_graph()
    rendered = json.dumps(graph, indent=2, ensure_ascii=False) + "\n"

    if args.check:
        if not OUT_FILE.exists():
            print("graph.json no existe: regenera con python scripts/graphify.py")
            return 1
        try:
            current = OUT_FILE.read_text(encoding="utf-8")
        except OSError as exc:
            print("ERROR leyendo {}: {}".format(OUT_FILE, exc), file=sys.stderr)
            return 2
        stamp = r'"generated_on": "[^"]*"'
        if re.sub(stamp, "", current) == re.sub(stamp, "", rendered):
            print("sin cambios")
            return 0
        print("el grafo esta desactualizado: regenera con python scripts/graphify.py")
        return 1

    try:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        OUT_FILE.write_text(rendered, encoding="utf-8")
    except OSError as exc:
        print("ERROR escribiendo {}: {}".format(OUT_FILE, exc), file=sys.stderr)
        return 2

    counts = graph["counts"]
    print(
        "graph.json escrito: {nodes} nodos, {edges} aristas, {objects_created} objetos creados, "
        "{external_references} refs externas, {entrypoints} entrypoints, {cycles} ciclos".format(**counts)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
