"""Real Godot simulation tests and two-process ENet reconnect smoke test."""
import os
from pathlib import Path
import re
import subprocess
import time
import heapq
import random
import selectors
import socket
import threading
import sys


class ImpairedUDP:
    """Real UDP forwarding: 150 ms RTT, +/-40 ms RTT jitter, 2% loss.

    ENet performs its actual acknowledgments/retransmissions through this relay.
    Each arriving client transport gets a separate upstream socket, preserving
    the old/new connection distinction across reconnects.
    """
    def __init__(self, blackout=False):
        self.selector = selectors.DefaultSelector()
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.front.bind(("127.0.0.1", 7778))
        self.front.setblocking(False)
        self.selector.register(self.front, selectors.EVENT_READ, None)
        self.upstreams = {}
        self.queue = []
        self.number = 0
        self.rng = random.Random(41)
        self.stopped = threading.Event()
        self.blackout = blackout
        self.blocked_until = 0
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def schedule(self, sock, address, payload):
        if self.rng.random() < 0.02:
            return
        copies = 2 if self.rng.random() < 0.01 else 1
        for _ in range(copies):
            self.number += 1
            heapq.heappush(self.queue, (time.monotonic() + .075 + self.rng.uniform(-.020, .020), self.number, sock, address, payload))

    def run(self):
        while not self.stopped.is_set():
            trigger = ROOT / "build/network-blackout.txt"
            if self.blackout and trigger.exists():
                trigger.unlink()
                self.blocked_until = time.monotonic() + 3.5
            for key, _ in self.selector.select(.003):
                try:
                    payload, source = key.fileobj.recvfrom(65535)
                except (BlockingIOError, ConnectionResetError):
                    continue
                if key.fileobj is self.front:
                    if source not in self.upstreams:
                        upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                        upstream.bind(("127.0.0.1", 0))
                        upstream.setblocking(False)
                        self.upstreams[source] = upstream
                        self.selector.register(upstream, selectors.EVENT_READ, source)
                    self.schedule(self.upstreams[source], ("127.0.0.1", 7779), payload)
                else:
                    if time.monotonic() >= self.blocked_until:
                        self.schedule(self.front, key.data, payload)
            while self.queue and self.queue[0][0] <= time.monotonic():
                _, _, sock, address, payload = heapq.heappop(self.queue)
                sock.sendto(payload, address)

    def close(self):
        self.stopped.set()
        self.thread.join(timeout=2)
        self.selector.close()
        self.front.close()
        for upstream in self.upstreams.values():
            upstream.close()

ROOT = Path(__file__).resolve().parents[1]
ENGINE = os.environ.get("PENGUIN_GODOT", str(ROOT / ".tools/Godot.app/Contents/MacOS/Godot"))


def main():
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    base = [ENGINE, "--headless", "--path", str(ROOT)]
    if "--network-only" not in sys.argv:
        unit = subprocess.run(base + ["--log-file", str(build / "race-engine.log"), "--fixed-fps", "60", "tests/race_runner.tscn"], capture_output=True, text=True, timeout=120)
        (build / "race-tests.txt").write_text(unit.stdout + unit.stderr)
        print(unit.stdout + unit.stderr)
        assert unit.returncode == 0 and re.search(r"RACE RESULT: \d+ checks, 0 failures", unit.stdout) and "SCRIPT ERROR" not in unit.stderr, "simulation tests failed"
    run_network(base, build, False)
    run_network(base, build, True)
    run_network(base, build, True, True)
    print("MULTIPLAYER PASS: normal/impaired ENet, one-way outage, pause, reconnect, matching results, rematch, explicit leave")


def run_network(base, build, impaired, blackout=False):
    invite = build / "network-invitation.txt"
    invite.unlink(missing_ok=True)
    processes = []
    trigger = build / "network-blackout.txt"
    trigger.unlink(missing_ok=True)
    relay = ImpairedUDP(blackout) if impaired else None
    suffix = "-one-way" if blackout else ("-impaired" if impaired else "")
    try:
        for role in ["host", "client"]:
            log = (build / f"network-{role}{suffix}.txt").open("w")
            process = subprocess.Popen(base + ["--log-file", str(build / f"network-{role}{suffix}-engine.log"), "tests/race_network.tscn", "--", f"--{role}"] + (["--relay"] if impaired else []) + (["--blackout"] if blackout else []), stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
            processes.append((role, process, log))
            if role == "host":
                end = time.monotonic() + 10
                while not invite.exists() and process.poll() is None and time.monotonic() < end:
                    time.sleep(0.05)
                assert invite.exists(), "host did not produce invitation"
        hashes = []
        for role, process, log in processes:
            code = process.wait(timeout=90)
            log.close()
            output = (build / f"network-{role}{suffix}.txt").read_text()
            print(output)
            assert code == 0 and "NETWORK PASS" in output and "SCRIPT ERROR" not in output and "ERROR:" not in output, f"{role} network test failed"
            hashes.append(re.search(r"hash=([0-9a-f]+)", output)[1])
        assert hashes[0] == hashes[1], "peers ended with different canonical states"
        print(f"NETWORK PASS: {'one-way outage' if blackout else ('impaired' if impaired else 'normal')} transport")
    finally:
        for _, process, log in processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            log.close()
        invite.unlink(missing_ok=True)
        trigger.unlink(missing_ok=True)
        if relay:
            relay.close()


if __name__ == "__main__":
    main()
