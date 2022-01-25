import numpy as np
from numpy import *
from scipy import io
from numpy.linalg import *
import matplotlib.pyplot as plt

# https://numpy.org/doc/stable/user/numpy-for-matlab-users.html
# https://github.com/victorlei/smop
    
def t_disp(disp = None): 
    vmax,umax = disp.shape
    v_map = dot(np.transpose(np.array([np.arange(1,vmax+1)])), np.ones((1,umax)))
    u_map = dot(np.ones((vmax,1)), np.array([np.arange(1,umax+1)]))
    import ipdb; ipdb.set_trace()
    v = np.reshape(v_map, tuple(np.array([vmax*umax,1])), order="F")
    u = np.reshape(u_map, tuple(np.array([vmax*umax,1])), order="F")
    d = np.reshape(disp, tuple(np.array([vmax*umax,1])), order="F")
    u[d == 0] = []
    v[d == 0] = []
    d[d == 0] = []
    Su = sum(u)
    Sv = sum(v)
    Sd = sum(d)
    Su2 = sum(u ** 2)
    Sv2 = sum(v ** 2)
    Sdu = sum(np.multiply(u,d))
    Sdv = sum(np.multiply(v,d))
    Suv = sum(np.multiply(u,v))
    n = len(u)
    beta0=(dot(Sd ** 2,(Sv2 + Su2)) - dot(dot(2,Sd),(dot(Sv,Sdv) + dot(Su,Sdu))) + dot(n,(Sdv ** 2 + Sdu ** 2))) / 2
    beta1=(dot(Sd ** 2,(Sv2 - Su2)) + dot(dot(2,Sd),(dot(Su,Sdu) - dot(Sv,Sdv))) + dot(n,(Sdv ** 2 - Sdu ** 2))) / 2
    beta2=dot(- Sd ** 2,Suv) + dot(Sd,(dot(Sv,Sdu) + dot(Su,Sdv))) - dot(dot(n,Sdv),Sdu)
    gamma0=(dot(n,Sv2) + dot(n,Su2) - Sv ** 2 - Su ** 2) / 2
    gamma1=(dot(n,Sv2) - dot(n,Su2) - Sv ** 2 + Su ** 2) / 2
    gamma2=dot(Sv,Su) - dot(n,Suv)
    del(Su)
    del(Sv)
    del(Sd)
    del(Su2)
    del(Sv2)
    del(Sdu)
    del(Sdv)
    del(Suv)
    del(vmax)
    del(umax)

    A=(dot(beta1,gamma0) - dot(beta0,gamma1))
    B=(dot(beta0,gamma2) - dot(beta2,gamma0))
    C=(dot(beta1,gamma2) - dot(beta2,gamma1))
    delta = A ** 2 + B ** 2 - C ** 2
    tmp1 = (A + np.sqrt(delta)) / (B - C)
    tmp2 = (A - np.sqrt(delta)) / (B - C)
    theta1 = np.arctan(tmp1)
    theta2 = np.arctan(tmp2)
    del(A)
    del(B)
    del(C)
    del(beta0)
    del(beta1)
    del(beta2)
    del(gamma0)
    del(gamma1)
    del(gamma2)
    del(tmp1)
    del(tmp2)
    del(delta)
    t1=dot(v,cos(theta1)) - dot(u,sin(theta1))
    t2=dot(v,cos(theta2)) - dot(u,sin(theta2))
    T1 = np.array([np.ones((n,1)),t1])
    T2 = np.array([np.ones((n,1)),t2])
    f1=dot(dot(dot(dot(d.T,T1),inv(dot(T1.T,T1))),T1.T),d)
    f2=dot(dot(dot(dot(d.T,T2),inv(dot(T2.T,T2))),T2.T),d)
    if f1 < f2:
        theta = theta2
    else:
        theta = theta1
    
    del(t1)
    del(t2)
    del(T1)
    del(T2)
    del(f1)
    del(f2)
    del(theta1)
    del(theta2)
    t = v@np.cos(theta) - u@np.sin(theta)
    T = np.array([np.ones((n,1)),t])
    a = inv(np.transpose(T)@T)@np.transpose(T)@d
    t_map = v_map@np.cos(theta) - u_map@np.sin(theta)
    disp1 = disp - (a(1) + a(2)@t_map) + 30
    disp1[disp == 0] = 0
    del(t_map)
    del(v_map)
    del(u_map)
    del(theta)
    del(a)
    del(u)
    del(v)
    del(d)
    del(t)
    del(n)
    del(T)
    # disp1 is the transformed disparity map
    
    #{
    figure
    ax = subplot(2,1,1)
    imshow(disp,[],'Colormap',jet(4096))
    plt.title('original disparity map')
    ax = subplot(2,1,2)
    imshow(disp1,[],'Colormap',jet(4096))
    plt.title('transformed disparity map')
    #}
    return disp1
    
if __name__=="__main__":
    t_disp(io.loadmat("data.mat")['disp'])