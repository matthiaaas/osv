use std::time::{Duration, Instant};

const CYCLE_INTERVAL: u64 = 1_000_000;

pub struct IpsMonitor {
    last_time: Instant,
    last_cycles: u64,
}

impl IpsMonitor {
    pub fn new(current_cycles: u64) -> Self {
        Self {
            last_time: Instant::now(),
            last_cycles: current_cycles,
        }
    }

    pub fn update(&mut self, current_cycles: u64) {
        if current_cycles % CYCLE_INTERVAL != 0 {
            return;
        }

        if self.last_time.elapsed() >= Duration::from_secs(1) {
            let now = Instant::now();
            let delta_cycles = current_cycles - self.last_cycles;
            let delta_time = now.duration_since(self.last_time).as_secs_f64();

            let ips = delta_cycles as f64 / delta_time;
            println!("IPS: {:.2}", ips);

            self.last_time = now;
            self.last_cycles = current_cycles;
        }
    }
}

impl Default for IpsMonitor {
    fn default() -> Self {
        Self::new(0)
    }
}
