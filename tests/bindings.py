"""Exercise real I/U keystrokes on the integration test's private tmux server."""

import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time


def main():
    socket = sys.argv[1]
    command = ["tmux", "-S", socket]
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    environment = dict(os.environ, TERM="xterm-256color")
    client = subprocess.Popen(
        command + ["attach-session", "-t", "plugins"],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=environment,
    )
    os.close(slave)
    output = bytearray()

    def query(*arguments):
        return subprocess.check_output(command + list(arguments), text=True).strip()

    def wait_for(predicate, description):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if client.poll() is not None:
                raise RuntimeError(f"tmux client exited while {description}")
            if predicate():
                return
            if select.select([master], [], [], 0.05)[0]:
                output.extend(os.read(master, 65536))
                del output[:-4000]
        raise RuntimeError(f"Timed out while {description}")

    try:
        wait_for(
            lambda: str(client.pid) in query("list-clients", "-F", "#{client_pid}").splitlines(),
            "attaching the private terminal client",
        )
        for key in ("I", "U"):
            subprocess.run(command + ["set-option", "-g", "@binding-reloaded", "pending"], check=True)
            # Ctrl-Space is NUL. Send actual prefix keystrokes instead of
            # re-parsing list-keys output, whose escaping differs in tmux 3.4.
            os.write(master, b"\x00" + key.encode("ascii"))
            wait_for(
                lambda: query("show-option", "-gv", "@binding-reloaded") == "complete",
                f"executing prefix + {key} and reloading the configuration",
            )
            print(f"prefix + {key}: pinned installer completed and configuration reloaded.")
    except Exception:
        print(f"Recent private-client output: {bytes(output)!r}", file=sys.stderr)
        raise
    finally:
        if client.poll() is None:
            client.terminate()
            try:
                client.wait(timeout=5)
            except subprocess.TimeoutExpired:
                client.kill()
                client.wait()
        os.close(master)


if __name__ == "__main__":
    main()
