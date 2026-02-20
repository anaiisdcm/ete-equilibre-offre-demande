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
avail = read_col_dict(file, sheet1, "E", 1.0, Float64, n_assets, name)
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

for asset in ASSETS
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

#Region of assets
north = Set(a for a in ASSETS if region[a] == "n")
south = Set(a for a in ASSETS if region[a] == "s")

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
load_gas_north = XLSX.readdata(file, sheet2, "D2:D169")
load_gas_north = Float64.(coalesce(vec(load_gas_north),0.0))
load_gas_south = XLSX.readdata(file, sheet2, "E2:E169")
load_gas_south = Float64.(coalesce(vec(load_gas_south),0.0))
load_h2_north = XLSX.readdata(file, sheet2, "F2:F169")
load_h2_north = Float64.(coalesce(vec(load_h2_north),0.0))
#data for inter generation
solar = XLSX.readdata(file, sheet2, "G2:G169")
wind_on = XLSX.readdata(file, sheet2, "I2:I169")
wind_off = XLSX.readdata(file, sheet2, "J2:J169")
hydroFO_fatal = XLSX.readdata(file, sheet2, "M2:M169")
hydroLake_fatal = XLSX.readdata(file, sheet2, "N2:N169")
thermal_fatal = XLSX.readdata(file, sheet2, "P2:P169")
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
interconn_avail = read_col_dict(file, sheet3, "C", 1.0, Float64, n_interconn, name)
interconn_energy = read_col_dict(file, sheet3, "D", "", String, n_interconn, name)
interconn_region_ref = read_col_dict(file, sheet3, "E", "n", String, n_interconn, name)

INTERCONNEXIONS = Set(String.(vec(name)))
for ic in INTERCONNEXIONS
    ic_energy = interconn_energy[ic]

    if ic_energy == "elec"
        push!(elec_in, ic)
        push!(elec_out, ic)
    elseif ic_energy == "gas"
        push!(gas_in, ic)
        push!(gas_out, ic)
    elseif ic_energy == "h2"
        push!(h2_in, ic)
        push!(h2_out, ic)
    end

    if interconn_region_ref[ic] == "n"
        push!(north, ic)
    elseif interconn_region_ref[ic] == "s"
        push!(south, ic)
    end
end

for ic in INTERCONNEXIONS
    Avail[ic] = ones(Tmax)*interconn_avail[ic]
    Pout_max[ic] = interconn_pmax[ic]
end

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

#EOD gas north
if !isempty(intersect(union(gas_out, gas_in),north))
    @constraint(model, eod_gas_north[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(intersect(gas_out,north),inter))
    + sum(P_out[a,t] for a in intersect(intersect(gas_out,north),disp))
    + sum(P_out[a,t] for a in intersect(intersect(gas_out,north),stock))
    + sum(P_out[ic, t] for ic in intersect(INTERCONNEXIONS, gas_out, north))
    == load_gas_north[t]
    + sum(P_in[a,t] for a in intersect(intersect(gas_in,north),stock))
    + sum(P_in[a,t] for a in intersect(intersect(gas_in,north),disp))
    + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, gas_in, north)))
end

#EOD gas south
if !isempty(intersect(union(gas_out,gas_in),south))
    @constraint(model, eod_gas_south[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(intersect(gas_out,south),inter))
    + sum(P_out[a,t] for a in intersect(intersect(gas_out,south),disp))
    + sum(P_out[a,t] for a in intersect(intersect(gas_out,south),stock))
    + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, gas_out, south))
    == load_gas_south[t]
    + sum(P_in[a,t] for a in intersect(intersect(gas_in,south),stock))
    + sum(P_in[a,t] for a in intersect(intersect(gas_in,south),disp))
    + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, gas_in, south)))
end

#EOD h2 north
if !isempty(intersect(union(h2_out,h2_in),north))
    @constraint(model, eod_h2_north[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(intersect(h2_out,north),inter))
    + sum(P_out[a,t] for a in intersect(intersect(h2_out,north),disp))
    + sum(P_out[a,t] for a in intersect(intersect(h2_out,north),stock))
    + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, h2_out, north))
    == load_h2_north[t]
    + sum(P_in[a,t] for a in intersect(intersect(h2_in,north),stock))
    + sum(P_in[a,t] for a in intersect(intersect(h2_in,north),disp))
    + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, h2_in, north)))
end

#EOD h2 south
if !isempty(intersect(union(h2_out,h2_in),south))
    @constraint(model, eod_h2_south[t in 1:Tmax],
    sum(P_out[a,t] for a in intersect(intersect(h2_out,south),inter))
    + sum(P_out[a,t] for a in intersect(intersect(h2_out,south),disp))
    + sum(P_out[a,t] for a in intersect(intersect(h2_out,south),stock))
    + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, h2_out, south))
    == sum(P_in[a,t] for a in intersect(intersect(h2_in,south),stock))
    + sum(P_in[a,t] for a in intersect(intersect(h2_in,south),disp))
    + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, h2_in, south)))
end

#Availability
P_out_max_avail = Dict{Tuple{String,Int}, Float64}()
P_in_max_avail  = Dict{Tuple{String,Int}, Float64}()

#To avoid quadratic constraints
for a in union(ASSETS, INTERCONNEXIONS), t in 1:Tmax
    if a in union(elec_out, gas_out, h2_out)
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

# Interconnexions
@constraint(model, interconn_gas1[exn in intersect(INTERCONNEXIONS, gas_in, north),
                                  ims in intersect(INTERCONNEXIONS, gas_out, south),
                                  t in 1:Tmax],
                                  P_in[exn,t] == P_out[ims,t])
@constraint(model, interconn_gas2[imn in intersect(INTERCONNEXIONS, gas_out, north),
                                  exs in intersect(INTERCONNEXIONS, gas_in, south),
                                  t in 1:Tmax],
                                  P_out[imn,t] == P_in[exs,t])
@constraint(model, interconn_h21[exn in intersect(INTERCONNEXIONS, h2_in, north),
                                  ims in intersect(INTERCONNEXIONS, h2_out, south),
                                  t in 1:Tmax],
                                  P_in[exn,t] == P_out[ims,t])
@constraint(model, interconn_h22[imn in intersect(INTERCONNEXIONS, h2_out, north),
                                  exs in intersect(INTERCONNEXIONS, h2_in, south),
                                  t in 1:Tmax],
                                  P_out[imn,t] == P_in[exs,t])

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
    for (j,a) in enumerate(union(elec_out, gas_out, h2_out))
        sheet[1, j+1] = a
    end

    # values
    for t in 1:Tmax
        sheet[t+1, 1] = t
        for (j,a) in enumerate(union(elec_out, gas_out, h2_out))
            sheet[t+1, j+1] = value(P_out[a,t])
        end
    end

    ############################
    # SHEET 2 : P_in
    ############################
    sheet = XLSX.addsheet!(xf, "P_in")

    sheet["A1"] = "Time"
    for (j,a) in enumerate(union(elec_in, gas_in, h2_in))
        sheet[1, j+1] = a
    end

    for t in 1:Tmax
        sheet[t+1, 1] = t
        for (j,a) in enumerate(union(elec_in, gas_in, h2_in))
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
