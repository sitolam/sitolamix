import time

class RateLimitTimer:
    def __init__(self):
        self.timers = {}

    def limit(self, key, sec):
        if key not in self.timers:
            self.timers[key] = {
                'seconds': sec,
                'last_sync': time.time()
            }
            return False

        current_time = time.time()
        timer = self.timers[key]

        if current_time - timer['last_sync'] < timer['seconds']:
            try:
                elapsed = current_time - timer['last_sync']
                remaining = timer['seconds'] - elapsed
                if not key in ["resizeEvent"]:
                    print(f"rate limit: {key}, {remaining:.1f}/{timer['seconds']} sec")
            except Exception as e:
                print(e)
            return True

        timer['last_sync'] = current_time
        return False

rate_limit = RateLimitTimer()

# print(rate_limit.limit("example", 5))
# print(rate_limit.limit("example", 5))
# time.sleep(6)
# print(rate_limit.limit("example", 5))