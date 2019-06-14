from . import Road
import numpy as np

## TODO: set these values as function arguments (model parameters)
sim_time = 100
trans_time = 1
num_lanes = 1

def simulate(density, frac_bus, trial, alpha):
    roadlength = 10
    vmax = 5
    alpha = alpha
    frac_bus = frac_bus
    density = density
    p_slow = 0
    periodic = True
    throughputs = []
    road = Road(roadlength, num_lanes, vmax, alpha, 
                        frac_bus, periodic, density, p_slow)
    for t in range(sim_time+trans_time):
        road.timestep_parallel()
        if t >= trans_time:
            throughputs.append(road.throughput())
    res = {"throughput": np.mean(throughputs),
            "frac_bus": frac_bus,
            "density": road.get_density(),
            "trial": trial,
            "alpha": alpha, 
            "p_slow": 0}    
    return res

