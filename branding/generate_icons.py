BG={'light':('#86CDEE','#86E0C3','#FFFFFF','#2C86AE'),'dark':('#123247','#0F4A42','#E8F7FA','#7CCBEA')}
def defs(a,b):
    return f'''<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>'''
def mark(fg,ac):
    return f'''<g>
<rect x="356" y="330" width="84" height="230" rx="42" fill="{fg}"/>
<rect x="470" y="250" width="84" height="310" rx="42" fill="{fg}"/>
<rect x="584" y="300" width="84" height="260" rx="42" fill="{fg}"/>
<path d="M290 610 Q290 540 360 540 H664 Q734 540 734 610 V720 Q734 790 664 790 H360 Q290 790 290 720 Z" fill="{fg}"/>
<path d="M300 580 L512 690 L724 580" fill="none" stroke="{ac}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M300 300 C400 300 430 190 540 190 S660 240 730 170" fill="none" stroke="{ac}" stroke-width="30" stroke-linecap="round"/>
<circle cx="730" cy="170" r="34" fill="{ac}"/>
</g>'''
def icon(mode):
    a,b,fg,ac=BG[mode]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{defs(a,b)}
<rect width="1024" height="1024" fill="url(#bg)"/><ellipse cx="512" cy="120" rx="620" ry="280" fill="url(#gloss)"/>{mark(fg,ac)}</svg>'''
tinted=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><rect width="1024" height="1024" fill="#000"/>{mark('#FFFFFF','#8C8C8C')}</svg>'''
open('icon-light.svg','w').write(icon('light'));open('icon-dark.svg','w').write(icon('dark'));open('icon-tinted.svg','w').write(tinted)
a,b,fg,ac=BG['light']
open('icon-mac.svg','w').write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{defs(a,b)}
<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/><g transform="translate(100 100) scale(.8047)">{mark(fg,ac)}</g></svg>''')
# pistes
def piste2():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{defs(a,b)}<rect width="1024" height="1024" rx="225" fill="url(#bg)"/>
<circle cx="512" cy="512" r="290" fill="none" stroke="#fff" stroke-width="60"/><circle cx="512" cy="512" r="290" fill="none" stroke="{ac}" stroke-width="60" stroke-dasharray="620 1200" transform="rotate(-90 512 512)" stroke-linecap="round"/><path d="M400 540 L480 620 L640 420" fill="none" stroke="{ac}" stroke-width="56" stroke-linecap="round" stroke-linejoin="round"/></svg>'''
def piste3():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{defs(a,b)}<rect width="1024" height="1024" rx="225" fill="url(#bg)"/>
<rect x="250" y="540" width="524" height="210" rx="50" fill="#fff"/><rect x="340" y="520" width="344" height="30" rx="15" fill="{ac}"/><rect x="400" y="240" width="224" height="290" rx="36" fill="#fff"/><path d="M450 450 C490 350 530 420 574 310" fill="none" stroke="{ac}" stroke-width="32" stroke-linecap="round"/></svg>'''
open('piste-1-enveloppe-barres.svg','w').write(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{defs(a,b)}<rect width="1024" height="1024" rx="225" fill="url(#bg)"/>{mark(fg,ac)}</svg>''')
open('piste-2-anneau.svg','w').write(piste2());open('piste-3-urne.svg','w').write(piste3())
