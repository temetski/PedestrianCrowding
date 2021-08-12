roadlen = 500
num_lanes = 1
np.random.seed(2882936862)
# randseed = np.random.get_state()
# alpha1 = 10**-2.3
# alpha2 = 10**-1.9

density = 0.4
alpha1 = 10**-2
alpha2 = 10**-1.8

# density = 0.5
# alpha1 = 10**-1.6
# alpha2 = 10**-1.2


frac_bus = 1/num_lanes
road1 = Road(roadlen, num_lanes, vmax=5, alpha=alpha1, frac_bus=frac_bus, periodic=True, density=density, p_slow=0.1)
road2 = Road(roadlen, num_lanes, vmax=5, alpha=alpha2, frac_bus=frac_bus, periodic=True, density=density, p_slow=0.1)

T = 3000
timefactor = 6
num_subplots = 2

std = np.zeros((num_subplots, T, num_lanes, roadlen))
for i in range(T):
    std[0,i] = road1.get_road()
    std[1,i] = road2.get_road()
    road1.timestep_parallel()
    road2.timestep_parallel()

fig_width = 3
my_cmap = matplotlib.cm.get_cmap('gray_r')
my_cmap.set_over('r')
fig, axes = plt.subplots(1,num_subplots,figsize=(fig_width,fig_width/num_subplots*(T/roadlen/timefactor)*1.5), dpi=400, sharey=True, sharex=True)
if num_subplots == 1:
    axes = [axes]
for i, ax in enumerate(axes):
    im = ax.imshow(1*(std[i,::timefactor,0,:]), origin="lower", cmap=my_cmap, vmax=1.001, 
                   extent=(0,roadlen,0,T), aspect="auto")

axes[0].set_title(r"$\alpha=10^{%.1f}$"%np.log10(alpha1))    
axes[1].set_title(r"$\alpha=10^{%.1f}$"%np.log10(alpha2)) 
axes[0].tick_params(axis="x", labelsize=6)
axes[0].tick_params(axis="y", labelsize=6)
axes[1].tick_params(axis="x", labelsize=6)
axes[0].locator_params(nbins=3)

ax_par = fig.add_subplot(111, frameon=False)
ax_par.set_xlabel("position")
ax_par.set_ylabel("time")
ax_par.tick_params(labelcolor='none', top=False, bottom=False, left=False, right=False)
fig.savefig("../images/std_comparison_fb_%.2f.pdf"%(frac_bus), bbox_inches="tight")
# print("did not save image")