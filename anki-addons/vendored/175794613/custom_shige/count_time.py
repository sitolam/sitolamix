import time

# for debug

IS_TIME_PRINT = True

class TaskTimer:
    def __init__(self):
        self.task_timers = {}

    def start(self, identifier):
        if not IS_TIME_PRINT:
            return
        self.task_timers[identifier] = time.time()

    def end(self, identifier):
        if not IS_TIME_PRINT:
            return
        if identifier not in self.task_timers:
            return
        end_time = time.time()
        try:
            elapsed_time = end_time - self.task_timers[identifier]
        except Exception:
            return
        print(f"TaskTimer: {identifier} : {elapsed_time:.2f} sec")
        del self.task_timers[identifier]


shigeTaskTimer = TaskTimer()

# # Example usage
# timer = TaskTimer()
# timer.start_timer("task1")
# time.sleep(2)  # Wait for 2 seconds as an example
# timer.end_timer("task1")

# timer.start_timer("task2")
# time.sleep(3)  # Wait for 3 seconds as an example
# timer.end_timer("task2")