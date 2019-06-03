import numpy as np
from pytrafficmodel import Road
from multiprocessing import Pool, Manager
import itertools
import csv

sim_time = 3000
trans_time = 1000
num_lanes = 1

def simulate(density, frac_bus, trial, alpha):
    roadlength = 500
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

densities = np.arange(0.02, 1, 0.02)
bus_fractions = np.linspace(0, 1/num_lanes, 11)
trials = range(50)
# alphas = np.geomspace(1e-4, 1, 49)
alphas = np.geomspace(1e-4, 1, 29)

def g(tup):
    return simulate(*tup)
p = Pool()


with open('dataset.csv', 'w') as f:
    writer = csv.writer(f)
    lines = 0
    for result in p.imap_unordered(g, itertools.product(densities, bus_fractions, trials, alphas)):
        if lines == 0:
            writer.writerow(result.keys())
            lines += 1
        writer.writerow(result.values())