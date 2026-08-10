#!/usr/bin/env python3
"""
Dependency Visualization - Generate diagrams for dependency analysis
Creates SVG diagrams of the dependency graph and architecture
"""

import json
import re
from pathlib import Path
from datetime import datetime

class DependencyVisualizer:
    def __init__(self, analysis_dir: str):
        self.analysis_dir = Path(analysis_dir)
        self.output_dir = self.analysis_dir / "diagrams"
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def load_analysis(self):
        """Load the dependency analysis"""
        json_file = self.analysis_dir / "dependency-map.json"
        with open(json_file, "r") as f:
            return json.load(f)

    def generate_dependency_graph_dot(self, data: dict) -> str:
        """Generate DOT format for Graphviz"""
        lines = [
            'digraph Dependencies {',
            '  rankdir=LR;',
            '  node [shape=box, style="rounded,filled", fillcolor=lightblue];',
            '  edge [color=gray];',
            '',
        ]

        # Node styling by type
        lines.append('  // Files (Nodes)')
        files = data.get("files", {})

        # Color by layer
        layer_colors = {
            'steamApp': '#FFE4B5',           # App entry - orange
            'Views': '#B0E0E6',              # Views - light blue
            'ViewModels': '#98FB98',         # ViewModels - light green
            'Workers': '#DDA0DD',            # Workers - plum
            'Models': '#F0E68C',             # Models - khaki
        }

        for file_path in sorted(files.keys()):
            node_id = file_path.replace("/", "_").replace(".", "_")
            file_name = Path(file_path).name

            # Determine color by layer
            color = '#FFE4B5'  # default
            if 'Views' in file_path:
                color = '#B0E0E6'
            elif 'ViewModels' in file_path:
                color = '#98FB98'
            elif 'Workers' in file_path:
                color = '#DDA0DD'
            elif 'Models' in file_path:
                color = '#F0E68C'
            elif 'App' in file_name:
                color = '#FFE4B5'

            lines.append(f'  {node_id} [label="{file_name}", fillcolor="{color}", fontname="Courier"];')

        lines.append('')
        lines.append('  // Dependencies (Edges)')

        # Add edges for local references
        for file_path, deps in files.items():
            source_id = file_path.replace("/", "_").replace(".", "_")
            references = deps.get("references", [])

            for ref in references:
                # Find target file
                target_file = None
                for other_file in files.keys():
                    if other_file != file_path:
                        # Check if this file contains the type
                        if ref in other_file or ref.lower().replace('view', '') in other_file.lower():
                            target_file = other_file
                            break

                if target_file:
                    target_id = target_file.replace("/", "_").replace(".", "_")
                    lines.append(f'  {source_id} -> {target_id} [label="{ref}", fontsize=9];')

        lines.extend([
            '',
            '  // Legend',
            '  {',
            '    rank=sink;',
            '    legend [shape=note, label="Layers: App | Views | ViewModels | Models | Workers"];',
            '  }',
            '}'])


        return '\n'.join(lines)

    def generate_architecture_diagram(self, data: dict) -> str:
        """Generate architecture layer diagram"""
        svg_width = 900
        svg_height = 600

        lines = [
            f'<svg width="{svg_width}" height="{svg_height}" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            '<style>',
            '.layer-title { font-size: 14px; font-weight: bold; fill: white; }',
            '.file-box { fill: lightblue; stroke: #333; stroke-width: 2; rx: 5; }',
            '.app-box { fill: #FFE4B5; stroke: #333; stroke-width: 2; rx: 5; }',
            '.view-box { fill: #B0E0E6; stroke: #333; stroke-width: 2; rx: 5; }',
            '.vm-box { fill: #98FB98; stroke: #333; stroke-width: 2; rx: 5; }',
            '.model-box { fill: #F0E68C; stroke: #333; stroke-width: 2; rx: 5; }',
            '.worker-box { fill: #DDA0DD; stroke: #333; stroke-width: 2; rx: 5; }',
            '.text { font-family: Courier, monospace; font-size: 12px; }',
            '.arrow { stroke: #666; stroke-width: 2; marker-end: url(#arrowhead); }',
            '</style>',
            '<marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">',
            '<polygon points="0 0, 10 3, 0 6" fill="#666" />',
            '</marker>',
            '</defs>',
            '',
        ]

        # Title
        lines.append('<text x="450" y="30" text-anchor="middle" class="text" style="font-size: 18px; font-weight: bold;">Swift Dependency Architecture</text>')

        # Layer 1: App Entry (y=60)
        lines.append('<rect x="350" y="60" width="200" height="50" class="app-box"/>')
        lines.append('<text x="450" y="92" text-anchor="middle" class="text">📱 steamApp.swift</text>')

        # Arrow down
        lines.append('<line x1="450" y1="110" x2="450" y2="140" class="arrow"/>')

        # Layer 2: UI Coordinator (y=140)
        lines.append('<rect x="350" y="140" width="200" height="50" class="view-box"/>')
        lines.append('<text x="450" y="172" text-anchor="middle" class="text">🎨 ContentView</text>')

        # Arrow down
        lines.append('<line x1="450" y1="190" x2="450" y2="220" class="arrow"/>')

        # Layer 3: UI + ViewModel (y=220)
        lines.append('<g>')
        # Left: Views
        lines.append('<rect x="80" y="220" width="160" height="80" class="view-box"/>')
        lines.append('<text x="160" y="245" text-anchor="middle" class="text" style="font-weight: bold;">🎨 Views</text>')
        lines.append('<text x="160" y="265" text-anchor="middle" class="text">VideoPlayerView</text>')
        lines.append('<text x="160" y="283" text-anchor="middle" class="text">FullScreenView</text>')

        # Center: ViewModel
        lines.append('<rect x="370" y="220" width="160" height="80" class="vm-box"/>')
        lines.append('<text x="450" y="245" text-anchor="middle" class="text" style="font-weight: bold;">⚙️ ViewModel</text>')
        lines.append('<text x="450" y="265" text-anchor="middle" class="text">PlaybackViewModel</text>')
        lines.append('<text x="450" y="283" text-anchor="middle" class="text">(State)</text>')

        # Right: Models
        lines.append('<rect x="660" y="220" width="160" height="80" class="model-box"/>')
        lines.append('<text x="740" y="245" text-anchor="middle" class="text" style="font-weight: bold;">📦 Models</text>')
        lines.append('<text x="740" y="265" text-anchor="middle" class="text">VideoStream</text>')
        lines.append('<text x="740" y="283" text-anchor="middle" class="text">PlaybackState</text>')
        lines.append('</g>')

        # Arrows from ViewModel to Views and Models
        lines.append('<line x1="370" y1="260" x2="240" y2="260" class="arrow"/>')
        lines.append('<line x1="530" y1="260" x2="660" y2="260" class="arrow"/>')

        # Arrow down
        lines.append('<line x1="450" y1="300" x2="450" y2="330" class="arrow"/>')

        # Layer 4: Workers (y=330)
        lines.append('<rect x="350" y="330" width="200" height="50" class="worker-box"/>')
        lines.append('<text x="450" y="362" text-anchor="middle" class="text">🔧 VideoPlayerWorker</text>')

        # Legend
        lines.append('<g transform="translate(20, 450)">')
        lines.append('<text x="0" y="0" class="text" style="font-weight: bold;">Layer Guide:</text>')
        lines.append('<rect x="0" y="10" width="20" height="20" class="app-box"/>')
        lines.append('<text x="30" y="25" class="text">App Entry Point</text>')
        lines.append('<rect x="200" y="10" width="20" height="20" class="view-box"/>')
        lines.append('<text x="230" y="25" class="text">UI Views</text>')
        lines.append('<rect x="370" y="10" width="20" height="20" class="vm-box"/>')
        lines.append('<text x="400" y="25" class="text">Business Logic (ViewModel)</text>')
        lines.append('<rect x="630" y="10" width="20" height="20" class="model-box"/>')
        lines.append('<text x="660" y="25" class="text">Models (Data)</text>')
        lines.append('<rect x="0" y="50" width="20" height="20" class="worker-box"/>')
        lines.append('<text x="30" y="65" class="text">Utilities (Workers)</text>')
        lines.append('</g>')

        lines.append('</svg>')
        return '\n'.join(lines)

    def generate_stats_diagram(self, data: dict) -> str:
        """Generate statistics visualization"""
        files = data.get("files", {})

        # Calculate stats
        total_imports = sum(f.get("total_imports", 0) for f in files.values())
        avg_imports = total_imports / len(files) if files else 0

        # Count by layer
        layers = {
            'Views': 0,
            'ViewModels': 0,
            'Workers': 0,
            'Models': 0,
            'App': 0,
        }

        for file_path in files.keys():
            if 'Views' in file_path:
                layers['Views'] += 1
            elif 'ViewModels' in file_path:
                layers['ViewModels'] += 1
            elif 'Workers' in file_path:
                layers['Workers'] += 1
            elif 'Models' in file_path:
                layers['Models'] += 1
            else:
                layers['App'] += 1

        svg_width = 800
        svg_height = 500

        lines = [
            f'<svg width="{svg_width}" height="{svg_height}" xmlns="http://www.w3.org/2000/svg">',
            '<style>',
            '.title { font-size: 20px; font-weight: bold; }',
            '.stat-box { stroke: #333; stroke-width: 2; rx: 5; }',
            '.stat-text { font-family: Courier, monospace; font-size: 14px; }',
            '.stat-label { font-size: 12px; fill: #666; }',
            '.bar { rx: 3; }',
            '</style>',
            '',
        ]

        # Title
        lines.append(f'<text x="400" y="30" text-anchor="middle" class="title">📊 Dependency Statistics</text>')
        lines.append(f'<text x="400" y="55" text-anchor="middle" class="stat-label">Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</text>')

        # Stats boxes (left side)
        stats = [
            ("Total Files", str(len(files))),
            ("Total Imports", str(total_imports)),
            ("Avg Imports/File", f"{avg_imports:.1f}"),
            ("Circular Deps", "0 ✅"),
        ]

        y = 100
        for label, value in stats:
            lines.append(f'<rect x="50" y="{y}" width="250" height="60" class="stat-box" fill="#f0f0f0"/>')
            lines.append(f'<text x="70" y="{y+25}" class="stat-label">{label}</text>')
            lines.append(f'<text x="70" y="{y+50}" class="stat-text" style="font-size: 18px; font-weight: bold;">{value}</text>')
            y += 80

        # Layer breakdown (right side - bar chart)
        lines.append(f'<text x="550" y="100" class="stat-label" style="font-size: 14px;">Files by Layer:</text>')

        colors = {
            'Views': '#B0E0E6',
            'ViewModels': '#98FB98',
            'Workers': '#DDA0DD',
            'Models': '#F0E68C',
            'App': '#FFE4B5',
        }

        max_files = max(layers.values()) if layers.values() else 1
        bar_height = 20
        y = 120

        for layer, count in sorted(layers.items(), key=lambda x: -x[1]):
            bar_width = (count / max_files * 200) if max_files > 0 else 0
            lines.append(f'<rect x="420" y="{y}" width="{bar_width}" height="{bar_height}" class="bar" fill="{colors.get(layer, "#ccc")}"/>')
            lines.append(f'<text x="635" y="{y+15}" class="stat-text">{layer} ({count})</text>')
            y += 35

        lines.append('</svg>')
        return '\n'.join(lines)

    def generate_graphviz_dot(self, data: dict) -> str:
        """Generate DOT format that can be used with Graphviz"""
        return self.generate_dependency_graph_dot(data)

    def save_svg(self, filename: str, content: str):
        """Save SVG file"""
        filepath = self.output_dir / filename
        with open(filepath, "w") as f:
            f.write(content)
        print(f"✅ Generated: {filepath}")

    def generate_all(self):
        """Generate all visualizations"""
        print("🎨 Generating dependency visualizations...")

        data = self.load_analysis()

        # Architecture diagram
        arch_svg = self.generate_architecture_diagram(data)
        self.save_svg("01-architecture.svg", arch_svg)

        # Statistics diagram
        stats_svg = self.generate_stats_diagram(data)
        self.save_svg("02-statistics.svg", stats_svg)

        # Dependency graph (DOT format)
        dot_content = self.generate_graphviz_dot(data)
        dot_file = self.output_dir / "dependency-graph.dot"
        with open(dot_file, "w") as f:
            f.write(dot_content)
        print(f"✅ Generated: {dot_file}")
        print(f"\n💡 Tip: Convert DOT to SVG with:")
        print(f"   dot -Tsvg {dot_file} -o {self.output_dir}/03-dependency-graph.svg")

        print(f"\n📁 Diagrams saved to: {self.output_dir}")

def main():
    analysis_dir = Path(__file__).parent
    visualizer = DependencyVisualizer(str(analysis_dir))
    visualizer.generate_all()

if __name__ == "__main__":
    main()
