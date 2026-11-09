"""Visuels de publication : en-tête de fiche App Store, résultats de recherche, aperçu de lien.

Formats App Store Connect (iOS 27) : en-tête 21:9 en 3840 x 1646, recherche 3:2 en 3840 x 2560, sans transparence.
Le nom de l'app et le bouton Obtenir sont affichés par l'App Store : ils ne figurent pas dans ces images.
Rendu PNG : voir README de ce dossier.
"""

FONT = "-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif"
INK, ACCENT = "#12344A", "#1F7FA8"


def background(w, h):
    # Même dégradé que l'icône, halos flous et courbes purement décoratives (aucune donnée).
    return f'''<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D3EEFA"/><stop offset=".55" stop-color="#A9DDEF"/><stop offset="1" stop-color="#8FD9C4"/></linearGradient>
<filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{h * .12:.0f}"/></filter>
<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="{h * .025:.0f}" stdDeviation="{h * .035:.0f}" flood-color="{INK}" flood-opacity=".22"/></filter>
</defs>
<rect width="{w}" height="{h}" fill="url(#bg)"/>
<circle cx="{w * .15:.0f}" cy="{h * .1:.0f}" r="{h * .45:.0f}" fill="#C4EFE0" opacity=".8" filter="url(#blur)"/>
<circle cx="{w * .88:.0f}" cy="{h * .95:.0f}" r="{h * .5:.0f}" fill="#BFE3F7" opacity=".9" filter="url(#blur)"/>
<circle cx="{w * .78:.0f}" cy="{h * .05:.0f}" r="{h * .3:.0f}" fill="#FFFFFF" opacity=".55" filter="url(#blur)"/>
<path d="M0 {h * .84:.0f} C{w * .17:.0f} {h * .76:.0f} {w * .28:.0f} {h * .9:.0f} {w * .47:.0f} {h * .8:.0f} S{w * .77:.0f} {h * .66:.0f} {w} {h * .74:.0f}" fill="none" stroke="{ACCENT}" stroke-opacity=".12" stroke-width="{h * .006:.1f}"/>
<path d="M0 {h * .91:.0f} C{w * .2:.0f} {h * .86:.0f} {w * .35:.0f} {h * .96:.0f} {w * .55:.0f} {h * .88:.0f} S{w * .83:.0f} {h * .8:.0f} {w} {h * .84:.0f}" fill="none" stroke="#1E8E76" stroke-opacity=".10" stroke-width="{h * .006:.1f}"/>'''


def icon(x, y, size):
    # Icône source (branding/icon-source-1024.png) découpée en carré arrondi.
    r = size * .225
    return f'''<clipPath id="sq"><rect x="{x:.0f}" y="{y:.0f}" width="{size:.0f}" height="{size:.0f}" rx="{r:.0f}"/></clipPath>
<g filter="url(#shadow)"><g clip-path="url(#sq)"><image href="../icon-source-1024.png" x="{x:.0f}" y="{y:.0f}" width="{size:.0f}" height="{size:.0f}"/></g></g>'''


def text(x, y, size, s, weight=600, fill=INK, anchor="start", opacity=1):
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="{FONT}" font-size="{size:.0f}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" opacity="{opacity}" letter-spacing="{-size * .01:.1f}">{s}</text>'


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{background(w, h)}{body}</svg>'


PHRASE = "Tous les sondages, une seule moyenne."
DETAIL = "Institut, dates, échantillon et notice pour chaque sondage."

# En-tête de fiche App Store, 21:9 : une seule idée, tout au centre (zone de sécurité).
W, H = 3840, 1646
s = 760
header = svg(W, H, icon(W / 2 - 1180, (H - s) / 2 - 40, s)
             + text(W / 2 - 300, H / 2 - 10, 150, "Tous les sondages,")
             + text(W / 2 - 300, H / 2 + 170, 150, "une seule moyenne.", fill=ACCENT))

# Résultats de recherche, 3:2.
W2, H2 = 3840, 2560
s2 = 1000
search = svg(W2, H2, icon((W2 - s2) / 2, 430, s2)
             + text(W2 / 2, 1760, 170, PHRASE, anchor="middle")
             + text(W2 / 2, 1950, 90, DETAIL, weight=500, fill=ACCENT, anchor="middle"))

# Aperçu de lien (GitHub, réseaux sociaux), 1280 x 640.
W3, H3 = 1280, 640
s3 = 300
social = svg(W3, H3, icon(110, (H3 - s3) / 2, s3)
             + text(480, 300, 96, "Sondoscope", weight=700)
             + text(484, 370, 36, "Les sondages de la présidentielle 2027", weight=500, fill=ACCENT)
             + text(484, 430, 26, PHRASE, weight=400, opacity=.72))

for name, content in [("product-header-21x9", header), ("search-3x2", search), ("social-1280x640", social)]:
    open(f"{name}.svg", "w").write(content)
