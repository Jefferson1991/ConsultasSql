# =============================================================================
# ALERTA ÓRDENES DE COMPRA — mismo patrón que NotificacionStockMinimo.py
# Vista: dbo.ORDENES_COMPRA (AlertasB1)
#        -> OPENQUERY(HANAODBC) -> EMPAQPLAST_PROD.SB1_VIEW_ORDENES_COMPRA
#
# ALCANCE: serie OCNAC (nacionales) y sólo documentos y líneas ABIERTOS. Los
# dos filtros están en la vista de HANA, no en este script.
#
# Por ahora: sin parámetros. Siempre trae y envía toda la vista
# dbo.ORDENES_COMPRA (todo lo abierto OCNAC).
#
# Uso:
#   python NotificacionOrdenesCompra.py
#
# Dependencias: xlsxwriter; sqlcmd en PATH (igual que el resto de reportes).
# =============================================================================

import os
import subprocess
import smtplib
import sys
from datetime import datetime
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import xlsxwriter

# --- CONFIGURACIÓN CORREO (misma cuenta que otros reportes) ---
# La clave se toma de la variable de entorno EMAIL_PASSWORD; el setdefault
# mantiene el script ejecutable tal cual como los demás reportes.
os.environ.setdefault("EMAIL_PASSWORD", "J%770655176490ol")

SMTP_CONFIG = {
    "host": "smtp.office365.com",
    "port": 587,
    "user": "sistemas@empaqplast.com",
}

# Destinatarios — REVISAR antes de programar la tarea.
DESTINATARIOS = [
    "jvasconez@empaqplast.com",
]

# --- SQL ---
SERVIDOR_SQL = "localhost\\SQLEXPRESS"
BASE_DATOS = "AlertasB1"
SEPARADOR = "~"

# Columnas del reporte. El orden aquí es el orden de las columnas del Excel.
COLUMNAS = [
    "Serie",
    "Numero_OC",
    "Fecha_Contabilizacion",
    "Fecha_Entrega_Linea",
    "Codigo_Proveedor",
    "Nombre_Proveedor",
    "Ref_Proveedor",
    "Condicion_Pago",
    "Creado_Por",
    "Moneda",
    "Linea",
    "Codigo_Articulo",
    "Descripcion",
    "Unidad",
    "Bodega",
    "Cantidad_Pedida",
    "Cantidad_Recibida",
    "Cantidad_Pendiente",
    "Precio_Unitario",
    "Total_Linea",
    "Valor_Pendiente",
    "Dias_Atraso",
    "Documento_Base",
    "Documento_Destino",
    "Comentarios",
]

COLUMNAS_FECHA = {
    "Fecha_Contabilizacion",
    "Fecha_Documento",
    "Fecha_Entrega",
    "Fecha_Entrega_Linea",
}
COLUMNAS_ENTERAS = {"Numero_OC", "Linea", "Dias_Atraso", "DocEntry"}
COLUMNAS_DECIMALES = {
    "Cantidad_Pedida",
    "Cantidad_Recibida",
    "Cantidad_Pendiente",
    "Precio_Unitario",
    "Total_Linea",
    "Valor_Pendiente",
    "Total_OC",
    "Tasa_Cambio",
}
ANCHOS = {
    "Nombre_Proveedor": 34,
    "Descripcion": 42,
    "Comentarios": 50,
    "Condicion_Pago": 22,
    "Creado_Por": 20,
    "Documento_Base": 20,
    "Documento_Destino": 22,
    "Codigo_Articulo": 16,
    "Codigo_Proveedor": 16,
}


def _lista_select() -> str:
    """Comentarios se recorta: una línea muy larga desborda el ancho de sqlcmd."""
    campos = []
    for col in COLUMNAS:
        if col == "Comentarios":
            campos.append("LEFT(Comentarios, 200) AS Comentarios")
        else:
            campos.append(col)
    return ", ".join(campos)


def _armar_query() -> str:
    """Toda dbo.ORDENES_COMPRA (OCNAC abiertas desde HANA), sin filtro extra."""
    seleccion = _lista_select()
    cuerpo = (
        f"SELECT {seleccion} FROM dbo.ORDENES_COMPRA "
        "ORDER BY Dias_Atraso DESC, Numero_OC DESC, Linea;"
    )
    return "SET NOCOUNT ON; " + cuerpo


def ejecutar_sqlcmd_y_filas(query: str):
    """Devuelve (headers, clean_rows) o ([], []) si no hay datos."""
    command = [
        "sqlcmd",
        "-S",
        SERVIDOR_SQL,
        "-d",
        BASE_DATOS,
        "-Q",
        query,
        "-s",
        SEPARADOR,
        "-W",
        "-w",
        "65535",
    ]
    result = subprocess.run(
        command, capture_output=True, text=True, check=True, encoding="latin-1"
    )
    if not result.stdout or not result.stdout.strip():
        return [], []

    lines = result.stdout.strip().splitlines()
    if not lines:
        return [], []

    headers = lines[0].split(SEPARADOR)
    column_count = len(headers)

    clean_rows = []
    for line in lines[1:]:
        if "---" in line:
            continue
        if "rows affected" in line.lower() or not line.strip():
            continue
        row_data = line.split(SEPARADOR)
        # La vista de HANA ya limpia CR/LF y '~' de los campos de texto, así que
        # una fila con otro número de columnas es un caso raro: se descarta en
        # vez de intentar recomponerla a ciegas.
        if len(row_data) == column_count:
            clean_rows.append(row_data)

    return headers, clean_rows


def _indice(headers, nombre):
    for i, h in enumerate(headers):
        if h.strip() == nombre:
            return i
    return -1


def _a_numero(texto):
    texto = texto.strip().replace(",", "")
    if not texto or texto in ("-", "NULL"):
        return 0.0
    try:
        return float(texto)
    except ValueError:
        return None


def generar_excel(headers, rows, filename):
    workbook = xlsxwriter.Workbook(filename)
    ws = workbook.add_worksheet("Ordenes de Compra")

    header_fmt = workbook.add_format(
        {"bold": True, "font_color": "white", "bg_color": "#1F497D",
         "border": 1, "text_wrap": True, "valign": "vcenter"}
    )
    body_fmt = workbook.add_format({"border": 1, "valign": "top"})
    int_fmt = workbook.add_format({"border": 1, "num_format": "0", "valign": "top"})
    num_fmt = workbook.add_format(
        {"border": 1, "num_format": "#,##0.00", "valign": "top"}
    )
    date_fmt = workbook.add_format(
        {"border": 1, "num_format": "dd/mm/yyyy", "valign": "top"}
    )
    alerta_fmt = workbook.add_format(
        {"border": 1, "num_format": "0", "valign": "top",
         "bg_color": "#F8CBAD", "bold": True}
    )

    for col_num, h in enumerate(headers):
        nombre = h.strip()
        ws.write(0, col_num, nombre.replace("_", " "), header_fmt)
        ws.set_column(col_num, col_num, ANCHOS.get(nombre, 15))

    idx_atraso = _indice(headers, "Dias_Atraso")

    for row_num, row_data in enumerate(rows, start=1):
        for col_num, cell_value in enumerate(row_data):
            nombre = headers[col_num].strip()
            cell_value = cell_value.strip()

            if nombre in COLUMNAS_FECHA:
                try:
                    fecha = datetime.strptime(cell_value[:10], "%Y-%m-%d")
                    ws.write_datetime(row_num, col_num, fecha, date_fmt)
                except ValueError:
                    ws.write(row_num, col_num, cell_value, body_fmt)
                continue

            if nombre in COLUMNAS_ENTERAS or nombre in COLUMNAS_DECIMALES:
                valor = _a_numero(cell_value)
                if valor is None:
                    ws.write(row_num, col_num, cell_value, body_fmt)
                    continue
                if nombre in COLUMNAS_ENTERAS:
                    fmt = int_fmt
                    if nombre == "Dias_Atraso" and valor > 0:
                        fmt = alerta_fmt
                    ws.write_number(row_num, col_num, valor, fmt)
                else:
                    ws.write_number(row_num, col_num, valor, num_fmt)
                continue

            ws.write(row_num, col_num, cell_value, body_fmt)

    ws.freeze_panes(1, 0)
    ws.autofilter(0, 0, len(rows), len(headers) - 1)
    if idx_atraso >= 0:
        ws.set_column(idx_atraso, idx_atraso, 12)

    workbook.close()


def _resumen(headers, rows):
    """(numero de OC distintas, líneas, valor pendiente, líneas atrasadas)."""
    idx_oc = _indice(headers, "Numero_OC")
    idx_valor = _indice(headers, "Valor_Pendiente")
    idx_atraso = _indice(headers, "Dias_Atraso")

    ocs = set()
    valor_total = 0.0
    atrasadas = 0
    for row in rows:
        if idx_oc >= 0:
            ocs.add(row[idx_oc].strip())
        if idx_valor >= 0:
            valor = _a_numero(row[idx_valor])
            if valor:
                valor_total += valor
        if idx_atraso >= 0:
            dias = _a_numero(row[idx_atraso])
            if dias and dias > 0:
                atrasadas += 1
    return len(ocs), len(rows), valor_total, atrasadas


def enviar_correo(subject, destinatarios, attachment_path, encabezado, resumen):
    password = os.getenv("EMAIL_PASSWORD")
    msg = MIMEMultipart()
    msg["Subject"] = subject
    msg["From"] = SMTP_CONFIG["user"]
    msg["To"] = ", ".join(destinatarios)

    ocs, lineas, valor_total, atrasadas = resumen
    html_body = f"""
    <html>
    <body style="font-family: Arial, sans-serif;">
        <h2 style="color: #2c3e50;">{encabezado}</h2>
        <p>Estimado usuario,</p>
        <p>Adjuntamos el detalle de órdenes de compra tomado de SAP Business One.</p>
        <table style="border-collapse: collapse; font-size: 14px;">
            <tr><td style="padding:4px 12px;"><strong>Órdenes de compra</strong></td>
                <td style="padding:4px 12px;">{ocs}</td></tr>
            <tr><td style="padding:4px 12px;"><strong>Líneas</strong></td>
                <td style="padding:4px 12px;">{lineas}</td></tr>
            <tr><td style="padding:4px 12px;"><strong>Valor pendiente</strong></td>
                <td style="padding:4px 12px;">{valor_total:,.2f} USD</td></tr>
            <tr><td style="padding:4px 12px;"><strong>Líneas atrasadas</strong></td>
                <td style="padding:4px 12px;">{atrasadas}</td></tr>
        </table>
        <p>Saludos cordiales,<br/>El equipo de Empaqplast</p>
    </body>
    </html>
    """
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    if attachment_path and os.path.isfile(attachment_path):
        with open(attachment_path, "rb") as f:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename={os.path.basename(attachment_path)}",
            )
            msg.attach(part)

    smtp = smtplib.SMTP(SMTP_CONFIG["host"], SMTP_CONFIG["port"])
    smtp.starttls()
    smtp.login(SMTP_CONFIG["user"], password)
    smtp.send_message(msg)
    smtp.quit()
    print("Correo enviado correctamente.")


def main():
    asunto = "Órdenes de Compra pendientes de recibir"
    encabezado = "Órdenes de compra pendientes de recibir"

    print("Ejecutando consulta (sqlcmd)...")
    try:
        headers, rows = ejecutar_sqlcmd_y_filas(_armar_query())
    except subprocess.CalledProcessError as e:
        print("Error en sqlcmd:", e.stderr)
        sys.exit(1)

    if not rows:
        print("No hay órdenes de compra. No se envía correo.")
        return

    excel_file = f"OrdenesCompraPendientes_{datetime.now():%Y%m%d}.xlsx"
    generar_excel(headers, rows, excel_file)
    try:
        enviar_correo(
            asunto, DESTINATARIOS, excel_file, encabezado, _resumen(headers, rows)
        )
    finally:
        if os.path.exists(excel_file):
            try:
                os.remove(excel_file)
            except OSError:
                pass
    print("Proceso finalizado.")


if __name__ == "__main__":
    main()
