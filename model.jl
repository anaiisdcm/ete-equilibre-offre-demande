#packages
using JuMP
#use the solver you want
using HiGHS
#package to read excel files
using XLSX

println("Loading data ...")
Tmax = 168 #optimization for 1 week (7*24=168 hours)
Tmaxmax = Tmax + 24 #anneau de garde
duration_t = 1

#Data loading
file = "inputs_eminmax.xlsx"

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

function read_timeseries(file, sheet, col, startrow, nrows, default, T)
    range = "$(col)$(startrow):$(col)$(startrow+nrows-1)"
    data = XLSX.readdata(file, sheet, range)
    return T.(coalesce.(vec(data), default))
end

function col_letter(i::Int)
    s = ""
    while i > 0
        i, r = divrem(i-1, 26)
        s = string(Char('A' + r), s)
    end
    return s
end

#LOAD ASSETS DATA
sheet1 = "ASSETS"

raw_names = vec(XLSX.readdata(file, sheet1, "A2:A10000"))
n_assets = count(!ismissing, raw_names)

name = read_col(file, sheet1, "A", "", String, n_assets)
energy_in = read_col_dict(file, sheet1, "B", "", String, n_assets, name)
energy_out = read_col_dict(file, sheet1, "C", "", String, n_assets, name)
region = read_col_dict(file, sheet1, "D", "n", String, n_assets, name)
avail = read_col_dict(file, sheet1, "E", 1.0, Float64, n_assets, name)
Pout_max = read_col_dict(file, sheet1, "F", 0.0, Float64, n_assets, name)
Pout_min = read_col_dict(file, sheet1, "G", 0.0, Float64, n_assets, name)
dmin =  read_col_dict(file, sheet1, "H", 0, Int, n_assets, name)
on_init =  read_col_dict(file, sheet1, "I", 0, Int, n_assets, name)
h_on =  read_col_dict(file, sheet1, "J", 0, Int, n_assets, name)
h_off =  read_col_dict(file, sheet1, "K", 0, Int, n_assets, name)
eff = read_col_dict(file, sheet1, "L", 1.0, Float64, n_assets, name)
E_max = read_col_dict(file, sheet1, "M", 0.0, Float64, n_assets, name)
E_init = read_col_dict(file, sheet1, "N", 0.0, Float64, n_assets, name)
price = read_col_dict(file, sheet1, "O", 0.0, Float64, n_assets, name)
family = read_col_dict(file, sheet1, "P", "", String, n_assets, name)

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
    Avail[a] = ones(Tmaxmax)*avail[a]
end

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
    Avail[ic] = ones(Tmaxmax)*interconn_avail[ic]
    Pout_max[ic] = interconn_pmax[ic]
end

function compute_h_on(a, Tmax, on)
    if value(on[a,Tmax]) < 0.5
        return 0
    end

    h = 0
    for t in reverse(1:Tmax)
        if value(on[a,t]) > 0.5
            h += 1
        else
            break
        end
    end
    return h
end

function compute_h_off(a, Tmax, on)
    if value(on[a,Tmax]) > 0.5
        return 0
    end

    h = 0
    for t in reverse(1:Tmax)
        if value(on[a,t]) < 0.5
            h += 1
        else
            break
        end
    end
    return h
end

function run_model()
    global on_init
    global h_on
    global h_off
    global E_init
    global file

    for n in 0:1 #boucle sur les 52 semaines
        println("Optimizing week $n ...")

        # LOAD CONSUMTION AND PRODUCTION TIMESERIES
        sheet2 = "TIMESERIES"


        
        #data for electric load
        load_elec = read_timeseries(file, sheet2, "C", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        load_gas_n = read_timeseries(file, sheet2, "D", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        load_gas_s = read_timeseries(file, sheet2, "E", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        load_h2_n = read_timeseries(file, sheet2, "F", 2+Tmax*n, Tmaxmax, 0.0, Float64)

        #data for inter generation
        solar = read_timeseries(file, sheet2, "G", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        wind_on = read_timeseries(file, sheet2, "I", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        wind_off = read_timeseries(file, sheet2, "J", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        hydroFO_fatal = read_timeseries(file, sheet2, "M", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        hydroLake_fatal = read_timeseries(file, sheet2, "N", 2+Tmax*n, Tmaxmax, 0.0, Float64)
        thermal_fatal = read_timeseries(file, sheet2, "P", 2+Tmax*n, Tmaxmax, 0.0, Float64)

        #LOAD ENERGY STORAGE AVAILABILITY DATA
        sheet4 = "E_AVAIL"

        emin_cols = Dict{String, String}()
        emax_cols = Dict{String, String}()
        headers = vec(XLSX.readdata(file, sheet4, "A1:ZZ1"))

        for (i, h) in enumerate(headers)
            if !ismissing(h)
                h = String(h)

                if startswith(h, "EMIN_")
                    asset = replace(h, "EMIN_" => "")
                    emin_cols[asset] = col_letter(i)

                elseif startswith(h, "EMAX_")
                    asset = replace(h, "EMAX_" => "")
                    emax_cols[asset] = col_letter(i)
                end
            end
        end

        E_min_avail = Dict{Tuple{String,Int}, Float64}()
        E_max_avail = Dict{Tuple{String,Int}, Float64}()

        for s in stock
            emin_data = read_timeseries(file, sheet4, emin_cols[s], 2+Tmax*n, Tmaxmax, 0.0, Float64)
            emax_data = read_timeseries(file, sheet4, emax_cols[s], 2+Tmax*n, Tmaxmax, 0.0, Float64)
            for t in 1:Tmaxmax
                E_min_avail[(s, t)] = emin_data[t]
                E_max_avail[(s, t)] = emax_data[t]
            end
        end

        P_in_max_avail_stock = Dict{Tuple{String,Int}, Float64}()
        P_out_max_avail_stock = Dict{Tuple{String,Int}, Float64}()

        for a in stock, t in 1:Tmaxmax
            P_in_max_avail_stock[(a,t)]  = Pout_max[a]
            P_out_max_avail_stock[(a,t)] = Pout_max[a]
        end

        #Availability
        P_out_max_avail = Dict{Tuple{String,Int}, Float64}()
        P_in_max_avail  = Dict{Tuple{String,Int}, Float64}()

        #To avoid quadratic constraints
        for a in union(ASSETS, INTERCONNEXIONS), t in 1:Tmaxmax
            if a in union(elec_out, gas_out, h2_out)
                P_out_max_avail[(a,t)] = Pout_max[a] * Avail[a][t]
            end
            # if a in union(elec_in,gas_in)
            #     P_in_max_avail_const[(a,t)] = Pin_max[a] * Avail[a][t]
            # end
        end

        #############################
        #create the optimization model
        #############################
        model = Model(HiGHS.Optimizer)

        #############################
        #define the variables
        #############################

        #Power of functioning
        @variable(model, P_in[a in union(elec_in, gas_in, h2_in), t in 1:Tmaxmax] ≥ 0)
        @variable(model, P_out[a in union(elec_out, gas_out, h2_out), t in 1:Tmaxmax] ≥ 0)

        #Flags disp
        @variable(model, on[a in disp, t in 1:Tmaxmax], Bin)
        @variable(model, up[a in disp, t in 1:Tmaxmax], Bin)
        @variable(model, down[a in disp, t in 1:Tmaxmax], Bin)

        # #Available power
        # @variable(model, P_in_max_avail[a in union(elec_in,gas_in), t in 1:Tmaxmax] ≥ 0)
        # @variable(model, P_out_max_avail[a in union(elec_out,gas_out), t in 1:Tmaxmax] ≥ 0)

        #Stock variables
        @variable(model, E[a in stock, t in 1:Tmaxmax] ≥ 0)
        @variable(model, isCharging[a in stock, t in 1:Tmaxmax], Bin)

        #unsupplied energy variables
        @variable(model, Puns_elec[1:Tmaxmax] >= 0)
        @variable(model, Puns_gas_n[1:Tmaxmax] >= 0)
        @variable(model, Puns_gas_s[1:Tmaxmax] >= 0)
        @variable(model, Puns_h2_n[1:Tmaxmax] >= 0)
        @variable(model, Puns_h2_s[1:Tmaxmax] >= 0)
        #in excess energy variables
        @variable(model, Pexc_elec[1:Tmaxmax] >= 0)
        @variable(model, Pexc_gas_n[1:Tmaxmax] >= 0)
        @variable(model, Pexc_gas_s[1:Tmaxmax] >= 0)
        @variable(model, Pexc_h2_n[1:Tmaxmax] >= 0)
        @variable(model, Pexc_h2_s[1:Tmaxmax] >= 0)
        
        cuns = 5000 #cost of unsupplied energy €/MWh
        cexc = 0 #cost of in excess energy €/MWh

        #############################
        #define the constraints
        #############################
        #objective function
        @objective(model, Min,
            sum(P_out[a,t] * price[a] for a in ASSETS, t in 1:Tmaxmax)
            + sum(Puns_elec[t] + Puns_gas_n[t] + Puns_gas_s[t] + Puns_h2_n[t] + Puns_h2_s[t] for t in 1:Tmaxmax) * cuns
            + sum(Pexc_elec[t] + Pexc_gas_n[t] + Pexc_gas_s[t] + Pexc_h2_n[t] + Pexc_h2_s[t] for t in 1:Tmaxmax) * cexc
        )

        #Inter prod
        @constraint(model, [a in solar_assets, t in 1:Tmaxmax], P_out[a,t] == solar[t])
        @constraint(model, [a in wind_on_assets, t in 1:Tmaxmax], P_out[a,t] == wind_on[t])
        @constraint(model, [a in wind_off_assets, t in 1:Tmaxmax], P_out[a,t] == wind_off[t])
        @constraint(model, [a in hydroFO_assets, t in 1:Tmaxmax], P_out[a,t] == hydroFO_fatal[t])
        @constraint(model, [a in hydroLake_assets, t in 1:Tmaxmax], P_out[a,t] == hydroLake_fatal[t])
        @constraint(model, [a in thermal_fatal_assets, t in 1:Tmaxmax], P_out[a,t] == thermal_fatal[t])

        #EOD elec
        if !isempty(union(elec_out, elec_in))
            @constraint(model, eod_elec[t in 1:Tmaxmax],
            sum(P_out[a,t] for a in intersect(elec_out,inter))
            + sum(P_out[a,t] for a in intersect(elec_out,disp))
            + sum(P_out[a,t] for a in intersect(elec_out,stock))
            + Puns_elec[t]
            == load_elec[t] +
            sum(P_in[a,t] for a in intersect(elec_in,stock))
            + sum(P_in[a,t] for a in intersect(elec_in,disp))
            + Pexc_elec[t]
            )
        end

        #EOD gas north
        if !isempty(intersect(union(gas_out, gas_in),north))
            @constraint(model, eod_gas_north[t in 1:Tmaxmax],
            sum(P_out[a,t] for a in intersect(intersect(gas_out,north),inter))
            + sum(P_out[a,t] for a in intersect(intersect(gas_out,north),disp))
            + sum(P_out[a,t] for a in intersect(intersect(gas_out,north),stock))
            + sum(P_out[ic, t] for ic in intersect(INTERCONNEXIONS, gas_out, north))
            + Puns_gas_n[t]
            == load_gas_n[t]
            + sum(P_in[a,t] for a in intersect(intersect(gas_in,north),stock))
            + sum(P_in[a,t] for a in intersect(intersect(gas_in,north),disp))
            + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, gas_in, north))
            + Pexc_gas_n[t]
            )
        end

        #EOD gas south
        if !isempty(intersect(union(gas_out,gas_in),south))
            @constraint(model, eod_gas_south[t in 1:Tmaxmax],
            sum(P_out[a,t] for a in intersect(intersect(gas_out,south),inter))
            + sum(P_out[a,t] for a in intersect(intersect(gas_out,south),disp))
            + sum(P_out[a,t] for a in intersect(intersect(gas_out,south),stock))
            + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, gas_out, south))
            + Puns_gas_s[t]
            == load_gas_s[t]
            + sum(P_in[a,t] for a in intersect(intersect(gas_in,south),stock))
            + sum(P_in[a,t] for a in intersect(intersect(gas_in,south),disp))
            + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, gas_in, south))
            + Pexc_gas_s[t]
            )
        end

        #EOD h2 north
        if !isempty(intersect(union(h2_out,h2_in),north))
            @constraint(model, eod_h2_north[t in 1:Tmaxmax],
            sum(P_out[a,t] for a in intersect(intersect(h2_out,north),inter))
            + sum(P_out[a,t] for a in intersect(intersect(h2_out,north),disp))
            + sum(P_out[a,t] for a in intersect(intersect(h2_out,north),stock))
            + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, h2_out, north))
            + Puns_h2_n[t]
            == load_h2_n[t]
            + sum(P_in[a,t] for a in intersect(intersect(h2_in,north),stock))
            + sum(P_in[a,t] for a in intersect(intersect(h2_in,north),disp))
            + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, h2_in, north))
            + Pexc_h2_n[t]
            )
        end

        #EOD h2 south
        if !isempty(intersect(union(h2_out,h2_in),south))
            @constraint(model, eod_h2_south[t in 1:Tmaxmax],
            sum(P_out[a,t] for a in intersect(intersect(h2_out,south),inter))
            + sum(P_out[a,t] for a in intersect(intersect(h2_out,south),disp))
            + sum(P_out[a,t] for a in intersect(intersect(h2_out,south),stock))
            + sum(P_out[ic,t] for ic in intersect(INTERCONNEXIONS, h2_out, south))
            + Puns_h2_s[t]
            == sum(P_in[a,t] for a in intersect(intersect(h2_in,south),stock))
            + sum(P_in[a,t] for a in intersect(intersect(h2_in,south),disp))
            + sum(P_in[ic,t] for ic in intersect(INTERCONNEXIONS, h2_in, south))
            + Pexc_h2_s[t]
            )
        end

        #Pmin/Pmax disp
        @constraint(model, p_max_out_disp[a in intersect(disp,union(elec_out, gas_out, h2_out)), t in 1:Tmaxmax], P_out[a,t] ≤ P_out_max_avail[(a,t)] * on[a,t])
        @constraint(model, p_min_out_disp[a in intersect(disp,union(elec_out, gas_out, h2_out)), t in 1:Tmaxmax], P_out[a,t] ≥ Pout_min[a] * on[a,t])
        #@constraint(model, [a in disp, t in 1:Tmaxmax], P_in[a,t] ≤ P_in_max_avail[(a,t)] * on[a,t])
        #@constraint(model, [a in disp, t in 1:Tmaxmax], P_in[a,t] ≥ Pin_min[a] * on[a,t])


        #Pmin/Pmax non disp
        #@constraint(model, [a in elec_in ∪ gas_in , t in 1:Tmaxmax], P_in[a,t] ≤ P_in_max_avail[(a,t)])
        @constraint(model, p_max_out[a in setdiff(union(elec_out, gas_out, h2_out), disp), t in 1:Tmaxmax], P_out[a,t] ≤ P_out_max_avail[(a,t)])
  
        if n == 0
            for a in disp
                on_init[a] = 0
                h_on[a] = 0
                h_off[a] = dmin[a]
            end
        end

        if n > 0
            file = "results_semaine_$(n-1).xlsx" #on ouvre les résultats de la semaine précédente pour récupérer l'état d'activité des actifs
            sheet4 = "ASSETS_STATE" #feuille allouée à l'état d'activité

            name = read_col(file, sheet4, "A", "", String, n_assets)
            on_init =  read_col_dict(file, sheet4, "B", 0, Int, n_assets, name)
            h_on =  read_col_dict(file, sheet4, "C", 0, Int, n_assets, name)
            h_off =  read_col_dict(file, sheet4, "D", 0, Int, n_assets, name)
            E_init = read_col_dict(file, sheet4, "E", 0.0, Float64, n_assets, name)
        end

        
        #dmin constraints
        @constraint(model, up_down_1[a in disp, t in 2:Tmaxmax], on[a,t] - on[a,t-1] == up[a,t] - down[a,t])

        @constraint(model, up_down_2[a in disp, t in 1:Tmaxmax], up[a,t] + down[a,t] ≤ 1)

        @constraint(model, up_init[a in disp; on_init[a] == 0], up[a,1] == on[a,1])
        @constraint(model, down_init[a in disp; on_init[a] == 1], down[a,1] == 1 - on[a,1])

        @constraint(model,
            dmin_on[a in disp, t in 1:Tmaxmax; dmin[a] > 0 && t >= dmin[a]],
            on[a,t] >= sum(up[a,i] for i in t-dmin[a]+1:t)
        )

        @constraint(model,
            dmin_off[a in disp, t in 1:Tmaxmax; dmin[a] > 0 && t >= dmin[a]],
            on[a,t] <= 1 - sum(down[a,i] for i in t-dmin[a]+1:t)
        )

        # @constraint(model,
        #     dmin_on_init[a in disp, t in 1:Tmaxmax; dmin[a] > 0 && t < dmin[a]],
        #     on[a,t] >= sum(up[a,i] for i in 1:t)
        # )
        # @constraint(model,
        #     dmin_off_init[a in disp, t in 1:Tmaxmax; dmin[a] > 0 && t < dmin[a]],
        #     on[a,t] <= 1 - sum(down[a,i] for i in 1:t)
        # )

        @constraint(model,
            min_up_init[a in disp, t in 1:Tmaxmax;
                on_init[a] == 1 &&
                dmin[a] > 0 &&
                t <= max(dmin[a] - h_on[a], 0)
            ],
            on[a,t] == 1
        )

        @constraint(model,
            min_down_init[a in disp, t in 1:Tmaxmax;
                on_init[a] == 0 &&
                dmin[a] > 0 &&
                t <= max(dmin[a] - h_off[a], 0)
            ],
            on[a,t] == 0
        )

        # Conv constraints
        # Do not add whole conv set because storage assets be in conv and it will interfere with stock management
        @constraint(model, conv_eff[a in union(conv_ge, conv_eh2, conv_gh2), t in 1:Tmaxmax], P_out[a,t] == eff[a] * P_in[a,t])

        # Stock constraints
        # Energy stock init
        @constraint(model, energy_init[a in stock], E[a,1] == E_init[a] + (eff[a]*P_in[a,1] - P_out[a,1]) * duration_t)

        # Energy stock
        @constraint(model, stock_energy[a in stock, t in 2:Tmaxmax], E[a,t] == E[a,t-1] + (eff[a]*P_in[a,t] - P_out[a,t]) * duration_t
        )

        # Charge boundaries
        @constraint(model, [a in stock, t in 1:Tmaxmax], E[a,t] <= E_max_avail[(a,t)])
        @constraint(model, [a in stock, t in 1:Tmaxmax], E[a,t] >= E_min_avail[(a,t)])

        #Discharge init and max
        @constraint(model, discharge_max_stock_init[a in stock], P_out[a,1] * duration_t <= E_init[a])
        @constraint(model, discharge_max_stock[a in stock, t in 2:Tmaxmax], P_out[a,t] * duration_t <= E[a,t-1])

        #Charge and discharge available
        @constraint(model, p_charge_avail[a in stock, t in 1:Tmaxmax], P_in[a,t] <= P_in_max_avail_stock[(a,t)] * isCharging[a,t])
        @constraint(model, p_discharge_avail[a in stock, t in 1:Tmaxmax], P_out[a,t] <= P_out_max_avail_stock[(a,t)] * (1 - isCharging[a,t]))

        # Interconnexions
        @constraint(model, interconn_gas1[exn in intersect(INTERCONNEXIONS, gas_in, north),
                                        ims in intersect(INTERCONNEXIONS, gas_out, south),
                                        t in 1:Tmaxmax],
                                        P_in[exn,t] == P_out[ims,t])
        @constraint(model, interconn_gas2[imn in intersect(INTERCONNEXIONS, gas_out, north),
                                        exs in intersect(INTERCONNEXIONS, gas_in, south),
                                        t in 1:Tmaxmax],
                                        P_out[imn,t] == P_in[exs,t])
        @constraint(model, interconn_h21[exn in intersect(INTERCONNEXIONS, h2_in, north),
                                        ims in intersect(INTERCONNEXIONS, h2_out, south),
                                        t in 1:Tmaxmax],
                                        P_in[exn,t] == P_out[ims,t])
        @constraint(model, interconn_h22[imn in intersect(INTERCONNEXIONS, h2_out, north),
                                        exs in intersect(INTERCONNEXIONS, h2_in, south),
                                        t in 1:Tmaxmax],
                                        P_out[imn,t] == P_in[exs,t])

        #solve model
        set_optimizer_attribute(model, "mip_rel_gap", 0.005)
        optimize!(model)
        #------------------------------
        #Results
        @show termination_status(model)
        @show objective_value(model)

        println("\n\n\n")


        outfile = "results.xlsx"

        XLSX.openxlsx(outfile, mode="w") do xf
            # # Delete default Excel sheet
            # if "Sheet1" in XLSX.sheetnames(xf)
            #     XLSX.delete!(xf, "Sheet1")
            # end

            ############################
            # SHEET 1 : P_out
            ############################
            sheet = XLSX.addsheet!(xf, "P_OUT")

            # header
            sheet["A1"] = "Time"
            for (j,a) in enumerate(union(elec_out, gas_out, h2_out))
                sheet[1, j+1] = a
            end

            # values
            for t in 1:Tmaxmax
                sheet[t+1, 1] = t
                for (j,a) in enumerate(union(elec_out, gas_out, h2_out))
                    sheet[t+1, j+1] = value(P_out[a,t])
                end
            end

            ############################
            # SHEET 2 : P_in
            ############################
            sheet = XLSX.addsheet!(xf, "P_IN")

            sheet["A1"] = "Time"
            for (j,a) in enumerate(union(elec_in, gas_in, h2_in))
                sheet[1, j+1] = a
            end

            for t in 1:Tmaxmax
                sheet[t+1, 1] = t
                for (j,a) in enumerate(union(elec_in, gas_in, h2_in))
                    sheet[t+1, j+1] = value(P_in[a,t])
                end
            end

            ############################
            # SHEET 3 : STOCK ENERGY
            ############################
            sheet = XLSX.addsheet!(xf, "STOCK_E")

            sheet["A1"] = "Time"
            for (j,a) in enumerate(stock)
                sheet[1, j+1] = a
            end

            for t in 1:Tmaxmax
                sheet[t+1, 1] = t
                for (j,a) in enumerate(stock)
                    sheet[t+1, j+1] = value(E[a,t])
                end
            end

            ############################
            # SHEET 4 : FINAL ASSETS STATE
            ############################
            sheet = XLSX.addsheet!(xf, "ASSETS_STATE")
            
            sheet["A1"] = "asset_name"
            sheet["B1"] = "on_t=$(Tmax)"
            sheet["C1"] = "h_on_t=$(Tmax)"
            sheet["D1"] = "h_off_t=$(Tmax)"
            sheet["E1"] = "energy_t=$(Tmax)"
            for (j,a) in enumerate(ASSETS)
                sheet[j+1, 1] = a
                # Is asset on at the end of the optimized week ?
                if a in disp
                    sheet[j+1, 2] = value(on[a,Tmax])
                else
                    sheet[j+1, 2] = 0
                end 
                # How many hours the asset has been on at the end of the optimized week ?
                if a in disp
                    sheet[j+1, 3] = compute_h_on(a, Tmax, on)
                else
                    sheet[j+1, 3] = 0
                end
                # How many hours the asset has been off at the end of the optimized week ?
                if a in disp
                    sheet[j+1, 4] = compute_h_off(a, Tmax, on)
                else
                    sheet[j+1, 4] = 0
                end
                # How much energy is stored at the end of the optimized week ?
                if a in stock
                    sheet[j+1, 5] = value(E[a,Tmax])
                else
                    sheet[j+1, 5] = 0.0
                end
            end

        end

        cp("results.xlsx", "results_semaine_$(n).xlsx"; force=true) #sauvegarde le fichier résultats de la semaine n et laisse le fichier "results" en fichier glissant

    end
end

run_model()