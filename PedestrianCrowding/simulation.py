from . import Road
import numpy as np

## TODO: set these values as function arguments (model parameters)
sim_time = 3000
trans_time = 1000


def simulate(density, frac_bus, trial, alpha, station_period=1, num_lanes=2, sim_time=3000, trans_time=1000):
    roadlength = 500
    vmax = 5
    alpha = alpha
    frac_bus = frac_bus
    density = density
    p_slow = 0.1
    periodic = True
    throughputs = []
    throughputs_lane = np.zeros((sim_time, num_lanes))
    waiting_times = []
    road = Road(roadlength, num_lanes, vmax, alpha, 
                        frac_bus, periodic, density, p_slow, station_period)
    for t in range(sim_time+trans_time):
        road.timestep_parallel()
        if t > trans_time:
            throughputs.append(road.throughput())
            throughputs_lane[t-trans_time] = road.throughput_per_lane()
            waiting_times += road.waiting_times
    res = {"throughput": np.mean(throughputs),
            "throughput_lanes": np.mean(throughputs_lane, axis=0).tolist(),
            "frac_bus": frac_bus,
            "density": road.get_density(),
            "trial": trial,
            "alpha": alpha, 
            "p_slow": p_slow,
            "mean_waiting_time": np.mean(waiting_times) if waiting_times else 0,
            "median_waiting_time": np.median(waiting_times) if waiting_times else 0,
            "quartile1_waiting_time": np.percentile(waiting_times, 25) if waiting_times else 0,
            "quartile3_waiting_time": np.percentile(waiting_times, 75) if waiting_times else 0,
            "station_period": station_period}    
    return res

