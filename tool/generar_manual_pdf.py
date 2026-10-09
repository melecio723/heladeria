#!/usr/bin/env python3
"""Genera el Manual de uso del Gestor de Créditos Bear Helados."""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, inch
from reportlab.platypus import (
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "assets" / "images" / "bear_logo_nobg.png"
OUT = Path.home() / "Downloads" / "Manual-Gestor-Creditos-Bear-Helados.pdf"

RED = colors.HexColor("#E53935")
BROWN = colors.HexColor("#5D3A1A")
INDIGO = colors.HexColor("#1A237E")
MUTED = colors.HexColor("#666666")
LIGHT = colors.HexColor("#F5F5F5")
BORDER = colors.HexColor("#E0E0E0")


def styles():
    base = getSampleStyleSheet()
    return {
        "cover_title": ParagraphStyle(
            "cover_title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=26,
            textColor=BROWN,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "cover_sub": ParagraphStyle(
            "cover_sub",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=13,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "h1": ParagraphStyle(
            "h1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=16,
            textColor=RED,
            spaceBefore=16,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "h2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12,
            textColor=INDIGO,
            spaceBefore=12,
            spaceAfter=6,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=14,
            alignment=TA_JUSTIFY,
            textColor=colors.HexColor("#222222"),
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "bullet",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=10,
            leading=13,
            leftIndent=4,
            textColor=colors.HexColor("#222222"),
        ),
        "note": ParagraphStyle(
            "note",
            parent=base["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9,
            leading=12,
            textColor=MUTED,
            spaceBefore=4,
            spaceAfter=8,
        ),
        "footer": ParagraphStyle(
            "footer",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=8,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "toc": ParagraphStyle(
            "toc",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=11,
            leading=18,
            textColor=colors.HexColor("#222222"),
        ),
    }


def bullets(items, st):
    return ListFlowable(
        [ListItem(Paragraph(i, st["bullet"]), leftIndent=12, value="•") for i in items],
        bulletType="bullet",
        start="•",
        leftIndent=18,
        spaceBefore=2,
        spaceAfter=8,
    )


def info_box(title, text, st):
    data = [[Paragraph(f"<b>{title}</b><br/>{text}", st["body"])]]
    t = Table(data, colWidths=[16.5 * cm])
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
                ("BOX", (0, 0), (-1, -1), 0.5, BORDER),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return t


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(BORDER)
    canvas.line(2 * cm, 1.4 * cm, letter[0] - 2 * cm, 1.4 * cm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(2 * cm, 0.9 * cm, "Bear Helados — Gestor de Créditos")
    canvas.drawRightString(letter[0] - 2 * cm, 0.9 * cm, f"Página {doc.page}")
    canvas.restoreState()


def build():
    st = styles()
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=letter,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=1.8 * cm,
        bottomMargin=2 * cm,
        title="Manual de uso — Gestor de Créditos Bear Helados",
        author="Bear Helados",
        subject="Manual de usuario del sistema de gestión de créditos",
    )

    story = []

    # Portada
    story.append(Spacer(1, 2.2 * cm))
    if LOGO.exists():
        img = Image(str(LOGO), width=4.2 * cm, height=4.2 * cm)
        img.hAlign = "CENTER"
        story.append(img)
        story.append(Spacer(1, 0.6 * cm))
    story.append(Paragraph("Bear Helados", st["cover_title"]))
    story.append(Paragraph("Gestor de Créditos", st["cover_title"]))
    story.append(Spacer(1, 0.3 * cm))
    story.append(Paragraph("Manual de uso", st["cover_sub"]))
    story.append(Paragraph("Aplicación de escritorio offline para Windows y macOS", st["cover_sub"]))
    story.append(Spacer(1, 1.2 * cm))
    story.append(
        info_box(
            "Versión del manual",
            "Incluye las funciones actuales del sistema: ventas a crédito, caja, inventario, "
            "reportes, recordatorio por WhatsApp, clave de seguridad para editar o borrar ventas "
            "y respaldo de la base de datos.",
            st,
        )
    )
    story.append(PageBreak())

    # Índice
    story.append(Paragraph("Contenido", st["h1"]))
    toc = [
        "1. Introducción",
        "2. Instalación en Windows",
        "3. Inicio de sesión y roles",
        "4. Indicadores (panel principal)",
        "5. Ventas / Créditos",
        "6. Caja",
        "7. Clientes",
        "8. Inventario y productos",
        "9. Vendedores y promotores",
        "10. Reportes",
        "11. Productores",
        "12. Usuarios",
        "13. Configuración",
        "14. Clave de seguridad (editar / borrar ventas)",
        "15. Respaldo de la base de datos",
        "16. Impresión de tickets",
        "17. Recordatorio por WhatsApp",
        "18. Preguntas frecuentes",
    ]
    for line in toc:
        story.append(Paragraph(line, st["toc"]))
    story.append(PageBreak())

    # 1
    story.append(Paragraph("1. Introducción", st["h1"]))
    story.append(
        Paragraph(
            "El <b>Gestor de Créditos Bear Helados</b> es una aplicación de escritorio que funciona "
            "<b>sin internet</b>. Toda la información se guarda en una base de datos local en la "
            "computadora. Sirve para registrar ventas a crédito, controlar pagos, inventario, caja, "
            "comisiones de vendedores y reportes del negocio.",
            st["body"],
        )
    )
    story.append(
        Paragraph(
            "Este manual describe el uso diario del sistema. Las secciones 14 y 15 detallan las "
            "funciones más recientes: protección con clave de seguridad y respaldo de datos.",
            st["body"],
        )
    )

    # 2
    story.append(Paragraph("2. Instalación en Windows", st["h1"]))
    story.append(Paragraph("Pasos recomendados:", st["body"]))
    story.append(
        bullets(
            [
                "Descomprima el archivo <b>gestor-creditos-windows.zip</b> en una carpeta permanente "
                "(por ejemplo Escritorio o Documentos).",
                "Abra la carpeta descomprimida y ejecute <b>gestor_creditos.exe</b>.",
                "Si Windows pide instalar componentes Visual C++, use los archivos incluidos en el "
                "paquete o siga el archivo README_INSTALACION.txt del zip.",
                "No elimine DLLs de la misma carpeta del ejecutable: la app las necesita para arrancar.",
            ],
            st,
        )
    )
    story.append(
        Paragraph(
            "En macOS la app se entrega como <b>gestor_creditos.app</b>. Al abrirla por primera vez, "
            "si el sistema bloquea la ejecución, use Clic derecho → Abrir.",
            st["note"],
        )
    )

    # 3
    story.append(Paragraph("3. Inicio de sesión y roles", st["h1"]))
    story.append(
        Paragraph(
            "Al abrir el programa verá la pantalla de acceso. Ingrese usuario y contraseña.",
            st["body"],
        )
    )
    story.append(
        info_box(
            "Acceso inicial de administrador",
            "Usuario: <b>admin</b><br/>Contraseña: <b>admin123</b><br/>"
            "Se recomienda cambiar esta contraseña desde Usuarios después del primer ingreso.",
            st,
        )
    )
    story.append(Paragraph("Roles", st["h2"]))
    story.append(
        bullets(
            [
                "<b>Administrador:</b> acceso completo (indicadores, reportes, vendedores, productores, "
                "usuarios y configuración).",
                "<b>Vendedor:</b> acceso operativo a ventas, caja, clientes e inventario según lo definido "
                "en el sistema.",
            ],
            st,
        )
    )

    # 4
    story.append(Paragraph("4. Indicadores (panel principal)", st["h1"]))
    story.append(
        Paragraph(
            "Disponible para administradores. Resume ventas, saldos, créditos pendientes, clientes y "
            "vencimientos del día para una vista rápida del negocio.",
            st["body"],
        )
    )

    # 5
    story.append(Paragraph("5. Ventas / Créditos", st["h1"]))
    story.append(
        Paragraph(
            "Módulo central del sistema. Aquí se registran las ventas a crédito y se consultan saldos.",
            st["body"],
        )
    )
    story.append(Paragraph("Nueva venta", st["h2"]))
    story.append(
        bullets(
            [
                "Pulse <b>Nueva venta</b>.",
                "Busque y seleccione el cliente (por nombre o código).",
                "Agregue productos del catálogo (puede buscar por nombre) e indique la cantidad.",
                "Defina el número de cuotas y revise el total.",
                "Pulse <b>Registrar e imprimir</b>.",
            ],
            st,
        )
    )
    story.append(
        Paragraph(
            "Al registrar, el sistema imprime <b>dos copias del ticket de CREDITO</b> (mismo formato "
            "de factura a crédito). La orden de despacho no se imprime automáticamente; puede "
            "generarla después desde el detalle de la venta si la necesita.",
            st["body"],
        )
    )
    story.append(Paragraph("Acciones sobre una venta", st["h2"]))
    story.append(
        bullets(
            [
                "<b>Ver:</b> detalle de productos, cuotas, saldos y comisiones.",
                "<b>Pago:</b> registrar abonos parciales o totales.",
                "<b>Imprimir:</b> reimprimir el ticket de venta.",
                "<b>Recordar:</b> abrir WhatsApp con un mensaje de cobranza editable.",
                "<b>Editar:</b> modificar descripción y notas (requiere clave de seguridad).",
                "<b>Borrar:</b> eliminar la venta, restaurar stock y quitar pagos/cuotas ligados "
                "(requiere clave de seguridad).",
            ],
            st,
        )
    )
    story.append(
        Paragraph(
            "Puede filtrar la lista por Todos, Pendientes, Parciales o Pagados.",
            st["note"],
        )
    )

    # 6
    story.append(Paragraph("6. Caja", st["h1"]))
    story.append(
        Paragraph(
            "Controla el efectivo del turno: apertura, movimientos, abonos en efectivo asociados a "
            "créditos y cierre con arqueo.",
            st["body"],
        )
    )
    story.append(
        bullets(
            [
                "En <b>Configuración</b> el admin elige modo <b>una sola caja</b> o <b>multi-caja</b>.",
                "Abra caja al iniciar el turno e indique el fondo inicial.",
                "Al cerrar, capture el efectivo contado; el sistema calcula la diferencia y puede "
                "imprimir el corte de caja.",
            ],
            st,
        )
    )

    # 7
    story.append(Paragraph("7. Clientes", st["h1"]))
    story.append(
        Paragraph(
            "Alta y mantenimiento de clientes: nombre, código, teléfono, dirección, notas y vendedor "
            "asignado. El teléfono es necesario para usar el botón Recordar (WhatsApp).",
            st["body"],
        )
    )

    # 8
    story.append(Paragraph("8. Inventario y productos", st["h1"]))
    story.append(
        bullets(
            [
                "Catálogo con costo, margen, precio de venta, descripción y presentación "
                "(individual o combo).",
                "Stock actual con entradas y salidas manuales, además del descuento automático al vender.",
                "Historial de movimientos de inventario.",
            ],
            st,
        )
    )

    # 9
    story.append(Paragraph("9. Vendedores y promotores", st["h1"]))
    story.append(
        Paragraph(
            "Gestione el equipo comercial. Cada vendedor tiene un <b>porcentaje de comisión</b>. "
            "Los promotores agrupan vendedores para reportes de equipo.",
            st["body"],
        )
    )
    story.append(
        info_box(
            "Cómo se calcula la comisión",
            "Sobre cada venta el sistema calcula:<br/>"
            "• <b>Comisión venta</b> = % × monto total de la venta (lo que corresponde al empleado).<br/>"
            "• <b>Comisión cobrada</b> = % × lo que el cliente ya pagó.<br/>"
            "• <b>Comisión pendiente</b> = % × saldo por cobrar.<br/><br/>"
            "Si el dueño paga al empleado aunque el cliente aún no pague, use la "
            "<b>Comisión venta</b> como referencia para liquidar al personal.",
            st,
        )
    )

    # 10
    story.append(Paragraph("10. Reportes", st["h1"]))
    story.append(Paragraph("Hay cuatro pestañas principales:", st["body"]))
    story.append(Paragraph("Cobranza", st["h2"]))
    story.append(
        Paragraph(
            "Filtra por periodo (hoy, mañana, semanal o personalizado) y opcionalmente por vendedor. "
            "Muestra totales de ventas, cobrado, saldo y las tres comisiones. Incluye listas de "
            "créditos (todos / pagados / pendientes), impresión a PDF y botón Recordar.",
            st["body"],
        )
    )
    story.append(Paragraph("Por cliente", st["h2"]))
    story.append(
        Paragraph(
            "Listado de clientes con compras, totales, saldos y estado. Puede filtrar por vendedor, "
            "periodo y tipo (todos, con adeudo, más activos, inactivos), buscar por nombre/código/"
            "teléfono y <b>imprimir la lista</b> del filtro actual.",
            st["body"],
        )
    )
    story.append(Paragraph("Por promotor", st["h2"]))
    story.append(
        Paragraph(
            "Resumen del equipo bajo un promotor: ventas, cobrado, pendiente y comisión de venta "
            "por cada vendedor.",
            st["body"],
        )
    )
    story.append(Paragraph("Ganancias", st["h2"]))
    story.append(
        Paragraph(
            "Ingresos, costos, comisiones y ganancia del periodo, con gráfica y desglose por producto. "
            "Las comisiones usadas aquí se basan en la comisión de venta.",
            st["body"],
        )
    )

    # 11
    story.append(Paragraph("11. Productores", st["h1"]))
    story.append(
        Paragraph(
            "Catálogo de productores / proveedores (datos de contacto y notas) para asociar "
            "información del origen de mercancía cuando aplique.",
            st["body"],
        )
    )

    # 12
    story.append(Paragraph("12. Usuarios", st["h1"]))
    story.append(
        Paragraph(
            "Solo administradores. Crear usuarios, asignar rol (admin o vendedor), vincular a un "
            "vendedor del catálogo si corresponde, activar/desactivar y restablecer contraseñas.",
            st["body"],
        )
    )

    # 13
    story.append(Paragraph("13. Configuración", st["h1"]))
    story.append(
        bullets(
            [
                "Nombre del negocio, dirección y teléfono (aparecen en tickets).",
                "Ancho de ticket: 58 mm u 80 mm.",
                "Impuesto opcional en ticket.",
                "Firma y código de país para mensajes de WhatsApp.",
                "Modo de caja (única o múltiple) y alta de cajas.",
                "Clave de seguridad (ver sección 14).",
                "Reiniciar datos operativos (borra ventas/pagos/caja de prueba; no borra clientes, "
                "productos ni usuarios).",
                "Respaldo de base de datos (ver sección 15).",
            ],
            st,
        )
    )

    # 14 — latest
    story.append(Paragraph("14. Clave de seguridad (editar / borrar ventas)", st["h1"]))
    story.append(
        Paragraph(
            "Para evitar cambios o eliminaciones accidentales (o no autorizadas), el administrador "
            "define una <b>clave de seguridad</b> distinta de la contraseña de inicio de sesión.",
            st["body"],
        )
    )
    story.append(Paragraph("Configurar la clave", st["h2"]))
    story.append(
        bullets(
            [
                "Inicie sesión como <b>administrador</b>.",
                "Vaya a <b>Configuración</b>.",
                "En la tarjeta <b>Clave de seguridad</b>, escriba la nueva clave (mínimo 4 caracteres), "
                "confírmela y pulse <b>Guardar clave</b>.",
                "Solo el administrador puede crear o cambiar esta clave.",
            ],
            st,
        )
    )
    story.append(Paragraph("Cuándo se pide", st["h2"]))
    story.append(
        bullets(
            [
                "Al pulsar <b>Editar</b> en una venta.",
                "Al pulsar <b>Borrar</b> en una venta.",
            ],
            st,
        )
    )
    story.append(
        Paragraph(
            "Si la clave no está configurada, el sistema avisará que el administrador debe definirla "
            "antes de permitir editar o borrar. Tras ingresar la clave correcta, en borrado se pide "
            "además una confirmación; al eliminar se restaura el stock descontado por esa venta.",
            st["body"],
        )
    )

    # 15 — latest
    story.append(Paragraph("15. Respaldo de la base de datos", st["h1"]))
    story.append(
        Paragraph(
            "La información vive en un archivo SQLite local. Es importante respaldarlo con regularidad "
            "(por ejemplo al cierre de día o antes de reinstalar Windows).",
            st["body"],
        )
    )
    story.append(Paragraph("Cómo respaldar", st["h2"]))
    story.append(
        bullets(
            [
                "Entre como administrador y abra <b>Configuración</b>.",
                "En <b>Base de datos local</b> pulse <b>Respaldar</b>.",
                "Se abrirá el diálogo del sistema operativo para elegir carpeta y nombre del archivo "
                "(extensión .db).",
                "Confirme Guardar. Verá un mensaje con la ruta del respaldo.",
            ],
            st,
        )
    )
    story.append(
        info_box(
            "Reinstalación",
            "Si reinstala el programa o formatea la PC sin un respaldo previo, se pierden los datos "
            "operativos. Conserve el archivo .db en un USB o carpeta segura. Para recuperar, contacte "
            "soporte técnico con el archivo de respaldo.",
            st,
        )
    )

    # 16
    story.append(Paragraph("16. Impresión de tickets", st["h1"]))
    story.append(
        bullets(
            [
                "Formato térmico estilo Bear Helados (logo, factura, condición CREDITO, cliente, "
                "vendedor, productos y totales).",
                "Configure 58 mm u 80 mm según su impresora.",
                "En macOS el PDF se abre en Vista Previa para imprimir; en Windows se abre el visor/"
                "navegador disponible.",
                "Desde el detalle de la venta también puede imprimir la <b>Orden de despacho</b> "
                "(sin montos, orientada a entrega).",
                "El corte de caja tiene su propio ticket de arqueo.",
            ],
            st,
        )
    )

    # 17
    story.append(Paragraph("17. Recordatorio por WhatsApp", st["h1"]))
    story.append(
        Paragraph(
            "En ventas pendientes y en el reporte de cobranza puede usar <b>Recordar</b>. Se abre un "
            "cuadro donde edita el mensaje y la firma; al confirmar se abre WhatsApp (enlace wa.me) "
            "con el texto listo para enviar. El cliente debe tener teléfono registrado. No requiere "
            "API de WhatsApp Business.",
            st["body"],
        )
    )

    # 18
    story.append(Paragraph("18. Preguntas frecuentes", st["h1"]))
    faqs = [
        (
            "¿Necesito internet?",
            "No. El sistema es offline. Solo se usa conexión si usted abre WhatsApp o enlaces externos.",
        ),
        (
            "¿Qué pasa si reinstalo y no respaldé?",
            "Se pierden ventas y datos operativos. Use siempre Respaldar en Configuración.",
        ),
        (
            "¿Quién puede cambiar la clave de seguridad?",
            "Solo el administrador, desde Configuración.",
        ),
        (
            "¿La comisión se paga aunque el cliente no haya abonado?",
            "La cifra a usar para pagar al empleado es Comisión venta (sobre el total). "
            "Comisión cobrada refleja solo lo ya pagado por el cliente.",
        ),
        (
            "Al registrar una venta, ¿cuántos tickets salen?",
            "Dos copias del ticket CREDITO. La orden de despacho es opcional desde el detalle.",
        ),
        (
            "El ticket se ve cortado o feo",
            "Revise en Configuración el ancho (58 u 80 mm) y la configuración de la impresora térmica "
            "(sin márgenes extra, papel correcto).",
        ),
    ]
    for q, a in faqs:
        story.append(Paragraph(f"<b>{q}</b>", st["body"]))
        story.append(Paragraph(a, st["body"]))

    story.append(Spacer(1, 1.2 * cm))
    story.append(
        Paragraph(
            "— Fin del manual —<br/>Bear Helados · Gestor de Créditos",
            st["cover_sub"],
        )
    )

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(OUT)


if __name__ == "__main__":
    build()
