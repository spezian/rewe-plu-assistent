from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    PageTemplate,
    Paragraph,
    Spacer,
)


ROOT = Path("/home/spezian/Documents/ChatGPT/Rewe PLU Assistent")
OUT = ROOT / "output/pdf/Der_Blick_Analyse_Deutung_Kurzfassung.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)

PAGE_W, PAGE_H = A4
MARGIN_L = 22 * mm
MARGIN_R = 22 * mm
MARGIN_T = 17 * mm
MARGIN_B = 17 * mm

NAVY = HexColor("#22384B")
RUST = HexColor("#A45E42")
INK = HexColor("#242A2F")
MUTED = HexColor("#66717A")
LINE = HexColor("#D5DDE2")
PALE = HexColor("#F4F7F8")

SANS_DIR = Path("/home/spezian/.local/share/fonts/NotoSans")
SERIF_DIR = Path("/usr/share/fonts/noto")
pdfmetrics.registerFont(TTFont("Sans", str(SANS_DIR / "NotoSans-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Bold", str(SANS_DIR / "NotoSans-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Serif", str(SERIF_DIR / "NotoSerif-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Serif-Bold", str(SERIF_DIR / "NotoSerif-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Serif-Italic", str(SERIF_DIR / "NotoSerif-Italic.ttf")))

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="DocTitle", fontName="Serif-Bold", fontSize=17.5, leading=21,
    textColor=NAVY, alignment=TA_CENTER, spaceAfter=1.5 * mm,
))
styles.add(ParagraphStyle(
    name="DocMeta", fontName="Sans", fontSize=8.4, leading=10.5,
    textColor=MUTED, alignment=TA_CENTER, spaceAfter=3.5 * mm,
))
styles.add(ParagraphStyle(
    name="Section", fontName="Sans-Bold", fontSize=10.6, leading=13,
    textColor=RUST, spaceBefore=2.1 * mm, spaceAfter=1.2 * mm,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="BodySchool", fontName="Serif", fontSize=10.1, leading=13.25,
    textColor=INK, alignment=TA_JUSTIFY, spaceAfter=2.2 * mm,
    allowWidows=0, allowOrphans=0,
))
styles.add(ParagraphStyle(
    name="Note", fontName="Sans", fontSize=7.5, leading=9.5,
    textColor=MUTED, alignment=TA_CENTER,
))


class NumberedCanvas(Canvas):
    def __init__(self, *args, **kwargs):
        Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.saveState()
            self.setFont("Sans", 7.4)
            self.setFillColor(MUTED)
            self.drawRightString(PAGE_W - MARGIN_R, 9 * mm, f"{self._pageNumber} / {total}")
            self.restoreState()
            Canvas.showPage(self)
        Canvas.save(self)


def page_decor(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(0.6)
    canvas.line(MARGIN_L, PAGE_H - 10.5 * mm, PAGE_W - MARGIN_R, PAGE_H - 10.5 * mm)
    canvas.setFont("Sans-Bold", 7.1)
    canvas.setFillColor(NAVY)
    canvas.drawString(MARGIN_L, PAGE_H - 8.4 * mm, "GEDICHTANALYSE UND DEUTUNG")
    canvas.setFont("Sans", 7.1)
    canvas.setFillColor(MUTED)
    canvas.drawRightString(PAGE_W - MARGIN_R, PAGE_H - 8.4 * mm, "Deutsch · 12. Klasse")
    canvas.restoreState()


doc = BaseDocTemplate(
    str(OUT), pagesize=A4,
    leftMargin=MARGIN_L, rightMargin=MARGIN_R,
    topMargin=MARGIN_T, bottomMargin=MARGIN_B,
    title="Der Blick - Analyse und Deutung (Kurzfassung)",
    author="Schulische Ausarbeitung",
    subject="Analyse und Deutung mit strikter Trennung",
)
frame = Frame(
    MARGIN_L, MARGIN_B,
    PAGE_W - MARGIN_L - MARGIN_R,
    PAGE_H - MARGIN_T - MARGIN_B,
    id="main",
)
doc.addPageTemplates([PageTemplate(id="school", frames=[frame], onPage=page_decor)])


def P(text, style="BodySchool"):
    return Paragraph(text, styles[style])


story = [
    Spacer(1, 1 * mm),
    P("Der Blick", "DocTitle"),
    P("Analyse und Deutung zu Joseph von Eichendorffs Gedicht (ca. 1810)", "DocMeta"),
    HRFlowable(width="100%", thickness=1.2, color=RUST, spaceAfter=2.5 * mm),

    P("Kurze Einleitung", "Section"),
    P(
        "Das um 1810 entstandene Gedicht <i>Der Blick</i> von Joseph von Eichendorff lässt sich der Epoche der Romantik zuordnen. Es thematisiert einen intensiven Blickkontakt zwischen einem lyrischen Ich und einem angesprochenen Du sowie die Grenzen der gesprochenen Sprache. Im Mittelpunkt steht die Frage, auf welche Weise tiefe Gefühle ohne Worte mitgeteilt werden können."
    ),

    P("Kurze Inhaltsangabe", "Section"),
    P(
        "Zu Beginn wird das lyrische Ich von einem lächelnden Du angesehen. Es stellt fest, dass dieser Blick mehr ausdrückt, als eine Lippe wörtlich sagen könnte. Anschließend beschreibt das Ich die Gefühle, die aus dem Herzen kommen und durch die Augen vermittelt werden. In der dritten Strophe nimmt es im Augenpaar des Du eine zuvor verschlossene Quelle wahr. Zum Schluss öffnet sich das lyrische Ich vollständig diesem Blick, der seinen Schmerz mit Glück erfüllt."
    ),

    P("Analyse", "Section"),
    P(
        "Äußerlich ist das Gedicht in vier Strophen mit jeweils vier Versen gegliedert und umfasst somit insgesamt 16 Verse. Jede Strophe bildet zugleich einen vollständigen Satz. Die erste Strophe weist das Reimschema abcb auf, da sich nur die Verse 2 und 4 mit „an“ und „kann“ reimen. In den drei folgenden Strophen liegt jeweils ein Kreuzreim nach dem Schema abab vor. Das Metrum ist überwiegend ein vierhebiger Trochäus. Dabei wechseln weibliche Kadenzen in den ungeraden Versen mit männlichen Kadenzen in den geraden Versen. Auffällig sind außerdem mehrere Enjambements, beispielsweise zwischen V. 1 und 2, V. 3 und 4 sowie V. 15 und 16. Die formale Gestaltung ist damit größtenteils regelmäßig; lediglich das Reimschema der ersten Strophe bildet eine Abweichung."
    ),
    P(
        "Die Sprechsituation wird durch die Personalpronomen „du“, „mich“ und „ich“ bestimmt. Ein lyrisches Ich richtet sich unmittelbar an ein lyrisches Du, wobei kein richtiger Dialog entsteht. Das Du spricht nicht selbst, sondern wird ausschließlich durch seinen Blick und sein Lächeln dargestellt. Der innere Aufbau folgt den vier Strophen: Die erste Strophe beschreibt den Blickkontakt, die zweite setzt die wörtliche Sprache in Beziehung zu den Augen, die dritte konzentriert sich auf die Wahrnehmung der „Quelle“ und die vierte auf das Öffnen des Ichs. Die Anapher „Und ich“ am Anfang der Verse 9 und 13 verbindet dabei die letzten beiden Sinnabschnitte. Das Pronomen „sie“ in V. 5 bezieht sich grammatisch auf die zuvor genannte „Lippe“; daraus lässt sich das Geschlecht des Du nicht bestimmen."
    ),
    P(
        "Die sprachliche Gestaltung weist mehrere rhetorische Mittel auf. In V. 2 steht der Vergleich „lächelnd wie aus Himmeln“. Die „Lippe“ in V. 3 ist eine Metonymie für das Sprechen, während „solche Sprache“ (V. 4) den Blick mit Sprache verbindet. Zur Bildsprache gehören außerdem „des Himmels Quelle“ (V. 9) und der „Abgrund meiner Schmerzen“ (V. 15). Das Wortfeld des Wassers wird durch „entquillt“, „Quelle“, „bricht“, „strömend“ und „füllt [...] aus“ gebildet. Hinzu kommen die Gegensätze „verschlossen“ und „öffne“ sowie „Schmerzen“ und „Glück“. Die Wiederholung „Alles, alles“ (V. 14) und die wiederholte Steigerungsform „reinster/reinsten“ (V. 11 f.) fallen besonders auf. In V. 16 wird der Blick durch das Pronomen „er“ und das Verb „füllt“ personifiziert."
    ),
    P(
        "Grammatisch steht das Gedicht überwiegend im Präsens; nur „war“ (V. 10) ist Präteritum. „Könnte“ (V. 5) steht im Konjunktiv II. „Lächelnd“ und „strömend“ sind Partizipien I, „süßer“ ist ein Komparativ und „reinster/reinsten“ sind Superlative. Hinzu kommen die Dative „dem Herzen“, „den Augen“ und „diesem Blick“ sowie die Genitive „des Himmels“ und „meiner Schmerzen“. Bei der Wortwahl stehen positiv konnotierte Ausdrücke wie „lächelnd“, „Helle“, „reinsten“ und „Glück“ den negativen Formulierungen „lang verschlossen“ und „Abgrund meiner Schmerzen“ gegenüber."
    ),

    P("Deutung", "Section"),
    P(
        "Der Blick lässt sich als eine Form nonverbaler Kommunikation deuten, die tiefer reicht als gesprochene Worte. Bereits der Titel hebt dieses Leitmotiv hervor. Die „Lippe“ kann die Gefühle zwar möglicherweise wörtlich benennen, doch in den Augen werden sie für das lyrische Ich unmittelbarer und glaubwürdiger. Der Blick ist deshalb nicht nur eine Wahrnehmung, sondern eine eigene „Sprache“. Der Vergleich mit den „Himmeln“ und die „Quelle“ des Himmels steigern die Begegnung zu einer fast übernatürlichen Erfahrung. Das angesprochene Du wird dadurch idealisiert, ohne dass der Text eindeutig festlegt, ob es sich um eine Frau oder einen Mann handelt."
    ),
    P(
        "Gleichzeitig zeigt das Gedicht eine deutliche Veränderung des lyrischen Ichs. Die Formulierungen „mir lang verschlossen“ und „Abgrund meiner Schmerzen“ weisen auf frühere Verletzungen und eine innere Verschlossenheit hin. In der letzten Strophe wird dieser Zustand umgekehrt: Das Ich „öffnet“ alles und lässt sich auf die Zuneigung des Du ein. Die zusammenhängende Wassermetaphorik verdeutlicht diesen Vorgang. Was zunächst dem Herzen „entquillt“, wird zur Quelle und strömt schließlich in den inneren Abgrund. So wird aus einer schmerzhaften Leere ein mit Glück erfüllter Raum. Das lyrische Ich wirkt zunächst empfindsam und verletzt, am Ende jedoch vertrauensvoll und bereit, sich emotional zu öffnen."
    ),
    P(
        "Diese Deutung passt zur Romantik. Typisch sind der Vorrang des Gefühls, die subjektive Wahrnehmung, die Sehnsucht nach tiefer Verbundenheit und die Verbindung einer persönlichen Erfahrung mit Himmel, Licht und Reinheit. Die Liebe erscheint als etwas, das nicht vollständig erklärt werden kann, sondern durch einen einzigen Augenblick erfahrbar wird. Auf einer existenziellen Ebene macht das Gedicht deutlich, dass das Gefühl, gesehen und angenommen zu werden, einen Menschen aus seiner inneren Isolation lösen kann."
    ),

    P("Kurzes Fazit", "Section"),
    P(
        "Zusammenfassend lässt sich sagen, dass <i>Der Blick</i> eine äußerlich kleine, innerlich jedoch entscheidende Begegnung beschreibt. Die regelmäßige Form, die auffälligen Gegensätze und die Bildfelder von Augen, Himmel und Wasser unterstützen die Entwicklung vom Verschlossensein zur Öffnung. Damit bestätigt sich die Aussage, dass ein Blick manchmal mehr ausdrücken und bewirken kann, als Worte es vermögen."
    ),
]

doc.build(story, canvasmaker=NumberedCanvas)
print(OUT)
