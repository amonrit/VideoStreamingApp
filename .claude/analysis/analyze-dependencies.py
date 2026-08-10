#!/usr/bin/env python3
"""
Swift Dependency Analyzer
Generates dependency maps for Swift code structure
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Set, List

class SwiftDependencyAnalyzer:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.swift_files: Dict[str, Path] = {}
        self.dependencies: Dict[str, Dict] = {}
        self.frameworks: Set[str] = set()

    def find_swift_files(self):
        """Find all Swift source files (excluding build directory)"""
        exclude_dirs = {'build', '.build', 'Pods', '.swift-version', 'DerivedData'}

        for root, dirs, files in os.walk(self.project_root):
            # Remove excluded directories from search
            dirs[:] = [d for d in dirs if d not in exclude_dirs]

            for file in files:
                if file.endswith('.swift'):
                    full_path = Path(root) / file
                    # Use relative path as key
                    rel_path = full_path.relative_to(self.project_root)
                    self.swift_files[str(rel_path)] = full_path

    def extract_imports(self, file_path: Path) -> Set[str]:
        """Extract import statements from Swift file"""
        imports = set()
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Match: import FrameworkName or import Module.Submodule
                pattern = r'^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)'
                matches = re.findall(pattern, content, re.MULTILINE)
                imports.update(matches)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
        return imports

    def extract_class_references(self, file_path: Path, file_key: str) -> Set[str]:
        """Extract references to classes/structs from other local files"""
        references = set()
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

                # Remove comments
                content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

                # Known classes/structs in the project (exclude this file)
                known_types = {
                    'PlaybackViewModel': 'ViewModels/PlaybackViewModel.swift',
                    'VideoPlayerWorker': 'Workers/VideoPlayerWorker.swift',
                    'VideoStream': 'Models/VideoStream.swift',
                    'PlaybackState': 'Models/PlaybackState.swift',
                    'VideoPlayerView': 'Views/VideoPlayerView.swift',
                    'ContentView': 'Views/ContentView.swift',
                    'FullScreenPlayerView': 'Views/FullScreenPlayerView.swift',
                    'CustomVideoPlayerController': 'Views/VideoPlayerView.swift',
                    'ProgressBarView': 'Views/VideoPlayerView.swift',
                }

                for type_name, type_file in known_types.items():
                    if type_file != file_key and type_name in content:
                        references.add(type_name)

        except Exception as e:
            print(f"Error extracting references from {file_path}: {e}")

        return references

    def categorize_frameworks(self, imports: Set[str]) -> Dict[str, Set[str]]:
        """Categorize imports into categories"""
        apple_frameworks = {
            'Foundation', 'UIKit', 'SwiftUI', 'AVFoundation', 'AVKit',
            'Combine', 'os', 'CoreVideo', 'CoreMedia', 'CoreGraphics',
            'CoreFoundation', 'Darwin', 'Dispatch'
        }

        categorized = {
            'apple': set(),
            'local': set(),
            'external': set()
        }

        for imp in imports:
            if imp in apple_frameworks:
                categorized['apple'].add(imp)
            elif imp.startswith('.') or '/' in imp or imp[0].islower():
                categorized['local'].add(imp)
            else:
                categorized['external'].add(imp)

        return categorized

    def analyze(self):
        """Run full dependency analysis"""
        self.find_swift_files()

        for file_key, file_path in sorted(self.swift_files.items()):
            imports = self.extract_imports(file_path)
            references = self.extract_class_references(file_path, file_key)
            categorized = self.categorize_frameworks(imports)

            self.dependencies[file_key] = {
                'imports': {
                    'apple': sorted(list(categorized['apple'])),
                    'local': sorted(list(categorized['local'])),
                    'external': sorted(list(categorized['external']))
                },
                'references': sorted(list(references)),
                'total_imports': len(imports)
            }

            # Collect all frameworks
            self.frameworks.update(imports)

    def generate_graph_structure(self) -> Dict:
        """Generate dependency graph for visualization"""
        graph = {
            'nodes': [],
            'edges': []
        }

        node_map = {}

        # Add file nodes
        for file_key in self.dependencies.keys():
            node_id = file_key.replace('/', '_').replace('.', '_')
            node_map[file_key] = node_id

            graph['nodes'].append({
                'id': node_id,
                'label': Path(file_key).name,
                'file': file_key,
                'type': 'file'
            })

        # Add dependency edges
        for file_key, deps in self.dependencies.items():
            source_id = node_map[file_key]

            # Add edges for local references
            for ref in deps['references']:
                # Find which file contains this type
                for other_file_key, other_file_path in self.swift_files.items():
                    if other_file_key != file_key:
                        with open(other_file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            if f'class {ref}' in content or f'struct {ref}' in content:
                                target_id = node_map.get(other_file_key)
                                if target_id:
                                    graph['edges'].append({
                                        'source': source_id,
                                        'target': target_id,
                                        'label': ref,
                                        'type': 'local'
                                    })

        return graph

    def export_json(self, output_path: Path):
        """Export to JSON format"""
        analysis = {
            'timestamp': datetime.now().isoformat(),
            'project': str(self.project_root.name),
            'files_analyzed': len(self.dependencies),
            'total_frameworks': len(self.frameworks),
            'files': self.dependencies,
            'graph': self.generate_graph_structure(),
            'frameworks': {
                'apple': sorted([f for f in self.frameworks if not any(c.islower() for c in f[:3])]),
                'external': sorted([f for f in self.frameworks if f not in {
                    'Foundation', 'UIKit', 'SwiftUI', 'AVFoundation', 'AVKit',
                    'Combine', 'os', 'CoreVideo', 'CoreMedia', 'CoreGraphics',
                    'CoreFoundation', 'Darwin', 'Dispatch'
                }])
            }
        }

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, indent=2)

    def export_markdown(self, output_path: Path):
        """Export to Markdown format"""
        lines = [
            "# Swift Dependency Map",
            f"\n**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"\n**Project:** steam",
            f"\n**Files Analyzed:** {len(self.dependencies)}",
            "\n---\n",
            "## 📊 Summary\n",
            f"- **Total Swift Files:** {len(self.dependencies)}",
            f"- **Unique Frameworks:** {len(self.frameworks)}",
            f"- **Apple Frameworks:** {len([f for f in self.frameworks if f[0].isupper()])}",
            "\n---\n",
            "## 📁 File Dependencies\n"
        ]

        for file_key in sorted(self.dependencies.keys()):
            deps = self.dependencies[file_key]
            file_name = Path(file_key).name

            lines.append(f"### `{file_key}`\n")

            if deps['imports']['apple']:
                lines.append("**Apple Frameworks:**")
                for imp in deps['imports']['apple']:
                    lines.append(f"  - `{imp}`")
                lines.append("")

            if deps['references']:
                lines.append("**Local Dependencies:**")
                for ref in deps['references']:
                    lines.append(f"  - `{ref}`")
                lines.append("")

            lines.append("")

        lines.extend([
            "\n---\n",
            "## 🔗 Dependency Graph\n",
            "```\nDependency visualization stored in dependency-map.json\n```",
            "\n---\n",
            "## 🎯 Architecture Insights\n",
            "- **ViewModel Layer:** PlaybackViewModel (orchestrates player state)",
            "- **Worker Layer:** VideoPlayerWorker (handles KVO/Combine subscriptions)",
            "- **Model Layer:** VideoStream, PlaybackState (data entities)",
            "- **View Layer:** ContentView, VideoPlayerView, FullScreenPlayerView (UI)",
            "- **Entry Point:** steamApp (App delegate)",
        ])

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))

def main():
    project_root = Path('/Users/amonrit/Documents/steam/steam')
    analyzer = SwiftDependencyAnalyzer(str(project_root))

    print("🔍 Analyzing Swift dependencies...")
    analyzer.analyze()

    output_json = Path('/Users/amonrit/Documents/steam/.claude/analysis/dependency-map.json')
    output_md = Path('/Users/amonrit/Documents/steam/.claude/analysis/dependency-map.md')

    print(f"📝 Exporting to JSON: {output_json}")
    analyzer.export_json(output_json)

    print(f"📝 Exporting to Markdown: {output_md}")
    analyzer.export_markdown(output_md)

    # Generate visualizations
    print("🎨 Generating visualizations...")
    try:
        # Import dynamically due to hyphenated filename
        import sys
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "visualize",
            Path('/Users/amonrit/Documents/steam/.claude/analysis/visualize-dependencies.py')
        )
        visualize = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(visualize)
        visualizer = visualize.DependencyVisualizer('/Users/amonrit/Documents/steam/.claude/analysis')
        visualizer.generate_all()
    except Exception as e:
        print(f"⚠️  Visualization generation failed: {e}")

    print("✅ Analysis complete!")

if __name__ == '__main__':
    main()
