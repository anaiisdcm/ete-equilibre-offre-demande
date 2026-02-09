#packages
using JuMP
#use the solver you want
using HiGHS
#package to read excel files
using XLSX

Tmax = 168 #optimization for 1 week (7*24=168 hours)

#data for load and inter generation
data_file = "inputs.xlsx"

#data for load generation
load = XLSX.readdata(data_file, "Données instantanées", "C2:C169")
load = Float64.(vec(load))

#data for inter generation
solar = XLSX.readdata(data_file, "Données instantanées", "E2:E169")
wind_on = XLSX.readdata(data_file, "Données instantanées", "G2:G169")
wind_off = XLSX.readdata(data_file, "Données instantanées", "H2:H169")
hydroFO_fatal = XLSX.readdata(data_file, "Données instantanées", "K2:K169")
hydroLake_fatal = XLSX.readdata(data_file, "Données instantanées", "L2:L169")
thermal_fatal = XLSX.readdata(data_file, "Données instantanées", "N2:N169")

#To get rid of potential missing values
solar           = Float64.(coalesce.(vec(solar), 0.0))
wind_on         = Float64.(coalesce.(vec(wind_on), 0.0))
wind_off        = Float64.(coalesce.(vec(wind_off), 0.0))
hydroLake_fatal = Float64.(coalesce.(vec(hydroLake_fatal), 0.0))
hydroFO_fatal   = Float64.(coalesce.(vec(hydroFO_fatal), 0.0))
thermal_fatal   = Float64.(coalesce.(vec(thermal_fatal), 0.0))

#data for disp clusters
N_disp = 39
names_disp = XLSX.readdata(data_file, "Production électrique", "A2:A40")
dictdisp = Dict(i=> names_disp[i] for i in 1:N_disp)
Pout_max_disp = XLSX.readdata(data_file, "Production électrique", "B2:B40") #MW
Pout_min_disp = XLSX.readdata(data_file, "Production électrique", "C2:C40") #MW
#Pin_max_disp = XLSX.readdata(data_file, "Production électrique", "") #MW
#Pin_min_disp = XLSX.readdata(data_file, "Production électrique", "") #MW
dmin_disp = XLSX.readdata(data_file, "Production électrique", "D2:D40") #hours
costs_disp = XLSX.readdata(data_file, "Production électrique", "E2:E40") #$/MWh
efficacity_disp = XLSX.readdata(data_file, "Production électrique", "G2:G40")

Pout_max_disp = Float64.(vec(Pout_max_disp))
Pout_min_disp = Float64.(vec(Pout_min_disp))
dmin_disp     = Int.(vec(dmin_disp))
costs_disp = Float64.(vec(costs_disp))
efficacity_disp = Float64.(vec(efficacity_disp))


#data for conv clusters
N_conv = 31
#Créer une feuille Excel avec les converters ?


#data for inter assets
N_inter = 7
Pmax_inter = XLSX.readdata(data_file, "Production électrique", "B41:B47") #MW
Pmax_inter = Float64.(vec(Pmax_inter))

#costs
c_disp = repeat(costs_disp', Tmax) #cost of disp generation $/MWh
cuns = 5000*ones(Tmax) #cost of unsupplied energy $/MWh
cexc = zeros(Tmax) #cost of in excess energy $/MWh

#############################
#create the optimization model
#############################
model = Model(HiGHS.Optimizer) #J'ai laissé ce solver pour l'instant.

#############################
#define the variables
#############################
#thermal generation variables
#@variable(model, Pin_disp[1:Tmax,1:N_disp] >= 0)
@variable(model, Pout_disp[1:Tmax,1:N_disp] >= 0)
@variable(model, Pinter[1:Tmax,1:N_inter] >= 0)
@variable(model, UCdisp[1:Tmax,1:N_disp], Bin)
@variable(model, UPdisp[1:Tmax,1:N_disp], Bin)
@variable(model, DOdisp[1:Tmax,1:N_disp], Bin)

#unsupplied energy variables
@variable(model, Puns[1:Tmax] >= 0)
#in excess energy variables
@variable(model, Pexc[1:Tmax] >= 0)
#
# #############################
#define the objective function
#############################
@objective(model, Min, sum(Pout_disp .* c_disp) + (Puns'cuns) + (Pexc'cexc))

#############################
#define the constraints
#############################
#balance constraint
@constraint(model, balance[t in 1:Tmax], sum(Pout_disp[t,g] for g in 1:N_disp) + solar[t] + wind_on[t] + wind_off[t] + thermal_fatal[t] + hydroFO_fatal[t] + hydroLake_fatal[t] + Puns[t] - load[t] - Pexc[t] == 0)
# inter assets Pmax constraints
@constraint(model, max_inter[t in 1:Tmax, g in 1:N_inter], Pinter[t,g] <= Pmax_inter[g])
#disp unit Pmax in and out constraints
#@constraint(model, P_max_in_disp[t in 1:Tmax, g in 1:N_disp], Pin_disp[t,g] <= Pin_max_disp[g]*UCdisp[t,g])
@constraint(model, P_max_out_disp[t in 1:Tmax, g in 1:N_disp], Pout_disp[t,g] <= Pout_max_disp[g]*UCdisp[t,g])
#disp unit Pmin in and out constraints
#@constraint(model, P_min_in_disp[t in 1:Tmax, g in 1:N_disp], Pin_min_disp[g] * UCdisp[t,g] <= Pin_disp[t,g])
@constraint(model, P_min_out_disp[t in 1:Tmax, g in 1:N_disp], Pout_min_disp[g] * UCdisp[t,g] <= Pout_disp[t,g])

#Initial state data
on_init = XLSX.readdata(data_file, "Production électrique", "H2:H40")
on_init = Int.(vec(coalesce.(on_init, 0)))

#disp unit Dmin constraints
for g in 1:N_disp
        if (dmin_disp[g] > 1)
            @constraint(model, [t in 2:Tmax], UCdisp[t,g]-UCdisp[t-1,g]==UPdisp[t,g]-DOdisp[t,g],  base_name = "fct_disp_$g")
            @constraint(model, [t in 1:Tmax], UPdisp[t,g]+DOdisp[t,g]<=1,  base_name = "UPDOdisp_$g")
            # Up-init constraint
            if on_init[g] == 0
                @constraint(model, UPdisp[1,g] == UCdisp[1,g], base_name = "iniUPdisp_$g")
            else
                @constraint(model, UPdisp[1,g] == 0, base_name = "iniUPdisp_$g")
            end
            # Down-init constraint
            if on_init[g] > 0
                @constraint(model, DOdisp[1,g] == 1 - UCdisp[1,g], base_name = "iniDOdisp_$g")
            else
                @constraint(model, DOdisp[1,g] == 0, base_name = "iniDOdisp_$g")
            end
            # Dmin_up constraint
            @constraint(model, [t in dmin_disp[g]:Tmax], UCdisp[t,g] >= sum(UPdisp[i,g] for i in (t-dmin_disp[g]+1):t),  base_name = "dminUPdisp_$g")
            # Dmin_down constraint
            @constraint(model, [t in dmin_disp[g]:Tmax], UCdisp[t,g] <= 1 - sum(DOdisp[i,g] for i in (t-dmin_disp[g]+1):t),  base_name = "dminDOdisp_$g")
            @constraint(model, [t in 1:dmin_disp[g]-1], UCdisp[t,g] >= sum(UPdisp[i,g] for i in 1:t), base_name = "disp_dispUPdisp_$(g)_init")
            @constraint(model, [t in 1:dmin_disp[g]-1], UCdisp[t,g] <= 1-sum(DOdisp[i,g] for i in 1:t), base_name = "disp_dispDOdisp_$(g)_init")
    end
end

#Conversion constraint (il faut avoir les contraintes sur Pin_disp pour décommenter)
#@constraint(model, [t in 1:Tmax, g in 1:N_disp], Pout_disp[t,g] <= efficacity_disp[g] * Pin_disp[t,g])


#TODO: solve and analyse dispe results
#solve dispe model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)


# #exports results as csv file
# disp_gen = value.(Pdisp)


# # new file created
# touch("results.csv")

# # file handling in write mode
# f = open("results.csv", "w")

# for name in names
#     write(f, "$name ;")
# end
# write(f, "Hydro ; STEP pompage ; STEP turbinage ; Batterie injection ; Batterie soutirage ; RES ; load ; Net load \n")

# for t in 1:Tmax
#     for g in 1:Nth
#         write(f, "$(th_gen[t,g]) ; ")
#     end
#     for h in 1:Nhy
#         write(f, "$(hy_gen[t,h]) ;")
#     end
#     write(f, "$(STEP_charge[t]) ; $(STEP_decharge[t]) ;")
#     write(f, "$(battery_charge[t]) ; $(battery_decharge[t]) ;")
#     write(f, "$(Pres[t]) ;  $(load[t]) ; $(load[t]-Pres[t]) \n")

# end

# close(f)

