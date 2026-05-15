import networkx as nx
import matplotlib.pyplot as plt

# 1. 定义网络拓扑与权重 (边代表活动，数字代表天数)
edges = [
    ('A', 'B', 1), ('A', 'C', 7), ('A', 'D', 10), ('A', 'E', 2), ('A', 'F', 4),
    ('B', 'G', 5), ('C', 'G', 2), ('D', 'G', 4), ('D', 'H', 5),
    ('E', 'H', 6), ('F', 'H', 7),
    ('H', 'G', 1), ('G', 'I', 3), ('G', 'J', 9),
    ('H', 'L', 9), ('H', 'M', 3),
    ('I', 'O', 10), ('J', 'K', 5), ('K', 'O', 2),
    ('L', 'N', 4), ('M', 'N', 7),
    ('N', 'O', 10), ('N', 'Q', 4),
    ('O', 'P', 9), ('Q', 'P', 2)
]

G = nx.DiGraph()
for u, v, d in edges:
    G.add_edge(u, v, duration=d)

# 2. 前向推算 (Earliest Times)
nodes_sorted = list(nx.topological_sort(G))
et = {node: 0 for node in G.nodes()}
for u in nodes_sorted:
    for v in G.successors(u):
        et[v] = max(et[v], et[u] + G[u][v]['duration'])

# 3. 逆向推算 (Latest Times)
total_len = et[nodes_sorted[-1]]
lt = {node: total_len for node in G.nodes()}
for u in reversed(nodes_sorted):
    for v in G.predecessors(u):
        lt[v] = min(lt[v], lt[u] - G[v][u]['duration'])

# 4. 计算活动参数与关键路径
critical_edges = []
for u, v, d in G.edges(data=True):
    dur = d['duration']
    es = et[u]
    ls = lt[v] - dur
    tf = ls - es
    if tf == 0: critical_edges.append((u, v))

# 5. 可视化布局
pos = {
    'A': (0, 0), 'B': (2, 4), 'C': (2, 2), 'D': (2, 0), 'E': (2, -2), 'F': (2, -4),
    'G': (5, 3), 'H': (5, -3), 'I': (7, 4), 'J': (7, 2), 'L': (8, -1), 'M': (8, -4),
    'K': (9, 2), 'N': (11, -3), 'O': (13, 2), 'Q': (14, -2), 'P': (16, 2)
}

plt.figure(figsize=(15, 7))
nx.draw_networkx_nodes(G, pos, node_size=1000, node_color='white', edgecolors='black')
nx.draw_networkx_labels(G, pos, font_size=12, font_weight='bold')
nx.draw_networkx_edges(G, pos, edgelist=[e for e in G.edges() if e not in critical_edges], width=1.5, alpha=0.5)
nx.draw_networkx_edges(G, pos, edgelist=critical_edges, width=3, edge_color='red', arrowsize=20)

# 标注活动信息
edge_labels = {}
for u, v, d in G.edges(data=True):
    dur, es, ls = d['duration'], et[u], lt[v] - d['duration']
    edge_labels[(u, v)] = f"{dur}\n(ES:{es},LS:{ls},TF:{ls-es})"

nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_size=8, label_pos=0.4)
plt.title(f"Software Development Project Critical Path Analysis (Total Length: {total_len})", size=14)
plt.axis('off')
plt.show()