def node(name, kind, resp, members=""):
    k = f'<FONT POINT-SIZE="9" COLOR="#6b6458"><I>{kind}</I></FONT><BR/>' if kind else ''
    m = f'<BR/><FONT POINT-SIZE="9" FACE="DejaVu Sans Mono" COLOR="#444444">{members}</FONT>' if members else ''
    return f'{name} [label=<{k}<B>{name}</B><BR/><FONT POINT-SIZE="10">{resp}</FONT>{m}>];'
HEAD = '''digraph G {
graph [rankdir=TB, fontname="DejaVu Sans", fontsize=12, nodesep=0.25, ranksep=0.45, compound=true, newrank=true, bgcolor="white", pad=0.3];
node [shape=box, style="rounded,filled", fontname="DejaVu Sans", fontsize=11, margin="0.12,0.06", penwidth=0.8];
edge [fontname="DejaVu Sans", fontsize=9, color="#555555", arrowsize=0.7];
'''
def cluster(cid, label, fill, border, body):
    return f'subgraph cluster_{cid} {{ label=<<B>{label}</B>>; style="rounded,filled"; fillcolor="{fill}"; color="{border}"; fontsize=13; node [fillcolor="white", color="{border}"];\n{body}\n}}\n'
ISA = 'arrowhead=empty, style=solid, color="#333333", label=" is-a"'
HAS = 'arrowhead=diamond, arrowtail=none, dir=forward, label=" has-a"'
USES = 'style=dashed, arrowhead=vee, label=" uses"'
