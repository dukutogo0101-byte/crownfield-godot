#!/usr/bin/env python3
"""Original Crownfield vector assets; deterministic, editable, no borrowed graphics."""
from pathlib import Path
import random, subprocess
ROOT=Path(__file__).resolve().parents[1]
DEFS='''<defs>
<linearGradient id="stone" x2=".1" y2="1"><stop stop-color="#fff2cd"/><stop offset="1" stop-color="#bfb88c"/></linearGradient>
<linearGradient id="roof" x2=".5" y2="1"><stop stop-color="#db8060"/><stop offset="1" stop-color="#863f3b"/></linearGradient>
<linearGradient id="metal" x2=".8" y2="1"><stop stop-color="#f0f8ee"/><stop offset=".45" stop-color="#8ea9a7"/><stop offset="1" stop-color="#425b67"/></linearGradient>
<linearGradient id="wood" x2=".2" y2="1"><stop stop-color="#d6a66b"/><stop offset="1" stop-color="#74503b"/></linearGradient>
<linearGradient id="gold" x2=".5" y2="1"><stop stop-color="#fff1ac"/><stop offset=".55" stop-color="#d8a548"/><stop offset="1" stop-color="#987339"/></linearGradient>
<linearGradient id="grass" x2=".3" y2="1"><stop stop-color="#53876d"/><stop offset="1" stop-color="#356250"/></linearGradient>
<linearGradient id="sea" x2=".2" y2="1"><stop stop-color="#3c7180"/><stop offset="1" stop-color="#254556"/></linearGradient>
</defs>'''
def save(name,body,w=128,h=128,defs=DEFS):
 p=ROOT/name;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{body}</svg>')
def path(d,fill,stroke='',sw=1):return f'<path d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if stroke else '')+'/>'
def rect(x,y,w,h,fill,rx=0,stroke=''):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'+(f' stroke="{stroke}"' if stroke else '')+'/>'
def circle(x,y,r,fill):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>'
shadow='<ellipse cx="64" cy="111" rx="46" ry="10" fill="#092a2a" opacity=".24"/>'
r=random.Random(70041)
body=rect(0,0,64,64,'url(#grass)')
for i in range(100):
 x,y=r.randrange(64),r.randrange(64);c=r.choice(['#83a181','#6c9477','#2c5b49','#739e7d'])
 body+=path(f'M{x} {y}l2 -2m-2 2l-1 -3','none',c,.7)
for i in range(12):
 x,y=r.randrange(64),r.randrange(64);body+=path(f'M{x} {y}l6 1','none','#4a775f',.6)
save('terrain/grass.svg',body,64,64)
body=rect(0,0,64,64,'url(#sea)')
for y in range(-4,70,12):
 for x in range(-16,70,32):
  body+=path(f'M{x} {y}q8 -3 16 0t16 0','none','#568c98',1.4)
  body+=path(f'M{x+7} {y+4}q5 -1 10 0','none','#366775',.8)
save('terrain/water.svg',body,64,64)
body=rect(0,0,64,64,'#916950')
for i in range(45):
 x,y=r.randrange(64),r.randrange(64);body+=path(f'M{x} {y}l4 -2 4 1 -2 3 -5 1z',r.choice(['#785c49','#a4805d','#aa8160','#67584a']))
for i in range(20):
 x,y=r.randrange(64),r.randrange(64);body+=path(f'M{x} {y}l2 -4','none','#648164',.9)
save('terrain/rough.svg',body,64,64)
body=rect(0,0,64,64,'url(#grass)')+path('M5 52L9 32 20 16 36 10 52 24 60 52z','#61706a','#42594d')+path('M7 50L21 30 20 16 11 31z','#8b9981')+path('M24 18L34 13 49 25 41 32z','#9ba38c')+path('M36 20L43 28 35 40 27 31z','#75857a')+path('M19 54V43Q19 27 32 27T45 43V54z','#203238','#31484b',2)+path('M24 53V42Q24 32 33 33Q41 34 41 43V53z','#111f28')+path('M7 54l16 -4h20l14 4z','#aeaa81')
save('terrain/cave.svg',body,64,64)
# Castle: masonry keep, tiled terracotta towers, raised battlements, crenellations and banners.
body=shadow+path('M23 103L63 118 108 99 71 87z','#9fa48c')
body+=path('M27 54L68 43 107 57v48L66 117 27 103z','url(#stone)','#626960',1.2)
body+=path('M68 43v74l39 -12V57z','#adae8e')
body+=path('M27 54L68 43 107 57 66 69z','#e3ddb4')
body+=rect(40,42,48,52,'url(#stone)',1,'#7c8070')+path('M40 42L64 22 88 42z','url(#roof)','#6f4540',1)
body+=path('M45 40L64 25 84 40M51 35h26M55 31h17','none','#ecae86',.8)
for x in [27,87]:
 body+=rect(x,46,19,54,'url(#stone)',2,'#7f8470')+path(f'M{x-3} 47l12 -23 13 23z','url(#roof)','#78453e',1)
 body+=path(f'M{x+1} 44l8 -16 9 16M{x+4} 39h11','none','#efa582',1)
 body+=rect(x+7,62,5,13,'#465a58',2)+rect(x+5,59,9,3,'#dcd6b2')
body+=path('M56 108V87q0 -12 9 -12t9 12v24z','#465354','#8f8970',2)+path('M59 105V88q0 -8 6 -8t6 8v20z','url(#wood)')
body+=path('M65 81v26M61 88v18M69 87v19','none','#5b4b3d',.8)+circle(69,99,1.3,'#dab065')
for yy in [71,81,91,100]:
 body+=path(f'M30 {yy}h13m38 0h20M48 {yy}h6','none','#b1ad8d',.7)
for x in [28,34,40,86,92,98]:body+=rect(x,50,5,7,'#ece1b9',1)
body+=path('M64 25V7','none','#c1ae79',1.4)+path('M65 7l18 4 -18 8z','#58abb0','#245765',.7)+path('M69 11h8','none','#d8ebe2',1)
save('entities/castle.svg',body)
# Village: two cottages, trim, orchard, path and vegetable rows.
body=shadow+path('M19 104L65 116 105 98 63 86z','#b5aa80')+path('M30 68L68 61 91 76v29L62 113 30 101z','url(#stone)','#7c7d62')+path('M63 69L91 76v29l-29 8z','#b0ae85')+path('M22 70L48 42 75 51 101 79 63 84z','url(#roof)','#764b3d',1.2)+path('M22 70L48 42 63 68v16z','#b76248')
body+=path('M28 68L48 47 59 68M33 65h23M39 58h14M69 57l26 19M75 56l20 17M79 61l-13 2M85 68l-20 3','none','#e8a578',.9)
body+=rect(74,48,7,20,'#bebba0',1,'#7c816f')+rect(72,47,11,5,'#dcd4ae',1)
body+=rect(43,84,11,21,'url(#wood)',2,'#776445')+rect(34,81,6,10,'#486e70',1)+rect(76,85,9,10,'#456d72',1)
body+=path('M35 86h4M38 82v9M77 90h7M81 86v8','none','#d9d6a8',.8)+path('M31 98h10M56 107l6 -2','none','#6b7761',1)
body+=path('M45 106L41 115 58 119 63 112z','#d2c4a2')
body+=rect(17,88,3,17,'#745c40',1)+circle(19,81,12,'#4d7653')+circle(12,77,9,'#658a5c')+circle(23,74,10,'#759363')+circle(15,79,2,'#d9a474')+circle(24,81,2,'#c88768')
for i in range(3):
 body+=path(f'M85 {104+i*4}l17 -5','none','#6f8057',2)
 for j in range(3):body+=path(f'M{89+j*5} {102+i*4-j}l-2 -3 3 1 2 -3','none','#7ba06b',1.5)
save('entities/village.svg',body)
# Shield knight, spear, articulated armour, warm leather details.
body='<ellipse cx="64" cy="108" rx="28" ry="9" fill="#092a2a" opacity=".24"/>'
body+=path('M55 78l-5 22 -7 9 15 1 8 -28M70 78l4 24 11 7 -15 1 -7 -28','url(#metal)','#394e5c',2)
body+=path('M50 56l-10 17 8 7 13 -18M76 55l10 13 10 -6 4 8 -17 11 -13 -19','url(#metal)','#394e5c',2)
body+=path('M49 49L63 45 79 51 77 79 62 86 50 77z','url(#metal)','#3c5860',2)+path('M54 51L63 64 74 51M62 64v16','none','#c2d2c1',1.7)
body+=path('M50 77l26 -1v7l-14 5 -12 -4z','#80583f')+rect(61,78,6,6,'url(#gold)',1)
body+=path('M50 44V30q0 -17 13 -17t14 17v14l-14 8z','url(#metal)','#38525a',2)+path('M50 32l27 -1v7l-27 3z','#33484e')+path('M63 16v28','none','#dbe4ce',2)+path('M55 34h6m5 -1h7','none','#e4c788',1.2)
body+=path('M61 17Q48 10 53 3q13 -3 19 8l-6 8z','#60abb0','#315f68',1)+path('M55 6l9 9','none','#9ad4cd',1.5)
body+=path('M98 14v95','none','#927458',3)+path('M91 20l7 -18 7 18 -7 -4z','url(#metal)','#415b63',1)
body+=path('M30 56l25 -3 10 9 -8 27 -13 10 -16 -13z','#366c79','#ddb774',2)+path('M33 60l19 -3 7 7 -7 22 -8 8 -12 -11z','#589ba5')+path('M43 62v20M35 72h16','none','#dbe7d3',2)
save('entities/unit.svg',body)
# Mounted sovereign; visible crown, ceremonial cloak, horse harness.
body=shadow+path('M34 77L28 104 21 111h13l9 -26M47 81l-2 26h11l3 -24M79 81l8 26h13l-7 -8 -4 -21M91 72l11 21 10 14h10l-10 -16 -7 -27','url(#wood)','#514b42',2)
body+=path('M24 62q-15 5 -10 24l7 6q-5 -16 11 -18','none','#584d3b',5)+path('M29 66Q42 54 63 60L84 59 92 37 109 39 119 58 110 69 100 64 95 80Q79 93 49 87L29 80z','url(#wood)','#614f3a',2)
body+=path('M95 39l4 -11 4 11M104 39l4 -11 4 13','url(#wood)','#5b4937')+path('M90 44l6 -6 8 2 2 11 -10 9','none','#493c32',3)+circle(109,48,1.8,'#182d2e')
body+=path('M40 65Q58 56 76 64l-4 21 -31 -3z','#386b7b','#d6ad67',2)+path('M46 65l20 3 -1 9 -18 -2z','#67a5af')+path('M89 51l-5 17 -22 -16','none','#d8bd88',1.2)
body+=path('M51 38L69 34 79 57 67 78 41 68z','#538f99','#2e5664',2)+path('M51 39l-8 27 15 4 7 -30z','#75b5b4')+path('M60 48l16 6 10 -3','none','#d4e2d0',7)+path('M64 56l9 20 -6 10 -10 -3 6 -8 -9 -14','url(#metal)','#40565d',1.5)
body+=path('M52 32V21q0 -10 10 -10t10 10v11l-10 8z','url(#metal)','#3d5a60',1.5)+path('M53 25h17v5H53z','#3c535b')
body+=path('M51 15l-2 -12 8 5 5 -7 5 7 8 -5 -3 12z','url(#gold)','#8d6c3e',1)+circle(62,10,2,'#529a9b')
body+=path('M36 43Q38 28 49 25L52 40 41 68 28 73z','#427b87','#305763',1)+path('M39 36l-7 26M44 33l-6 31','none','#83b3b0',1)
save('entities/leader.svg',body)
# timber bridge with diagonal decking, layered rails and pilings.
body=shadow+path('M8 91L84 34 120 57 46 114z','#4c4937','#39493f',2)+path('M9 83L83 29 118 52 45 107z','url(#wood)','#574837',2)
for i in range(10):
 x=12+i*7.2;y=82-i*5.2;body+=path(f'M{x} {y}l32 21','none','#5d4934',2)+path(f'M{x+2} {y-1}l31 20','none','#ddae74',.8)
for x,y in [(9,83),(34,65),(60,46),(83,29),(46,107),(72,88),(97,69),(118,52)]:
 body+=rect(x-2,y-23,5,31,'url(#wood)',1,'#554b38')+path(f'M{x-2} {y-23}l3 -2 4 3 -3 2z','#d6ba89')
body+=path('M8 68L83 13M8 77L83 22M45 91L117 38M45 100L117 47','none','#876447',4)+path('M8 67L83 12M45 90L117 37','none','#ddb780',1)
save('entities/bridge.svg',body)
body=shadow
for x in [21,41,61,81,101]:
 y=102-int((x-21)*.12);body+=path(f'M{x-4} {y}v-40l4 -8 5 8v40z','url(#wood)','#5a4c38',1.4)+path(f'M{x} {y-39}v34','none','#d4b084',.8)
body+=path('M18 72l88 -12v8L18 80z','url(#wood)','#5a4a35')+path('M18 91l88 -12v8L18 99z','url(#wood)','#5a4a35')
for x in [21,41,61,81,101]:body+=circle(x,75-int((x-21)*.12),1,'#384847')+circle(x,94-int((x-21)*.12),1,'#384847')
save('entities/fence.svg',body)
# Brand mark has no Falcom visual or name.
icon=rect(0,0,192,192,'#122d36',40)+rect(9,9,174,174,'#1c414a',34,'#4d7373')+path('M43 53L96 36l53 17v59q-10 32 -53 49 -43 -17 -53 -49z','#315b63','#cea760',4)+path('M53 59l43 -14 43 14v52q-9 25 -43 40 -34 -15 -43 -40z','#234a54')+path('M58 87l-5 -31 24 13 19 -25 19 25 24 -13 -5 31z','url(#gold)','#f0dba0',2)+rect(58,90,76,14,'url(#gold)',3)+circle(96,80,5,'#378f94')+path('M76 123l20 13 20 -13','none','#769995',3)
save('icon.svg',icon,192,192)
# Atmospheric title landscape, intentionally separate from exact simulation map.
body=rect(0,0,1600,800,'#122e3a')+'''<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#3a6972"/><stop offset=".68" stop-color="#d7cbb0"/><stop offset="1" stop-color="#9cb2a0"/></linearGradient></defs>'''+rect(0,0,1600,800,'url(#sky)')+circle(1190,180,94,'#e5dbba')
body+=path('M0 420L140 308 258 371 398 233 560 336 693 253 837 353 976 248 1132 366 1302 258 1442 346 1600 265V800H0z','#60847f')+path('M0 477L241 365 370 463 619 365 812 450 984 340 1178 443 1364 337 1600 435V800H0z','#47766d')+path('M0 590Q350 374 650 496T1600 469V800H0z','#315f55')+path('M790 460Q1050 521 912 574T998 800h-279q175 -174 126 -216t-55 -124z','#759aa0')+path('M817 482Q985 524 879 569T924 800h-66q112 -162 72 -207t-113 -111z','#92b3b1')
body+=path('M0 701Q310 509 628 591L882 800H0z','#224b41')+path('M1062 800Q1176 494 1600 469V800z','#214d43')
# ridge village and unique distant keep, detailed manually scaled existing originals.
castle=(ROOT/'entities/castle.svg').read_text().split('</defs>',1)[1].rsplit('</svg>',1)[0]
village=(ROOT/'entities/village.svg').read_text().split('</defs>',1)[1].rsplit('</svg>',1)[0]
body+=f'<g transform="translate(363 343) scale(1.8)">{castle}</g>'
for x,y,s in [(240,460,.8),(590,518,.65),(1148,555,.9),(1272,509,.6)]:body+=f'<g transform="translate({x} {y}) scale({s})">{village}</g>'
for i in range(50):
 x=r.randrange(1600);y=r.randrange(610,830);height=r.randrange(25,80)
 body+=path(f'M{x} {y}l-17 0 17 -{height} 20 {height}z','#173d37')+path(f'M{x} {y}v-{height-8}l11 {height-8}z','#2a5546')
body+=path('M270 680Q450 546 661 602','none','#7b8c66',8)+path('M990 677l130 -70','none','#b39a6c',10)+path('M991 666l130 -70','none','#655a42',3)+path('M1002 689l130 -70','none','#655a42',3)
save('title_landscape.svg',body,1600,800)
# Android icon source / prescribed safe foreground dimensions.
save('android_background.svg',rect(0,0,432,432,'#122d36'),432,432)
mark=icon.split(rect(9,9,174,174,'#1c414a',34,'#4d7373'))[-1]
save('android_foreground.svg',f'<g transform="translate(84 84) scale(1.375)">{mark}</g>',432,432)
if __name__=='__main__':
 for src,name in [('icon.svg','icon.png'),('android_background.svg','android_background.png'),('android_foreground.svg','android_foreground.png')]:
  subprocess.run(['inkscape',str(ROOT/src),'--export-type=png',f'--export-filename={ROOT/name}'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 print('Generated 14 original SVG assets and 3 PNG icons.')
