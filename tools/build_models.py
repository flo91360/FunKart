"""Modèles originaux FunKart : lancer avec Blender 4.x en mode background.
Les .glb sont livrés dans le dépôt ; Blender n'est requis que pour les régénérer.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)

def vec(p):
    return (p[0], -p[2], p[1])

def linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def material(name, color, rough=.48, metal=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    h = color.lstrip('#')
    c = tuple(linear(int(h[i:i+2], 16)/255) for i in (0,2,4)) + (1,)
    m.diffuse_color = c
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = c
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    return m

def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)

def empty(name, pos=(0,0,0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = vec(pos)
    return o

def finish(o, name, pos, mat, parent, rot=(0,0,0)):
    o.name = name
    o.parent = parent
    o.location = vec(pos)
    o.rotation_euler = tuple(math.radians(v) for v in (rot[0],-rot[2],rot[1]))
    o.data.materials.append(mat)
    if o.type == 'MESH':
        for p in o.data.polygons:
            p.use_smooth = True
    return o

def orb(name, pos, size, mat, parent=None, rot=(0,0,0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20)
    o=bpy.context.object
    o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,pos,mat,parent,rot)

def box(name, pos, size, mat, parent=None, bevel=.08, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object
    o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Bords arrondis','BEVEL'); mod.width=bevel; mod.segments=4
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Normales pondérées','WEIGHTED_NORMAL'); mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,pos,mat,parent,rot)

def cylinder(name,pos,radius,depth,mat,parent=None,axis='Y',bevel=.03):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth)
    o=bpy.context.object
    if bevel:
        mod=o.modifiers.new('Arrondi','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    rot={'X':(0,0,90),'Y':(0,0,0),'Z':(90,0,0)}[axis]
    return finish(o,name,pos,mat,parent,rot)

def tube(name, points, radius, mat, parent=None):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'
    curve.resolution_u=12; curve.bevel_depth=radius; curve.bevel_resolution=3
    s=curve.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for p,xyz in zip(s.bezier_points,points):
        p.co=vec(xyz); p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(obj)
    obj.parent=parent; obj.data.materials.append(mat)
    return obj

def ear(name, pos, height, width, mat, parent, tilt=0):
    # Un pavillon plein, incurvé, plutôt qu'un cône.
    coords=[(-width,0,0),(-width*.75,height*.55,0),(width*.12,height, .03),
            (width*.85,height*.47,0),(width,0,0), (0,height*.3,-.12), (0,height*.3,.12)]
    faces=[]
    for i in range(5):
        faces.append((5,i,(i+1)%5)); faces.append((6,(i+1)%5,i))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata([vec(p) for p in coords],[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    mod=o.modifiers.new('Pavillon doux','SUBSURF'); mod.levels=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,pos,mat,parent,(0,0,tilt))

def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    # Conversion des courbes pour un GLB autonome.
    for o in list(bpy.context.scene.objects):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT')
            bpy.context.view_layer.objects.active=o; o.select_set(True)
            bpy.ops.object.convert(target='MESH'); o.select_set(False)
    # Regrouper les pièces immobiles par matériau, en conservant les pivots
    # des roues, de la tête et des yeux pour les animations dans Godot.
    groups={}
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            groups.setdefault((o.parent, tuple(o.data.materials)), []).append(o)
    for objects in groups.values():
        if len(objects) < 2:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    print('MODÈLE',name,flush=True)


def kart():
    reset()
    paint=material('Paint','#E09B4B',.27,.12)
    cream=material('Ivoire','#E8DFCC',.55)
    iron=material('Châssis','#23383C',.45,.35)
    rubber=material('Pneus','#29363A',.85)
    leather=material('Cuir','#845541',.9)
    chrome=material('Métal brossé','#BECAC1',.29,.75)
    lamp=material('Verre ambré','#FFE4A3',.22)
    root=empty('Racer')
    # Coque courte et ronde d'un petit bolide d'atelier.
    box('Plancher',(0,.4,.05),(1.72,.24,2.6),iron,root,.1)
    orb('Capot',(0,.69,-.95),(.78,.42,.69),paint,root)
    box('BandeCapot',(0,1.057,-.97),(.16,.025,.72),cream,root,.012,(-8,0,0))
    for side in [-1,1]:
        box('Flanc',(side*.75,.73,.13),(.26,.52,1.5),paint,root,.12)
        tube('Arceau latéral',[(side*.92,.45,-.6),(side*.98,.52,0),(side*.92,.49,.72)],.055,chrome,root)
        for axle,z in [('Rear',.96),('Front',-.95)]:
            pivot=empty('Wheel'+axle+('L' if side<0 else 'R'),(side*.97,.46,z),root)
            cylinder('Pneu',(0,0,0),.46,.38,rubber,pivot,'X',.085)
            for out in [-1,1]:
                cylinder('Flanc crème',(out*.19,0,0),.345,.028,cream,pivot,'X',.012)
                cylinder('Jante',(out*.214,0,0),.225,.035,paint,pivot,'X',.018)
                cylinder('Moyeu',(out*.24,0,0),.084,.05,chrome,pivot,'X',.015)
                for i in range(6):
                    a=i*math.tau/6
                    cylinder('Rivet',(out*.24,math.cos(a)*.16,math.sin(a)*.16),.018,.02,chrome,pivot,'X',.003)
            # Rainures en relief pour lire la rotation.
            for i in range(16):
                a=i*math.tau/16
                box('Sculpture pneu',(0,math.cos(a)*.444,math.sin(a)*.444),(.27,.026,.045),iron,pivot,.01,(math.degrees(a),0,0))
        # Ailes indépendantes aux courbes tendues.
        tube('Aile arrière',[(side*.97,.61,.48),(side*.97,.99,.78),(side*.97,1.02,1.16),(side*.97,.63,1.45)],.14,paint,root)
        cylinder('Phare',(side*.53,.75,-1.48),.18,.16,iron,root,'Z',.03)
        cylinder('Lentille',(side*.53,.75,-1.58),.143,.025,lamp,root,'Z',.015)
        tube('Pare-chocs',[(side*.77,.4,-1.35),(side*.73,.45,-1.64),(0,.45,-1.72)],.06,chrome,root)
        box('Marchepied',(side*.91,.4,.05),(.33,.08,.62),leather,root,.035)
        cylinder('Échappement',(side*.5,.62,1.28),.105,.51,chrome,root,'Z',.01)
        cylinder('Sortie sombre',(side*.5,.62,1.54),.076,.015,iron,root,'Z',0)
    # Une calandre en laiton et son macaron.
    box('Calandre',(0,.64,-1.57),(.55,.3,.06),iron,root,.1)
    for x in [-.18,-.09,0,.09,.18]:
        box('Barreau',(x,.64,-1.61),(.018,.21,.025),chrome,root,.008)
    orb('Emblème',(0,.93,-1.49),(.09,.07,.025),cream,root)
    box('Banquette',(0,.65,.12),(1.08,.21,.92),leather,root,.1)
    box('Dossier',(0,.97,.59),(1.08,.62,.23),leather,root,.12,(-8,0,0))
    for x in [-.3,0,.3]:
        tube('Couture',[(x,.76,.44),(x,1.07,.48),(x,1.21,.51)],.008,cream,root)
    box('Coffre arrière',(0,.68,1.02),(1.08,.43,.58),paint,root,.12)
    box('Sac de voyage',(0,1.01,.99),(.8,.31,.42),leather,root,.12)
    for x in [-.25,.25]:
        box('Sangle',(x,1.17,.99),(.065,.025,.43),cream,root,.008)
    tube('Colonne volant',[(0,.59,-.42),(0,1.0,-.47)],.035,iron,root)
    # Cercle du volant dans un plan incliné vers le pilote.
    pts=[]
    for i in range(17):
        a=i*math.tau/16
        pts.append((math.cos(a)*.26,1.04+math.sin(a)*.13,-.47+math.sin(a)*.22))
    tube('Volant',pts,.035,leather,root)
    export('racer')


PALETTES={
 'chat':('#CC8D5D','#F3D5AC','#394E55'), 'chien':('#A97855','#EAD6B6','#B17B55'),
 'grenouille':('#83A36E','#DCE6A4','#668A56'), 'licorne':('#DCD2DA','#F4ECE5','#C59BAA'),
 'panda':('#E8E2D3','#E8E2D3','#374047'), 'lion':('#CDA26B','#EED2A3','#976445'),
 'singe':('#846548','#D9B889','#846548'), 'pingouin':('#34454D','#F1DDAC','#34454D'),
 'tortue':('#9EAD74','#E0D3A0','#486C58'), 'lapin':('#DCCAB4','#F1DFCB','#D6B4AE'),
 'renard':('#C4774A','#F5DABB','#71483B'), 'ours':('#886452','#BFA184','#75523F'),
 'souris':('#9CA3A0','#E2D2BD','#D8A8A2')}

def animal(kind):
    reset()
    f,m,e=PALETTES[kind]
    fur=material('Fourrure',f,.85); muzzle=material('Museau',m,.8); darkfur=material('Marquages',e,.82)
    ink=material('Yeux','#16282F',.17); white=material('Reflets','#FFF4DE',.2)
    pink=material('Oreilles intérieures','#D9A498',.8)
    outfit=material('Salopette','#355C63',.8); stitch=material('Coutures','#DCC99C',.7)
    gold=material('Laiton','#D6AA5F',.32,.65)
    root=empty('Driver')
    # Proportions de figurine : buste rond, petites pattes, tête généreuse.
    orb('Buste',(0,1.1,.08),(.39,.49,.33),fur,root)
    orb('Salopette',(0,.94,.07),(.4,.35,.34),outfit,root)
    box('Plastron',(0,1.16,-.22),(.41,.4,.095),outfit,root,.09)
    box('Poche',(0,1.12,-.278),(.23,.18,.035),outfit,root,.035)
    for side in [-1,1]:
        tube('Bretelle',[(side*.19,1.04,-.28),(side*.22,1.44,-.17),(side*.25,1.43,.12)],.045,outfit,root)
        orb('Bouton',(side*.18,1.28,-.285),(.034,.034,.02),gold,root)
        tube('Bras',[(side*.31,1.35,-.03),(side*.43,1.17,-.19),(side*.24,1.05,-.45)],.115,fur,root)
        orb('Patte',(side*.24,1.05,-.45),(.13,.115,.15),muzzle,root)
        orb('Jambe',(side*.22,.78,-.13),(.18,.2,.35),outfit,root)
        orb('Chaussure',(side*.22,.63,-.39),(.18,.13,.24),darkfur,root)
    head=empty('Head',(0,1.95,-.02),root)
    # Large front et joues qui descendent vers le petit museau.
    orb('Crâne',(0,.05,0),(.59,.55,.45),fur,head)
    orb('Joues',(0,-.15,-.07),(.54,.36,.4),fur,head)
    if kind in ('chat','renard','licorne'):
        for side in [-1,1]:
            ear('Oreille',(side*.38,.39,.015),.68 if kind=='renard' else .58,.26,darkfur if kind=='renard' else fur,head,-side*16)
            ear('Intérieur',(side*.38,.43,-.055),.45,.16,pink,head,-side*16)
    elif kind=='lapin':
        for side in [-1,1]:
            orb('Oreille',(side*.25,.8,.03),(.15,.6,.13),fur,head,(0,0,-side*12))
            orb('Intérieur',(side*.25,.81,-.075),(.077,.43,.035),pink,head,(0,0,-side*12))
    elif kind=='chien':
        for side in [-1,1]:
            orb('Oreille tombante',(side*.53,.06,.015),(.18,.47,.18),darkfur,head,(0,0,side*17))
    elif kind in ('panda','ours','lion','souris','singe'):
        for side in [-1,1]:
            r=.28 if kind=='souris' else .21
            p=(side*.48,.41 if kind!='singe' else .08,.02)
            orb('Oreille',p,(r,r,.14),darkfur,head)
            orb('Conque',(p[0],p[1],-.1),(r*.6,r*.62,.04),pink if kind=='souris' else muzzle,head)
    if kind=='lion':
        for i in range(12):
            a=i*math.tau/12
            orb('Crinière',(math.cos(a)*.58,.02+math.sin(a)*.58,.18),(.25,.28,.21),darkfur,head,(0,0,math.degrees(a)))
    if kind=='panda':
        for side in [-1,1]:
            orb('Tache',(side*.24,.1,-.385),(.19,.23,.075),darkfur,head,(0,0,side*20))
    if kind in ('singe','pingouin'):
        for side in [-1,1]:
            orb('Masque',(side*.2,.08,-.34),(.27,.34,.12),muzzle,head)
    if kind=='renard':
        for side in [-1,1]:
            orb('Favoris',(side*.34,-.19,-.26),(.26,.16,.19),muzzle,head,(0,0,side*20))
    if kind=='grenouille':
        for side in [-1,1]:
            orb('Arcade',(side*.31,.48,-.08),(.22,.24,.22),fur,head)
    # Yeux ovales brillants, enfoncés dans le visage, avec reflet et paupière.
    for side in [-1,1]:
        ex=side*(.31 if kind=='grenouille' else .23)
        ey=.48 if kind=='grenouille' else .11
        ez=-.25 if kind=='grenouille' else -.424
        eye=empty('EyeL' if side<0 else 'EyeR',(ex,ey,ez),head)
        orb('Blanc',(0,0,0),(.132,.16,.072),white,eye)
        orb('Iris',(0,-.012,-.057),(.086,.113,.04),ink,eye)
        orb('Éclat',(-.027,.038,-.088),(.027,.034,.012),white,eye)
        orb('Petit éclat',(.033,-.045,-.09),(.012,.013,.008),white,eye)
        tube('Sourcil',[(ex-side*.1,ey+.2,ez+.03),(ex,ey+.23,ez+.01),(ex+side*.09,ey+.19,ez+.04)],.025,darkfur,head)
    if kind=='pingouin':
        orb('Bec',(0,-.13,-.48),(.16,.09,.18),gold,head)
    elif kind=='grenouille':
        tube('Sourire',[(-.27,-.13,-.405),(0,-.2,-.44),(.27,-.13,-.405)],.018,darkfur,head)
    else:
        for side in [-1,1]:
            orb('Museau',(side*.11,-.18,-.4),(.21,.155,.15),muzzle,head)
        orb('Nez',(0,-.095,-.535),(.085,.06,.045),ink,head)
        tube('Bouche',[(-.11,-.24,-.51),(0,-.27,-.535),(.11,-.24,-.51)],.012,darkfur,head)
    if kind=='chat':
        for side in [-1,1]:
            for j in range(3):
                tube('Rayure',[(side*.4,.3-j*.12,-.32),(side*.47,.25-j*.12,-.28)],.018,darkfur,head)
        for j in [-1,0,1]:
            tube('Rayure front',[(j*.1,.52,-.13),(j*.12,.38,-.32)],.022,darkfur,head)
    if kind=='licorne':
        mane=material('Crinière','#B7A4BC',.7)
        for i in range(5):
            orb('Mèche',(.02,.46-i*.16,.25+i*.015),(.19,.17,.2),mane,head)
        bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.11,radius2=.015,depth=.48)
        finish(bpy.context.object,'Corne',(0,.62,-.26),gold,head,(-15,0,0))
    if kind=='tortue':
        shell=material('Carapace','#486A50',.63)
        orb('Carapace',(0,1.2,.36),(.48,.52,.24),shell,root)
        for side in [-1,1]:
            tube('Écaille',[(side*.1,.82,.52),(side*.25,1.15,.59),(side*.13,1.58,.47)],.018,stitch,root)
    if kind in ('chat','chien','renard','lion','singe','souris'):
        r=.13 if kind in ('renard','chat') else .065
        tube('Queue',[(.2,.87,.4),(.5,1,.68),(.7,1.3,.65),(.67,1.48,.49)],r,fur,root)
        if kind in ('renard','lion'):
            orb('Bout de queue',(.67,1.48,.49),(.16,.19,.14),muzzle if kind=='renard' else darkfur,root)
    if kind=='lapin': orb('Pompon',(0,.98,.44),(.2,.2,.18),muzzle,root)
    # Un petit col et une étiquette de l'atelier.
    tube('Col',[(-.21,1.52,-.14),(0,1.48,-.29),(.21,1.52,-.14)],.045,stitch,root)
    export(kind)

if __name__ == "__main__":
    kart()
    for animal_id in PALETTES:
        animal(animal_id)
