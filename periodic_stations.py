import numpy as np
from PedestrianCrowding import Road
from PedestrianCrowding.simulation import simulate
from multiprocessing import Pool, Manager
import itertools
import csv

sim_time = 3000
trans_time = 3000
num_lanes = 1
roadlength = 5000
p_slow = 0.1
v_max = 5

densities = np.arange(0.02, 1, 0.02)
# bus_fractions = np.linspace(0, 1/num_lanes, 5)
bus_fractions = np.arange(0, 0.101, 0.01)
trials = range(50)
alpha_max = 0.1
station_periods = (roadlength*(0.5)**np.arange(1, np.log2(roadlength))).astype(int)
alphas = station_periods/roadlength*(2*alpha_max)
print(station_periods)

def g(tup):
    return simulate(*tup, station_period=tup[-1]*roadlength/(2*alpha_max), num_lanes=num_lanes, 
                    sim_time=sim_time, trans_time=trans_time, roadlength=roadlength, v_max=v_max, p_slow=p_slow)
p = Pool()


with open('periodic_stations_maxalpha_%s_bf.csv'%alpha_max, 'w') as f:
    writer = csv.writer(f)
    lines = 0
    for result in p.imap_unordered(g, itertools.product(densities, bus_fractions, trials, alphas)):
        if lines == 0:
            writer.writerow(result.keys())
            lines += 1
        writer.writerow(result.values())