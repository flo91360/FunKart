"""Accessoires sculptés du village, regroupés par matériau pour le rendu."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from build_models import *


def soft(name,pos,size,mat,parent=None,rot=(0,0,0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10)
    o=bpy.context.object; o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,pos,mat,parent,rot)


def packed(name):
    for o in list(bpy.context.scene.objects):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT')
            o.select_set(True); bpy.context.view_layer.objects.active=o
            bpy.ops.object.convert(target='MESH')
    groups={}
    for o in bpy.context.scene.objects:
        if o.type=='MESH':groups.setdefault(o.data.materials[0].name,[]).append(o)
    for material_name,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=material_name
    export(name)


def house():
    reset()
    bark=material('Écorce','#6B5140',.92)
    groove=material('Veines','#543E35',.95)
    frame=material('Bois coupé','#B89A6B',.8)
    green=material('Feuilles','#426D5B',.85)
    green2=material('Feuilles claires','#61816B',.85)
    blue=material('Porte','#345B59',.7)
    glass=material('Fenêtres','#F2CC8C',.3)
    gold=material('Laiton','#B7A06B',.38,.3)
    root=empty('Workshop')
    # Tronc ovale et racines intégrées visuellement, veines dessinées à la main.
    soft('Tronc',(0,3.5,0),(2.4,4.0,2.25),bark,root)
    for i in range(12):
        a=i*math.tau/12
        p=lambda r,y:(math.cos(a)*r,y,math.sin(a)*r)
        tube('Racine',[p(1.5,2),p(2.0,.8),p(3.3,.12)],.27,bark,root)
        tube('Veine',[p(2.19,1.6),p(2.34,3.4),p(2.11,5.6),p(1.8,6.4)],.045,groove,root)
    cylinder('Terrasse',(0,.12,0),3.2,.24,frame,root,bevel=.1)
    # Porte arquée, tournée vers -Z.
    box('Porte',(0,1.3,-2.18),(1.38,2.2,.2),blue,root,.42)
    for x in [-.43,-.21,0,.21,.43]:
        tube('Planches',[(x,.38,-2.30),(x,1.5,-2.30),(x,2.15,-2.26)],.012,frame,root)
    tube('Encadrement',[(-.84,.2,-2.2),(-.84,1.8,-2.2),(-.57,2.6,-2.1),(0,2.75,-2.09),(.57,2.6,-2.1),(.84,1.8,-2.2),(.84,.2,-2.2)],.105,frame,root)
    orb('Poignée',(.44,1.2,-2.35),(.075,.075,.05),gold,root)
    for x in [-1.2,1.2]:
        cylinder('Fenêtre',(x,4.05,-1.95),.61,.15,glass,root,'Z',.02)
        ring=[]
        for i in range(17):
            a=i*math.tau/16;ring.append((x+math.cos(a)*.65,4.05+math.sin(a)*.65,-2.055))
        tube('Cadre',ring,.08,frame,root)
        box('Croisée',(x,4.05,-2.13),(1.12,.07,.08),frame,root,.025)
        box('Croisée',(x,4.05,-2.13),(.07,1.12,.08),frame,root,.025)
        box('Rebord',(x,3.32,-2.12),(1.5,.17,.5),frame,root,.06)
    # Tuiles en feuilles charnues, quatre rangées qui se chevauchent.
    for tier in range(4):
        radius=3.0-tier*.62
        for i in range(10):
            a=i*math.tau/10+tier*.21
            soft('Tuile feuille',(math.sin(a)*radius*.73,6.3+tier*.72,math.cos(a)*radius*.73),(.78,.27,1.85-tier*.24),green if (i+tier)%3 else green2,root,(0,math.degrees(a),0))
    soft('Faîte',(0,8.6,0),(.45,.35,.55),green2,root)
    box('Enseigne',(0,3.18,-2.56),(1.4,.43,.13),frame,root,.1)
    for x in [-.44,.44]:tube('Chaînette',[(x,3.4,-2.55),(x,3.62,-2.3)],.018,gold,root)
    packed('workshop')


def oak():
    reset()
    bark=material('Écorce','#735744',.9)
    dark=material('Fente','#594436',.9)
    leaves=[material('Feuillage'+str(i),c,.9) for i,c in enumerate(['#3D6458','#567866','#6D886C'])]
    root=empty('Oak')
    tube('Tronc',[(0,0,0),(.15,3.2,0),(-.25,6.6,.3),(0,8,.1)],.64,bark,root)
    for i in range(6):
        a=i*math.tau/6
        tube('Racine',[(0,1.3,0),(math.cos(a),.35,math.sin(a)),(math.cos(a)*1.8,.08,math.sin(a)*1.8)],.23,bark,root)
        tube('Branche',[(0,4.7,0),(math.cos(a)*1.5,6.5,math.sin(a)*1.5),(math.cos(a)*2.7,7.5,math.sin(a)*2.7)],.2,bark,root)
        for j in range(2):
            soft('Couronne',(math.cos(a)*(2.2-j),7.8+j*1.8,math.sin(a)*(2.2-j)),(2.4-j*.3,1.55,2.15-j*.2),leaves[(i+j)%3],root,(0,i*29,0))
    packed('oak')


def mushroom():
    reset();stem=material('Pied','#DCCCB1',.9);cap=material('Chapeau','#BB865C',.7);spot=material('Taches','#EBD4AA',.8)
    root=empty('Mushroom')
    tube('Pied',[(0,0,0),(.06,.5,0),(-.03,1.1,0)],.2,stem,root)
    soft('Chapeau',(0,1.18,0),(.85,.36,.8),cap,root)
    soft('Dessous',(0,1.1,0),(.69,.12,.66),stem,root)
    for i in range(7):
        a=i*math.tau/7;r=.34 if i%2 else .54
        soft('Tache',(math.cos(a)*r,1.41 if i%2 else 1.37,math.sin(a)*r),(.1,.03,.11),spot,root)
    packed('mushroom')

house();oak();mushroom()
