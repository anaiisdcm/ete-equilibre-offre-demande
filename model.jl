#packages
using JuMP
#use the solver you want
using HiGHS
#package to read excel files
using XLSX

Tmax = 168 #optimization for 1 week (7*24=168 hours)
duration_t = 1

#Data loading
file = "inputs.xlsx"
sheet = "Données instantanées"

#data for load generation
load = XLSX.readdata(file, sheet, "C2:C169")
load = Float64.(coalesce(vec(load),0.0))

#data for inter generation
solar = XLSX.readdata(file, sheet, "E2:E169")
wind_on = XLSX.readdata(file, sheet, "G2:G169")
wind_off = XLSX.readdata(file, sheet, "H2:H169")
hydroFO_fatal = XLSX.readdata(file, sheet, "K2:K169")
hydroLake_fatal = XLSX.readdata(file, sheet, "L2:L169")
thermal_fatal = XLSX.readdata(file, sheet, "N2:N169")

#To get rid of potential missing values
solar           = Float64.(coalesce.(vec(solar), 0.0))
wind_on         = Float64.(coalesce.(vec(wind_on), 0.0))
wind_off        = Float64.(coalesce.(vec(wind_off), 0.0))
hydroLake_fatal = Float64.(coalesce.(vec(hydroLake_fatal), 0.0))
hydroFO_fatal   = Float64.(coalesce.(vec(hydroFO_fatal), 0.0))
thermal_fatal   = Float64.(coalesce.(vec(thermal_fatal), 0.0))

#data for production generation
sheet1 = "Production électrique"

names = XLSX.readdata(file, sheet1, "A2:A55")
Pout_max = Float64.(vec(coalesce(XLSX.readdata(file, sheet1, "B2:B55"), 0.0)))
Pout_min = Float64.(vec(coalesce(XLSX.readdata(file, sheet1, "C2:C55"), 0.0)))
dmin = Int.(vec(coalesce.(XLSX.readdata(file, sheet1, "D2:D55"), 0)))
Cost = Float64.(vec(coalesce.(XLSX.readdata(file, sheet1, "E2:E55"), 0.0)))
on_init = Int.(vec(coalesce.(XLSX.readdata(file, sheet1, "F2:F55"), 0)))
eff = Float64.(vec(coalesce.(XLSX.readdata(file, sheet1, "G2:G55"), 1.0)))
vector = String.(vec(XLSX.readdata(file, sheet1, "J2:J55")))
family = String.(vec(XLSX.readdata(file, sheet1, "K2:K55")))

#Building a set of assets
ASSETS = 1:length(names)

#Families of assets
elec_in  = Set{Int}()
elec_out = Set{Int}()
gas_in   = Set{Int}()
gas_out  = Set{Int}()
h2_in    = Set{Int}()
h2_out   = Set{Int}()

#If an asset is in several families
for a in ASSETS
    categories = split(vector[a], ";")  
    categories = strip.(categories)          
    if "elec_in" in categories
        push!(elec_in, a)
    end
    if "elec_out" in categories
        push!(elec_out, a)
    end
    if "gas_in" in categories
        push!(gas_in, a)
    end
    if "gas_out" in categories
        push!(gas_out, a)
    end
    if "h2_in" in categories
        push!(h2_in, a)
    end
    if "h2_out" in categories
        push!(h2_out, a)
    end
end

#Conversion assets
conv = Set(a for a in ASSETS if eff[a] < 1.0)

conv_ge  = Set(a for a in conv if a ∈ gas_in && a ∈ elec_out)
conv_eh2 = Set(a for a in conv if a ∈ elec_in && a ∈ h2_out)
conv_gh2 = Set(a for a in conv if a ∈ gas_in && a ∈ h2_out)

#Assets Functioning
disp  = Set(a for a in ASSETS if family[a] == "disp")
inter = Set(a for a in ASSETS if family[a] == "inter")
solar_assets = Set(a for a in inter if names[a] == "PV1")
wind_on_assets = Set(a for a in inter if names[a] == "Eolien terrestre 1")
wind_off_assets = Set(a for a in inter if names[a] == "Eolien offshore 1")
hydroFO_assets = Set(a for a in inter if names[a] == "Hydro (fil de l'eau) 1")
hydroLake_assets = Set(a for a in inter if names[a] == "Hydro lac 1")
thermal_fatal_assets = Set(a for a in inter if names[a] == "Déchet 1" || names[a] == "Biomasse 1")
stock = Set(a for a in ASSETS if family[a] == "stock")

#assets availability (100% du temps pour le moment)
Avail = Dict{Int, Vector{Float64}}()
for a in ASSETS
    Avail[a] = ones(Tmax)
end

#############################
#create the optimization model
#############################
model = Model(HiGHS.Optimizer)

#############################
#define the variables
#############################

#Power of functioning
@variable(model, P_in[a in elec_in ∪ gas_in, t in 1:Tmax] ≥ 0)
@variable(model, P_out[a in elec_out ∪ gas_out, t in 1:Tmax] ≥ 0)

#Flags disp
@variable(model, on[a in disp, t in 1:Tmax], Bin)
@variable(model, up[a in disp, t in 1:Tmax], Bin)
@variable(model, down[a in disp, t in 1:Tmax], Bin)

#Available power
@variable(model, P_in_max_avail[a in elec_in ∪ gas_in, t in 1:Tmax] ≥ 0)
@variable(model, P_out_max_avail[a in elec_out ∪ gas_out, t in 1:Tmax] ≥ 0)

# #stock variables
@variable(model, E[a in stock, t in 1:Tmax] ≥ 0)
@variable(model, isCharging[a in stock, t in 1:Tmax], Bin)

#############################
#define the constraints
#############################
#objective function
@objective(model, Min, sum(P_out[a,t] * Cost[a] for a in disp, t in 1:Tmax))

#Inter prod
@constraint(model, [a in solar_assets, t in 1:Tmax], P_out[a,t] == solar[t])
@constraint(model, [a in wind_on_assets, t in 1:Tmax], P_out[a,t] == wind_on[t])
@constraint(model, [a in wind_off_assets, t in 1:Tmax], P_out[a,t] == wind_off[t])
@constraint(model, [a in hydroFO_assets, t in 1:Tmax], P_out[a,t] == hydroFO_fatal[t])
@constraint(model, [a in hydroLake_assets, t in 1:Tmax], P_out[a,t] == hydroLake_fatal[t])
@constraint(model, [a in thermal_fatal_assets, t in 1:Tmax], P_out[a,t] == thermal_fatal[t])

#EOD elec
@constraint(model, [t in 1:Tmax], sum(P_out[a,t] for a in inter) + sum(P_out[a,t] for a in disp) + sum(P_out[a,t] for a in stock) == load[t] + sum(P_in[a,t] for a in stock))

#Availability
P_out_max_avail = Dict{Tuple{Int,Int}, Float64}()
P_in_max_avail  = Dict{Tuple{Int,Int}, Float64}()

#To avoid quadratic constraints
for a in ASSETS, t in 1:Tmax
    if a in elec_out ∪ gas_out
        P_out_max_avail[(a,t)] = Pout_max[a] * Avail[a][t]
    end
    # if a in elec_in ∪ gas_in
    #     P_in_max_avail_const[(a,t)] = Pin_max[a] * Avail[a][t]
    # end
end

#Pmin/Pmax disp
@constraint(model, [a in disp, t in 1:Tmax], P_out[a,t] ≤ P_out_max_avail[(a,t)] * on[a,t])
@constraint(model, [a in disp, t in 1:Tmax], P_out[a,t] ≥ Pout_min[a] * on[a,t])
#@constraint(model, [a in disp, t in 1:Tmax], P_in[a,t] ≤ P_in_max_avail[(a,t)] * on[a,t])
#@constraint(model, [a in disp, t in 1:Tmax], P_in[a,t] ≥ Pin_min[a] * on[a,t])


#Pmin/Pmax non disp
#@constraint(model, [a in elec_in ∪ gas_in , t in 1:Tmax], P_in[a,t] ≤ P_in_max_avail[(a,t)])
@constraint(model, [a in setdiff(elec_out, disp), t in 1:Tmax], P_out[a,t] ≤ P_out_max_avail[(a,t)])

#dmin constraints

@constraint(model, [a in disp, t in 2:Tmax], on[a,t] - on[a,t-1] == up[a,t] - down[a,t])

@constraint(model, [a in disp, t in 1:Tmax], up[a,t] + down[a,t] ≤ 1)

for a in disp
    if on_init[a] == 0
        @constraint(model, up[a,1] == on[a,1])
    else
        @constraint(model, down[a,1] == 1 - on[a,1])
    end

    if dmin[a] > 0
        @constraint(model, [t in dmin[a]:Tmax], on[a,t] ≥ sum(up[a,i] for i in t-dmin[a]+1:t))
        @constraint(model, [t in dmin[a]:Tmax], on[a,t] ≤ 1 - sum(down[a,i] for i in t-dmin[a]+1:t))
        @constraint(model, [t in 1:(dmin[a]-1)], on[a,t] >= sum(up[a,i] for i in 1:t))
        @constraint(model, [t in 1:(dmin[a]-1)], on[a,t] <= 1 - sum(down[a,i] for i in 1:t))

    end
end

#conv constraints
@constraint(model, [a in conv_ge, t in 1:Tmax], P_out[a,t] == eff[a] * P_in[a,t])

#Stock constraints

# Initial energy
E_init = Dict{Int, Float64}()

for a in stock
    E_init[a] = 0
end

E_max_avail = Dict{Tuple{Int,Int}, Float64}()
E_min_avail = Dict{Tuple{Int,Int}, Float64}()
P_in_max_avail_stock = Dict{Tuple{Int,Int}, Float64}()
P_out_max_avail_stock = Dict{Tuple{Int,Int}, Float64}()

for a in stock, t in 1:Tmax
    P_in_max_avail_stock[(a,t)]  = Pout_max[a]
    P_out_max_avail_stock[(a,t)] = Pout_max[a]
    E_max_avail[(a,t)] = P_out_max_avail_stock[(a,t)] * duration_t
    E_min_avail[(a,t)] = 0
end

@constraint(model, [a in stock], E[a,1] == E_init[a] + (eff[a]*P_in[a,1] - P_out[a,1]) * duration_t)

# Energy stock
@constraint(model, [a in stock, t in 2:Tmax], E[a,t] == E[a,t-1] + (eff[a]*P_in[a,t] - P_out[a,t]) * duration_t
)

# Charge boundaries
@constraint(model, [a in stock, t in 1:Tmax], E[a,t] <= E_max_avail[(a,t)])
@constraint(model, [a in stock, t in 1:Tmax], E[a,t] >= E_min_avail[(a,t)])

#Discharge init and max
@constraint(model, [a in stock], P_out[a,1] * duration_t <= E_init[a])
@constraint(model, [a in stock, t in 2:Tmax], P_out[a,t] * duration_t <= E[a,t-1])

#Charge and discharge available
@constraint(model, [a in stock, t in 1:Tmax], P_in[a,t] <= P_in_max_avail_stock[(a,t)] * isCharging[a,t])
@constraint(model, [a in stock, t in 1:Tmax], P_out[a,t] <= P_out_max_avail_stock[(a,t)] * (1 - isCharging[a,t]))



#solve model
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)
