import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from matplotlib import animation
from IPython.display import HTML
# import pyximport; pyximport.install()
from PedestrianCrowding import Road, Bus
from multiprocessing import Pool, Manager
import itertools
import pandas as pd
import plot_init as pu
import csv
import unittest

class TestDeceleration(unittest.TestCase):
    def setup(self, vel, passenger_headway):
        roadlen=200
        num_lanes = 1
        # empty road
        road = Road(roadlen, num_lanes, vmax=5, alpha=0, frac_bus=0, periodic=True, density=0, p_slow=0.)

        # setup
        bus = Bus(Road=road, pos=5, lane=0, vel=vel, p_slow=0, p_lambda=0)
        road.vehicle_array.append(bus)
        road.pedestrian[0,bus.pos + passenger_headway] = 1
        data = []
        T = 5
        for i in range(T):
            road.timestep_parallel()
            data.append(bus.vel)
        return data

    def test_deceleration_bus(self):
        self.assertEqual(self.setup(vel=1, passenger_headway=3), [2,1,0,1,2])
        self.assertEqual(self.setup(vel=5, passenger_headway=5), [3,2,0,1,2])
        self.assertEqual(self.setup(vel=5, passenger_headway=4), [3,1,0,1,2])
        self.assertEqual(self.setup(vel=5, passenger_headway=3), [5,5,5,5,5])
        self.assertEqual(self.setup(vel=4, passenger_headway=4), [2,2,0,1,2])
        self.assertEqual(self.setup(vel=4, passenger_headway=5), [2,2,1,0,1])
        self.assertEqual(self.setup(vel=4, passenger_headway=1), [5,5,5,5,5])
        self.assertEqual(self.setup(vel=2, passenger_headway=3), [2,1,0,1,2])
        self.assertEqual(self.setup(vel=2, passenger_headway=5), [3,2,0,1,2])
        self.assertEqual(self.setup(vel=2, passenger_headway=4), [2,2,0,1,2])
        self.assertEqual(self.setup(vel=3, passenger_headway=5), [2,2,1,0,1])
        self.assertEqual(self.setup(vel=3, passenger_headway=4), [2,2,0,1,2])




if __name__ == '__main__':
    unittest.main()