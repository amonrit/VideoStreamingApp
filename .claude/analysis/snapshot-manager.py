#!/usr/bin/env python3
"""
Snapshot Manager - Track dependency changes across commits
"""

import json
import sys
from pathlib import Path
from datetime import datetime
import subprocess

class SnapshotManager:
    def __init__(self, analysis_dir: str):
        self.analysis_dir = Path(analysis_dir)
        self.history_dir = self.analysis_dir / "history"
        self.history_dir.mkdir(parents=True, exist_ok=True)

    def get_current_git_info(self):
        """Get current git commit info"""
        try:
            commit_hash = subprocess.check_output(
                ["git", "rev-parse", "--short", "HEAD"],
                cwd=self.analysis_dir.parent.parent,
                text=True
            ).strip()
            return commit_hash
        except:
            return "unknown"

    def save_snapshot(self, analysis_data: dict, commit_hash: str = None):
        """Save a snapshot with git metadata"""
        if commit_hash is None:
            commit_hash = self.get_current_git_info()

        # Add git metadata
        analysis_data["metadata"] = {
            "snapshot_timestamp": datetime.now().isoformat(),
            "git_commit": commit_hash,
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        snapshot_file = self.history_dir / f"{commit_hash}.json"
        with open(snapshot_file, "w") as f:
            json.dump(analysis_data, f, indent=2)

        print(f"✅ Snapshot saved: {snapshot_file}")
        return snapshot_file

    def load_snapshot(self, commit_hash: str):
        """Load a snapshot for a specific commit"""
        snapshot_file = self.history_dir / f"{commit_hash}.json"
        if not snapshot_file.exists():
            raise FileNotFoundError(f"Snapshot not found: {snapshot_file}")

        with open(snapshot_file, "r") as f:
            return json.load(f)

    def compare_snapshots(self, commit1: str, commit2: str = None):
        """Compare two snapshots and show what changed"""
        if commit2 is None:
            commit2 = self.get_current_git_info()

        snap1 = self.load_snapshot(commit1)
        snap2 = self.load_snapshot(commit2)

        print(f"\n📊 Comparing {commit1} → {commit2}\n")
        print("=" * 60)

        # Compare file count
        files1 = set(snap1.get("files", {}).keys())
        files2 = set(snap2.get("files", {}).keys())

        new_files = files2 - files1
        removed_files = files1 - files2
        changed_files = files1 & files2

        if new_files:
            print(f"\n✨ New Files ({len(new_files)}):")
            for f in sorted(new_files):
                print(f"  + {f}")

        if removed_files:
            print(f"\n❌ Removed Files ({len(removed_files)}):")
            for f in sorted(removed_files):
                print(f"  - {f}")

        if changed_files:
            print(f"\n⚠️  Modified Files ({len(changed_files)}):")
            for f in sorted(changed_files):
                deps1 = snap1["files"][f]
                deps2 = snap2["files"][f]

                imports1 = set(
                    deps1.get("imports", {}).get("apple", []) +
                    deps1.get("imports", {}).get("local", []) +
                    deps1.get("imports", {}).get("external", [])
                )
                imports2 = set(
                    deps2.get("imports", {}).get("apple", []) +
                    deps2.get("imports", {}).get("local", []) +
                    deps2.get("imports", {}).get("external", [])
                )

                new_imports = imports2 - imports1
                removed_imports = imports1 - imports2

                if new_imports or removed_imports:
                    print(f"\n  {f}:")
                    if new_imports:
                        for imp in sorted(new_imports):
                            print(f"    ➕ {imp}")
                    if removed_imports:
                        for imp in sorted(removed_imports):
                            print(f"    ➖ {imp}")

        print("\n" + "=" * 60)

    def list_snapshots(self):
        """List all available snapshots"""
        snapshots = sorted(self.history_dir.glob("*.json"))

        if not snapshots:
            print("No snapshots found.")
            return

        print("\n📋 Available Snapshots:\n")
        for snap_file in snapshots:
            with open(snap_file, "r") as f:
                data = json.load(f)
                meta = data.get("metadata", {})
                commit = meta.get("git_commit", snap_file.stem)
                date = meta.get("created_at", "unknown")
                file_count = len(data.get("files", {}))
                print(f"  {commit:12} | {date:19} | {file_count} files")

def main():
    analysis_dir = Path(__file__).parent

    manager = SnapshotManager(str(analysis_dir))

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "list":
            manager.list_snapshots()

        elif command == "compare":
            if len(sys.argv) < 3:
                print("Usage: python3 snapshot-manager.py compare <commit1> [commit2]")
                sys.exit(1)
            commit1 = sys.argv[2]
            commit2 = sys.argv[3] if len(sys.argv) > 3 else None
            manager.compare_snapshots(commit1, commit2)

        elif command == "save":
            # Read from stdin (used by pre-commit hook)
            analysis_data = json.loads(sys.stdin.read())
            manager.save_snapshot(analysis_data)

        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
    else:
        # No command - just list snapshots
        manager.list_snapshots()

if __name__ == "__main__":
    main()
