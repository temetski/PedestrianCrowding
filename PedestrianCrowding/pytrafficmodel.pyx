#cython: language_level=3, boundscheck=False, wraparound=False

import numpy as np
cimport numpy as np
from libc.stdlib cimport RAND_MAX
import random as rnd    
# cimport PedestrianCrowding.random
# cdef PedestrianCrowding.random.mt19937 gen = PedestrianCrowding.random.mt19937(rnd.randint(0, RAND_MAX))
# cdef PedestrianCrowding.random.uniform_real_distribution[double] dist = PedestrianCrowding.random.uniform_real_distribution[double](0.0,1.0)

STUFF="HI"
cdef int max_decel = 2
cdef class Vehicle:
    cdef readonly:
        int pos,lane, prev_lane, marker, vel, vmax
        float p_lambda, p_slow
    
    cdef public:
        np.int_t[:, :] road
        int prev_vel, id
    
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
        self.id = Road.get_id()

    cdef void accelerate(self):
        self.prev_vel = self.vel
        self.vel = min(self.vel+1, self.vmax)

    cdef void decelerate(self):
        self.vel = min(self.vel, self.headway(self.lane))

    cdef void random_slow(self):
        self.rng = np.random.random()
        if (self.rng < self.p_slow):
            self.vel = max(self.vel-1, 0)

    cdef void movement(self):
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


    cdef void place(self):
        self.road[self.lane, self.pos] = self.id

    cdef void remove(self):
        self.road[self.lane, self.pos] = 0

    cdef bint lanechange(self):
        cdef int where, max_headway, i, headway, current_headway
        where = 0; max_headway = 0
        cdef np.int_t[:] s
        s = np.zeros(self.Road.num_lanes, dtype=np.int)
        current_headway = self.headway(self.lane)

        if self.vel>current_headway:
            # scan for suitable lanes
            for i in range(self.Road.num_lanes):
                headway = self.headway(i)
                s[i] = headway
                if headway>max_headway:
                    where = i
                    max_headway = headway
            # self.lookback(where)

            if (where != self.lane) and (max_headway>current_headway):  # desired lane is different
                if self.lane > where and ((self.road[self.lane-1, self.pos]==0)) and self.lookback(self.lane-1):  # left
                    self.remove()
                    self.lane -= 1
                    self.place()
                    return True
                elif self.lane < where and ((self.road[self.lane+1, self.pos])==0) and self.lookback(self.lane+1):  # right
                    self.remove()
                    self.lane += 1
                    self.place()
                    return True
        return False

    cdef bint lookback(self, int target_lane):
        cdef int _pos, headwaycount
        headwaycount = 0
        _pos = self.pos-1
        if self.Road.periodic:
            _pos %= self.Road.roadlength
        while (self.road[target_lane, _pos]==0) and (headwaycount<(self.vmax)):
            _pos -= 1
            if self.Road.periodic:
                _pos %= self.Road.roadlength
            headwaycount += 1
        back_id = self.road[target_lane, _pos]
        if back_id == 0: # all clear!
            return True
        elif headwaycount+self.vel >= self.Road.get_vehicle(back_id).vel-max_decel: # will it crash?
            return True
        else: # too risky!
            return False


cdef class Bus(Vehicle):
    cdef public:
        np.int_t [:,:] pedestrian
        int num_passengers
        int wait_counter

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
        self.num_passengers = 0
        self.wait_counter = Road.bus_wait_time
        self.id = Road.get_id()

    cdef void accelerate(self):
        if self.wait_counter==self.Road.bus_wait_time:
            self.prev_vel = self.vel
            self.vel = min(self.vel+1, self.vmax)
        else:
            self.wait_counter += 1

    cpdef void decelerate(self):
        hw_pass = self.passenger_headway()
        hw = self.headway(self.lane)

        # skip when too fast
        if (2*self.prev_vel-3*max_decel)>hw_pass:# and (self.prev_vel-max_decel)>(max_decel):
            self.vel = min([self.vel, hw])
        else:
            # anticipate the stop
            if (self.prev_vel+max_decel)>=hw_pass>=max_decel:
                self.vel = min([self.vel, hw, max(self.prev_vel-max_decel, max_decel)]) 
            else:
                self.vel = min([self.vel, hw, hw_pass])
        # print(self.prev_vel, self.vel, hw, hw_pass, c)

    cdef int passenger_headway(self):
        cdef int _pos, headwaycount
        headwaycount = 0
        _pos = self.pos+1
        if self.Road.periodic:
            _pos %= self.Road.roadlength
        while (self.pedestrian[self.lane, _pos]==0) and (headwaycount<(self.vmax*2)):
            _pos += 1
            if self.Road.periodic:
                _pos %= self.Road.roadlength
            headwaycount += 1
        return headwaycount + 1

    cpdef void load(self):
        if self.pedestrian[self.lane, self.pos] != 0:
            self.Road.waiting_times.append(self.pedestrian[self.lane, self.pos])
            self.pedestrian[self.lane, self.pos] = 0
            self.vel = 0
            self.num_passengers += 1
            self.wait_counter = 0


cdef class Road:
    cdef public:
        int roadlength, num_lanes, vmax, station_period, max_passengers, bus_wait_time
        float alpha, frac_bus, density, p_slow
        bint periodic
        np.int_t[:,:] road, road_id_map
        np.int_t[:,:] pedestrian
        list waiting_times
        list vehicle_array

    cdef int id_counter

    def __cinit__(self, int roadlength, int num_lanes, int vmax, float alpha, 
                    float frac_bus, bint periodic, float density, float p_slow,
                    int station_period=1, int max_passengers=2147483647, int bus_wait_time=0):
        self.roadlength = roadlength
        self.vehicle_array = []
        self.road = np.zeros((num_lanes, roadlength), dtype=np.int)
        self.pedestrian = np.zeros((num_lanes, roadlength), dtype=np.int)
        self.vmax = vmax
        self.num_lanes = num_lanes
        self.alpha = alpha
        self.periodic = periodic
        self.p_slow = p_slow
        self.waiting_times = []
        self.station_period = station_period
        self.max_passengers = max_passengers
        self.bus_wait_time = bus_wait_time
        self.id_counter = 0
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

    cdef int get_id(self):
        self.id_counter = self.id_counter + 1
        return self.id_counter

    cdef place_vehicle_type(self, type veh_type, int number):
        cdef int i, pos, lane
        cdef Vehicle vehicle
        for i in range(number):
            pos=0; lane=self.num_lanes-1
            while not self.place_check(pos, lane):
                pos = np.random.randint(self.roadlength)
                if veh_type != Bus: # type checking
                    lane = np.random.randint(self.num_lanes)
                else:
                    lane = self.num_lanes-1
            vehicle = veh_type(Road=self, pos=pos, lane=lane, vel=self.vmax, p_slow=self.p_slow, p_lambda=0 if veh_type == Bus else 1)
            self.vehicle_array.append(vehicle)
            vehicle.place()

    cdef bint place_check(self, int pos, int lane):
        return False if self.road[lane, pos] else True

    cpdef timestep_parallel(self):
        if not self.periodic:
            self.populate()
        if self.frac_bus>0:
            self.spawn_pedestrian(self.station_period)
        np.random.shuffle(self.vehicle_array)
        cdef list reached_end = []
        cdef int i
        cdef Vehicle vehicle
        self.waiting_times = []
        lcs = np.zeros_like(self.vehicle_array)
        for i, vehicle in enumerate(self.vehicle_array):
            vehicle.accelerate()
            if type(vehicle) == Bus:
                if vehicle.num_passengers<self.max_passengers:
                    vehicle.load()

            if np.random.random() < vehicle.p_lambda:
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
            if np.random.random() < vehicle.p_lambda:
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
                if (np.random.random() < self.frac_bus_converter()) and (i == (self.num_lanes-1)):
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
            if self.pedestrian[self.num_lanes-1][i] == 0:
                self.pedestrian[self.num_lanes-1][i] += (self.road[self.num_lanes-1,i] == 0) * (np.random.random() < self.alpha)*1
            else:
                # increment waiting time
                self.pedestrian[self.num_lanes-1][i] += 1


    cdef float frac_bus_converter(self):
        return self.num_lanes*self.frac_bus

    cpdef np.float64_t throughput(self):
        return 1.*sum([i.vel for i in self.vehicle_array])/self.roadlength/self.num_lanes

    cpdef np.ndarray[np.float64_t, ndim=1] throughput_per_lane(self):
        cdef np.ndarray[np.float64_t, ndim=1] lane = np.empty(self.num_lanes, dtype=np.float64)
        for i in range(self.num_lanes):
            lane[i] = 1.*sum([j.vel for j in self.vehicle_array if j.lane==i])/self.roadlength
        return lane

    # cpdef np.ndarray[np.float64_t, ndim=1] throughput_per_lane(self):
    #     cdef np.ndarray[np.float64_t, ndim=1] count = np.empty(self.num_lanes, dtype=np.float64)
    #     cdef int i,j
    #     for i in range(len(self.road)):
    #         for j in range(len(self.road[0])):
    #             if self.road[i,j] != 0:
    #                 count[i] += 1
    #     return count/self.road.size

    cpdef np.float64_t get_density(self):
        cdef int count = 0
        cdef int i,j
        for i in range(len(self.road)):
            for j in range(len(self.road[0])):
                if self.road[i,j] != 0:
                    count += 1
        return count/self.road.size

    cpdef int get_num_full_buses(self):
        cdef Vehicle veh
        cdef int count = 0
        for veh in self.vehicle_array:
            if type(veh) == Bus:
                if veh.num_passengers == self.max_passengers:
                    count += 1
        return count

    cpdef np.int_t[:,:] get_road(self):
        cdef np.int_t[:,:] road
        cdef Vehicle veh
        road = np.zeros((self.num_lanes, self.roadlength), dtype=np.int)
        for veh in self.vehicle_array:
            road[veh.lane, veh.pos] = veh.marker
        return road

    cdef Vehicle get_vehicle(self, int veh_id):
        cdef Vehicle veh
        for veh in self.vehicle_array:
            if veh.id == veh_id:
                return veh