#!/usr/bin/env python
from pyspark import SparkContext

from itertools import product
import numpy as np
import json

from PedestrianCrowding.simulation import simulate

'''
The output from `saveAsTextFile` will be a *directory* of output text files 
from each of the partitions. Concatenate all the contents of the directory
after running the script, i.e. `cat output.txt/* > output_cat.txt


To run locally:
> spark-submit --py-files dist/PedestrianCrowding-2019.6.14-py3.6-macosx-10.7-x86_64.egg sample-spark.py

To run on a standalone cluster:
> spark-submit --deploy-mode cluster \
    --master spark://192.168.200.230:7077 \
    --py-files dist/PedestrianCrowding-2019.6.14-py3.6-macosx-10.7-x86_64.egg \
    sample-spark.py

'''

## TODO: set these values as function arguments (model parameters)
num_lanes = 2

densities = np.arange(0.2, 1, 0.2)
bus_fractions = np.linspace(0, 1/num_lanes, 11)
trials = range(50)
alphas = np.geomspace(1e-4, 1, 29)


def operation(params):
	# Output of the mapped function should ideally be a tuple
	# (creates a CSV) or a string from pickling the object.
	result = simulate(*params)
	output = json.dumps({
			"param_list": params,
			"param_output": result
	})
	return output

if __name__ == "__main__":
	param_set = product(densities, bus_fractions, trials, alphas)
	with SparkContext(appName="MeasuringGraphs") as sc:
		output = sc.parallelize(param_set).map(lambda x: operation(x))
		output.saveAsTextFile("output.txt")
