#packages
using JuMP
#use the solver you want
using HiGHS
#package to read excel files
using XLSX

Tmax = 168 #optimization for 1 week (7*24=168 hours)
duration_t = 1

#Data loading
file = "inputs_stock.xlsx"

#LOAD ASSETS DATA
sheet1 = "ASSETS"

raw_names = vec(XLSX.readdata(file, sheet1, "A2:A10000"))
n_assets = count(!ismissing, raw_names)

function read_col(file, sheet, col, default, T, n)
    data = vec(XLSX.readdata(file, sheet, "$(col)2:$(col)10000"))
    return T.(coalesce.(data, default))[1:n]
end

function read_col_dict(file, sheet, col, default, T, n, name)
    data = vec(XLSX.readdata(file, sheet, "$(col)2:$(col)10000"))
    data = T.(coalesce.(data, default))[1:n]
    dict = Dict(name[i] => data[i] for i in eachindex(name))
    return dict
end

name = read_col(file, sheet1, "A", "", String, n_assets)
energy_in = read_col_dict(file, sheet1, "B", "", String, n_assets, name)
energy_out = read_col_dict(file, sheet1, "C", "", String, n_assets, name)
region = read_col_dict(file, sheet1, "D", "n", String, n_assets, name)
avail = read_col_dict(file, sheet1, "E", 0.0, Float64, n_assets, name)
Pout_max = read_col_dict(file, sheet1, "F", 0.0, Float64, n_assets, name)
Pout_min = read_col_dict(file, sheet1, "G", 0.0, Float64, n_assets, name)
dmin =  read_col_dict(file, sheet1, "H", 0, Int, n_assets, name)
on_init =  read_col_dict(file, sheet1, "I", 0, Int, n_assets, name)
eff = read_col_dict(file, sheet1, "J", 1.0, Float64, n_assets, name)
E_max = read_col_dict(file, sheet1, "K", 0.0, Float64, n_assets, name)
E_init = read_col_dict(file, sheet1, "L", 0.0, Float64, n_assets, name)
price = read_col_dict(file, sheet1, "M", 0.0, Float64, n_assets, name)
family = read_col_dict(file, sheet1, "N", "", String, n_assets, name)

#Building a set of assets
ASSETS = Set(String.(vec(name)))

#Families of assets
elec_in  = Set{String}()
elec_out = Set{String}()
gas_in   = Set{String}()
gas_out  = Set{String}()
h2_in    = Set{String}()
h2_out   = Set{String}()

for asset in name
    ein  = energy_in[asset]
    eout = energy_out[asset]

    ein == "elec" && push!(elec_in, asset)
    ein == "gas"  && push!(gas_in, asset)
    ein == "h2"   && push!(h2_in, asset)

    eout == "elec" && push!(elec_out, asset)
    eout == "gas"  && push!(gas_out, asset)
    eout == "h2"   && push!(h2_out, asset)
end

#Conversion assets
conv = Set(a for a in ASSETS if eff[a] < 1.0)

conv_ge  = Set(a for a in conv if a in gas_in && a in elec_out)
conv_eh2 = Set(a for a in conv if a in elec_in && a in h2_out)
conv_gh2 = Set(a for a in conv if a in gas_in && a in h2_out)

#Assets Functioning
disp  = Set(a for a in ASSETS if family[a] == "disp")
inter = Set(a for a in ASSETS if family[a] == "inter")
solar_assets = Set(a for a in inter if occursin("PV", a))
wind_on_assets = Set(a for a in inter if a == "Eolien terrestre 1")
wind_off_assets = Set(a for a in inter if a == "Eolien offshore 1")
hydroFO_assets = Set(a for a in inter if a == "Hydro (fil de l'eau) 1")
hydroLake_assets = Set(a for a in inter if a == "Hydro lac 1")
thermal_fatal_assets = Set(a for a in inter if a == "Déchet 1" || a == "Biomasse 1")
stock = Set(a for a in ASSETS if family[a] == "stock")

#assets availability (100% du temps pour le moment)
Avail = Dict{String, Vector{Float64}}()
for a in ASSETS
    Avail[a] = ones(Tmax)*avail[a]
end

# LOAD CONSUMTION AND PRODUCTION TIMESERIES
sheet2 = "TIMESERIES"

#data for electric load
load_elec = XLSX.readdata(file, sheet2, "C2:C169")
load_elec = Float64.(coalesce(vec(load_elec),0.0))
load_gas = XLSX.readdata(file, sheet2, "D2:D169")
load_gas = Float64.(coalesce(vec(load_gas),0.0))
load_h2 = XLSX.readdata(file, sheet2, "E2:E169")
load_h2 = Float64.(coalesce(vec(load_h2),0.0))
#data for inter generation
solar = XLSX.readdata(file, sheet2, "F2:F169")
wind_on = XLSX.readdata(file, sheet2, "H2:H169")
wind_off = XLSX.readdata(file, sheet2, "I2:I169")
hydroFO_fatal = XLSX.readdata(file, sheet2, "L2:L169")
hydroLake_fatal = XLSX.readdata(file, sheet2, "M2:M169")
thermal_fatal = XLSX.readdata(file, sheet2, "O2:O169")
#To get rid of potential missing values
solar           = Float64.(coalesce.(vec(solar), 0.0))
wind_on         = Float64.(coalesce.(vec(wind_on), 0.0))
wind_off        = Float64.(coalesce.(vec(wind_off), 0.0))
hydroLake_fatal = Float64.(coalesce.(vec(hydroLake_fatal), 0.0))
hydroFO_fatal   = Float64.(coalesce.(vec(hydroFO_fatal), 0.0))
thermal_fatal   = Float64.(coalesce.(vec(thermal_fatal), 0.0))

#LOAD INTERCONNEXION DATA
sheet3 = "INTERCONN"

raw_names = vec(XLSX.readdata(file, sheet3, "A2:A10000"))
n_interconn = count(!ismissing, raw_names)
name = read_col(file, sheet3, "A", "", String, n_interconn)

interconn_pmax = read_col_dict(file, sheet3, "B", 0.0, Float64, n_interconn, name)
interconn_avail = read_col_dict(file, sheet3, "C", 0.0, Float64, n_interconn, name)
interconn_energy = read_col_dict(file, sheet3, "D", "", String, n_interconn, name)
interconn_region_ref = read_col_dict(file, sheet3, "E", "n", String, n_interconn, name)

#############################
#create the optimization model
#############################
model = Model(HiGHS.Optimizer)

#############################
#define the variables
#############################

#Power of functioning
@variable(model, P_in[a in union(elec_in, gas_in, h2_in), t in 1:Tmax] ≥ 0)
@variable(model, P_out[a in union(elec_out, gas_out, h2_out), t in 1:Tmax] ≥ 0)

#Flags disp
@variable(model, on[a in disp, t in 1:Tmax], Bin)
@variable(model, up[a in disp, t in 1:Tmax], Bin)
@variable(model, down[a in disp, t in 1:Tmax], Bin)

#Available power
@variable(model, P_in_max_avail[a in union(elec_in, gas_in, h2_in), t in 1:Tmax] ≥ 0)
@variable(model, P_out_max_avail[a in union(elec_out, gas_out, h2_out), t in 1:Tmax] ≥ 0)

# #stock variables
@variable(model, E[a in stock, t in 1:Tmax] ≥ 0)
@variable(model, isCharging[a in stock, t in 1:Tmax], Bin)

#############################
#define the constraints
#############################
#objective function
@objective(model, Min, sum(P_out[a,t] * price[a] for a in ASSETS, t in 1:Tmax))

#Inter prod
@constraint(model, [a in solar_assets, t in 1:Tmax], P_out[a,t] == solar[t])
@constraint(model, [a in wind_on_assets, t in 1:Tmax], P_out[a,t] == wind_on[t])
@constraint(model, [a in wind_off_assets, t in 1:Tmax], P_out[a,t] == wind_off[t])
@constraint(model, [a in hydroFO_assets, t in 1:Tmax], P_out[a,t] == hydroFO_fatal[t])
@constraint(model, [a in hydroLake_assets, t in 1:Tmax], P_out[a,t] == hydroLake_fatal[t])
@constraint(model, [a in thermal_fatal_assets, t in 1:Tmax], P_out[a,t] == thermal_fatal[t])

#EOD elec
if !isempty(union(elec_out, elec_in))
    @constraint(model, eod_elec[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(elec_out,inter))
    + sum(P_out[a,t] for a in intersect(elec_out,disp))
    + sum(P_out[a,t] for a in intersect(elec_out,stock))
    == load_elec[t] +
    sum(P_in[a,t] for a in intersect(elec_in,stock))
    + sum(P_in[a,t] for a in intersect(elec_in,disp)))
end

#EOD gas
if !isempty(union(gas_out, gas_in))
    @constraint(model, eod_gas[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(gas_out,inter))
    + sum(P_out[a,t] for a in intersect(gas_out,disp))
    + sum(P_out[a,t] for a in intersect(gas_out,stock))
    == load_gas[t]
    + sum(P_in[a,t] for a in intersect(gas_in,stock))
    + sum(P_in[a,t] for a in intersect(gas_in,disp)))
end

#EOD h2
if !isempty(union(h2_out, h2_in))
    @constraint(model, eod_h2[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(h2_out,inter))
    + sum(P_out[a,t] for a in intersect(h2_out,disp))
    + sum(P_out[a,t] for a in intersect(h2_out,stock))
    == load_h2[t]
    + sum(P_in[a,t] for a in intersect(h2_in,stock))
    + sum(P_in[a,t] for a in intersect(h2_in,disp)))
end

#Availability
P_out_max_avail = Dict{Tuple{String,Int}, Float64}()
P_in_max_avail  = Dict{Tuple{String,Int}, Float64}()

#To avoid quadratic constraints
for a in ASSETS, t in 1:Tmax
    if a in union(elec_out,gas_out)
        P_out_max_avail[(a,t)] = Pout_max[a] * Avail[a][t]
    end
    # if a in union(elec_in,gas_in)
    #     P_in_max_avail_const[(a,t)] = Pin_max[a] * Avail[a][t]
    # end
end

#Pmin/Pmax disp
@constraint(model, p_max_out_disp[a in intersect(disp,union(elec_out, gas_out, h2_out)), t in 1:Tmax], P_out[a,t] ≤ P_out_max_avail[(a,t)] * on[a,t])
@constraint(model, p_min_out_disp[a in intersect(disp,union(elec_out, gas_out, h2_out)), t in 1:Tmax], P_out[a,t] ≥ Pout_min[a] * on[a,t])
#@constraint(model, [a in disp, t in 1:Tmax], P_in[a,t] ≤ P_in_max_avail[(a,t)] * on[a,t])
#@constraint(model, [a in disp, t in 1:Tmax], P_in[a,t] ≥ Pin_min[a] * on[a,t])


#Pmin/Pmax non disp
#@constraint(model, [a in elec_in ∪ gas_in , t in 1:Tmax], P_in[a,t] ≤ P_in_max_avail[(a,t)])
@constraint(model, p_max_out[a in setdiff(union(elec_out, gas_out, h2_out), disp), t in 1:Tmax], P_out[a,t] ≤ P_out_max_avail[(a,t)])

#dmin constraints
@constraint(model, up_down_1[a in disp, t in 2:Tmax], on[a,t] - on[a,t-1] == up[a,t] - down[a,t])

@constraint(model, up_down_2[a in disp, t in 1:Tmax], up[a,t] + down[a,t] ≤ 1)

@constraint(model, up_init[a in disp; on_init[a] == 0], up[a,1] == on[a,1])
@constraint(model, down_init[a in disp; on_init[a] == 1], down[a,1] == 1 - on[a,1])

@constraint(model,
    dmin_on[a in disp, t in 1:Tmax; dmin[a] > 0 && t >= dmin[a]],
    on[a,t] >= sum(up[a,i] for i in t-dmin[a]+1:t)
)

@constraint(model,
    dmin_off[a in disp, t in 1:Tmax; dmin[a] > 0 && t >= dmin[a]],
    on[a,t] <= 1 - sum(down[a,i] for i in t-dmin[a]+1:t)
)

@constraint(model,
    dmin_on_init[a in disp, t in 1:Tmax; dmin[a] > 0 && t < dmin[a]],
    on[a,t] >= sum(up[a,i] for i in 1:t)
)

@constraint(model,
    dmin_off_init[a in disp, t in 1:Tmax; dmin[a] > 0 && t < dmin[a]],
    on[a,t] <= 1 - sum(down[a,i] for i in 1:t)
)

#conv constraints
@constraint(model, conv_eff[a in conv, t in 1:Tmax], P_out[a,t] == eff[a] * P_in[a,t])

#Stock constraints
E_max_avail = Dict{Tuple{String,Int}, Float64}()
E_min_avail = Dict{Tuple{String,Int}, Float64}()
P_in_max_avail_stock = Dict{Tuple{String,Int}, Float64}()
P_out_max_avail_stock = Dict{Tuple{String,Int}, Float64}()

for a in stock, t in 1:Tmax
    P_in_max_avail_stock[(a,t)]  = Pout_max[a]
    P_out_max_avail_stock[(a,t)] = Pout_max[a]
    E_max_avail[(a,t)] = E_max[a] * Avail[a][t]
    E_min_avail[(a,t)] = 0
end

# Energy stock init
@constraint(model, energy_init[a in stock], E[a,1] == E_init[a] + (eff[a]*P_in[a,1] - P_out[a,1]) * duration_t)

# Energy stock
@constraint(model, stock_energy[a in stock, t in 2:Tmax], E[a,t] == E[a,t-1] + (eff[a]*P_in[a,t] - P_out[a,t]) * duration_t
)

# # Charge boundaries
# @constraint(model, [a in stock, t in 1:Tmax], E[a,t] <= E_max_avail[(a,t)])
# @constraint(model, [a in stock, t in 1:Tmax], E[a,t] >= E_min_avail[(a,t)])

#Discharge init and max
@constraint(model, discharge_max_stock_init[a in stock], P_out[a,1] * duration_t <= E_init[a])
@constraint(model, discharge_max_stock[a in stock, t in 2:Tmax], P_out[a,t] * duration_t <= E[a,t-1])

#Charge and discharge available
@constraint(model, p_charge_avail[a in stock, t in 1:Tmax], P_in[a,t] <= P_in_max_avail_stock[(a,t)] * isCharging[a,t])
@constraint(model, p_discharge_avail[a in stock, t in 1:Tmax], P_out[a,t] <= P_out_max_avail_stock[(a,t)] * (1 - isCharging[a,t]))


#solve model
set_optimizer_attribute(model, "mip_rel_gap", 0.005)
optimize!(model)
#------------------------------
#Results
@show termination_status(model)
@show objective_value(model)

outfile = "results.xlsx"

XLSX.openxlsx(outfile, mode="w") do xf

    ############################
    # SHEET 1 : P_out
    ############################
    sheet = XLSX.addsheet!(xf, "P_out")

    # header
    sheet["A1"] = "Time"
    for (j,a) in enumerate(union(elec_out, gas_out))
        sheet[1, j+1] = a
    end

    # values
    for t in 1:Tmax
        sheet[t+1, 1] = t
        for (j,a) in enumerate(union(elec_out, gas_out))
            sheet[t+1, j+1] = value(P_out[a,t])
        end
    end

    ############################
    # SHEET 2 : P_in
    ############################
    sheet = XLSX.addsheet!(xf, "P_in")

    sheet["A1"] = "Time"
    for (j,a) in enumerate(union(elec_in, gas_in))
        sheet[1, j+1] = a
    end

    for t in 1:Tmax
        sheet[t+1, 1] = t
        for (j,a) in enumerate(union(elec_in, gas_in))
            sheet[t+1, j+1] = value(P_in[a,t])
        end
    end

    ############################
    # SHEET 3 : STOCK ENERGY
    ############################
    sheet = XLSX.addsheet!(xf, "Stock_E")

    sheet["A1"] = "Time"
    for (j,a) in enumerate(stock)
        sheet[1, j+1] = a
    end

    for t in 1:Tmax
        sheet[t+1, 1] = t
        for (j,a) in enumerate(stock)
            sheet[t+1, j+1] = value(E[a,t])
        end
    end

end
