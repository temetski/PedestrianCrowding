import numpy as np
from PedestrianCrowding import Road
from PedestrianCrowding.simulation import simulate
from multiprocessing import Pool, Manager
import json
import itertools
import csv

sim_time = 3000
trans_time = 3000
num_lanes = 1
roadlength = 5120
p_slow = 0.1
v_max = 5

# densities = np.arange(0.02, 1, 0.02)
densities = np.arange(0.54, 1, 0.02)
# bus_fractions = np.linspace(0, 1/num_lanes, 5)
bus_fractions = np.arange(0, 0.101, 0.01)
bus_fractions = [0.03, 0.25, 0.5, 0.75, 1]
trials = range(50)
alpha_max = 0.1
station_periods = 2**np.arange(0, 9, 2)
PHI = 2
alphas = station_periods/roadlength*PHI


def g(tup):
    period = tup[-1]*roadlength/PHI
    return simulate(*tup, station_period=period, num_lanes=num_lanes,
                    sim_time=sim_time, trans_time=trans_time, roadlength=roadlength, v_max=v_max, p_slow=p_slow)


p = Pool()


# with open('../data/dataset_stations_maxalpha_%s.csv' % alpha_max, 'w') as datafile:
with open('../data/dataset_stations_maxalpha_%s.csv' % alpha_max, 'a') as datafile:
    writer = csv.writer(datafile)
    # lines = 0
    lines = 1
    paramsfile = open(
        '../data/dataset_stations_maxalpha_%s.json' % alpha_max, 'a')
    for result in p.imap_unordered(g, itertools.product(densities, bus_fractions, trials, alphas)):
        if lines == 0:
            writer.writerow(result.keys())
            lines += 1
        writer.writerow(result.values())

        params_dict = {'density': result['density'],
                       'alpha': result['alpha'],
                       'frac_bus': result['frac_bus'],
                       'station_period': result['station_period'],
                       'trial': result['trial'],
                       }
        paramsfile.write(json.dumps(params_dict))
        paramsfile.write('\n')
    paramsfile.close()
