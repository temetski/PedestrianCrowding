import numpy as np
from PedestrianCrowding import Road
from PedestrianCrowding.simulation import simulate
from multiprocessing import Pool, Manager
import itertools
import csv

sim_time = 3000
trans_time = 1000
num_lanes = 1
roadlength = 500
p_slow = 0.1
v_max = 5

densities = np.arange(0.02, 1, 0.02)
bus_fractions = np.linspace(0, 1/num_lanes, 11)
trials = range(50)
alphas = np.geomspace(1e-4, 1, 49)
waiting_times = [1,2,4,8]
def g(tup):
    density, frac_bus, trial, alpha, bus_wait_time = tup
    return simulate(density, frac_bus, trial, alpha, num_lanes=num_lanes,
                    sim_time=sim_time, trans_time=trans_time, v_max=v_max,
                    p_slow=p_slow, bus_wait_time=bus_wait_time)
p = Pool()

        
with open('../data/dataset_stopped_time.csv', 'w') as f:
    writer = csv.writer(f)
    lines = 0
    ## crossover data
    densities = np.arange(0.2, 0.81, 0.1)
    alphas = np.geomspace(1e-4, 1, 49)
    for result in p.imap_unordered(g, itertools.product(densities, [1], trials, alphas, waiting_times)):
        if lines == 0:
            writer.writerow(result.keys())
            lines += 1
        writer.writerow(result.values())
        
    ## FD data
    densities = np.arange(0.02, 1, 0.02)
    bus_fractions = [0,0.2,0.5]
    for result in p.imap_unordered(g, itertools.product(densities, bus_fractions, trials, [1e-3], waiting_times)):
        writer.writerow(result.values())