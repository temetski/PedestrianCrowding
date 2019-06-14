#from distutils.core import setup, Extension
from setuptools import setup, find_packages
from setuptools.extension import Extension
from Cython.Build import cythonize

from datetime import datetime
from platform import system, os
import numpy

cpp_stdlib = "libc++"

extra_compile_args = [
    "-std=c++11", ## Compile C++11 code
    ## Add include directories
    "-I/usr/local/include",
    "-I/usr/include",
    # "-I./source",
    "-I{0}".format(numpy.get_include()),
#     "-flto",
    "-D_GLIBCXX_USE_CXX11_ABI=0" # Cython/GCC5 issues
    ## Link-time optimization
]

extra_link_args = [
    "-std=c++11", ## Link C++11 code
    "-D_GLIBCXX_USE_CXX11_ABI=0" # Cython/GCC5 issues
]

if system() == "Darwin":
    # Set minimum target to 10.7 (supports C++11/libc++)
    os.environ["MACOSX_DEPLOYMENT_TARGET"] = "10.9"
    extra_compile_args += [ "-stdlib={0}".format(cpp_stdlib) ]


setup(
    name="pytrafficmodel",
    packages=find_packages(),
    version='{d.year}.{d.month}.{d.day}'.format(d=datetime.now()), # trust me on this one
    
    ext_modules = cythonize(Extension(
           "PedestrianCrowding.pytrafficmodel",                                # the extension name
           sources=["PedestrianCrowding/pytrafficmodel.pyx"], # the Cython source and
                                                  # additional C++ source files
           language="c++",                        # generate and compile C++ code
           extra_compile_args=extra_compile_args,
            extra_link_args=extra_link_args), 
            language_level=3
      ))
