#cython: language_level=3, boundscheck=False, wraparound=False

import numpy as np
cimport numpy as np
from libc.stdlib cimport RAND_MAX
import random as rnd    
cimport random
cdef random.mt19937 gen = random.mt19937(rnd.randint(0, RAND_MAX))
cdef random.uniform_real_distribution[double] dist = random.uniform_real_distribution[double](0.0,1.0)

STUFF="HI"
cdef class Vehicle(object):
    cdef readonly:
        int pos,lane, prev_lane, marker, vel, vmax
        float p_lambda, p_slow
    
    cdef public:
        np.int_t[:, :] road
    
    cdef float rng
    cdef Road Road

    def __cinit__(self, Road Road, int pos, int lane, int vel, float p_slow, float p_lambda, **kwargs):
        self.pos = pos
        self.lane = lane
        self.prev_lane = 0
        self.p_lambda = p_lambda
        self.p_slow = p_slow
        self.marker = 1
        self.vel = vel
        self.vmax = Road.vmax
        self.road = Road.road
        self.Road = Road

    cdef accelerate(self):
        self.vel = min(self.vel+1, self.vmax)

    cdef decelerate(self):
        self.vel = min(self.vel, self.headway(self.lane))

    cdef random_slow(self):
        self.rng = dist(gen)
        if (self.rng < self.p_slow):
            self.vel = max(self.vel-1, 0)

    cdef movement(self):
        self.remove()
        self.pos += self.vel
        if self.Road.periodic:
            self.pos %= self.Road.roadlength
        self.place()

    cdef int headway(self, int lane):
        cdef int _pos, headwaycount
        headwaycount = 0
        _pos = self.pos+1
        if self.Road.periodic:
            _pos %= self.Road.roadlength
        while (self.road[lane, _pos]==0) and (headwaycount<(self.vmax*2)):
            _pos += 1
            if self.Road.periodic:
                _pos %= self.Road.roadlength
            headwaycount += 1
        return headwaycount


    cpdef place(self):
        self.road[self.lane, self.pos] += self.marker

    cdef remove(self):
        self.road[self.lane, self.pos] -= self.marker

    cdef bint lanechange(self):
        cdef int where, max_headway, i, headway, current_headway
        where = 0; max_headway = 0
        cdef np.int_t[:] s
        s = np.zeros(self.Road.num_lanes, dtype=np.int)
        current_headway = self.headway(self.lane)

        for i in range(self.Road.num_lanes):
            headway = self.headway(i)
            s[i] = headway
            if headway>max_headway:
                where = i
                max_headway = headway

        if (where != self.lane) and (max_headway>current_headway):  # desired lane is different
            if self.lane > where and ((self.road[self.lane-1, self.pos]==0)):  # left
                self.remove()
                self.lane -= 1
                self.place()
                return True
            elif self.lane < where and ((self.road[self.lane+1, self.pos])==0):  # right
                self.remove()
                self.lane += 1
                self.place()
                return True
        return False


cdef class Bus(Vehicle):
    cdef public:
        np.int_t [:,:] pedestrian

    def __cinit__(self, Road Road, int pos, int lane, int vel, float p_slow, float p_lambda, **kwargs):
        self.pos = pos
        self.lane = lane
        self.prev_lane = 0
        self.p_lambda = p_lambda
        self.p_slow = p_slow
        self.marker = 2
        self.vel = vel
        self.vmax = Road.vmax
        self.road = Road.road
        self.Road = Road
        self.pedestrian = Road.pedestrian

    cpdef decelerate(self):
        self.vel = min([self.vel, self.headway(self.lane), self.passenger_headway()])

    cdef int passenger_headway(self):
        cdef int _pos, headwaycount
        headwaycount = 0
        _pos = self.pos+1
        if self.Road.periodic:
            _pos %= self.Road.roadlength
        while (self.pedestrian[self.lane, _pos]==0) and (headwaycount<self.vmax):
            _pos += 1
            if self.Road.periodic:
                _pos %= self.Road.roadlength
            headwaycount += 1
        return headwaycount + 1

    cpdef load(self):
        if self.pedestrian[self.lane, self.pos] != 0:
            self.pedestrian[self.lane, self.pos] = 0
            self.vel = 0


cdef class Road:
    cdef public:
        int roadlength, num_lanes, vmax
        float alpha, frac_bus, density, p_slow
        bint periodic
        np.int_t[:,:] road
        np.int_t[:,:] pedestrian
        list vehicle_array

    def __cinit__(self, int roadlength, int num_lanes, int vmax, float alpha, 
                    float frac_bus, bint periodic, float density, float p_slow):
        self.roadlength = roadlength
        self.vehicle_array = []
        self.road = np.zeros((num_lanes, roadlength), dtype=np.int)
        self.pedestrian = np.zeros((num_lanes, roadlength), dtype=np.int)
        self.vmax = vmax
        self.num_lanes = num_lanes
        self.alpha = alpha
        self.periodic = periodic
        self.p_slow = p_slow
        if frac_bus <= 1./num_lanes:
            self.frac_bus = frac_bus
        else:
            raise ValueError("Invalid Bus Fraction")
        cdef int num_buses, num_vehicles, num_cars
        if self.periodic:
            num_vehicles = int(density*roadlength*num_lanes)
            num_buses = int(num_vehicles*frac_bus)
            num_cars = num_vehicles - num_buses
            self.place_vehicle_type(Bus, num_buses)
            self.place_vehicle_type(Vehicle, num_cars)

    cpdef place_vehicle_type(self, Vehicle, int number):
        cdef int i, pos, lane
        for i in range(number):
            pos=0; lane=self.num_lanes-1
            while not self.place_check(pos, lane):
                pos = np.random.randint(self.roadlength)
                if Vehicle != Bus: # type checking
                    lane = np.random.randint(self.num_lanes)
                else:
                    lane = self.num_lanes-1
            vehicle = Vehicle(Road=self, pos=pos, lane=lane, vel=self.vmax, p_slow=self.p_slow, p_lambda=0 if Vehicle == Bus else 1)
            self.vehicle_array.append(vehicle)
            vehicle.place()

    cdef bint place_check(self, int pos, int lane):
        return False if self.road[lane, pos] else True

    cpdef timestep_parallel(self):
        if not self.periodic:
            self.populate()
        if self.frac_bus>0:
            self.spawn_pedestrian()
        np.random.shuffle(self.vehicle_array)
        cdef list reached_end = []
        cdef int i
        cdef Vehicle vehicle
        lcs = np.zeros_like(self.vehicle_array)
        for i, vehicle in enumerate(self.vehicle_array):
            vehicle.accelerate()
            if type(vehicle) == Bus:
                vehicle.load()

            if dist(gen) < vehicle.p_lambda:
                lcs[i] = vehicle.lanechange()*1
                
        for i, vehicle in enumerate(self.vehicle_array):

            vehicle.decelerate()

            if not lcs[i]:
                vehicle.random_slow()
        for i, vehicle in enumerate(self.vehicle_array):

            vehicle.movement()

            if vehicle.pos >= (self.roadlength-self.vmax-1):
                reached_end.append(i)
        if not self.periodic:
            self.clear(reached_end)
            
    cpdef timestep(self):
        if not self.periodic:
            self.populate()
        if self.frac_bus>0:
            self.spawn_pedestrian()
        np.random.shuffle(self.vehicle_array)
        cdef list reached_end = []
        cdef int i
        cdef Vehicle vehicle
        for i, vehicle in enumerate(self.vehicle_array):
            vehicle.accelerate()
            if type(vehicle) == Bus:
                vehicle.load()

            lc = False
            if dist(gen) < vehicle.p_lambda:
                lc = vehicle.lanechange()
                
            vehicle.decelerate()

            if not lc:
                vehicle.random_slow()
            vehicle.movement()

            if vehicle.pos >= (self.roadlength-self.vmax-1):
                reached_end.append(i)
        if not self.periodic:
            self.clear(reached_end)

    def populate(self):
        for i, lane in enumerate(self.road):
            if lane[0] == 0:  # First cell empty
                if (dist(gen) < self.frac_bus_converter()) and (i == (self.num_lanes-1)):
                    vehicle = Bus(Road=self, pos=0, lane=i, vel=self.vmax,
                                  p_slow=self.p_slow, p_lambda=0)
                else:
                    vehicle = Vehicle(
                        Road=self, pos=0, lane=i, vel=self.vmax, p_slow=self.p_slow, p_lambda=1)
                self.vehicle_array.append(vehicle)
                vehicle.place()

    def clear(self, reached_end):
        for i in reached_end:
            self.vehicle_array[i].remove()
        self.vehicle_array = [veh for i, veh in enumerate(
            self.vehicle_array) if i not in reached_end]

    cdef spawn_pedestrian(self, int period=1):
        cdef int i
        for i in range(0, len(self.pedestrian[self.num_lanes-1]), period):
            self.pedestrian[self.num_lanes-1][i] += (self.pedestrian[self.num_lanes-1][i] == 0)*(self.road[self.num_lanes-1,i] == 0) * (dist(gen) < self.alpha)*1


    cdef float frac_bus_converter(self):
        return self.num_lanes*self.frac_bus

    cpdef float throughput(self):
        return 1.*sum([i.vel for i in self.vehicle_array])/self.roadlength/self.num_lanes

    cpdef float get_density(self):
        cdef int count = 0
        cdef int i,j
        for i in range(len(self.road)):
            for j in range(len(self.road[0])):
                if self.road[i,j] != 0:
                    count += 1
        return count/self.road.size

