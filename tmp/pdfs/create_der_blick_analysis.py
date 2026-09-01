from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Flowable,
    Frame,
    HRFlowable,
    KeepTogether,
    LongTable,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path("/home/spezian/Documents/ChatGPT/Rewe PLU Assistent")
OUT = ROOT / "output/pdf/Der_Blick_Analyse_und_Deutung.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)

PAGE_W, PAGE_H = A4
MARGIN_L = 18 * mm
MARGIN_R = 18 * mm
MARGIN_T = 19 * mm
MARGIN_B = 18 * mm

NAVY = HexColor("#18324A")
TEAL = HexColor("#177E89")
CORAL = HexColor("#D9665B")
GOLD = HexColor("#D89C28")
PURPLE = HexColor("#76539B")
GREEN = HexColor("#36856A")
INK = HexColor("#263442")
MUTED = HexColor("#647380")
PALE_BLUE = HexColor("#E8F2FA")
PALE_TEAL = HexColor("#E5F4F2")
PALE_CORAL = HexColor("#FBEAE7")
PALE_GOLD = HexColor("#FFF4D7")
PALE_PURPLE = HexColor("#F0EAF7")
PALE_GREEN = HexColor("#E8F3ED")
PAPER = HexColor("#FBFCFD")
LINE = HexColor("#D8E0E6")


SANS_DIR = Path("/home/spezian/.local/share/fonts/NotoSans")
SERIF_DIR = Path("/usr/share/fonts/noto")
pdfmetrics.registerFont(TTFont("Sans", str(SANS_DIR / "NotoSans-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Bold", str(SANS_DIR / "NotoSans-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Italic", str(SANS_DIR / "NotoSans-Italic.ttf")))
pdfmetrics.registerFont(TTFont("Serif", str(SERIF_DIR / "NotoSerif-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Serif-Bold", str(SERIF_DIR / "NotoSerif-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Serif-Italic", str(SERIF_DIR / "NotoSerif-Italic.ttf")))


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="TitleCustom", fontName="Serif-Bold", fontSize=25, leading=29,
    textColor=NAVY, alignment=TA_LEFT, spaceAfter=5 * mm,
))
styles.add(ParagraphStyle(
    name="SubtitleCustom", fontName="Sans", fontSize=11.3, leading=16,
    textColor=MUTED, spaceAfter=5 * mm,
))
styles.add(ParagraphStyle(
    name="Kicker", fontName="Sans-Bold", fontSize=8.2, leading=10,
    textColor=TEAL, uppercase=True, spaceAfter=2 * mm,
))
styles.add(ParagraphStyle(
    name="H1Custom", fontName="Serif-Bold", fontSize=17.5, leading=21,
    textColor=NAVY, spaceBefore=2 * mm, spaceAfter=4 * mm, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="H2Custom", fontName="Sans-Bold", fontSize=12.1, leading=15,
    textColor=TEAL, spaceBefore=3.2 * mm, spaceAfter=2 * mm, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="H3Custom", fontName="Sans-Bold", fontSize=9.6, leading=12,
    textColor=NAVY, spaceBefore=2.3 * mm, spaceAfter=1.2 * mm, keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="BodyCustom", fontName="Sans", fontSize=9.2, leading=13.3,
    textColor=INK, spaceAfter=2.1 * mm,
))
styles.add(ParagraphStyle(
    name="BodySmall", fontName="Sans", fontSize=8.1, leading=11.2,
    textColor=INK, spaceAfter=1.5 * mm,
))
styles.add(ParagraphStyle(
    name="BulletCustom", fontName="Sans", fontSize=9.0, leading=13,
    textColor=INK, leftIndent=5 * mm, firstLineIndent=-3.3 * mm,
    bulletIndent=0, spaceAfter=1.2 * mm,
))
styles.add(ParagraphStyle(
    name="BulletSmall", fontName="Sans", fontSize=8.0, leading=11,
    textColor=INK, leftIndent=4.5 * mm, firstLineIndent=-3 * mm,
    spaceAfter=0.8 * mm,
))
styles.add(ParagraphStyle(
    name="Quote", fontName="Serif-Italic", fontSize=10, leading=14,
    textColor=NAVY, leftIndent=6 * mm, rightIndent=5 * mm,
    borderColor=TEAL, borderWidth=1.2, borderPadding=(3 * mm, 3 * mm, 3 * mm, 4 * mm),
    spaceBefore=2 * mm, spaceAfter=3 * mm,
))
styles.add(ParagraphStyle(
    name="Poem", fontName="Serif", fontSize=11.6, leading=17.2,
    textColor=INK, spaceAfter=0,
))
styles.add(ParagraphStyle(
    name="PoemNum", fontName="Sans-Bold", fontSize=7.6, leading=17.2,
    textColor=MUTED, alignment=TA_CENTER,
))
styles.add(ParagraphStyle(
    name="Caption", fontName="Sans", fontSize=7.5, leading=10,
    textColor=MUTED, spaceAfter=2 * mm,
))
styles.add(ParagraphStyle(
    name="TableHead", fontName="Sans-Bold", fontSize=7.7, leading=10,
    textColor=colors.white,
))
styles.add(ParagraphStyle(
    name="TableCell", fontName="Sans", fontSize=7.6, leading=10.7,
    textColor=INK,
))
styles.add(ParagraphStyle(
    name="TableCellBold", fontName="Sans-Bold", fontSize=7.6, leading=10.7,
    textColor=NAVY,
))
styles.add(ParagraphStyle(
    name="CalloutTitle", fontName="Sans-Bold", fontSize=9.2, leading=12,
    textColor=NAVY, spaceAfter=1.2 * mm,
))
styles.add(ParagraphStyle(
    name="CalloutBody", fontName="Sans", fontSize=8.4, leading=12,
    textColor=INK,
))
styles.add(ParagraphStyle(
    name="Speech", fontName="Sans", fontSize=9.4, leading=14,
    textColor=INK, spaceAfter=2.5 * mm,
))


def P(text, style="BodyCustom"):
    return Paragraph(text, styles[style])


def bullet(text, small=False):
    return Paragraph("• " + text, styles["BulletSmall" if small else "BulletCustom"])


def head(title, kicker=None):
    out = []
    if kicker:
        out.append(P(kicker.upper(), "Kicker"))
    out.append(P(title, "H1Custom"))
    out.append(HRFlowable(width="100%", thickness=0.8, color=LINE, spaceAfter=3 * mm))
    return out


def sub(title):
    return P(title, "H2Custom")


def callout(title, body, bg=PALE_TEAL, accent=TEAL):
    content = [P(title, "CalloutTitle"), P(body, "CalloutBody")]
    table = Table([[content]], colWidths=[PAGE_W - MARGIN_L - MARGIN_R], hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.7, accent),
        ("LINEBEFORE", (0, 0), (0, -1), 4.2, accent),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return table


class NumberedCanvasMixin:
    pass


from reportlab.pdfgen import canvas as canvas_module


class NumberedCanvas(canvas_module.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(total)
            super().showPage()
        super().save()

    def draw_page_number(self, total):
        self.saveState()
        self.setFont("Sans", 7.5)
        self.setFillColor(MUTED)
        self.drawRightString(PAGE_W - MARGIN_R, 10 * mm, f"{self._pageNumber} / {total}")
        self.restoreState()


def page_decor(canvas, doc):
    canvas.saveState()
    if doc.page > 1:
        canvas.setFillColor(NAVY)
        canvas.rect(0, PAGE_H - 8 * mm, PAGE_W, 8 * mm, stroke=0, fill=1)
        canvas.setFont("Sans-Bold", 7.3)
        canvas.setFillColor(colors.white)
        canvas.drawString(MARGIN_L, PAGE_H - 5.2 * mm, "DER BLICK - ANALYSE UND DEUTUNG")
        canvas.setFillColor(TEAL)
        canvas.rect(MARGIN_L, 13.2 * mm, 35 * mm, 1.2, stroke=0, fill=1)
        canvas.setFont("Sans", 7.2)
        canvas.setFillColor(MUTED)
        canvas.drawString(MARGIN_L, 9.9 * mm, "Joseph von Eichendorff, ca. 1810")
    canvas.restoreState()


doc = BaseDocTemplate(
    str(OUT), pagesize=A4,
    leftMargin=MARGIN_L, rightMargin=MARGIN_R,
    topMargin=MARGIN_T, bottomMargin=MARGIN_B,
    title="Der Blick - Analyse und Deutung",
    author="Unterrichtsunterlage",
    subject="Ausführliche Gedichtanalyse für die 12. Klasse",
)
frame = Frame(MARGIN_L, MARGIN_B, PAGE_W - MARGIN_L - MARGIN_R, PAGE_H - MARGIN_T - MARGIN_B, id="main")
doc.addPageTemplates([PageTemplate(id="analysis", frames=frame, onPage=page_decor)])

story = []


# TITELSEITE
story += [Spacer(1, 16 * mm)]
story.append(P("GEDICHTANALYSE · 12. KLASSE", "Kicker"))
story.append(P("Der Blick", "TitleCustom"))
story.append(P("Joseph von Eichendorff (ca. 1810)", "SubtitleCustom"))
story.append(HRFlowable(width="40%", thickness=3, color=TEAL, hAlign="LEFT", spaceAfter=8 * mm))
story.append(callout(
    "Leitthese",
    "Der Blick des angesprochenen Du wird zu einer wortlosen Sprache: Er löst die innere Verschlossenheit des lyrischen Ichs und verwandelt einen tiefen Schmerzraum in Glück. Die Liebeserfahrung erhält dadurch eine fast himmlische, transzendente Bedeutung.",
    PALE_BLUE, NAVY,
))
story.append(Spacer(1, 8 * mm))

overview = [
    [P("TEXTARBEIT", "TableHead"), P("DEUTUNG", "TableHead"), P("VORTRAG", "TableHead")],
    [P("21 Markierungen direkt am Gedicht; Versangaben; Farbcode", "TableCell"),
     P("Strophe für Strophe, Form, Sprache, Grammatik, Perspektive, Epoche", "TableCell"),
     P("Klarer Ablauf für die Klasse plus ausformulierter Deutungstext", "TableCell")],
]
t = Table(overview, colWidths=[54 * mm, 62 * mm, 58 * mm])
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("GRID", (0, 0), (-1, -1), 0.5, LINE),
    ("LEFTPADDING", (0, 0), (-1, -1), 8),
    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ("TOPPADDING", (0, 0), (-1, -1), 8),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
]))
story.append(t)
story.append(Spacer(1, 9 * mm))
story.append(P("Enthalten", "H2Custom"))
for x in [
    "klassischer schulischer Aufbau: Einleitung, Deutungshypothese, Hauptteil, Schluss",
    "Ausgangssituation, Gefühls- und Handlungsentwicklung, Charakterisierung des lyrischen Ichs",
    "Metrum, Kadenzen, Reim, Satzbau, Bildsprache, rhetorische Mittel und Wortfelder",
    "Pronomen, Kasus, Zeitformen, Konjunktiv II, Partizipien, Adjektive und Steigerungen",
    "Epochenbezug zur Romantik, alternative Lesarten und Grenzen der Aussage",
]:
    story.append(bullet(x))
story.append(Spacer(1, 8 * mm))
story.append(P("Arbeitsgrundlage: die bereitgestellte Gedichtabbildung und die handschriftliche To-do-Liste. Die To-do-Liste wird als Analyseauftrag behandelt, nicht als Bestandteil des Gedichts.", "Caption"))
story.append(PageBreak())


# LESEKARTE
story += head("1. Lesekarte: Was geschieht?", "Orientierung vor der Detailanalyse")
story.append(callout(
    "Kernaussage in einem Satz",
    "Ein liebevoller Blick teilt Gefühle unmittelbarer mit als Worte; er gibt dem zuvor verschlossenen und schmerzbelasteten lyrischen Ich Vertrauen, sodass es sich öffnet und Glück erfährt.",
    PALE_TEAL, TEAL,
))
story.append(sub("Ausgangssituation"))
for x in [
    "Ein nicht näher bestimmtes <b>Du</b> schaut das lyrische Ich lächelnd an (V. 1-2). Die Situation ist intim, aber äußerlich kaum beschrieben.",
    "Das lyrische Ich reagiert sofort innerlich: Es <b>fühlt</b>, dass der Blick mehr ausdrückt, als eine Lippe sagen könnte (V. 3-4).",
    "Die Rückschau <i>mir lang verschlossen</i> (V. 10) und der <i>Abgrund meiner Schmerzen</i> (V. 15) zeigen eine Vorgeschichte von Verschlossenheit und Leid.",
    "Weder Ort noch Geschlecht oder genaue Beziehung werden genannt. Eine Liebessituation ist sehr plausibel, bleibt aber eine Deutung.",
]: story.append(bullet(x))

story.append(sub("Handlungs- und Gefühlsentwicklung"))
flow_data = [
    [P("1 · Kontakt", "TableCellBold"), P("Das Du blickt und lächelt.", "TableCell"), P("Zuwendung, Wärme", "TableCell")],
    [P("2 · Reflexion", "TableCellBold"), P("Das Ich vergleicht Blick und Worte.", "TableCell"), P("Staunen, Gewissheit", "TableCell")],
    [P("3 · Offenbarung", "TableCellBold"), P("Der Blick erscheint als Quelle des Himmels.", "TableCell"), P("Hoffnung, Erhellung", "TableCell")],
    [P("4 · Wandlung", "TableCellBold"), P("Das Ich öffnet sich; Glück füllt den Schmerzabgrund.", "TableCell"), P("Vertrauen, Erlösung", "TableCell")],
]
t = Table(flow_data, colWidths=[33 * mm, 85 * mm, 56 * mm])
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (0, -1), PALE_BLUE),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story.append(t)

story.append(sub("Erwartung durch den Titel"))
for x in [
    "Der bestimmte Artikel <i>Der</i> macht aus einem alltäglichen Sehen <b>den einen bedeutsamen Blick</b>.",
    "Das Nomen <i>Blick</i> lässt zunächst Beobachtung oder Kontakt erwarten. Erfüllt wird diese Erwartung durch den direkten Blickkontakt; übertroffen wird sie, weil der Blick Sprache, Quelle und handelnde Kraft wird.",
    "Die leitende Frage lautet: <b>Was kann ein Blick mitteilen, was Worte nicht können?</b>",
]: story.append(bullet(x))

story.append(sub("Deutungshypothese"))
story.append(P("Eichendorffs Gedicht gestaltet den Blick eines geliebten Menschen als nonverbale und besonders wahrhaftige Sprache. Dieser Blick überwindet die Distanz zwischen Du und Ich, öffnet einen lange verschlossenen Innenraum und ersetzt Schmerz durch Glück. Die Bilder von Himmel, Quelle und Licht heben die persönliche Begegnung in eine romantisch-transzendente Sphäre.", "Quote"))
story.append(PageBreak())


# MARKIERTER TEXT
story += head("2. Markierter Gedichttext", "Am Text erläutern")
story.append(P("Die farbigen Stellen markieren Funktionen, nicht nur einzelne Stilmittel. Die hochgestellten Zahlen führen zu den Erläuterungen auf den folgenden Seiten.", "BodySmall"))

legend_data = [
    ["Bild / Symbol", PALE_PURPLE, PURPLE], ["Gefühl / Wirkung", PALE_GREEN, GREEN],
    ["Gegensatz / Wandel", PALE_CORAL, CORAL], ["Grammatik / Syntax", PALE_GOLD, GOLD],
    ["Perspektive / Beziehung", PALE_BLUE, NAVY],
]
legend_cells = []
for label, bg, accent in legend_data:
    legend_cells.append(Table([[P(label, "TableCellBold")]], colWidths=[34 * mm], style=TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg), ("BOX", (0, 0), (-1, -1), 0.5, accent),
        ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ])))
story.append(Table([legend_cells], colWidths=[35 * mm] * 5, hAlign="LEFT"))
story.append(Spacer(1, 4 * mm))

poem_lines = [
    (1, '<span backColor="#E8F2FA">Schaust du mich aus deinen Augen</span><super>1</super>'),
    (2, '<span backColor="#E8F3ED">Lächelnd</span><super>2</super> <span backColor="#F0EAF7">wie aus Himmeln</span><super>3</super> an,'),
    (3, '<span backColor="#FFF4D7">Fühl\' ich wohl</span><super>4</super>, dass <span backColor="#FBEAE7">keine Lippe</span><super>5</super>'),
    (4, 'Solche <span backColor="#F0EAF7">Sprache</span><super>6</super> führen kann.'),
    (None, ''),
    (5, '<span backColor="#FFF4D7">Könnte</span><super>7</super> sie\'s auch <span backColor="#FBEAE7">wörtlich sagen</span><super>8</super>,'),
    (6, 'Was dem <span backColor="#F0EAF7">Herzen tief entquillt</span><super>9</super>,'),
    (7, '<span backColor="#E8F3ED">Still</span> den <span backColor="#E8F2FA">Augen aufgetragen</span><super>10</super>,'),
    (8, 'Wird es <span backColor="#E8F3ED">süßer</span><super>11</super> nur erfüllt.'),
    (None, ''),
    (9, '<span backColor="#E8F2FA">Und ich seh\'</span><super>12</super> <span backColor="#F0EAF7">des Himmels Quelle</span><super>13</super>,'),
    (10, 'Die <span backColor="#FBEAE7">mir lang verschlossen war</span><super>14</super>,'),
    (11, 'Wie sie <span backColor="#F0EAF7">bricht</span> in <span backColor="#E8F3ED">reinster Helle</span><super>15</super>'),
    (12, 'Aus dem <span backColor="#E8F3ED">reinsten</span> <span backColor="#E8F2FA">Augenpaar</span><super>16</super>.'),
    (None, ''),
    (13, '<span backColor="#E8F2FA">Und ich öffne</span><super>17</super> <span backColor="#E8F3ED">still</span> im Herzen'),
    (14, '<span backColor="#E8F3ED">Alles, alles</span><super>18</super> <span backColor="#FFF4D7">diesem Blick</span><super>19</super>,'),
    (15, 'Und den <span backColor="#FBEAE7">Abgrund meiner Schmerzen</span><super>20</super>'),
    (16, '<span backColor="#F0EAF7">Füllt er strömend aus</span><super>21</super> mit <span backColor="#E8F3ED">Glück</span>.'),
]
rows = []
for n, line in poem_lines:
    if n is None:
        rows.append([P("", "PoemNum"), Spacer(1, 3.2 * mm)])
    else:
        rows.append([P(str(n), "PoemNum"), P(line, "Poem")])
t = Table(rows, colWidths=[10 * mm, 154 * mm], hAlign="CENTER")
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), PAPER),
    ("BOX", (0, 0), (-1, -1), 0.7, LINE),
    ("LINEBEFORE", (1, 0), (1, -1), 1.4, TEAL),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("LEFTPADDING", (0, 0), (-1, -1), 8),
    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ("TOPPADDING", (0, 0), (-1, -1), 1),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
]))
story.append(t)
story.append(Spacer(1, 3 * mm))
story.append(P("Text nach der bereitgestellten Abbildung. Apostrophe und historische Formulierungen wurden beibehalten. Verszählung: V. 1-16.", "Caption"))
story.append(PageBreak())


# ANNOTATIONEN 1-11
story += head("3. Randnotizen zu den Markierungen", "Strophe 1 und 2")
ann_1 = [
    ("1 · V. 1", "Direkte Beziehung: <i>du</i> ist Subjekt, <i>mich</i> Akkusativobjekt. Der Blick geht vom Du aus und trifft das Ich. Der Satz beginnt mit dem Verb <i>Schaust</i>: ein uneingeleiteter Bedingungssatz, sinngemäß 'Wenn du ... schaust'."),
    ("2 · V. 2", "Das Partizip I <i>lächelnd</i> beschreibt eine gleichzeitige Begleithandlung. Es prägt den Blick als freundlich, beruhigend und zugewandt."),
    ("3 · V. 2", "Vergleich und Überhöhung: <i>wie aus Himmeln</i>. Der ungewöhnliche Plural steigert die Erfahrung; der Blick scheint aus mehr als nur einem Himmel zu kommen. Das Du wird idealisiert."),
    ("4 · V. 3", "<i>Fühl' ich</i> zeigt die Innensicht des lyrischen Ichs. <i>wohl</i> meint hier eine sichere, zugleich empfindsame Gewissheit. Die Elision <i>Fühl'</i> hält Metrum und Sprachfluss."),
    ("5 · V. 3", "<i>keine Lippe</i> ist eine absolute Verneinung. Die Lippe steht metonymisch für das Sprechen. Körperteil und Funktion werden verbunden."),
    ("6 · V. 4", "Metapher: Der Blick besitzt eine <i>Sprache</i>. Sichtbares wird wie Sprechen behandelt. Pointe der ersten Strophe: Gerade das Wortlose teilt besonders viel mit."),
    ("7 · V. 5", "<i>Könnte</i> steht im Konjunktiv II. Er eröffnet einen nur gedachten Gegenfall: Selbst wenn die Lippe sprechen könnte, bliebe der Blick überlegen."),
    ("8 · V. 5", "Der Ausdruck <i>wörtlich sagen</i> bildet den Gegenpol zur stillen Kommunikation. Das einschränkende <i>auch</i> hat concessive Wirkung: sogar unter dieser Annahme."),
    ("9 · V. 6", "Flüssigkeitsmetapher: Gefühle <i>entquillen</i> dem Herzen. Das Herz erscheint als Ursprung des Innersten; <i>tief</i> verstärkt Authentizität und seelische Tiefe."),
    ("10 · V. 7", "Den Augen wird eine Botschaft <i>aufgetragen</i>. Das Passivische lässt die Augen als Vermittler einer inneren Wahrheit erscheinen. <i>still</i> betont lautlose, nicht leere Kommunikation."),
    ("11 · V. 8", "<i>süßer</i> ist ein Komparativ und eine synästhetische Wertung: Eine Geschmacksqualität beschreibt emotionalen Genuss. Das Passiv <i>wird ... erfüllt</i> rückt die Wirkung, nicht einen Sprecher, in den Mittelpunkt."),
]
for n, text in ann_1:
    story.append(KeepTogether([P(n, "H3Custom"), P(text, "BodySmall")]))
story.append(callout(
    "Zwischenergebnis nach Strophe 2",
    "Das Gedicht behauptet nicht einfach, Worte seien wertlos. Es zeigt genauer: Für sehr tiefe Gefühle ist der Blick unmittelbarer, stiller und 'süßer' als eine wörtliche Aussage.",
    PALE_GOLD, GOLD,
))
story.append(PageBreak())


# ANNOTATIONEN 12-21
story += head("4. Randnotizen zu den Markierungen", "Strophe 3 und 4")
ann_2 = [
    ("12 · V. 9", "Die Anapher <i>Und ich</i> beginnt auch V. 13. Das Ich wird zunehmend aktiv: zuerst sieht es, später öffnet es sich. <i>seh'</i> führt vom Fühlen zur visionären Wahrnehmung."),
    ("13 · V. 9", "Die Genitivmetapher <i>des Himmels Quelle</i> verschmilzt Transzendenz und Wasserbild. Möglich sind zwei Nuancen: eine Quelle, die zum Himmel gehört, oder der Ursprung himmlischen Glücks."),
    ("14 · V. 10", "<i>mir</i> ist ein Dativ der Beteiligung: Für das Ich war diese Quelle nicht erreichbar. Das Präteritum <i>war</i> öffnet eine Vorgeschichte; <i>lang verschlossen</i> steht gegen das jetzige Hervorbrechen und Öffnen."),
    ("15 · V. 11", "Das dynamische Verb <i>bricht</i> verleiht der Quelle Kraft. Der Superlativ <i>reinster</i> und die Lichtmetapher <i>Helle</i> deuten Klarheit, Wahrheit, Hoffnung und Idealität an."),
    ("16 · V. 12", "Die Wiederholung <i>reinster/reinsten</i> steigert die Idealisierung. <i>Augenpaar</i> ist metonymisch für das Du; zugleich betont <i>Paar</i> Harmonie und Ganzheit."),
    ("17 · V. 13", "<i>Und ich öffne</i> markiert den Wendepunkt zur eigenen Handlung. Das Verb <i>öffnen</i> beantwortet direkt das vorherige <i>verschlossen</i>. Der Vorgang bleibt <i>still</i>: innerlich, freiwillig, vertrauensvoll."),
    ("18 · V. 14", "Die Geminatio <i>Alles, alles</i> steigert das Totalitätsversprechen. Das Ich hält keinen inneren Bereich zurück; die Wiederholung klingt zugleich emotional bewegt."),
    ("19 · V. 14", "<i>diesem Blick</i> ist Dativobjekt zu <i>öffnen</i>: Der Blick wird zum Empfänger des Innersten. Das Demonstrativpronomen <i>diesem</i> konzentriert die Aussage auf genau den gegenwärtigen Blick."),
    ("20 · V. 15", "Die Metapher <i>Abgrund meiner Schmerzen</i> räumlicht Leid als tiefe Leere. Der Genitiv <i>meiner Schmerzen</i> bindet es ausdrücklich an die Biografie des Ichs. Der Abgrund kontrastiert mit Himmel, Quelle und Helle."),
    ("21 · V. 16", "Der Blick wird personifiziert: Das Pronomen <i>er</i> macht ihn zum handelnden Subjekt. <i>strömend</i> setzt das Quellenmotiv fort; das trennbare Verb <i>füllt ... aus</i> bezeichnet vollständige Verwandlung. <i>Glück</i> ist der antithetische Endpunkt zu <i>Schmerzen</i>."),
]
for n, text in ann_2:
    story.append(KeepTogether([P(n, "H3Custom"), P(text, "BodySmall")]))
story.append(callout(
    "Wichtigster Bildzusammenhang",
    "Quelle -> hervorbrechen -> strömen -> ausfüllen. Das Gedicht entwickelt nicht vier zufällige Bilder, sondern eine zusammenhängende Bewegung: Die vom Blick ausgehende 'Quelle' fließt in den inneren 'Abgrund' des Ichs und ersetzt dessen Leere durch Glück.",
    PALE_PURPLE, PURPLE,
))
story.append(PageBreak())


# STROPHENANALYSE
story += head("5. Deutung zu jeder Strophe", "Inhalt, Sprache, Gefühl und Funktion")

stanzas = [
    ("Strophe 1 · V. 1-4: Der Blick als wortlose Sprache", [
        "<b>Inhalt:</b> Das Du schaut das Ich lächelnd an; dieses erkennt die Ausdruckskraft des Blicks.",
        "<b>Gefühl:</b> Zärtlichkeit und staunende Gewissheit. Der Blick wirkt sicherer als ein gesprochenes Bekenntnis.",
        "<b>Sprache:</b> Der Himmelsvergleich erhöht das Du; <i>Lippe</i> und <i>Sprache</i> bilden das Wortfeld des Sprechens. Die visuelle Wahrnehmung übernimmt dessen Funktion.",
        "<b>Struktur:</b> Ursache und Reaktion sind in einem einzigen Satz verbunden: Schaust du ..., fühle ich ... . So wird die unmittelbare Wirkung formal sichtbar.",
        "<b>Funktion:</b> Die zentrale These wird gesetzt: Der Blick kann etwas vermitteln, das Sprache nicht erreicht.",
    ]),
    ("Strophe 2 · V. 5-8: Reflexion über Worte und Augen", [
        "<b>Inhalt:</b> Das Ich prüft gedanklich den Gegenfall, dass die Lippe das Gefühl doch aussprechen könnte.",
        "<b>Gefühl:</b> Die anfängliche Wahrnehmung wird zur reflektierten Überzeugung. 'Süßer' zeigt Genuss, Nähe und Trost.",
        "<b>Sprache:</b> Konjunktiv II, Herzmetapher, stille Augen und synästhetischer Komparativ. <i>entquillt</i> beginnt das Leitmotiv des Fließens.",
        "<b>Gegensatz:</b> wörtlich/still, Lippe/Augen, sagen/erfüllen. Nicht Lautstärke, sondern Echtheit zählt.",
        "<b>Funktion:</b> Die Behauptung aus Strophe 1 wird argumentativ begründet: Gefühl kann zwar theoretisch benannt, im Blick aber intensiver verwirklicht werden.",
    ]),
    ("Strophe 3 · V. 9-12: Der Blick als himmlische Quelle", [
        "<b>Inhalt:</b> Das Ich sieht im Augenpaar eine zuvor verschlossene Quelle des Himmels aufbrechen.",
        "<b>Gefühl:</b> Erhellung und Offenbarung lösen lange Entbehrung ab. Die Erfahrung erreicht ihren idealisierenden Höhepunkt.",
        "<b>Sprache:</b> Himmel, Quelle, Helle und Reinheit bilden ein romantisch-transzendentes Bildfeld. <i>bricht</i> bringt Energie in die ruhige Grundstimmung.",
        "<b>Zeitstruktur:</b> Präsens des Sehens trifft auf Präteritum <i>war</i>. Dadurch entsteht ein Vorher-Nachher: lange verschlossen - jetzt zugänglich.",
        "<b>Funktion:</b> Aus Kommunikation wird Offenbarung. Der persönliche Blick erscheint als Zugang zu einer höheren, nahezu heiligen Wirklichkeit.",
    ]),
    ("Strophe 4 · V. 13-16: Öffnung und Verwandlung", [
        "<b>Inhalt:</b> Das Ich öffnet sein gesamtes Inneres; der personifizierte Blick füllt den Schmerzabgrund mit Glück.",
        "<b>Gefühl:</b> Vertrauen, Hingabe und Erlösung. Das Ich bleibt nicht mehr nur empfangend, sondern antwortet aktiv.",
        "<b>Sprache:</b> <i>Alles, alles</i> totalisiert die Öffnung. <i>Abgrund</i> und <i>Glück</i> bilden den stärksten Gegensatz; <i>strömend</i> schließt das Quellenbild.",
        "<b>Raumbewegung:</b> Oben (Himmel) und unten (Abgrund), außen (Augen/Blick) und innen (Herz) werden durch das Strömen verbunden.",
        "<b>Funktion:</b> Die vorher vorbereitete Wandlung wird vollendet. Der Schluss endet nicht bei Schmerz, sondern beim einsilbigen Zielwort <i>Glück</i>.",
    ]),
]
for title, items in stanzas:
    block = [P(title, "H2Custom")]
    block.extend(bullet(x, small=True) for x in items)
    story.append(KeepTogether(block))
story.append(PageBreak())


# FORM
story += head("6. Form und Struktur", "Wie die äußere Ordnung die Aussage trägt")
form_rows = [
    [P("Aspekt", "TableHead"), P("Befund", "TableHead"), P("Wirkung / Deutung", "TableHead")],
    [P("Aufbau", "TableCellBold"), P("4 Strophen mit je 4 Versen; jede Strophe bildet einen vollständigen Satz.", "TableCell"), P("Übersichtliche Stufen: Begegnung, Reflexion, Offenbarung, Verwandlung. Die regelmäßige Form fängt die starken Gefühle auf.", "TableCell")],
    [P("Reim", "TableCellBold"), P("Strophe 1: abcb; nur V. 2/4 reimen sich (<i>an/kann</i>). Mit x für reimlose Verse auch xaxa notierbar. Strophen 2-4: Kreuzreim abab.", "TableCell"), P("Die erste Strophe wirkt leicht offener; danach wächst formale Geschlossenheit. Vorsichtige Deutung: Mit der inneren Gewissheit stabilisiert sich auch der Reim.", "TableCell")],
    [P("Metrum", "TableCellBold"), P("Überwiegend vierhebiger Trochäus: betonte Silbe vor unbetonter Silbe.", "TableCell"), P("Der fallende Rhythmus wirkt ruhig, liedhaft und innig; er passt zur stillen Kommunikation.", "TableCell")],
    [P("Kadenzen", "TableCellBold"), P("Ungerade Verse meist weiblich klingend, gerade Verse männlich; regelmäßiger Wechsel.", "TableCell"), P("Weibliche Ausgänge tragen den Gedanken weiter, männliche Enden schließen klar ab. Besonders <i>Glück</i> setzt einen festen Schlusspunkt.", "TableCell")],
    [P("Enjambements", "TableCellBold"), P("Mehrere Sätze laufen über Versgrenzen, z. B. V. 1-3, V. 5-8, V. 9-12 und V. 15-16.", "TableCell"), P("Der Gedanke fließt weiter, ähnlich der Quelle. Reim und Satzgrenzen verhindern dennoch Unruhe.", "TableCell")],
    [P("Strophenanfänge", "TableCellBold"), P("V. 9 und 13: <i>Und ich ...</i>", "TableCell"), P("Anapher und Entwicklungszeichen: sehen -> öffnen. Die Wahrnehmung wird zur Handlung.", "TableCell")],
]
t = LongTable(form_rows, colWidths=[29 * mm, 66 * mm, 79 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(sub("Metrisches Beispiel"))
story.append(P("<b>SCHAU</b>st du | <b>MICH</b> aus | <b>DEI</b>nen | <b>AU</b>gen &nbsp;&nbsp; (vier Hebungen, weiblicher Ausgang)", "Quote"))
story.append(P("<b>LÄ</b>chelnd | <b>WIE</b> aus | <b>HIM</b>meln | <b>AN</b> &nbsp;&nbsp; (vier Hebungen, männlicher Ausgang)", "Quote"))
story.append(callout(
    "Methodischer Hinweis",
    "Form nicht isoliert aufzählen. Im Vortrag immer die Dreierfolge verwenden: Befund -> Beleg -> Wirkung. Beispiel: 'Der regelmäßige Trochäus erzeugt einen ruhigen, liedhaften Rhythmus und unterstützt so die stille Innigkeit der Begegnung.'",
    PALE_GOLD, GOLD,
))
story.append(PageBreak())


# SPRACHLICHE MITTEL
story += head("7. Sprachliche Mittel und Bildsprache", "Beleg, Fachbegriff, Wirkung")
device_rows = [
    [P("Mittel", "TableHead"), P("Beleg", "TableHead"), P("Funktion im Gedicht", "TableHead")],
    [P("Vergleich", "TableCellBold"), P("<i>wie aus Himmeln</i> (V. 2)", "TableCell"), P("Idealisierung des Du; der Blick überschreitet Alltäglichkeit.", "TableCell")],
    [P("Metapher", "TableCellBold"), P("<i>solche Sprache</i> (V. 4)", "TableCell"), P("Der Blick wird zum bedeutungstragenden Zeichensystem.", "TableCell")],
    [P("Metonymie", "TableCellBold"), P("<i>Lippe</i>, <i>Augenpaar</i> (V. 3, 12)", "TableCell"), P("Körperteile stehen für Sprechen bzw. das kommunizierende Du.", "TableCell")],
    [P("Fließende Leitmetapher", "TableCellBold"), P("<i>entquillt - Quelle - bricht - strömend - füllt ... aus</i>", "TableCell"), P("Gefühl wird als lebendige Kraft entwickelt; es verbindet Du und Ich.", "TableCell")],
    [P("Licht-/Himmelsmetaphorik", "TableCellBold"), P("<i>Himmeln</i>, <i>des Himmels Quelle</i>, <i>reinster Helle</i>", "TableCell"), P("Transzendenz, Hoffnung, Reinheit; mögliche religiöse Nebenbedeutung.", "TableCell")],
    [P("Personifikation", "TableCellBold"), P("Der Blick <i>füllt ... aus</i> (V. 16)", "TableCell"), P("Aus einer Wahrnehmung wird ein wirksamer Akteur.", "TableCell")],
    [P("Synästhesie / Übertragung", "TableCellBold"), P("<i>süßer ... erfüllt</i> (V. 8)", "TableCell"), P("Geschmack beschreibt emotionale Intensität; die Wirkung wird sinnlich.", "TableCell")],
    [P("Antithesen", "TableCellBold"), P("<i>wörtlich/still</i>, <i>verschlossen/öffne</i>, <i>Schmerzen/Glück</i>", "TableCell"), P("Die Entwicklung vom Mangel zur Erfüllung wird scharf sichtbar.", "TableCell")],
    [P("Geminatio", "TableCellBold"), P("<i>Alles, alles</i> (V. 14)", "TableCell"), P("Emotionaler Nachdruck und vollständige Hingabe.", "TableCell")],
    [P("Anapher", "TableCellBold"), P("<i>Und ich</i> (V. 9, 13)", "TableCell"), P("Verknüpft Wahrnehmen und Handeln; stärkt die Ich-Entwicklung.", "TableCell")],
    [P("Steigerung", "TableCellBold"), P("<i>süßer</i>; <i>reinster/reinsten</i>", "TableCell"), P("Der Blick wird gegenüber Worten aufgewertet und idealisiert.", "TableCell")],
    [P("Raummetapher", "TableCellBold"), P("<i>Abgrund meiner Schmerzen</i> (V. 15)", "TableCell"), P("Seelischer Schmerz erscheint als tiefe, zu füllende Leere.", "TableCell")],
]
t = LongTable(device_rows, colWidths=[38 * mm, 57 * mm, 79 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), PURPLE),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 5.5),
    ("RIGHTPADDING", (0, 0), (-1, -1), 5.5),
    ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(Spacer(1, 3 * mm))
story.append(P("Klanglich fallen weiche Laute wie l, m und sch sowie die Wörter <i>still</i>, <i>süßer</i> und <i>Helle</i> auf. Sie unterstützen die sanfte Grundstimmung. Die kräftigeren Verben <i>bricht</i> und <i>strömt</i> markieren dagegen den Höhepunkt der inneren Bewegung. Klangdeutungen bleiben ergänzend; wichtiger sind Wortwahl und Bildzusammenhang.", "BodyCustom"))
story.append(PageBreak())


# GRAMMATIK
story += head("8. Grammatik und Wortarten mit Deutungswert", "Nicht nur benennen - die Wirkung erklären")
grammar_rows = [
    [P("Form", "TableHead"), P("Beleg", "TableHead"), P("Einfluss auf Aussage und Perspektive", "TableHead")],
    [P("Personalpronomen", "TableCellBold"), P("<i>du - mich - ich - mir - meiner - er</i>", "TableCell"), P("Die Pronomen zeichnen eine Beziehung: Das Du wirkt auf das Ich; am Ende handelt der zum 'er' personifizierte Blick im Inneren des Ichs.", "TableCell")],
    [P("Kasus", "TableCellBold"), P("<i>mich</i> Akk.; <i>aus deinen Augen</i> Dat.; <i>dem Herzen</i> Dat.; <i>des Himmels</i> Gen.; <i>meiner Schmerzen</i> Gen.", "TableCell"), P("Akkusativ markiert das getroffene Ich. Dative bezeichnen Ursprung, Ort, Beteiligung oder Empfänger. Genitive verdichten Zugehörigkeit: Quelle des Himmels, Abgrund der eigenen Schmerzen.", "TableCell")],
    [P("Konjunktiv II", "TableCellBold"), P("<i>Könnte sie's ... sagen</i> (V. 5)", "TableCell"), P("Gedankenexperiment statt Tatsache. Selbst der günstigste Fall für Worte ändert nichts an der Überlegenheit des Blicks.", "TableCell")],
    [P("Tempus", "TableCellBold"), P("meist Präsens; einmal <i>war</i> (V. 10)", "TableCell"), P("Das Präsens macht die Erfahrung unmittelbar. Das Präteritum schafft den belasteten Hintergrund, von dem sich der jetzige Wandel abhebt.", "TableCell")],
    [P("Partizip I", "TableCellBold"), P("<i>lächelnd</i>, <i>strömend</i>", "TableCell"), P("Gleichzeitige Begleithandlungen: Das Du blickt lächelnd; der Blick erfüllt strömend. Dadurch bleibt die Bewegung fließend.", "TableCell")],
    [P("Partizip II / Passiv", "TableCellBold"), P("<i>verschlossen</i>, <i>aufgetragen</i>, <i>wird ... erfüllt</i>", "TableCell"), P("Zunächst dominieren Zustände und Empfang. In Strophe 4 wechseln aktive Verben (<i>öffne</i>, <i>füllt</i>) in den Vordergrund.", "TableCell")],
    [P("Steigerungsformen", "TableCellBold"), P("Komparativ <i>süßer</i>; Superlativ <i>reinster/reinsten</i>", "TableCell"), P("Die sprachliche Intensität wächst von Vergleich zu höchster Reinheit.", "TableCell")],
    [P("Total- und Negationswörter", "TableCellBold"), P("<i>keine</i>, <i>Alles, alles</i>", "TableCell"), P("Die Gegensätze werden absolut formuliert: Keine Lippe erreicht den Blick; nichts im Ich bleibt verschlossen.", "TableCell")],
    [P("Präpositionen", "TableCellBold"), P("mehrfach <i>aus</i>; daneben <i>im Herzen</i>, <i>mit Glück</i>", "TableCell"), P("<i>aus</i> betont Herkunft und Hervortreten; <i>im</i> lokalisiert die Wirkung im Inneren; <i>mit</i> nennt den neuen Inhalt des Schmerzabgrunds.", "TableCell")],
    [P("Satzstellung", "TableCellBold"), P("<i>Schaust du ..., fühl' ich ...</i>; <i>Könnte ...</i>", "TableCell"), P("Verb-Erst-Stellung erzeugt konditionale Logik ohne 'wenn'. Die Wirkung des Blicks erscheint zuverlässig und unmittelbar.", "TableCell")],
    [P("Elision", "TableCellBold"), P("<i>Fühl'</i>, <i>seh'</i>, <i>sie’s</i>", "TableCell"), P("Auslassungen sichern Rhythmus und geben der kunstvollen Sprache einen mündlich-nahen Fluss.", "TableCell")],
]
t = LongTable(grammar_rows, colWidths=[36 * mm, 55 * mm, 83 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), GOLD),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 5.5),
    ("RIGHTPADDING", (0, 0), (-1, -1), 5.5),
    ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(Spacer(1, 3 * mm))
story.append(callout(
    "Zu den Dativen",
    "Ein Dativ hat nicht automatisch eine poetische Wirkung. Entscheidend ist seine Satzfunktion: <i>dem Herzen</i> bezeichnet den Ursprung, <i>mir</i> die betroffene Person, <i>im Herzen</i> den inneren Ort und <i>diesem Blick</i> den Empfänger der Öffnung. Erst diese Funktionen unterstützen die Deutung.",
    PALE_GOLD, GOLD,
))
story.append(PageBreak())


# WORTFELDER UND GEGENSÄTZE
story += head("9. Wortfelder, Gegensätze und Veränderung", "Das Bedeutungsnetz des Gedichts")
word_rows = [
    [P("Wortfeld", "TableHead"), P("Wörter", "TableHead"), P("Deutungsfunktion", "TableHead")],
    [P("Sehen / nonverbale Kommunikation", "TableCellBold"), P("<i>Blick, schaust, Augen, seh', Augenpaar</i>", "TableCell"), P("Trägt die eigentliche Begegnung; Sichtbarkeit ersetzt Sprache.", "TableCell")],
    [P("Sprechen", "TableCellBold"), P("<i>Lippe, Sprache, wörtlich sagen</i>", "TableCell"), P("Vergleichsfolie, an der die größere Ausdruckskraft des Blicks sichtbar wird.", "TableCell")],
    [P("Inneres / Gefühl", "TableCellBold"), P("<i>fühl', Herz/Herzen, Schmerzen, Glück</i>", "TableCell"), P("Zeigt den Weg von Wahrnehmung zu seelischer Veränderung.", "TableCell")],
    [P("Wasser / Bewegung", "TableCellBold"), P("<i>entquillt, Quelle, bricht, strömend, füllt ... aus</i>", "TableCell"), P("Gefühl wird als kontinuierliche, lebensspendende Kraft dargestellt.", "TableCell")],
    [P("Höhe / Licht / Reinheit", "TableCellBold"), P("<i>Himmeln, Himmel, reinster Helle, reinsten</i>", "TableCell"), P("Idealisiert die Begegnung und öffnet eine transzendente Lesart.", "TableCell")],
    [P("Verschluss / Raum", "TableCellBold"), P("<i>verschlossen, öffne, Abgrund, füllt ... aus</i>", "TableCell"), P("Macht die innere Wandlung räumlich und nachvollziehbar.", "TableCell")],
]
t = Table(word_rows, colWidths=[46 * mm, 60 * mm, 68 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), TEAL),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)

story.append(sub("Zentrale Gegensatzpaare"))
contrast_rows = [
    [P("Worte", "TableCellBold"), P("↔", "TableCell"), P("Blick", "TableCellBold"), P("mittelbare Benennung ↔ unmittelbare Erfahrung", "TableCell")],
    [P("laut / wörtlich", "TableCellBold"), P("↔", "TableCell"), P("still", "TableCellBold"), P("äußere Sprache ↔ innere Wahrheit", "TableCell")],
    [P("verschlossen", "TableCellBold"), P("↔", "TableCell"), P("öffne", "TableCellBold"), P("Abwehr / Mangel ↔ Vertrauen / Hingabe", "TableCell")],
    [P("Abgrund / Schmerzen", "TableCellBold"), P("↔", "TableCell"), P("Himmel / Glück", "TableCellBold"), P("Tiefe und Dunkel ↔ Höhe und Helle", "TableCell")],
    [P("lange Vergangenheit", "TableCellBold"), P("↔", "TableCell"), P("jetziger Augenblick", "TableCellBold"), P("Dauer des Leids ↔ plötzliche Wende", "TableCell")],
]
t = Table(contrast_rows, colWidths=[37 * mm, 8 * mm, 42 * mm, 87 * mm])
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), PALE_CORAL),
    ("GRID", (0, 0), (-1, -1), 0.45, colors.white),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("ALIGN", (1, 0), (1, -1), "CENTER"),
    ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story.append(t)
story.append(Spacer(1, 3 * mm))
story.append(P("Die Gegensätze bleiben nicht nebeneinander stehen. Sie bilden eine <b>gerichtete Entwicklung</b>: Der Blick führt von der verschlossenen, schmerzhaften Tiefe zur offenen, hellen Glückserfahrung. Genau darin liegt die innere Handlung des Gedichts.", "BodyCustom"))
story.append(PageBreak())


# LYRISCHES ICH / FIGUREN
story += head("10. Lyrisches Ich, Du und Beziehung", "Perspektive, Charakter und Reflexion")
story.append(sub("Stellung des lyrischen Ichs"))
for x in [
    "Es gibt <b>keinen Erzähler</b> im üblichen epischen Sinn, sondern ein lyrisches Ich. Wir erhalten ausschließlich seine Wahrnehmung, Gefühle und Deutung des Blicks.",
    "Die Perspektive ist subjektiv: Ob das Du tatsächlich dieselbe Bedeutung beabsichtigt, bleibt offen. Sicher ist nur, wie das Ich den Blick erlebt.",
    "Die Verben zeigen eine Entwicklung: <i>fühlen</i> (innerlich aufnehmen) -> <i>sehen</i> (erkennen/visionär wahrnehmen) -> <i>öffnen</i> (aktiv handeln).",
    "Das Ich erscheint sensibel, reflektiert und verletzlich. Der 'Abgrund' deutet starke Vorerfahrungen von Schmerz an; die vollständige Öffnung zeigt großes Vertrauen und emotionale Risikobereitschaft.",
]: story.append(bullet(x))

story.append(sub("Das angesprochene Du"))
for x in [
    "Das Du spricht nicht. Es wird nur durch <i>Augen</i>, <i>Lächeln</i> und <i>Blick</i> gegenwärtig.",
    "Dadurch bleibt es offen und idealisiert. Es kann ein geliebter Mensch sein; Geschlecht und konkrete Beziehung werden nicht festgelegt.",
    "Seine Wirkung ist außergewöhnlich: Der Blick spendet Klarheit, löst Verschluss und erzeugt Glück. Das Du wird nicht psychologisch ausgearbeitet, sondern vor allem als Auslöser der Ich-Wandlung gezeigt.",
]: story.append(bullet(x))

story.append(sub("Beziehungsdynamik"))
relation = [
    [P("Du", "TableCellBold"), P("blickt / lächelt", "TableCell"), P("Ich", "TableCellBold"), P("fühlt", "TableCell")],
    [P("Augen", "TableCellBold"), P("tragen Inneres still nach außen", "TableCell"), P("Ich", "TableCellBold"), P("sieht die Quelle", "TableCell")],
    [P("Blick", "TableCellBold"), P("wird zum handelnden 'er'", "TableCell"), P("Ich", "TableCellBold"), P("öffnet alles", "TableCell")],
    [P("Glück", "TableCellBold"), P("strömt in den Schmerzabgrund", "TableCell"), P("Beziehung", "TableCellBold"), P("wird als gegenseitige Öffnung erfahrbar", "TableCell")],
]
t = Table(relation, colWidths=[29 * mm, 59 * mm, 28 * mm, 58 * mm])
t.setStyle(TableStyle([
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("BACKGROUND", (0, 0), (0, -1), PALE_BLUE),
    ("BACKGROUND", (2, 0), (2, -1), PALE_TEAL),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story.append(t)
story.append(Spacer(1, 3 * mm))
story.append(callout(
    "Charakterreflexion",
    "Der Moment 'macht' mit dem Ich zweierlei: Er gibt ihm erstens Gewissheit über die Zuneigung des Du und konfrontiert es zweitens mit der eigenen verschlossenen Vergangenheit. Deshalb ist die Öffnung nicht bloß romantische Schwärmerei, sondern eine bewusste Antwort auf frühere Verletzung.",
    PALE_BLUE, NAVY,
))
story.append(PageBreak())


# EPOCHE
story += head("11. Epoche: Romantik", "Einordnung ohne Etikettenschwindel")
story.append(P("Die Datierung <b>ca. 1810</b> weist in die Romantik, genauer in den Bereich der Hochromantik. Eichendorff zählt zu den zentralen Autoren dieser Epoche. Die Einordnung ist nicht nur chronologisch, sondern lässt sich am Text belegen.", "BodyCustom"))

epoch_rows = [
    [P("Romantischer Zug", "TableHead"), P("Textbeleg", "TableHead"), P("Bedeutung", "TableHead")],
    [P("Vorrang des Gefühls", "TableCellBold"), P("<i>Fühl' ich</i>; Herz; Schmerzen; Glück", "TableCell"), P("Inneres Erleben ist wichtiger als äußeres Geschehen.", "TableCell")],
    [P("Unsagbarkeit", "TableCellBold"), P("Keine Lippe kann die Sprache des Blicks führen.", "TableCell"), P("Tiefe Wahrheit entzieht sich rein vernünftiger, wörtlicher Sprache.", "TableCell")],
    [P("Transzendenz", "TableCellBold"), P("Himmel, Quelle, Helle, Reinheit", "TableCell"), P("Die Liebeserfahrung öffnet eine höhere Wirklichkeit.", "TableCell")],
    [P("Sehnsucht und Erfüllung", "TableCellBold"), P("lange verschlossene Quelle -> Glück", "TableCell"), P("Mangel und Wunsch nach Ganzheit werden im Augenblick aufgehoben.", "TableCell")],
    [P("Symbolische Bildwelt", "TableCellBold"), P("Quelle, Licht, Abgrund", "TableCell"), P("Konkrete Bilder verweisen auf seelische und geistige Vorgänge.", "TableCell")],
    [P("Liedhafte Form", "TableCellBold"), P("regelmäßige Strophen, Trochäus, Reim", "TableCell"), P("Schlicht wirkende Musikalität trägt komplexe Empfindung.", "TableCell")],
]
t = Table(epoch_rows, colWidths=[43 * mm, 62 * mm, 69 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), GREEN),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(sub("Warum nicht Expressionismus?"))
story.append(P("Die handschriftliche Liste nennt 'Expressionismus' und 'Romantik' als mögliche Epochenbeispiele. Für dieses Gedicht ist <b>Romantik</b> überzeugend: Datierung, Autor, harmonische Liedform, Himmels- und Quellenbild sowie die Hinwendung zum Gefühl passen dazu. Typisch expressionistische Großstadt-, Zerfalls- oder Schockbilder fehlen.", "BodyCustom"))
story.append(sub("Religiöse oder Liebesdeutung?"))
for x in [
    "<b>Liebesdeutung:</b> Lächeln, direkte Du-Anrede, Augenpaar und innere Öffnung sprechen für eine intime menschliche Begegnung.",
    "<b>Transzendente Nebenlesart:</b> Himmel, Quelle, Reinheit und Licht verleihen dem Blick eine fast göttliche Qualität.",
    "<b>Abgewogenes Urteil:</b> Der Text muss kein religiöses Bekenntnis sein. Wahrscheinlicher ist, dass eine Liebeserfahrung mithilfe religiös-transzendenter Bilder erhöht wird.",
]: story.append(bullet(x))
story.append(PageBreak())


# KOMPLETTE MUSTERANALYSE
story += head("12. Musteranalyse im klassischen Aufbau", "Ausformulierte Fassung")
story.append(sub("Einleitung und Deutungshypothese"))
story.append(P("Das Gedicht <i>Der Blick</i> von Joseph von Eichendorff, das auf etwa 1810 datiert wird und der Romantik zuzuordnen ist, thematisiert die besondere Ausdruckskraft eines liebevollen Blicks. In vier Strophen schildert ein lyrisches Ich, wie die stumme Zuwendung eines Du stärker als Worte wirkt und einen tiefen inneren Wandel auslöst. Der Blick lässt sich dabei als nonverbale Sprache deuten, die das lange verschlossene Ich öffnet und seine Schmerzen in Glück verwandelt.", "BodyCustom"))

story.append(sub("Hauptteil: Inhalt und Entwicklung"))
story.append(P("Zu Beginn schaut das angesprochene Du das lyrische Ich lächelnd an. Die äußere Handlung ist also minimal, ihre innere Wirkung jedoch groß. Das Ich 'fühlt' sofort, dass keine Lippe eine vergleichbare Sprache führen könne (V. 3-4). In der zweiten Strophe reflektiert es diese Wahrnehmung. Der Konjunktiv II 'Könnte' (V. 5) eröffnet einen gedachten Gegenfall: Selbst wenn das im Herzen entstandene Gefühl wörtlich ausgesprochen werden könnte, würde es durch die Augen noch 'süßer' erfüllt (V. 8). Damit wird der Blick nicht als bloßer Ersatz, sondern als Steigerung der Sprache verstanden.", "BodyCustom"))
story.append(P("In der dritten Strophe wechselt die Darstellung von der Reflexion zur visionären Bildsprache. Das Ich sieht 'des Himmels Quelle' (V. 9), die ihm lange verschlossen gewesen sei. Quelle, Helle und die doppelte Superlativform 'reinster/reinsten' (V. 11-12) idealisieren das Augenpaar. Gleichzeitig eröffnet das Präteritum 'war' (V. 10) eine Vorgeschichte des Mangels. Die vierte Strophe vollendet die Veränderung: Das Ich öffnet 'Alles, alles' (V. 14), während der personifizierte Blick den 'Abgrund' der Schmerzen mit Glück füllt (V. 15-16). Aus passiver Wahrnehmung wird damit eine gegenseitige Bewegung von Zuwendung und Öffnung.", "BodyCustom"))

story.append(sub("Hauptteil: Form und Sprache"))
story.append(P("Die regelmäßige Anlage aus vier vierzeiligen Strophen gibt der starken Empfindung Ordnung. Das Gedicht ist überwiegend im vierhebigen Trochäus gestaltet und wechselt weibliche und männliche Kadenzen. Dadurch entsteht ein ruhiger, liedhafter Rhythmus. Während sich in der ersten Strophe nur die geraden Verse reimen, folgen die Strophen zwei bis vier dem Kreuzreim. Diese zunehmende formale Geschlossenheit kann vorsichtig als Spiegel wachsender innerer Gewissheit gelesen werden. Weil jede Strophe zugleich einen ganzen Satz bildet, erscheinen die vier Strophen als klar aufeinanderfolgende Gedankenschritte.", "BodyCustom"))
story.append(P("Besonders wichtig ist die zusammenhängende Wassermetaphorik. Das Gefühl 'entquillt' dem Herzen (V. 6), wird zur 'Quelle' (V. 9), 'bricht' hervor (V. 11) und füllt schließlich 'strömend' den inneren Abgrund aus (V. 16). So erhält das eigentlich Unsichtbare eine räumliche Bewegung. Daneben strukturieren Gegensätze den Text: wörtliches Sagen steht gegen stille Augen, Verschlossensein gegen Öffnung und Schmerz gegen Glück. Die Wiederholung 'Alles, alles' unterstreicht die vollständige Hingabe. Der Blick wird außerdem personifiziert, indem das Pronomen 'er' ihn zum handelnden Subjekt macht. Er ist nicht mehr nur Zeichen, sondern eine verändernde Kraft.", "BodyCustom"))

story.append(sub("Schluss"))
story.append(P("Insgesamt bestätigt sich die Deutungshypothese: Das Gedicht zeigt, wie ein Blick dort Verständigung ermöglicht, wo Worte an Grenzen stoßen. Die romantischen Bilder von Himmel, Quelle und Licht erhöhen die zwischenmenschliche Begegnung zu einer Erfahrung von Ganzheit und Erlösung. Dabei liegt die eigentliche Handlung im Inneren des lyrischen Ichs: Es gelangt vom Gefühl des Verschlossenseins über Erkenntnis und Vertrauen zur vollständigen Öffnung. Das Schlusswort 'Glück' bündelt diese Entwicklung knapp und eindeutig.", "BodyCustom"))
story.append(PageBreak())


# VORTRAG
story += head("13. Ablauf für die Erläuterung in der Klasse", "Erst am Text zeigen, dann deuten")
story.append(sub("Teil A · Analyse direkt am markierten Text (ca. 7-9 Minuten)"))
steps = [
    ("1", "Titel und Ausgangsfrage", "'Der bestimmte Artikel macht aus einem alltäglichen Blick einen besonderen. Meine Leitfrage lautet: Was kann dieser Blick, was Worte nicht können?'"),
    ("2", "Strophe 1", "Markierungen 1-6 zeigen: direkte Du-Ich-Beziehung, Himmelsvergleich, Fühlen, Verneinung der Lippe und Blick als Sprache."),
    ("3", "Strophe 2", "Markierungen 7-11 zeigen: Konjunktiv II als Gedankenexperiment, Herz als Quelle, Augen als stille Vermittler, 'süßer' als Steigerung."),
    ("4", "Strophe 3", "Markierungen 12-16 zeigen: 'Und ich', verschlossene Vergangenheit, Quelle/Helle, Superlativ und idealisiertes Augenpaar."),
    ("5", "Strophe 4", "Markierungen 17-21 zeigen: aktive Öffnung, Totalität, Abgrund, Personifikation und Endpunkt Glück."),
    ("6", "Form", "Vier Stufen, überwiegend Trochäus, wechselnde Kadenzen, ab Strophe 2 Kreuzreim. Jeweils die Wirkung mitnennen."),
    ("7", "Übergang", "'Aus diesen Beobachtungen ergibt sich folgende Gesamtdeutung ...'"),
]
step_rows = [[P("Nr.", "TableHead"), P("Station", "TableHead"), P("Sprechhinweis", "TableHead")]]
for n, title, hint in steps:
    step_rows.append([P(n, "TableCellBold"), P(title, "TableCellBold"), P(hint, "TableCell")])
t = Table(step_rows, colWidths=[12 * mm, 36 * mm, 126 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("ALIGN", (0, 1), (0, -1), "CENTER"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(sub("Teil B · Deutung zum Vortragen (ca. 3 Minuten)"))
story.append(P("Meine Deutung ist, dass der Blick im Gedicht eine Sprache bildet, die tiefer reicht als gesprochene Worte. Entscheidend ist dabei die Entwicklung des lyrischen Ichs. Zu Beginn wird es vom Du angesehen und reagiert vor allem empfindend. Schon hier erkennt es im Blick eine Botschaft, die 'keine Lippe' ausdrücken kann. In der zweiten Strophe denkt es diese Beobachtung weiter: Selbst wenn das Gefühl wörtlich ausgesprochen werden könnte, wäre seine Erfüllung in den Augen 'süßer'. Der Text lehnt Sprache also nicht vollständig ab; er stellt den Blick als unmittelbarere und glaubwürdigere Form der Verständigung dar.", "Speech"))
story.append(P("In den letzten beiden Strophen wird aus dieser Verständigung eine innere Verwandlung. Die 'Quelle' des Himmels, die aus dem Augenpaar hervorbricht, steht für Hoffnung, Reinheit und eine beinahe transzendente Erfahrung. Besonders wichtig ist, dass diese Quelle dem Ich 'lang verschlossen' war. Der Augenblick trifft also auf einen Menschen, der schon länger Schmerz und innere Distanz erlebt. Deshalb bedeutet der Blick mehr als momentane Freude: Er schafft Vertrauen. Das Ich öffnet schließlich 'Alles, alles' und gibt damit seine bisherige Abwehr auf.", "Speech"))
story.append(P("Das Wasserbild verbindet den gesamten Vorgang. Was zunächst dem Herzen 'entquillt', wird zur Quelle und strömt am Ende in den 'Abgrund' der Schmerzen. Aus einer tiefen Leere wird ein mit Glück erfüllter Raum. Zugleich verbinden sich Gegensätze wie Himmel und Abgrund, Verschluss und Öffnung sowie Schmerz und Glück. Gerade diese gerichtete Bewegung macht die Aussage des Gedichts aus: Echte Zuwendung kann einen Menschen nicht nur erreichen, sondern sein Verhältnis zu sich selbst verändern. Typisch romantisch ist, dass eine kleine äußere Begegnung zum Zeichen einer höheren Einheit wird. Der Blick des Du vermittelt dem Ich, dass sein Innerstes gesehen und angenommen ist.", "Speech"))
story.append(PageBreak())


# CHECKLISTE
story += head("14. Checkliste: Ist alles abgedeckt?", "Abgleich mit der handschriftlichen To-do-Liste")
check_rows = [
    [P("Auftragspunkt", "TableHead"), P("Wo behandelt?", "TableHead"), P("Kurzprüfung", "TableHead")],
    [P("Titel / Erwartung / Fragen", "TableCellBold"), P("Kap. 1", "TableCell"), P("spezifischer Blick; Leitfrage nach Grenze der Worte", "TableCell")],
    [P("Ausgangssituation", "TableCellBold"), P("Kap. 1 und 5", "TableCell"), P("Blickkontakt; innerlich verletztes, verschlossenes Ich", "TableCell")],
    [P("Struktur / Aufbau / Form", "TableCellBold"), P("Kap. 5 und 6", "TableCell"), P("4 Stufen; Strophen, Satzbau, Reim, Metrum, Kadenzen", "TableCell")],
    [P("Handlungsentwicklung", "TableCellBold"), P("Kap. 1, 5 und 9", "TableCell"), P("Kontakt -> Reflexion -> Offenbarung -> Wandlung", "TableCell")],
    [P("Sprachliche Mittel / Bilder / Vergleiche", "TableCellBold"), P("Kap. 3, 4 und 7", "TableCell"), P("Beleg, Fachbegriff und Wirkung verknüpft", "TableCell")],
    [P("Adjektive / Nomen / Verben", "TableCellBold"), P("Kap. 7-9", "TableCell"), P("Wortfelder, Steigerung, dynamische Verben", "TableCell")],
    [P("Pronomen / Kasus / Konjunktiv", "TableCellBold"), P("Kap. 8", "TableCell"), P("du-ich-Beziehung; Dativ/Genitiv; Konjunktiv II", "TableCell")],
    [P("Stellung des lyrischen Ichs", "TableCellBold"), P("Kap. 10", "TableCell"), P("subjektive Innensicht; kein epischer Erzähler", "TableCell")],
    [P("Charakter / Reflexion / Erlebnisse", "TableCellBold"), P("Kap. 5 und 10", "TableCell"), P("sensibel, verletzt, reflektiert, vertrauend", "TableCell")],
    [P("Moral / Erkenntnis / Aussage", "TableCellBold"), P("Kap. 12 und 13", "TableCell"), P("echte Zuwendung kann Sprachgrenzen und Verschluss überwinden", "TableCell")],
    [P("Epoche / Autor", "TableCellBold"), P("Kap. 11", "TableCell"), P("Romantik/Hochromantik mit Textbelegen; nicht Expressionismus", "TableCell")],
    [P("Existenzielle Aspekte", "TableCellBold"), P("Kap. 9-13", "TableCell"), P("Gesehenwerden, Verletzlichkeit, Vertrauen, Erlösung, Ganzheit", "TableCell")],
]
t = LongTable(check_rows, colWidths=[57 * mm, 35 * mm, 82 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), TEAL),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(sub("Typische Fehler vermeiden"))
for x in [
    "Nicht schreiben: 'Der Autor fühlt ...'. Besser: 'Das lyrische Ich empfindet ...'.",
    "Nicht jedes Bild als Beweis für Religion ausgeben. Die transzendente Lesart als Möglichkeit kennzeichnen.",
    "Stilmittel nie nur sammeln. Immer: Beleg + Benennung + Wirkung + Bezug zur Deutung.",
    "Die erste Strophe nicht fälschlich als vollständigen Kreuzreim bezeichnen; nur V. 2 und 4 reimen sich.",
    "Keine biografischen Aussagen erfinden: Der Text verrät weder Geschlecht noch konkreten Anlass.",
]: story.append(bullet(x))
story.append(PageBreak())


# SPICKZETTEL
story += head("15. Spickzettel für Nachfragen", "Kurze Antworten mit Textbeleg")
qa = [
    ("Warum ist der Blick 'Sprache'?", "Weil er die aus dem Herzen kommenden Gefühle ohne Worte vermittelt (V. 4-8)."),
    ("Was bedeutet 'des Himmels Quelle'?", "Ein Bild für höchste Hoffnung oder Glück; die Liebeserfahrung wirkt transzendent (V. 9)."),
    ("Wo liegt der Wendepunkt?", "In V. 13: 'Und ich öffne'. Das Ich wird vom Wahrnehmenden zum Handelnden."),
    ("Was erfährt man über die Vergangenheit?", "Nur indirekt: Die Quelle war lange verschlossen, und das Ich trägt einen 'Abgrund' von Schmerzen in sich (V. 10, 15)."),
    ("Welche Hauptgegensätze gibt es?", "Wort/Blick, wörtlich/still, verschlossen/offen, Schmerzen/Glück, Abgrund/Himmel."),
    ("Welche Bildkette ist am wichtigsten?", "entquillt -> Quelle -> bricht -> strömend -> füllt aus. Sie macht die Gefühlswirkung zu einer Bewegung."),
    ("Was leistet der Konjunktiv II?", "'Könnte' entwirft eine hypothetische Möglichkeit und zeigt: Selbst dann wäre der Blick überlegen."),
    ("Warum Romantik?", "Gefühl, Unsagbarkeit, Sehnsucht, Transzendenz, Symbolbilder und liedhafte Form sind textnah belegbar."),
    ("Ist das Gedicht eindeutig ein Liebesgedicht?", "Die intime Du-Anrede und das Lächeln sprechen stark dafür; eine genaue Beziehung nennt der Text aber nicht."),
    ("Was ist die Aussage?", "Gesehen- und angenommen zu werden kann Vertrauen schaffen, Sprachgrenzen überwinden und seelischen Schmerz verwandeln."),
]
qa_rows = [[P("Frage", "TableHead"), P("Antwort", "TableHead")]]
for q, a in qa:
    qa_rows.append([P(q, "TableCellBold"), P(a, "TableCell")])
t = Table(qa_rows, colWidths=[67 * mm, 107 * mm], repeatRows=1)
t.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("GRID", (0, 0), (-1, -1), 0.45, LINE),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
    ("TOPPADDING", (0, 0), (-1, -1), 7),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PAPER]),
]))
story.append(t)
story.append(Spacer(1, 5 * mm))
story.append(callout(
    "Schlussformel",
    "'Der Blick' macht aus einem stillen Augenblick eine innere Handlung: Ein Mensch fühlt sich erkannt, wagt Öffnung und erlebt, dass Zuwendung den Raum des Schmerzes mit Glück füllen kann.",
    PALE_TEAL, TEAL,
))
story.append(Spacer(1, 4 * mm))
story.append(P("Stand: 31. August 2026 · Niveau: 12. Klasse · Versangaben beziehen sich auf die bereitgestellte Textfassung.", "Caption"))


doc.build(story, canvasmaker=NumberedCanvas)
print(OUT)
