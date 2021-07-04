#!/usr/bin/python3

import time

now = time.time()
while True:
    # print timestamp
    print(time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(now)), flush=True)

    # wait until next second, allowing sleep to wakeup early
    next = int(now) + 1
    while int(now) < next:
        time.sleep(next - now)
        now = time.time()
