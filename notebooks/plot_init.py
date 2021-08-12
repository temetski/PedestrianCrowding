# load libraries and set plot parameters
# import numpy as np

# plt.rcParams['text.usetex'] = True

label_size = 10
font_size = 7
legend_size = 7

def ticks_size():
    """Size of axes' ticks
    """
    return 8


def axis_lw():
    """Line width of the axes
    """
    return 0.6


def plot_lw():
    """Line width of the plotted curves
    """
    return 1.5


params = {'savefig.dpi': 300,
#               'text.usetex': True,
              'figure.dpi': 300,
              'figure.figsize': [3.5, 3.5/4*3],
              'font.size': font_size,
              'axes.labelsize': label_size,
              'axes.titlesize': label_size,
              'axes.linewidth': axis_lw(),
              'xtick.labelsize': ticks_size(),
              'ytick.labelsize': ticks_size(),
              'font.family': 'serif',
              'legend.fontsize': legend_size,
              'lines.markersize': 8,
         'grid.linewidth': 0.2,
         'grid.linestyle': '--',
         'legend.framealpha': 1,
         'legend.frameon': True}