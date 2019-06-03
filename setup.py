from distutils.core import setup, Extension
from Cython.Build import cythonize
import numpy
extra_compile_args = [
    "-std=c++11", ## Compile C++11 code
    ## Add include directories
    "-I/usr/include",
#     "-I./source",
    "-I{0}".format(numpy.get_include()),
#     "-flto",
    "-D_GLIBCXX_USE_CXX11_ABI=0" # Cython/GCC5 issues
    ## Link-time optimization
]

extra_link_args = [
    "-std=c++11", ## Link C++11 code
    # "-L/usr/local/Cellar/gsl/2.3/lib",
#     "-L./source",
#     "-lgsl",
#     "-lgslcblas",
#     "-lm"
]

setup(
    name="pytrafficmodel",
    version="0.0.1",
    
    ext_modules = cythonize(Extension(
           "pytrafficmodel",                                # the extension name
           sources=["source/pytrafficmodel.pyx"], # the Cython source and
                                                  # additional C++ source files
           language="c++",                        # generate and compile C++ code
           extra_compile_args=extra_compile_args,
            extra_link_args=extra_link_args
      )))