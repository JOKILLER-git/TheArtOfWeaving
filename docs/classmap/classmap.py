from common import *
from core import core_body, core_edges
import sys
mode = sys.argv[1]  # "3d" or "2d"
out = [HEAD]
app = "\n".join([
  node("GameApp","Control","app state machine: title → levels → end;<BR/>depends only on KnitLevelView" if mode=="3d" else "app state machine: title → levels → end","play_level(i)  toggle_view()" if mode=="3d" else "play_level(i)"),
  node("LevelSequence","","current level, advance, select"),
  node("ProgressStore","","load/save PlayerProgress"),
  node("AppUI","group","TitleScreen · EndScreen · YarnPull2D · YarnLoopLogo2D<BR/>ProgressBeads2D · LevelClothesline2D · LevelCard2D<BR/>LevelThumb2D · SwatchWall2D"),
])
out.append(cluster("app","app — game flow &amp; object-based UI","#eeeeee","#888888",app))
if mode=="3d":
    shared = "\n".join([
      node("KnitLevelView","abstract Control","one playable level","play()  restart()  is_completed()<BR/>signals: level_finished, next_requested"),
      node("FabricScreenMapper","abstract","fabric coords ↔ screen","to_screen()  to_fabric()  fit()"),
      node("YarnHandle","","yarn tip state","tip  held  can_grab()"),
    ])
    out.append(cluster("shared","presentation_shared — abstractions (new for 3D)","#fdf1dc","#c48a2c",shared))
p2 = [
  node("KnitLevel2D","KnitLevelView" if mode=="3d" else "Control","2D composition root of a level"),
  node("ScreenMapper2D","FabricScreenMapper" if mode=="3d" else "RefCounted","pixels ↔ fabric coords"),
  node("PointerInput2D","","mouse → fabric point → recognisers"),
  node("FabricView2D","","loops + over/under crossings<BR/>(Strand2D, StrandPainter2D)"),
  node("WorkingYarn2D","","Verlet working yarn"),
  node("Overlays","group","HintView2D · ChartCard2D · StarRatingView2D<BR/>Scissors2D · UnravelEffect2D · GestureDebugOverlay2D · SoundBank"),
]
out.append(cluster("p2","presentation_2d" + (" (overlays &amp; pointer input reused by 3D)" if mode=="3d" else ""),"#e4eef8","#3b78b0","\n".join(p2)))
if mode=="3d":
    p3 = "\n".join([
      node("KnitLevel3D","KnitLevelView","3D composition root; reuses 2D overlays"),
      node("CameraMapper3D","FabricScreenMapper","perspective camera; ray → fabric plane"),
      node("FabricView3D","","loops as tubes; z from crossing order"),
      node("WorkingYarn3D","","3D rope; z&lt;0 behind, z&gt;0 in front"),
      node("TubeMesh3D","","sweeps a tube mesh"),
    ])
    out.append(cluster("p3","presentation_3d — new","#efe8f8","#7a55b5",p3))
out.append(cluster("core","core — rules, data, gestures (unchanged 2D → 3D)","#e6f4ea","#3c8c55",core_body()))
out.append(core_edges())
e = f'''
GameApp -> LevelSequence [{HAS}];
GameApp -> ProgressStore [{HAS}];
GameApp -> AppUI [{HAS}];
ProgressStore -> PlayerProgress [{USES}];
LevelSequence -> LevelCatalog [{USES}];
KnitLevel2D -> ScreenMapper2D [{HAS}];
KnitLevel2D -> PointerInput2D [{HAS}];
KnitLevel2D -> FabricView2D [{HAS}];
KnitLevel2D -> WorkingYarn2D [{HAS}];
KnitLevel2D -> Overlays [{HAS}];
KnitLevel2D -> KnitSession [arrowhead=diamond, label=" has-a session,\\n score, gestures"];
KnitLevel2D -> GestureRecognizer [{HAS}];
PointerInput2D -> GestureRecognizer [{USES}];
FabricView2D -> StitchType [style=dashed, arrowhead=vee, label=" crossing order"];
'''
if mode=="3d":
    e += f'''
GameApp -> KnitLevelView [arrowhead=diamond, label=" has-a (2D or 3D)"];
KnitLevel2D -> KnitLevelView [{ISA}];
KnitLevel3D -> KnitLevelView [{ISA}];
ScreenMapper2D -> FabricScreenMapper [{ISA}];
CameraMapper3D -> FabricScreenMapper [{ISA}];
PointerInput2D -> FabricScreenMapper [{USES}];
PointerInput2D -> YarnHandle [{USES}];
Overlays -> FabricScreenMapper [{USES}];
WorkingYarn2D -> YarnHandle [{HAS}];
WorkingYarn3D -> YarnHandle [{HAS}];
KnitLevel3D -> CameraMapper3D [{HAS}];
KnitLevel3D -> FabricView3D [{HAS}];
KnitLevel3D -> WorkingYarn3D [{HAS}];
KnitLevel3D -> Overlays [arrowhead=diamond, label=" has-a (reused)"];
KnitLevel3D -> PointerInput2D [arrowhead=diamond, label=" has-a (reused)"];
KnitLevel3D -> KnitSession [arrowhead=diamond, label=" has-a session,\\n score, gestures"];
FabricView3D -> TubeMesh3D [{USES}];
WorkingYarn3D -> TubeMesh3D [{USES}];
FabricView3D -> StitchType [style=dashed, arrowhead=vee, label=" crossing order"];
'''
else:
    e += f'''
GameApp -> KnitLevel2D [{HAS}];
PointerInput2D -> ScreenMapper2D [{USES}];
Overlays -> ScreenMapper2D [{USES}];
'''
out.append(e)
out.append(f'''legend [shape=plaintext, style="", label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="2">
<TR><TD ALIGN="LEFT"><B>Legend</B></TD></TR>
<TR><TD ALIGN="LEFT">hollow arrow = is-a (inheritance)</TD></TR>
<TR><TD ALIGN="LEFT">diamond = has-a (owns / holds)</TD></TR>
<TR><TD ALIGN="LEFT">dashed arrow = uses / listens</TD></TR>
<TR><TD ALIGN="LEFT">green = core rules · blue = 2D · purple = 3D · amber = shared abstractions · grey = app</TD></TR>
</TABLE>>];''')
ranks = [
 ["GameApp","LevelSequence","ProgressStore","AppUI"],
 (["KnitLevelView","FabricScreenMapper","YarnHandle"] if mode=="3d" else []),
 (["KnitLevel2D","KnitLevel3D"] if mode=="3d" else ["KnitLevel2D"]),
 (["ScreenMapper2D","PointerInput2D","FabricView2D","WorkingYarn2D","Overlays","CameraMapper3D","FabricView3D","WorkingYarn3D","TubeMesh3D"] if mode=="3d" else ["ScreenMapper2D","PointerInput2D","FabricView2D","WorkingYarn2D","Overlays"]),
 ["KnitSession","GestureRecognizer","LevelScore","PlayerProgress","LevelCatalog"],
 ["Fabric","Yarn","StitchRegistry","HookResult","HookGesture","WrapGesture","StarRating","LevelDefinition"],
 ["StitchType","FabricLayout","PatternChart"],
 ["KnitStitch","PurlStitch","legend"],
]
ranks=[r for r in ranks if r]
for r in ranks: out.append("{rank=same; "+"; ".join(r)+";}")
for a,b in zip(ranks,ranks[1:]): out.append(f"{a[0]} -> {b[0]} [style=invis, weight=10];")
out.append("}")
open(f"classmap_{mode}.dot","w").write("\n".join(out))
