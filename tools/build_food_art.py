#!/usr/bin/env python3
"""Draw the Foods Panic miniature diner set. Run from any directory.

The live square in each 256px slot is 192px, with a 32px gutter for
filtered minification. Names/order are shared with ui/food_theme.gd.
All coordinates below are in a 64-unit working square, not source pixels.
"""
from pathlib import Path

INK, GLASS, IVORY, METAL = '#293b3e', '#3c6168', '#fff2c8', '#bbc8ba'
TEAMS = [('#d84d3d', '#933b35', '#fa8366'), ('#f2eaca', '#748d83', '#fff9e1'),
         ('#e9b73d', '#906529', '#ffe388'), ('#34769b', '#264e6b', '#7eb9c5')]
PAVERS = [('#adbcaa','#8e9e91','#c3cfb6'), ('#c99176','#ad7666','#dba78b'),
          ('#d3d7ba','#afbda8','#e2e5cb'), ('#d3bb77','#b49e69','#e0ce96'),
          ('#84a9ab','#71908e','#a3bcb6')]

def p(d, c, line=None, w=1):
    stroke = f' stroke="{line}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"' if line else ''
    return f'<path d="{d}" fill="{c}"{stroke}/>'

def s(d, c, w=1): return p(d, 'none', c, w)
def r(x,y,w,h,c,rad=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rad}" fill="{c}"/>'
def e(x,y,rx,ry,c):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{c}"/>'
def g(tr, art): return f'<g transform="{tr}">{art}</g>'
def use(key): return f'<use xlink:href="#{key}"/>'
def sym(name, art):
    defs.append(f'<g id="{name}">{art}</g>')
    return use(name)
def gradient(key, values):
    defs.append(f'<linearGradient id="{key}" x1="0%" y1="0%" x2="14%" y2="100%">'+
                ''.join(f'<stop offset="{i/(len(values)-1):.2f}" stop-color="{v}"/>' for i,v in enumerate(values))+'</linearGradient>')
    return f'url(#{key})'

defs = []
bun = gradient('bun',['#fff0a6','#f1b558','#c87a3f'])
cream = gradient('cream',['#fffae1','#f4e6bb','#cbbf9b'])
aqua = gradient('aqua',['#b9dfd3','#77a6a4','#4a727d'])
silver = gradient('silver',['#f2efcd','#c4d5ce','#729394'])
slate = gradient('slate',['#566b68','#344747'])
salmon = gradient('salmon',['#ffb18a','#e77863','#bc514c'])
for i,(light, shade, shine) in enumerate(TEAMS):
    gradient(f'color{i}',[shine,light,shade])

# Each emblem has the same center and baseline, giving roofs matching sign mounts.
def emblem(i):
    if i==0: # split-seed brioche, bright lettuce, folded cheddar and a charred patty
        a=p('M9 28Q11 37 31 37Q51 37 55 28L54 22H10Z',bun,INK,1.9)
        a+=p('M10 26Q19 30 30 29Q44 31 54 26L54 23Q42 20 32 23Q19 20 10 23Z','#713f34',INK,1.2)
        a+=p('M10 23Q15 18 21 22Q27 19 31 21Q37 18 42 21L53 19L54 22Q49 27 44 24L40 28L32 24Q24 26 19 23Q13 26 10 23Z','#92a94b')
        a+=p('M9 20C10 8 20 2 32 2C44 2 53 9 55 19Q48 23 32 23Q16 23 9 20Z',bun,INK,1.7)
        a+=s('M14 15Q19 6 30 6','#ffedbb',1.3)
        for x,y in [(22,12),(33,8),(40,14),(29,17),(47,16)]:
            a+=s(f'M{x} {y}l1.6 -.9','#fff1bf',1.5)
    elif i==1: # street stall: red lacquer noodle bowl with chopsticks and steam
        a=s('M32 19L51 3M36 20L56 7','#8d6749',1.6)
        a+=s('M19 16Q24 12 21 9Q18 6 22 3M28 15Q32 12 30 8','#f7ebd5',2.8)
        a+=p('M9 19Q14 36 31 36Q48 36 55 19Z','#b95143',INK,1.9)
        a+=p('M10 19Q32 14 54 19Q48 25 32 25Q17 25 10 19Z',cream,INK,1)
        a+=e(32,20,17,2.2,'#95603c')+s('M21 20q3 -3 7 -.5t7 -.5t8 .3','#edbd6c',1.5)
        a+=s('M17 26Q32 33 47 26','#f5d8a2',2.1)+r(24,34,15,3,INK,1.5)
    elif i==2: # playful octopus on the takoyaki marquee
        a=p('M15 24C11 11 17 3 30 2C42 1 51 11 48 24C54 26 56 22 55 20C63 27 54 36 47 31Q45 38 38 34Q33 41 27 34Q18 39 16 32C9 35 3 27 8 22Q9 28 15 24Z',salmon,INK,1.8)
        a+=s('M19 14Q23 7 30 7','#ffcb9e',2.1)+e(26,20,1.8,2.5,INK)+e(39,20,1.8,2.5,INK)
        a+=e(33,25,4.0,2.8,'#ffd19c')+e(33,25,2.0,1.1,'#90493f')
        a+=s('M12 28q3 3 5 1m5 3q2 2 4 0m12 0q2 2 4 -1m8 -2q3 0 4 -3','#ffc39a',1.3)
    else: # salmon nigiri; neither type nor a logo is needed at map scale
        a=p('M7 24Q8 14 20 13L48 11Q57 10 58 20Q58 29 50 31L19 35Q8 37 7 29Z',cream,INK,1.7)
        a+=p('M6 23Q7 13 18 10L46 5Q56 5 59 15L56 21L17 28Q9 30 6 23Z',salmon,INK,1.7)
        a+=s('M14 19q4 0 10 5m-2 -11q5 2 10 8m8 -12q5 2 10 8','#ffd2ab',2)
        a+=p('M25 10L34 8L41 13L41 29L32 31L31 17Z',INK)+s('M33 16l5 -1','#668075',1.2)
    return sym('em'+str(i),a)
emblems = [emblem(i) for i in range(4)]

def pavement(i, rough=False):
    base, joint, hi = PAVERS[i]
    # Continuous running-bond paving. Avoid strongly contrasted tile frames.
    a=r(-11,-11,86,86,base)
    if rough:
        a+=p('M-2 12L13 7L23 8L30 3L34 5L20 13L11 11Z M33 40L55 35L65 36L65 41L48 40L40 44Z',joint)
        a+=s('M-1 44l9 -4l7 2l5 -4l9 2m12 -24l5 5l7 1l5 6m-41 23l6 2l3 5',joint,1.2)
        a+=s('M10 42l4 1l5 -4m19 4l8 -4l6 1',hi,.9)
        for x,y in [(8,15),(34,26),(54,52),(19,33),(41,59),(57,10)]:
            a+=e(x,y,1.4,.8,joint)+s(f'M{x-1} {y-.8}h1.5',hi,.7)
    else:
        a+=s('M-11 12H75M-11 44H75M20 -11V12M52 12V44M20 44V75',joint,.85)
        a+=s('M-11 13H75M-11 45H75M21 -11V12M53 13V43M21 45V75',hi,.55)
        # A couple of porcelain flecks are quiet at overview, readable when close.
        a+=p('M8 25l2 -.8l2 .6l-2 .7zM35 52l2 -.6l2 .6l-2 .5z',hi)
    return a

def office():
    a=pavement(0,True)
    a+=e(33,55,27,5,'#788b7e')+p('M8 23L48 20L55 26V52L48 56H8Z','#b2ae91',INK,1.7)
    a+=p('M49 22L55 26V52L49 55Z','#897e69')
    a+=p('M6 20L45 17L58 22L51 28H6Z',slate,INK,1.5)
    a+=r(13,31,25,23,INK,1)+r(15,33,21,19,'#768787')
    a+=s('M16 36h19m-19 4h19m-19 4h19m-19 4h19','#455854',1.3)
    a+=r(42,30,5,10,'#ded3a6',1)+r(43,32,3,2,'#9d563c')+r(10,25,5,3,'#f2b954',1)
    return a

def refuse():
    a=e(32,53,27,5,'#374948')
    for x,y,z in [(32,19,.77),(10,14,1)]:
        b=p('M1 7H27L25 38Q14 42 4 38Z','#647f76',INK,1.8)
        b+=r(0,5,28,6,'#a2ada0',2)+s('M4 7h21','#d3d5b6',1.1)
        b+=s('M8 15l1 19m6 -20v20m7 -21l-1 19','#344e4a',1.5)+p('M8 5V2h10v3','#778a7c',INK,1.4)
        a+=g(f'translate({x} {y}) scale({z})',b)
    return a

def crossing(vertical=False):
    a=r(-0,21,64,24,INK)+r(0,22,64,19,'#c7ba98')+r(0,24,64,2,'#f5dba4')
    a+=s('M5 27v12m9 -12v12m9 -12v12m9 -12v12m9 -12v12m9 -12v12m9 -12v12','#9a896d',1.4)
    for x,y in [(3,18),(43,46)]:
        a+=r(x,y,18,4,INK,1.1)
        for xx in (x+2,x+8,x+14): a+=p(f'M{xx} {y+.4}h3l-2 3h-3z','#edbe57')
    return g('rotate(90 32 32)',a) if vertical else a

def shop(i, flagship):
    light,shade,shine=TEAMS[i]
    trim=f'url(#color{i})'
    base=e(33,55,28,5,'#475c56')
    if i==1: # wheeled yatai, canvas noren, red lantern
        a=r(9,26,3,24,'#765b46')+r(48,25,3,25,'#765b46')
        a+=r(11,42,40,11,'#b28962',1.5)+r(8,40,46,4,cream,1.5)
        a+=r(12,48,38,3,'#785b43',1)
        for x in (16,46): a+=e(x,54,4.4,4.4,INK)+e(x,54,2,2,'#b7b7a1')
        a+=p('M4 25L13 15L43 13L58 24L55 29H7Z',cream,INK,1.6)
        a+=p('M5 24L56 23L54 29L8 31Z','#d1c39c')
        for x in (10,21,32): a+=r(x,27,10,8,'#ece2c2',1.4)+s(f'M{x+2} 28v4','#c9bda0',.9)
        a+=p('M45 30q4 -4 8 -1q4 8 -1 11q-4 2 -7 -1q-2 -5 0 -9Z',salmon,INK,1.1)
        a+=s('M46 32h6m-7 3h7','#e6a784',1)+r(18,36,14,4,'#a14f40',2)
    elif i==2: # compact octagonal brass kiosk with a scalloped hotplate roof
        a=p('M9 28L48 26L54 32L51 51L42 56H15L9 51Z',cream,INK,1.7)
        a+=p('M43 33L54 29L51 51L43 55Z','#b18544')
        a+=r(15,32,26,13,GLASS,1.6)+r(17,34,22,9,'#473d36',1.4)
        for x in (20,27,34): a+=e(x,40,2.8,2.2,'#e9a15c')+e(x-.5,39.3,1.2,.7,'#f5cf87')
        a+=p('M6 28Q9 13 24 11Q45 6 56 26L54 31H8Z',trim,INK,1.7)
        a+=s('M9 26Q32 17 54 25',shine,1.8)+r(9,28,44,5,shade,2)
        a+=r(13,44,31,4,'#f9d17b',1.5)+s('M18 51h18','#b77542',1.2)
    elif i==3: # blue sushi bar, gabled roof and indigo split curtain
        a=p('M9 26H52V54H9Z',cream,INK,1.6)+r(9,30,43,3,'#866d51')
        a+=r(13,33,33,15,'#39555a',.8)+r(16,35,26,11,'#769290')
        a+=p('M3 27Q11 24 14 17L40 13L57 24L61 25L57 29Q43 29 34 25Q18 31 4 31Z',slate,INK,1.5)
        a+=s('M8 27q15 -2 25 -7l22 6','#799795',1.1)
        for x in (12,23,34): a+=p(f'M{x} 31h10v10q-5 2 -10 1Z',trim)+s(f'M{x+4} 33l1 4',shine,1)
        a+=r(9,48,43,5,'#866c48',1)+s('M11 49h38','#c7ae7f')
        a+=r(48,32,5,15,'#f2dcc2',2)+s('M50 35v7','#ae4740',1.5)
    else: # Streamline diner: rounded corner window, enamel fascia and checker kickplate
        a=p('M7 25Q7 20 15 20L46 18Q54 18 56 25V48Q55 55 47 55H14Q7 54 7 49Z',cream,INK,1.7)
        a+=p('M10 31H51V42Q50 47 44 47H10Z',aqua,INK,1.2)
        a+=s('M15 33l-3 7m10 -7l-7 11','#c8e4d6',1.3)+s('M33 32v14m10 -14v13',INK,1.6)
        a+=p('M4 24Q6 19 12 18L46 16Q55 16 59 22L57 27L12 30Q4 30 4 24Z',trim,INK,1.7)
        a+=s('M8 24l45 -3',shine,1.4)+s('M10 28l42 -3','#f6d6a4',1.2)
        a+=r(11,48,39,4,shade,1)
        for x in range(13,49,8): a+=r(x,48,4,2,IVORY)+r(x-3,50,3.5,2,IVORY)
    if flagship:
        # Headquarters have a monumental projecting menu sign on two brass posts.
        body=g('translate(0 7) scale(1 .91)',a)
        m=s('M20 32V17M44 32V17',INK,3.2)+s('M20 31V18M44 31V18','#d8b776',1.45)
        m+=p('M11 8Q30 0 48 6Q57 9 56 17Q55 24 47 26Q28 32 11 26Q5 24 6 17Q6 11 11 8Z',shade,INK,1.8)
        m+=p('M11 9Q32 2 49 8Q55 10 53 17Q52 23 46 24Q28 29 12 24Q7 23 8 17Q8 12 11 9Z',cream)
        m+=g('translate(11 3) scale(.65 .64)',emblems[i])
        return base+body+m
    return base+a+g('translate(16 9) scale(.49 .45)',emblems[i])

def wheel(x):
    return e(x,49,6.9,7.5,INK)+e(x,49,4.2,4.8,'#8b9b94')+e(x,49,2,2.4,'#e5dbb5')

def courier(i):
    light,shade,shine=TEAMS[i]
    a=e(32,56,29,3,'#4e635f')+wheel(13)+wheel(50)
    a+=p('M7 44Q10 36 20 36L28 40L40 40L43 29L41 26L45 24Q51 30 53 40L57 44Q53 46 47 44L43 48Q41 51 35 51H25Q21 51 20 47L18 44Z',f'url(#color{i})',INK,1.7)
    a+=p('M20 35Q25 32 33 34L35 37L23 39Z',INK)+s('M26 47h10q4 0 6 -4',shine,1.5)
    a+=r(4.5,24,17,12,shade,2)+r(4,22,18,4,cream,1.3)+s('M8 29h10',shine,1.8)
    a+=p('M28 22Q32 19 36 22L39 31L44 30L45 33Q38 37 35 34L32 30L31 35L37 38L35 46H31L32 40L24 37Q22 35 24 29Z',f'url(#color{i})',INK,1.6)
    a+=p('M26 15Q27 8 33 9Q39 8 40 15L38 17L38 22L34 24L29 21Z','#e9ae7b',INK,1.5)
    a+=p('M25 15Q25 6 32 6Q40 5 41 14L44 15L43 17H33L31 20L28 19Z',cream,INK,1.4)
    a+=s('M27 14q6 -3 12 -2',light,2)+s('M44 27l4 -3h4',INK,1.7)+e(50,34,2.5,3,IVORY)
    return a

def manager(i):
    light,shade,shine=TEAMS[i]
    a=e(32,56,19,3,'#465b58')
    a+=p('M20 42H41L39 54L34 56L31 47L28 55H20Z',slate,INK,1.6)
    a+=e(23,55,6,2.4,INK)+e(38,55,5,2.4,INK)
    a+=p('M22 28Q29 24 38 27Q44 30 46 37L51 35L54 38Q49 45 42 43L40 40L41 48Q30 53 18 46L19 40L16 46L12 44Q16 30 22 28Z',cream,INK,1.6)
    a+=p('M22 30L27 32L34 32L38 29L38 36L40 47Q31 51 21 46L23 37Z',f'url(#color{i})',INK,1)
    a+=s('M26 41q5 2 9 0',shine,1.5)
    a+=p('M22 17Q24 10 32 11Q39 12 39 19L41 23L38 24Q37 30 32 30Q24 30 22 23Z','#e9ad79',INK,1.4)
    a+=p('M21 17Q14 14 17 9Q18 6 23 7Q23 2 28 2Q32 1 35 5Q40 2 44 6Q48 11 41 15L40 21L23 22Z',cream,INK,1.6)
    a+=s('M24 18l14 -2','#b0bbae',1.4)+e(35.5,22.5,1,1.2,INK)
    a+=p('M12 45Q13 42 17 43L17 47Q14 49 12 47Z','#eab07a')
    a+=p('M43 35Q44 29 51 29Q56 29 58 35Z',silver,INK,1.15)+r(42,35,17.5,2.2,IVORY,.8)+e(51,28.8,1.3,1.1,INK)
    return a

def rails(mask):
    # Rail contours are drawn continuously through bends. Branches line up at
    # every tile edge; material under gutters is extended to support mipmaps.
    a=r(-11,-11,86,86,'#485854')
    for x,y,k in [(5,7,2),(44,5,2),(7,42,2),(55,51,2.5),(22,56,1.8),(9,28,1.5),(37,13,1.3),(46,46,1.7),(55,22,1.3),(28,25,2),(34,60,1.6)]:
        a+=p(f'M{x} {y}l{k} -.8l1.3 1.2l-2.2 1Z','#6a7469')
    arms=[f for f in range(4) if mask & (1<<f)]
    bends={3:0,6:90,12:180,9:270}
    if mask in bends:
        b=s('M32 -11V0Q32 32 64 32H75','#394744',22)
        for tr in ['translate(32 6)','translate(34 15) rotate(-15)','translate(39 23) rotate(-37)','translate(47 28) rotate(-62)','translate(57 31) rotate(-82)']:
            b+=g(tr,r(-13,-1.7,26,3.4,'#98836b',.8))
        for side in (-1,1):
            x=32+side*7;y=32-side*7
            b+=s(f'M{x} -11V0Q{x} {y} 64 {y}H75','#253a3b',3.6)+s(f'M{x} -11V0Q{x} {y} 64 {y}H75','#c0c5b2',1.7)
        return a+g(f'rotate({bends[mask]} 32 32)',b)
    if not arms: return a+e(32,32,11,11,'#2c403e')+e(32,32,6,6,'#8d998b')
    # Individual ties stop short of the center so rail junctions remain legible.
    for k in arms:
        b=r(19,-11,26,42,'#394744')
        for y in (-7,3,13,23):
            b+=r(19,y,26,3.5,'#94806a',.6)+s(f'M20 {y+.5}h24','#ac9d80',.8)
        a+=g(f'rotate({k*90} 32 32)',b)
    for k in arms:
        b=''
        for x in (25,39):
            b+=s(f'M{x} -11V38','#263e3d',3.6)+s(f'M{x} -11V38','#c0c5b2',1.7)
        a+=g(f'rotate({k*90} 32 32)',b)
    if len(arms)==1: a+=g(f'rotate({arms[0]*90} 32 32)',r(20,36,24,5,'#caac74',.8)+s('M21 38h22','#eed097',1))
    return a

tiles=[pavement(0),pavement(0,True),office(),refuse(),crossing(),crossing(True)]
tiles += [shop(i,hq) for hq in (False,True) for i in range(4)]
tiles += [f(i) for f in (courier,manager) for i in range(4)]
tiles += [rails(mask) for mask in range(16)]
tiles += [pavement(i,rough) for rough in (False,True) for i in range(1,5)]
assert len(tiles)==46
# Clip each slot (including its gutter), so rail ends cannot enter other slots.
defs.append('<clipPath id="slot"><rect x="0" y="0" width="256" height="256"/></clipPath>')
contents = ''.join(g(f'translate({i%8*256} {i//8*256})','<g clip-path="url(#slot)">'+g('translate(32 32) scale(3)',art)+'</g>') for i,art in enumerate(tiles))
svg='<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="2048" height="1536" viewBox="0 0 2048 1536"><defs>'+''.join(defs)+'</defs>'+contents+'</svg>\n'
dest=Path(__file__).resolve().parents[1]/'assets/foods/atlas.svg'
dest.write_text(svg,encoding='utf-8')
print(f'{len(tiles)} illustrated 192px tiles: {dest}')
