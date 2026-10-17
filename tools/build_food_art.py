#!/usr/bin/env python3
"""Hand-drawn pixel geometry for the Foods Panic presentation; no ripped tiles.

32px cells, 8 columns. See ui/food_theme.gd for the matching atlas order.
"""
from pathlib import Path

tiles = []
ink = '#272820'
cream = '#fff1c3'
colors = ['#ce4739', '#e6e5ce', '#edb52e', '#3e75c4']
dark = ['#852d2d', '#8c998e', '#a96925', '#294b83']

def rect(x, y, w, h, c):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'

def poly(points, c):
    return f'<path d="{points}" fill="{c}"/>'

def burger(x, y, scale=1):
    art = rect(1, 5, 18, 8, '#6f3929')
    art += poly('M2 5V3H4V1H15V2H18V5Z', '#f5be62')
    art += rect(3, 2, 13, 1, '#ffe0a0')
    art += rect(1, 6, 18, 2, '#87b54a') + rect(3, 8, 14, 2, '#e94d37')
    art += rect(2, 10, 16, 2, '#f0a735') + rect(4, 12, 12, 2, '#d08238')
    for sx, sy in [(5, 3), (10, 2), (14, 4)]: art += rect(sx, sy, 2, 1, '#fff0c1')
    return f'<g transform="translate({x},{y}) scale({scale})">{art}</g>'

def emblem(team, x, y, scale=1):
    if team == 0: return burger(x, y, scale)
    if team == 1:
        art = rect(2, 2, 14, 8, '#e34c40') + rect(4, 0, 10, 3, cream)
        art += rect(0, 10, 18, 2, cream) + rect(3, 12, 2, 2, ink) + rect(13, 12, 2, 2, ink)
        art += rect(7, 3, 4, 6, '#ffe7a3')
    elif team == 2:
        art = poly('M4 2H14V4H16V10H13V13H10V11H7V14H4V11H1V9H3V5Z', '#ce4c39')
        art += rect(5, 1, 8, 2, '#ef8060') + rect(6, 5, 2, 2, cream) + rect(11, 5, 2, 2, cream)
        art += rect(7, 6, 1, 1, ink) + rect(11, 6, 1, 1, ink)
    else:
        art = poly('M0 5L5 0H16L19 5V10H0Z', '#e9ead3')
        art += poly('M1 4L6 1H15L18 4Z', '#f18a73')
        art += rect(6, 3, 6, 7, '#293b37') + rect(7, 4, 4, 1, '#4e6b5c')
        art += rect(1, 10, 18, 2, '#8e6952')
    return f'<g transform="translate({x},{y}) scale({scale})">{art}</g>'

def pavement(rough=False):
    # Original view: olive-grey square paving, raised L relief and fine dithering.
    s = rect(0,0,32,32,'#656b51') + rect(1,1,30,30,'#c3c5a3')
    s += rect(3,3,27,27,'#878e6e') + rect(4,4,24,24,'#a1a582')
    s += rect(6,6,3,19,'#d0d0ab') + rect(9,23,15,3,'#c1c29c')
    s += rect(9,7,2,16,'#6a7355') + rect(11,21,13,2,'#707b5a')
    for y in range(6,21,3):
        s += rect(13,y,11,1,'#bfc29c') + rect(14,y+1,10,1,'#7c8763')
    for y in range(3,30,3):
        for x in range(3+(y%2),30,4): s += rect(x,y,1,1,'#969d78')
    s += rect(30,2,2,30,'#4e583f')+rect(2,30,28,2,'#4e583f')
    if rough:
        s += poly('M0 0H32V32H0Z','#77795f')
        for x,y in [(2,3),(19,13),(7,24),(25,27)]:
            s += rect(x,y,5,2,'#535b46') + rect(x+2,y+2,2,3,'#636b50')
        s += rect(11,10,9,10,'#969879') + rect(13,12,3,5,'#60694e')
    return s

tiles += [pavement(), pavement(True)]
# Shuttered trouble office (cave), refuse bins (fence).
tiles += [rect(2,7,28,23,ink)+rect(4,9,24,19,'#696354')+rect(2,4,28,6,'#80624c')+rect(5,3,22,2,'#aa835e')+rect(8,13,16,15,'#30332f')+rect(9,15,14,1,'#b5a584')+rect(9,19,14,1,'#93886f')+rect(9,23,14,1,'#93886f')+rect(5,7,3,3,'#e3a23e')]
tiles += [rect(3,8,12,20,ink)+rect(5,10,8,16,'#6a795d')+rect(2,7,14,3,'#a7ae8b')+rect(7,4,5,3,'#596549')+rect(6,12,2,11,'#91a17d')+rect(19,14,10,14,ink)+rect(20,15,8,12,'#b59d68')+rect(18,12,12,3,'#d7bd7d')]
# Crossings are overlays on rails. Slats and chevrons make passability visible.
for horizontal in [True,False]:
    s = rect(0,10,32,13,'#ddd4af') + rect(0,11,32,2,'#fff2c5') + rect(0,22,32,2,'#645a43')
    for x in range(1,32,5): s += rect(x,13,1,8,'#9b8a64')
    s += rect(2,4,3,8,ink)+rect(0,2,7,3,'#f6cc53')+rect(27,22,3,8,ink)+rect(25,28,7,3,'#f6cc53')
    if not horizontal: s=f'<g transform="translate(32,0) rotate(90)">{s}</g>'
    tiles.append(s)

def shop(team, hq=False):
    s = rect(2,27,29,4,'#595740')
    if team == 1: # white-roof food cart
        s += rect(4,14,24,13,ink)+rect(6,17,20,9,'#d8cfab')+rect(9,18,14,6,'#68766b')
        s += poly('M2 13L6 6H25L30 13V17H2Z', colors[team])
        for x in range(3,29,6): s+=rect(x,13,3,4,'#9da99a')
        s += rect(7,26,4,4,ink)+rect(23,26,4,4,ink)
    else:
        s += rect(4,12,25,16,ink)+rect(5,14,23,13,'#eee0b5')
        s += poly('M2 12L7 5H25L31 12V16H2Z', dark[team])
        s += poly('M3 11L8 5H24L29 11Z', colors[team])
        s += rect(7,6,17,1,'#f6c48c' if team==0 else '#e4dba6')
        s += rect(5,14,24,3,colors[team])
        for x in range(6,28,6): s += rect(x,14,3,3,cream)
        s += rect(7,19,7,7,'#526863')+rect(19,19,6,8,'#524a3d')
        s += rect(8,20,5,2,'#a2d3ca')+rect(22,23,1,1,'#edbd60')
        s += rect(16,19,1,7,'#c1b58a')+rect(4,27,25,2,'#817457')
    if hq:
        s += rect(10,0,2,9,'#5c5645')
        s += rect(3,1,25,12,ink)+rect(4,2,23,10,cream)
        s += emblem(team,6,2,0.85)
        s += rect(29,18,2,10,colors[team])+rect(28,18,4,2,cream)
    else:
        s += emblem(team,9,7,0.6)
    return s

tiles += [shop(t) for t in range(4)]
tiles += [shop(t,True) for t in range(4)]

def worker(team, manager=False):
    s = rect(5,28,23,3,'#625e48')
    if not manager: # delivery scooter with insulated food box
        s += rect(2,22,7,7,ink)+rect(24,22,7,7,ink)
        s += rect(4,24,3,3,'#c2c7b6')+rect(26,24,3,3,'#c2c7b6')
        s += poly('M7 23L12 16H23L28 23H23L20 20H14L11 25H7Z',colors[team])
        s += rect(4,13,11,8,dark[team])+rect(5,13,9,2,cream)
        s += rect(17,11,7,9,colors[team])+rect(20,18,8,2,'#e7d8a5')
        s += rect(25,14,2,6,ink)+rect(26,12,4,2,'#e2d9b6')
        s += rect(17,5,7,7,'#e9b582')+rect(16,4,9,3,cream)+rect(18,2,6,3,cream)
        s += rect(22,8,2,1,ink)
    else: # chef / manager: tall toque and apron; distinct from delivery staff
        s += rect(9,24,5,6,ink)+rect(19,24,5,6,ink)
        s += rect(8,12,17,14,colors[team])+rect(12,14,10,12,cream)
        s += rect(5,15,4,8,'#e9b582')+rect(25,15,4,8,'#e9b582')
        s += rect(12,6,11,8,'#e9b582')+rect(20,9,2,1,ink)
        s += rect(10,2,15,5,cream)+rect(12,0,5,3,cream)+rect(19,0,5,3,cream)
        s += rect(11,6,13,2,'#cbd1ba')+rect(13,14,8,2,dark[team])
        s += rect(15,20,2,2,dark[team])+rect(19,20,2,2,dark[team])
    return s

tiles += [worker(t) for t in range(4)] + [worker(t,True) for t in range(4)]
for mask in range(16): # bits: north east south west; branches join without seams
    s = rect(0,0,32,32,'#323328')
    for x,y in [(2,4),(12,2),(26,6),(4,27),(27,26),(17,16)]: s += rect(x,y,2,2,'#50503d')
    s += rect(10,10,12,12,'#191e1b')
    for bit in range(4):
        if not mask & (1<<bit): continue
        branch = rect(9,0,14,17,'#242a24')
        for y in range(1,17,5): branch += rect(6,y,20,3,'#6b5c3d')+rect(7,y,18,1,'#9f8a56')
        branch += rect(9,0,2,18,'#c7bea0')+rect(11,0,1,18,'#6b715e')+rect(21,0,2,18,'#c7bea0')
        s += f'<g transform="rotate({bit*90},16,16)">{branch}</g>'
    tiles.append(s)

# Original owned lots use strong red / ivory / gold / blue relief, not grass tint.
old = ['#656b51','#c3c5a3','#878e6e','#a1a582','#d0d0ab','#c1c29c','#6a7355','#707b5a','#bfc29c','#7c8763','#969d78','#4e583f']
palettes = [
 ['#30271e','#e8a059','#6d3426','#a34a32','#ffbf73','#e88c43','#572f24','#653323','#eaa265','#6f3929','#a94e31','#38271d'],
 ['#6c7a71','#f8f2d9','#a5b9ac','#d6e1cc','#ffffe9','#f1efce','#8baba0','#91b4a4','#f1f2d9','#9eada0','#c6d9c8','#637e75'],
 ['#514522','#ffe274','#967129','#d0a235','#ffe97f','#ffcc4b','#77562a','#876329','#ffe06b','#a87d29','#c39731','#554521'],
 ['#192a47','#8cb8e4','#36598a','#477bb8','#add4f4','#73b0ea','#213f69','#254674','#8bbfed','#365f91','#4779ae','#182c48'],
]
for rough in [False,True]:
    for palette in palettes:
        tile = pavement(rough)
        for a,b in zip(old,palette): tile = tile.replace(a,b)
        tiles.append(tile)

height = (len(tiles)+7)//8*32
svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="{height}" viewBox="0 0 256 {height}" shape-rendering="crispEdges">' 
for index, tile in enumerate(tiles):
    svg += f'<g transform="translate({index%8*32},{index//8*32})">{tile}</g>'
svg += '</svg>\n'
destination = Path(__file__).resolve().parents[1]/'assets/foods/atlas.svg'
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(svg)
print(f'{len(tiles)} hand-drawn pixel tiles: {destination}')
