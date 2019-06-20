import json
import pandas as pd
import sys

res = []
if __name__=="__main__":
    spark_out_file = sys.argv[1]
    with open(spark_out_file, "r") as f:
        for line in f:
            # print(line)
            res.append(json.loads(line)['param_output'])
    df = pd.DataFrame(res)
    out_file_name = spark_out_file.split(".")[0] + ".csv"
    df.to_csv(out_file_name)
