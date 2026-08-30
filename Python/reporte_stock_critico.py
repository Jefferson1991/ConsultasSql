# =============================================================================
# REPORTE STOCK CRITICO - Envio automatico por email
# =============================================================================
# Ejecuta sp_Stock_Critico_Clientes en SQL Server (AlertasB1),
# genera Excel con formato y semaforo, y envia por correo.
#
# Flujo: HANA (vista) -> SQL Server (OPENQUERY) -> sqlcmd -> Excel -> Email
#
# Dependencias: pip install xlsxwriter
# =============================================================================

import subprocess
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os
import xlsxwriter
from datetime import datetime

# --- CONFIGURACION ---
os.environ['EMAIL_PASSWORD'] = 'J%770655176490ol'

SMTP_CONFIG = {
    'host': "smtp.office365.com",
    'port': 587,
    'user': "sistemas@empaqplast.com",
    'to': [
        'dvaldez@empaqplast.com',
        'ecando@empaqplast.com',
        'achacha@empaqplast.com',
        'cbarbosa@empaqplast.com',
        'evalencia@empaqplast.com'
    ],
    'cc': ['jvasconez@empaqplast.com']
}

# --- CONFIGURACION SQL ---
SERVIDOR_SQL = 'localhost\\SQLEXPRESS'
BASE_DATOS = 'AlertasB1'
SP_NOMBRE = 'sp_Stock_Critico_Clientes'

SEPARADOR = "~"

# --- Colores del semaforo ---
COLOR_VERDE    = '#27AE60'
COLOR_AMARILLO = '#F39C12'
COLOR_ROJO     = '#E74C3C'
COLOR_HEADER   = '#1F497D'


def generar_excel_stock_critico(headers, rows, filename):
    """Genera Excel con formato condicional por semaforo y resumen de cumplimiento."""
    workbook = xlsxwriter.Workbook(filename)

    # =====================================================================
    # HOJA 1: Detalle por item
    # =====================================================================
    ws_detalle = workbook.add_worksheet("Stock Critico")

    # Formatos
    header_fmt = workbook.add_format({
        'bold': True, 'font_color': 'white', 'bg_color': COLOR_HEADER,
        'border': 1, 'align': 'center', 'valign': 'vcenter',
        'text_wrap': True, 'font_size': 10
    })
    body_fmt = workbook.add_format({
        'border': 1, 'valign': 'top', 'font_size': 10
    })
    num_fmt = workbook.add_format({
        'border': 1, 'num_format': '#,##0', 'valign': 'top', 'font_size': 10
    })
    num_dec_fmt = workbook.add_format({
        'border': 1, 'num_format': '#,##0.00', 'valign': 'top', 'font_size': 10
    })

    # Formatos semaforo
    verde_fmt = workbook.add_format({
        'border': 1, 'bg_color': COLOR_VERDE, 'font_color': 'white',
        'bold': True, 'align': 'center', 'valign': 'top', 'font_size': 10
    })
    amarillo_fmt = workbook.add_format({
        'border': 1, 'bg_color': COLOR_AMARILLO, 'font_color': 'white',
        'bold': True, 'align': 'center', 'valign': 'top', 'font_size': 10
    })
    rojo_fmt = workbook.add_format({
        'border': 1, 'bg_color': COLOR_ROJO, 'font_color': 'white',
        'bold': True, 'align': 'center', 'valign': 'top', 'font_size': 10
    })

    # Cumple / No cumple
    cumple_si_fmt = workbook.add_format({
        'border': 1, 'bg_color': '#D5F5E3', 'align': 'center',
        'valign': 'top', 'font_size': 10, 'bold': True
    })
    cumple_no_fmt = workbook.add_format({
        'border': 1, 'bg_color': '#FADBD8', 'align': 'center',
        'valign': 'top', 'font_size': 10, 'bold': True
    })

    # Encontrar indices de columnas clave
    headers_clean = [h.strip() for h in headers]
    idx_semaforo = headers_clean.index('Semaforo') if 'Semaforo' in headers_clean else -1
    idx_cumple = headers_clean.index('Cumple') if 'Cumple' in headers_clean else -1
    idx_doh = headers_clean.index('DOH') if 'DOH' in headers_clean else -1
    idx_cpd = headers_clean.index('CPD') if 'CPD' in headers_clean else -1

    # Columnas numericas enteras (stock, cantidades)
    cols_enteras = {
        'UIO_MP', 'UIO_PT', 'UIO_PROD', 'GYE_PT', 'GYE_MP', 'UIO_CONS', 'UIO_MAT',
        'UIO Total', 'GYE Total', 'STOCK', 'PR Dias', 'LeadTime', 'MinLevel',
        'Consumo_90_dias', 'Cumple'
    }
    # Columnas numericas decimales
    cols_decimales = {'CPD', 'DOH', 'PR_Cantidad'}

    # Anchos de columna
    anchos = {
        'Codigo': 14, 'Codigo_Secundario': 16, 'Item': 50, 'Cliente': 12, 'PR Dias': 8,
        'LeadTime': 10, 'MinLevel': 10,
        'UIO_MP': 12, 'UIO_PT': 12, 'UIO_PROD': 12, 'GYE_PT': 12, 'GYE_MP': 12,
        'UIO_CONS': 12, 'UIO_MAT': 12, 'Consumo_90_dias': 14,
        'UIO Total': 12, 'GYE Total': 12, 'STOCK': 14,
        'CPD': 14, 'PR_Cantidad': 12, 'DOH': 10, 'Cumple': 8, 'Semaforo': 10
    }

    # Escribir encabezados
    for col_num, header in enumerate(headers_clean):
        worksheet_write_header(ws_detalle, col_num, header, header_fmt)
        ancho = anchos.get(header, 12)
        ws_detalle.set_column(col_num, col_num, ancho)

    # Congelar panel (fila de encabezados)
    ws_detalle.freeze_panes(1, 0)

    # Contadores para resumen
    total_items = 0
    items_cumplen = 0

    # Escribir datos
    for row_num, row_data in enumerate(rows, start=1):
        total_items += 1
        for col_num, cell_value in enumerate(row_data):
            cell_value = cell_value.strip()
            header_name = headers_clean[col_num] if col_num < len(headers_clean) else ''

            # Columna Semaforo → formato con color
            if col_num == idx_semaforo:
                if cell_value.lower() == 'verde':
                    ws_detalle.write(row_num, col_num, cell_value, verde_fmt)
                elif cell_value.lower() == 'amarillo':
                    ws_detalle.write(row_num, col_num, cell_value, amarillo_fmt)
                else:
                    ws_detalle.write(row_num, col_num, cell_value, rojo_fmt)
                continue

            # Columna Cumple → SI/NO con color
            if col_num == idx_cumple:
                try:
                    val = int(float(cell_value.replace(',', '') or '0'))
                    texto = 'SI' if val == 1 else 'NO'
                    fmt = cumple_si_fmt if val == 1 else cumple_no_fmt
                    ws_detalle.write(row_num, col_num, texto, fmt)
                    if val == 1:
                        items_cumplen += 1
                except ValueError:
                    ws_detalle.write(row_num, col_num, cell_value, body_fmt)
                continue

            # Columnas numericas
            if header_name in cols_enteras or header_name in cols_decimales:
                try:
                    val_str = cell_value.replace(',', '')
                    val = float(val_str) if val_str and val_str != '-' else 0.0
                    fmt = num_dec_fmt if header_name in cols_decimales else num_fmt
                    ws_detalle.write(row_num, col_num, val, fmt)
                except ValueError:
                    ws_detalle.write(row_num, col_num, cell_value, body_fmt)
                continue

            # Texto
            ws_detalle.write(row_num, col_num, cell_value, body_fmt)

    # =====================================================================
    # HOJA 2: Resumen de cumplimiento
    # =====================================================================
    ws_resumen = workbook.add_worksheet("Resumen KR")

    titulo_fmt = workbook.add_format({
        'bold': True, 'font_size': 14, 'font_color': COLOR_HEADER,
        'bottom': 2, 'bottom_color': COLOR_HEADER
    })
    label_fmt = workbook.add_format({
        'bold': True, 'font_size': 11, 'border': 1, 'bg_color': '#D6E4F0',
        'align': 'left', 'valign': 'vcenter'
    })
    valor_fmt = workbook.add_format({
        'bold': True, 'font_size': 11, 'border': 1,
        'align': 'center', 'valign': 'vcenter'
    })
    pct_fmt = workbook.add_format({
        'bold': True, 'font_size': 14, 'border': 2,
        'align': 'center', 'valign': 'vcenter', 'num_format': '0.0%'
    })

    pct_cumple = items_cumplen / total_items if total_items > 0 else 0
    meta_cumple = pct_cumple >= 0.70

    pct_color_fmt = workbook.add_format({
        'bold': True, 'font_size': 16, 'border': 2,
        'align': 'center', 'valign': 'vcenter', 'num_format': '0.0%',
        'bg_color': COLOR_VERDE if meta_cumple else COLOR_ROJO,
        'font_color': 'white'
    })

    ws_resumen.set_column(0, 0, 30)
    ws_resumen.set_column(1, 1, 20)

    fecha_hoy = datetime.now().strftime("%d/%m/%Y")
    ws_resumen.write(0, 0, f"Cumplimiento Stock Critico - {fecha_hoy}", titulo_fmt)
    ws_resumen.write(1, 0, '', None)

    ws_resumen.write(2, 0, 'Total Items Monitoreados', label_fmt)
    ws_resumen.write(2, 1, total_items, valor_fmt)

    ws_resumen.write(3, 0, 'Items que Cumplen PR', label_fmt)
    ws_resumen.write(3, 1, items_cumplen, valor_fmt)

    ws_resumen.write(4, 0, 'Items que NO Cumplen', label_fmt)
    ws_resumen.write(4, 1, total_items - items_cumplen, valor_fmt)

    ws_resumen.write(5, 0, '', None)

    ws_resumen.write(6, 0, '% Cumplimiento', label_fmt)
    ws_resumen.write(6, 1, pct_cumple, pct_color_fmt)

    ws_resumen.write(7, 0, 'Meta (70%)', label_fmt)
    ws_resumen.write(7, 1, 0.70, pct_fmt)

    ws_resumen.write(8, 0, '', None)
    ws_resumen.write(9, 0, 'Estado', label_fmt)
    estado = 'CUMPLE META' if meta_cumple else 'NO CUMPLE META'
    estado_fmt = workbook.add_format({
        'bold': True, 'font_size': 14, 'border': 2,
        'align': 'center', 'valign': 'vcenter',
        'bg_color': COLOR_VERDE if meta_cumple else COLOR_ROJO,
        'font_color': 'white'
    })
    ws_resumen.write(9, 1, estado, estado_fmt)

    # Leyenda semaforo
    ws_resumen.write(11, 0, 'Leyenda Semaforo:', workbook.add_format({'bold': True, 'font_size': 11}))
    ws_resumen.write(12, 0, 'Verde', verde_fmt)
    ws_resumen.write(12, 1, 'DOH >= PR + 5 dias (bien abastecido)', body_fmt)
    ws_resumen.write(13, 0, 'Amarillo', amarillo_fmt)
    ws_resumen.write(13, 1, 'DOH entre PR y PR+5 (monitorear)', body_fmt)
    ws_resumen.write(14, 0, 'Rojo', rojo_fmt)
    ws_resumen.write(14, 1, 'DOH < PR (critico, riesgo quiebre)', body_fmt)

    workbook.close()


def worksheet_write_header(ws, col, text, fmt):
    """Helper para escribir encabezado."""
    ws.write(0, col, text, fmt)


def generar_tabla_html(headers, rows):
    """Genera tabla HTML con semaforo para incrustar en el cuerpo del email."""
    headers_clean = [h.strip() for h in headers]
    idx_semaforo = headers_clean.index('Semaforo') if 'Semaforo' in headers_clean else -1
    idx_cumple = headers_clean.index('Cumple') if 'Cumple' in headers_clean else -1

    # Solo columnas clave para el email (resumen visual, no todas)
    cols_email = ['Codigo', 'Item', 'Cliente', 'STOCK', 'CPD', 'DOH', 'PR Dias', 'Cumple', 'Semaforo']
    # Filtrar solo las que existan en headers
    idx_cols = [headers_clean.index(c) for c in cols_email if c in headers_clean]

    html = '<table style="border-collapse:collapse;font-family:Arial;font-size:11px;width:100%;">'

    # Encabezados
    html += '<tr>'
    for i in idx_cols:
        html += f'<th style="background:{COLOR_HEADER};color:white;padding:6px 10px;border:1px solid #ddd;text-align:center;">{headers_clean[i]}</th>'
    html += '</tr>'

    # Filas
    for row_data in rows:
        html += '<tr>'
        for i in idx_cols:
            val = row_data[i].strip() if i < len(row_data) else ''

            style = 'padding:4px 8px;border:1px solid #ddd;'

            if i == idx_semaforo:
                color = {'verde': COLOR_VERDE, 'amarillo': COLOR_AMARILLO, 'rojo': COLOR_ROJO}.get(val.lower(), '#999')
                style += f'background:{color};color:white;font-weight:bold;text-align:center;'
            elif i == idx_cumple:
                try:
                    es_si = int(float(val.replace(',', '') or '0')) == 1
                    val = 'SI' if es_si else 'NO'
                    bg = '#D5F5E3' if es_si else '#FADBD8'
                    style += f'background:{bg};text-align:center;font-weight:bold;'
                except ValueError:
                    pass
            else:
                # Intentar alinear numeros a la derecha
                try:
                    float(val.replace(',', ''))
                    style += 'text-align:right;'
                except ValueError:
                    style += 'text-align:left;'

            html += f'<td style="{style}">{val}</td>'
        html += '</tr>'

    html += '</table>'
    return html


def send_email(subject, attachment_path, headers, rows):
    """Envia email con tabla resumen en el cuerpo y Excel adjunto."""
    password = os.getenv('EMAIL_PASSWORD')
    msg = MIMEMultipart()
    msg['Subject'] = subject
    msg['From'] = SMTP_CONFIG['user']
    msg['To'] = ', '.join(SMTP_CONFIG['to'])
    msg['Cc'] = ', '.join(SMTP_CONFIG['cc'])

    fecha_hoy = datetime.now().strftime("%d/%m/%Y")

    # Calcular resumen
    total = len(rows)
    cumplen = 0
    idx_cumple = -1
    headers_clean = [h.strip() for h in headers]
    if 'Cumple' in headers_clean:
        idx_cumple = headers_clean.index('Cumple')
    for r in rows:
        try:
            if idx_cumple >= 0 and int(float(r[idx_cumple].strip().replace(',', '') or '0')) == 1:
                cumplen += 1
        except (ValueError, IndexError):
            pass

    pct = (cumplen / total * 100) if total > 0 else 0
    meta_ok = pct >= 70
    color_pct = COLOR_VERDE if meta_ok else COLOR_ROJO
    estado = 'CUMPLE' if meta_ok else 'NO CUMPLE'

    tabla_html = generar_tabla_html(headers, rows)

    html_body = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333;">
        <div style="border-left: 6px solid {COLOR_HEADER}; padding-left: 20px; background-color: #f9f9f9; padding: 20px;">

            <h2 style="color: {COLOR_HEADER}; margin-bottom: 5px;">Reporte Stock Critico</h2>
            <p style="color: #666; margin-top: 0;">Fecha: {fecha_hoy}</p>

            <!-- Resumen KR -->
            <div style="margin: 15px 0; padding: 15px; border-radius: 8px; background: white; border: 1px solid #ddd; display: inline-block;">
                <table style="font-size: 13px; border-collapse: collapse;">
                    <tr>
                        <td style="padding: 4px 15px;">Items monitoreados:</td>
                        <td style="padding: 4px 15px; font-weight: bold;">{total}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 15px;">Cumplen PR:</td>
                        <td style="padding: 4px 15px; font-weight: bold; color: {COLOR_VERDE};">{cumplen}</td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 15px;">No cumplen:</td>
                        <td style="padding: 4px 15px; font-weight: bold; color: {COLOR_ROJO};">{total - cumplen}</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px 15px; font-size: 15px; font-weight: bold;">Cumplimiento:</td>
                        <td style="padding: 8px 15px; font-size: 18px; font-weight: bold; color: white; background: {color_pct}; border-radius: 4px; text-align: center;">
                            {pct:.1f}% - {estado}
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 4px 15px; color: #999;">Meta:</td>
                        <td style="padding: 4px 15px; color: #999;">70%</td>
                    </tr>
                </table>
            </div>

            <!-- Tabla detalle -->
            <h3 style="color: {COLOR_HEADER};">Detalle por Item</h3>
            {tabla_html}

            <br>
            <p style="font-size: 11px; color: #999;">
                Semaforo: <span style="color:{COLOR_VERDE};">&#9632; Verde</span> (DOH &ge; PR+5) |
                <span style="color:{COLOR_AMARILLO};">&#9632; Amarillo</span> (entre PR y PR+5) |
                <span style="color:{COLOR_ROJO};">&#9632; Rojo</span> (DOH &lt; PR)
            </p>
            <p style="font-size: 11px; color: #999;">El archivo Excel adjunto contiene el detalle completo y la hoja de resumen.</p>

            <br>
            <h5 style="color: {COLOR_HEADER}; margin-bottom: 5px;">Atentamente</h5>
            <h5 style="color: {COLOR_HEADER}; margin-top: 0;">EMPAQPLAST S.A</h5>
        </div>
    </body>
    </html>
    """
    msg.attach(MIMEText(html_body, 'html'))

    # Adjuntar Excel
    if attachment_path and os.path.exists(attachment_path):
        with open(attachment_path, 'rb') as attachment:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header('Content-Disposition', f'attachment; filename={os.path.basename(attachment_path)}')
            msg.attach(part)

    try:
        smtp = smtplib.SMTP(SMTP_CONFIG['host'], SMTP_CONFIG['port'])
        smtp.starttls()
        smtp.login(SMTP_CONFIG['user'], password)
        smtp.sendmail(SMTP_CONFIG['user'], SMTP_CONFIG['to'] + SMTP_CONFIG['cc'], msg.as_string())
        smtp.quit()
        print("Correo enviado correctamente.")
    except Exception as e:
        print(f"Error al enviar correo: {e}")


def run():
    """Ejecuta SP, genera Excel y envia email."""
    print("Ejecutando sp_Stock_Critico_Clientes...")

    command = [
        'sqlcmd',
        '-S', SERVIDOR_SQL,
        '-d', BASE_DATOS,
        '-Q', f'EXEC {SP_NOMBRE}',
        '-s', SEPARADOR,
        '-W',
        '-w', '65535'
    ]

    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True, encoding='latin-1')

        if not result.stdout:
            print("Salida vacia.")
            return

        lines = result.stdout.strip().splitlines()
        if not lines:
            print("Sin datos.")
            return

        headers = lines[0].split(SEPARADOR)
        column_count = len(headers)
        print(f"Columnas detectadas: {column_count}")

        clean_rows = []
        for line in lines[1:]:
            if "---" in line or "rows affected" in line or not line.strip():
                continue

            row_data = line.split(SEPARADOR)

            # Si hay mas columnas de las esperadas (separador en el texto)
            if len(row_data) > column_count:
                fixed_row = row_data[:2]                          # Codigo, Item (podria estar partido)
                middle = " ".join(row_data[2:-(column_count-2)])  # Unir exceso
                fixed_row.append(middle)
                fixed_row.extend(row_data[-(column_count-3):])    # Resto de columnas
                # Si sigue mal, tomar las ultimas N columnas
                if len(fixed_row) != column_count:
                    fixed_row = row_data[:1]
                    fixed_row.append(" ".join(row_data[1:-(column_count-2)]))
                    fixed_row.extend(row_data[-(column_count-2):])
                clean_rows.append(fixed_row[:column_count])
            else:
                clean_rows.append(row_data)

        if not clean_rows:
            print("El SP no trajo datos.")
            return

        fecha_file = datetime.now().strftime("%Y%m%d")
        excel_file = f'Stock_Critico_{fecha_file}.xlsx'

        generar_excel_stock_critico(headers, clean_rows, excel_file)

        subject = f'Stock Critico - Cumplimiento PT ({datetime.now().strftime("%d/%m/%Y")})'
        send_email(subject, excel_file, headers, clean_rows)

        if os.path.exists(excel_file):
            os.remove(excel_file)

        print("Proceso finalizado con exito.")

    except subprocess.CalledProcessError as e:
        print("Error en sqlcmd:", e.stderr)
    except Exception as e:
        print(f"Error general: {e}")


if __name__ == "__main__":
    run()
