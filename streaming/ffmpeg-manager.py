#!/usr/bin/env python3
"""
Phase 3: FFmpeg Manager Service
Manages start/stop of FFmpeg transcoding processes with logging.
Runs inside the ffmpeg-transcoder container.

Usage:
  python3 ffmpeg-manager.py start <stream_name>
  python3 ffmpeg-manager.py stop <stream_name>
  python3 ffmpeg-manager.py status
"""

import subprocess
import os
import sys
import logging
from datetime import datetime
from pathlib import Path
import json
import signal

# Setup logging
LOG_DIR = Path("/logs")
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    filename=str(LOG_DIR / "ffmpeg-manager.log"),
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Also log to console
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console.setFormatter(formatter)
logging.getLogger('').addHandler(console)

logger = logging.getLogger(__name__)

# Track active processes
PROCESSES_FILE = LOG_DIR / "ffmpeg-processes.json"


def load_processes():
    """Load active processes from file"""
    if PROCESSES_FILE.exists():
        try:
            with open(PROCESSES_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Failed to load processes file: {e}")
    return {}


def save_processes(processes):
    """Save active processes to file"""
    try:
        with open(PROCESSES_FILE, 'w') as f:
            json.dump(processes, f, indent=2)
    except Exception as e:
        logger.error(f"Failed to save processes file: {e}")


def start_transcoding(stream_name):
    """Start FFmpeg transcoding for a stream"""
    try:
        logger.info(f"🎬 Starting transcoding for: {stream_name}")

        # Check if already running
        processes = load_processes()
        if stream_name in processes and processes[stream_name]['pid']:
            try:
                os.kill(processes[stream_name]['pid'], 0)  # Check if process exists
                logger.warning(f"⚠️  Transcoding already running for: {stream_name} (PID: {processes[stream_name]['pid']})")
                return
            except OSError:
                pass  # Process is dead, continue

        # Start new process
        script_path = "/ffmpeg-config/ffmpeg-transcode.sh"
        if not os.path.exists(script_path):
            logger.error(f"❌ Script not found: {script_path}")
            return

        # Make script executable
        os.chmod(script_path, 0o755)

        # Start transcoding process
        process = subprocess.Popen(
            [script_path, stream_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True  # Create new session for signal handling
        )

        # Save process info
        processes = load_processes()
        processes[stream_name] = {
            'pid': process.pid,
            'started_at': datetime.now().isoformat(),
            'status': 'running'
        }
        save_processes(processes)

        logger.info(f"✅ Started transcoding: {stream_name} (PID: {process.pid})")

    except Exception as e:
        logger.error(f"❌ Failed to start transcoding: {stream_name} - {str(e)}")


def stop_transcoding(stream_name):
    """Stop FFmpeg transcoding for a stream"""
    try:
        logger.info(f"🛑 Stopping transcoding for: {stream_name}")

        processes = load_processes()
        if stream_name not in processes:
            logger.warning(f"⚠️  No process found for: {stream_name}")
            return

        pid = processes[stream_name].get('pid')
        if not pid:
            logger.warning(f"⚠️  No PID found for: {stream_name}")
            return

        try:
            # Try graceful termination first
            os.killpg(os.getpgid(pid), signal.SIGTERM)
            logger.info(f"✅ Stopped transcoding: {stream_name} (PID: {pid})")
        except ProcessLookupError:
            logger.warning(f"⚠️  Process not found (may have already terminated): {stream_name}")
        except Exception as e:
            logger.error(f"❌ Error stopping process: {stream_name} - {str(e)}")
            # Try force kill as fallback
            try:
                os.killpg(os.getpgid(pid), signal.SIGKILL)
                logger.info(f"✅ Force killed: {stream_name}")
            except:
                pass

        # Update process status
        processes[stream_name]['status'] = 'stopped'
        processes[stream_name]['stopped_at'] = datetime.now().isoformat()
        save_processes(processes)

    except Exception as e:
        logger.error(f"❌ Failed to stop transcoding: {stream_name} - {str(e)}")


def get_status():
    """Get status of all transcoding processes"""
    try:
        processes = load_processes()
        if not processes:
            logger.info("No active transcoding processes")
            print("No active transcoding processes")
            return

        print("\n📊 FFmpeg Transcoding Status:")
        print("-" * 60)

        for stream_name, info in processes.items():
            pid = info.get('pid')
            status = info.get('status', 'unknown')
            started_at = info.get('started_at', 'unknown')

            # Check if process is actually running
            is_running = False
            if pid:
                try:
                    os.kill(pid, 0)
                    is_running = True
                except OSError:
                    is_running = False

            actual_status = "🟢 Running" if is_running else "🔴 Stopped"
            print(f"\n  Stream: {stream_name}")
            print(f"  Status: {actual_status}")
            print(f"  PID: {pid}")
            print(f"  Started: {started_at}")

        print("\n" + "-" * 60)

    except Exception as e:
        logger.error(f"❌ Failed to get status: {str(e)}")


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 ffmpeg-manager.py start <stream_name>")
        print("  python3 ffmpeg-manager.py stop <stream_name>")
        print("  python3 ffmpeg-manager.py status")
        sys.exit(1)

    command = sys.argv[1]

    if command == "start" and len(sys.argv) >= 3:
        stream_name = sys.argv[2]
        start_transcoding(stream_name)
    elif command == "stop" and len(sys.argv) >= 3:
        stream_name = sys.argv[2]
        stop_transcoding(stream_name)
    elif command == "status":
        get_status()
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
