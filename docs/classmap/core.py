from common import *
def core_body():
    return "\n".join([
      node("StitchType","abstract","stitch: id, symbol,<BR/>required yarn side, crossing order","required_side()  new_loop_in_front()"),
      node("KnitStitch","","yarn behind → V"),
      node("PurlStitch","","yarn in front → bump"),
      node("StitchRegistry","","lookup; side → stitch","by_id()  for_side()"),
      node("Yarn","","working yarn side","side  toggle()"),
      node("Fabric","","grid of finished stitches","place()  stitch_at()"),
      node("KnitSession","","rule state machine of one level;<BR/>handles invalid actions","try_hook()  toggle_yarn()  cut()<BR/>signals: stitch_made, level_completed…"),
      node("HookResult","","ACCEPTED / WRONG_SIDE /<BR/>NOT_NEXT / LEVEL_DONE / BLOCKED"),
      node("FabricLayout","","geometry in fabric coords","eye()  anchor()  loop_keys()"),
      node("GestureRecognizer","abstract","pointer path in fabric coords","feed(point)  reset()"),
      node("HookGesture","","upward through eye → hook","hook_requested(col)"),
      node("WrapGesture","","winding around anchor → wrap","wrap_completed  blocks_hook()"),
      node("LevelDefinition","Resource","one level: chart, star limits,<BR/>optional preset rows"),
      node("PatternChart","Resource","target stitches per row","stitch_at(row, col)"),
      node("LevelCatalog","Resource","level order"),
      node("LevelScore","","counts mistakes (WRONG_SIDE)"),
      node("StarRating","","mistakes → 1–3 stars"),
      node("PlayerProgress","","best stars per level","record()  best()"),
      '{rank=same; KnitStitch; PurlStitch;}',
    ])
def core_edges():
    return f'''
KnitStitch -> StitchType [{ISA}];
PurlStitch -> StitchType [{ISA}];
HookGesture -> GestureRecognizer [{ISA}];
WrapGesture -> GestureRecognizer [{ISA}];
KnitSession -> Fabric [{HAS}];
KnitSession -> Yarn [{HAS}];
KnitSession -> StitchRegistry [{HAS}];
KnitSession -> PatternChart [{USES}];
KnitSession -> HookResult [style=dashed, arrowhead=vee, label=" returns"];
StitchRegistry -> StitchType [{HAS}];
LevelCatalog -> LevelDefinition [{HAS}];
LevelDefinition -> PatternChart [{HAS}];
HookGesture -> WrapGesture [style=dashed, arrowhead=vee, label=" guard"];
HookGesture -> FabricLayout [{USES}];
WrapGesture -> FabricLayout [{USES}];
FabricLayout -> KnitSession [{USES}];
LevelScore -> KnitSession [style=dashed, arrowhead=vee, label=" listens"];
LevelScore -> StarRating [{HAS}];
'''
