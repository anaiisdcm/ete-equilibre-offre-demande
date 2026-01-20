#packages
using JuMP
#use the solver you want
using HiGHS


###########################
### 1. EOD tres simple
###########################
#create the optimization model
model = Model(HiGHS.Optimizer)
#------------------------------
#define the variables
#Nucleaire 1
@variable(model, Pnuc1 >= 0)
#Nucleaire 2
@variable(model, Pnuc2 >= 0)
#CCG
@variable(model, Pccg >= 0)
#Hydro
@variable(model, Phydro >= 0)
#Eolien
@variable(model, Peolien >= 0)
#------------------------------
#define the objective function
@objective(model, Min, 14*Pnuc1+16*Pnuc2+45*Pccg+48*Phydro+0*Peolien)
#------------------------------
#define the constraints
#la demande de 2200MWh doit être satisfaite
@constraint(model, eod, Pnuc1+Pnuc2+Pccg+Phydro+Peolien==2200)
#contraintes de production
@constraint(model, maxnuc1, Pnuc1 <= 900)
@constraint(model, maxnuc2, Pnuc2 <= 900)
@constraint(model, maxccg, Pccg <= 300)
@constraint(model, maxhydro, Phydro <= 300)
@constraint(model, maxeolien, Peolien <= 300)
#------------------------------
#print the model
print(model)
#------------------------------
#solve the model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)
@show value(Pnuc1)
@show value(Pnuc2)
@show value(Pccg)
@show value(Phydro)
@show value(Peolien)

###########################
### 2. EOD avec contrainte de minimum de fonctionnement => introduction des variables binaires
###########################
#create the optimization model
model = Model(HiGHS.Optimizer)
#------------------------------
#define the variables
#Nucleaire 1
@variable(model, Pnuc1 >= 0)
#Nucleaire 1 on (UCnuc1=1) ou off (UCnuc1=0)
@variable(model, UCnuc1, Bin)
#Nucleaire 2
@variable(model, Pnuc2 >= 0)
@variable(model, UCnuc2, Bin)
#CCG
@variable(model, Pccg >= 0)
@variable(model, UCccg, Bin)
#Hydro
@variable(model, Phydro >= 0)
#Eolien
@variable(model, Peolien >= 0)
#------------------------------
#define the objective function
@objective(model, Min, 14*Pnuc1+16*Pnuc2+45*Pccg+48*Phydro+0*Peolien)
#------------------------------
#define the constraints
#la demande de 2200MWh doit être satisfaite
@constraint(model, eod, Pnuc1+Pnuc2+Pccg+Phydro+Peolien==2200)
#contraintes de production
@constraint(model, maxnuc1, Pnuc1 <= 900*UCnuc1)
@constraint(model, minnuc1, 300*UCnuc1 <= Pnuc1)
@constraint(model, maxnuc2, Pnuc2 <= 900*UCnuc2)
@constraint(model, minnuc2, 300*UCnuc2  <= Pnuc2)
@constraint(model, maxccg, Pccg <= 300*UCccg)
@constraint(model, minccg, 150*UCccg <= Pccg)
@constraint(model, maxhydro, Phydro <= 300)
@constraint(model, maxeolien, Peolien <= 300)
#------------------------------
#print the model
print(model)
#------------------------------
#solve the model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)
@show value(Pnuc1)
@show value(Pnuc2)
@show value(Pccg)
@show value(Phydro)
@show value(Peolien)

###########################
### 3. EOD avec contrainte de rampe => problème d'optimisation sur plusieurs pas de temps et contraintes supplémentaires
###########################
#create the optimization model
model = Model(HiGHS.Optimizer)
#------------------------------
#define the variables
#Nombre de pas de temps
T = 3
#Demande pour chaque pas de temps
demande = [2200, 2450, 1900]
#Nucleaire 1
@variable(model, Pnuc1[1:T] >= 0)
#Nucleaire 1 on (UCnuc1=1) ou off (UCnuc1=0)
@variable(model, UCnuc1[1:T], Bin)
#Nucleaire 2
@variable(model, Pnuc2[1:T] >= 0)
@variable(model, UCnuc2[1:T], Bin)
#CCG
@variable(model, Pccg[1:T] >= 0)
@variable(model, UCccg[1:T], Bin)
#Hydro
@variable(model, Phydro[1:T] >= 0)
#Eolien
@variable(model, Peolien[1:T] >= 0)
#------------------------------
#define the objective function
@objective(model, Min, sum(14*Pnuc1[t]+16*Pnuc2[t]+45*Pccg[t]+48*Phydro[t]+0*Peolien[t] for t in 1:T))
#------------------------------
#define the constraints
#la demande doit être satisfaite à chaque heure t
@constraint(model, eod[t in 1:T], Pnuc1[t]+Pnuc2[t]+Pccg[t]+Phydro[t]+Peolien[t]==demande[t])
#contraintes de production
@constraint(model, maxnuc1[t in 1:T], Pnuc1[t] <= 900*UCnuc1[t])
@constraint(model, minnuc1[t in 1:T], 300*UCnuc1[t] <= Pnuc1[t])
@constraint(model, maxnuc2[t in 1:T], Pnuc2[t] <= 900*UCnuc2[t])
@constraint(model, minnuc2[t in 1:T], 300*UCnuc2[t]  <= Pnuc2[t])
@constraint(model, maxccg[t in 1:T], Pccg[t] <= 300*UCccg[t])
@constraint(model, minccg[t in 1:T], 150*UCccg[t] <= Pccg[t])
@constraint(model, maxhydro[t in 1:T], Phydro[t] <= 300)
@constraint(model, maxeolien[t in 1:T], Peolien[t] <= 300)
#contraintes de limitation de variation de la puissance
@constraint(model, rampenuc1[t in 2:T], -350 <= Pnuc1[t]-Pnuc1[t-1] <= 350)
@constraint(model, rampenuc2[t in 2:T], -350 <= Pnuc2[t]-Pnuc2[t-1] <= 350)
@constraint(model, rampeccg[t in 2:T], -200 <= Pccg[t]-Pccg[t-1] <= 200)
#------------------------------
#print the model
print(model)
#------------------------------
#solve the model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)
@show value.(Pnuc1)
@show value.(Pnuc2)
@show value.(Pccg)
@show value.(Phydro)
@show value.(Peolien)


###########################
### 4. EOD avec contrainte de Dmin => ajout de variables binaires supplémentaires
###########################
#create the optimization model
model = Model(HiGHS.Optimizer)
#------------------------------
#define the variables
#Nombre de pas de temps
T = 3
#Demande pour chaque pas de temps
demande = [2200, 2450, 1900]
#Nucleaire 1
@variable(model, Pnuc1[1:T] >= 0)
#Nucleaire 1 on (UCnuc1=1) ou off (UCnuc1=0)
@variable(model, UCnuc1[1:T], Bin)
@variable(model, UPnuc1[1:T], Bin)
@variable(model, DOnuc1[1:T], Bin)
#Nucleaire 2
@variable(model, Pnuc2[1:T] >= 0)
@variable(model, UCnuc2[1:T], Bin)
@variable(model, UPnuc2[1:T], Bin)
@variable(model, DOnuc2[1:T], Bin)
#CCG
@variable(model, Pccg[1:T] >= 0)
@variable(model, UCccg[1:T], Bin)
@variable(model, UPccg[1:T], Bin)
@variable(model, DOccg[1:T], Bin)
#Hydro
@variable(model, Phydro[1:T] >= 0)
#Eolien
@variable(model, Peolien[1:T] >= 0)
#------------------------------
#define the objective function
@objective(model, Min, sum(14*Pnuc1[t]+16*Pnuc2[t]+45*Pccg[t]+48*Phydro[t]+0*Peolien[t] for t in 1:T))
#------------------------------
#define the constraints
#la demande doit être satisfaite à chaque heure t
@constraint(model, eod[t in 1:T], Pnuc1[t]+Pnuc2[t]+Pccg[t]+Phydro[t]+Peolien[t]==demande[t])
#contraintes de production
@constraint(model, maxnuc1[t in 1:T], Pnuc1[t] <= 900*UCnuc1[t])
@constraint(model, minnuc1[t in 1:T], 300*UCnuc1[t] <= Pnuc1[t])
@constraint(model, maxnuc2[t in 1:T], Pnuc2[t] <= 900*UCnuc2[t])
@constraint(model, minnuc2[t in 1:T], 300*UCnuc2[t]  <= Pnuc2[t])
@constraint(model, maxccg[t in 1:T], Pccg[t] <= 300*UCccg[t])
@constraint(model, minccg[t in 1:T], 150*UCccg[t] <= Pccg[t])
@constraint(model, maxhydro[t in 1:T], Phydro[t] <= 300)
@constraint(model, maxeolien[t in 1:T], Peolien[t] <= 300)
#contraintes de limitation de variation de la puissance
@constraint(model, rampenuc1[t in 2:T], -350 <= Pnuc1[t]-Pnuc1[t-1] <= 350)
@constraint(model, rampenuc2[t in 2:T], -350 <= Pnuc2[t]-Pnuc2[t-1] <= 350)
@constraint(model, rampeccg[t in 2:T], -200 <= Pccg[t]-Pccg[t-1] <= 200)
#contraintes liant UC, UP et DO
@constraint(model, fctnuc1[t in 2:T], UCnuc1[t]-UCnuc1[t-1]==UPnuc1[t]-DOnuc1[t])
@constraint(model, UPDOnuc1[t in 1:T], UPnuc1[t]+DOnuc1[t]<=1)
@constraint(model, iniUPnuc1, UPnuc1[1]==UCnuc1[1])
@constraint(model, iniDOnuc1, DOnuc1[1]==1-UCnuc1[1])
@constraint(model, fctnuc2[t in 2:T], UCnuc2[t]-UCnuc2[t-1]==UPnuc2[t]-DOnuc2[t])
@constraint(model, UPDOnuc2[t in 1:T], UPnuc2[t]+DOnuc2[t]<=1)
@constraint(model, iniUPnuc2, UPnuc2[1]==UCnuc2[1])
@constraint(model, iniDOnuc2, DOnuc2[1]==1-UCnuc2[1])
@constraint(model, fctccg[t in 2:T], UCccg[t]-UCccg[t-1]==UPccg[t]-DOccg[t])
@constraint(model, UPDOccg[t in 1:T], UPccg[t]+DOccg[t]<=1)
@constraint(model, iniUPccg, UPccg[1]==UCccg[1])
@constraint(model, iniDOccg, DOccg[1]==1-UCccg[1])
#contraintes de Dmin de fonctionnement
@constraint(model, dminnuc1[t in min(24,T):T], UCnuc1[t] >= sum(UPnuc1[i] for i in (t-min(24,T)+1):t))
@constraint(model, dminnuc1_init[t in 1:2], UCnuc1[t] >= sum(UPnuc1[i] for i in 1:t))
@constraint(model, dminnuc2[t in min(24,T):T], UCnuc2[t] >= sum(UPnuc2[i] for i in (t-min(24,T)+1):t))
@constraint(model, dminnuc2_init[t in 1:2], UCnuc2[t] >= sum(UPnuc2[i] for i in 1:t))
@constraint(model, dminccg[t in 3:T], UCccg[t] >= sum(UPccg[i] for i in (t-3+1):t))
@constraint(model, dminccg_init[t in 1:2], UCccg[t] >= sum(UPccg[i] for i in 1:t))
#------------------------------
#print the model
print(model)
#------------------------------
#solve the model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)
@show value.(Pnuc1)
@show value.(Pnuc2)
@show value.(Pccg)
@show value.(Phydro)
@show value.(Peolien)
