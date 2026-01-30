# ETE-305 Modélisation d'équilibre offre-demande


## Données d'entrées, hypothèses

### Fenêtre d'optimisation
$T$ (entier positif) : Durée de la fenêtre d'optimisation (en h)

Convention débutante/finissante : est-ce qu'on affiche les valeurs d'énergie et autres valables à la fin du pas de temps $t$ ou au début du pas de temps $t$ ???


### Familles d'actifs
$elec_{in}$ : Actif consommant de l'électricité

$elec_{out}$ : Actif produisant de l'électricité

$gaz_{in}$ : Actif consommant du gaz

$gaz_{out}$ : Actif produisant du gaz

<!-- $heat_{in}$ : Actif consommant de la chaleur -->

<!-- $heat_{out}$ : Actif produisant de la chaleur -->


$nuc \in elec_{out}$ : Actif nucléaire

$ge \in gaz_{in} \cap elec_{out}$ : Actif convertisseur de gaz en électricité

$coal \in elec_{out}$ : Actif convertisseur de charbon en électricité

$fioul \in elec_{out}$ : Actif convertisseur de fioul en électricité

<!-- $gh \in gaz_{in} \cap heat_{out}$ : Actif convertisseur de gaz en chaleur -->

$inter \in elec_{out}$ : Actif production intermittente (solaire, éolien terrestre, éolien en mer, hydro fil de l'eau, valorisation des déchets, petite biomasse)

$PV \in inter$ : Actif de production photovoltaïque

$windon \in inter$ : Actif de production électrique éolienne terrestre

$windoff \in inter$ : Actif de production électrique éolienne en mer

$hydroFO \in inter$ : Actif de production hydroélectrique (fil de l'eau)

$waste \in inter$ : Actif de production électrique issue de la valorisation des déchets

$biomass \in inter$ : Actif de production électrique issue de la biomasse

$biogas \in gas_{out}$ : Actif de production de gaz issu de la biomasse

$hydroLac \in elec_{out}$ : Actif de production hydroélectrique pilotable avec stockage sans maitrise de la charge

$step \in elec_{in} \cap elec_{out}$ : Actif de conversion hydroélectrique avec stockage (pompage et turbinage)

$import_{elec} \in elec_{out}$ : Imports d'électricité sur le réseau

$export_{elec} \in elec_{in}$ : Exports d'électricité du réseau

$import_{gas} \in gas_{out}$ : Imports de gaz sur le réseau

$export_{gas} \in gas_{in}$ : Exports de gaz du réseau

$extraction_{gas} \in gas_{out}$ : Extraction de gaz = production de gaz

$gastank \in gas_{in} \cap gas_{out}$ : Actif de stockage de gaz

$h2tank \in elec_{in} \cap elec_{out}$ : Actif de stockage d'électricité exploitant l'électrolyse


### Capacités installées
$P_{out_{max}, asset}$ : Puissance maximale produite par l'actif $elec_{out} \cap gaz_{out}$ <!-- \cap heat_{out} -->

$P_{out_{min}, asset}$ : Puissance minimale produite par l'actif $elec_{out} \cap gaz_{out}$ <!-- \cap heat_{out} -->

$P_{in_{max}, asset}$ : Puissance maximale consommée par l'actif $elec_{in} \cap gaz_{in}$  <!-- \cap heat_{in} -->

$P_{in_{min}, asset}$ : Puissance minimale consommée par l'actif $elec_{in} \cap gaz_{in}$  <!-- \cap heat_{in} -->

### Capacités de stockage
$E_{max_{hydroLac, step, gastank, h2tank}}$ : Energie maximale stockée par l'actif $hydroLac, step, gastank, h2tank$

$E_{min_{hydroLac, step, gastank, h2tank}}$ : Energie minimale stockée par l'actif $hydroLac, step, gastank, h2tank$ <!-- Probablement =0 au début -->


### Durée minimale de fonctionnement et d'arrêt
$d_{min_{nuc, ge, gh, coal, fioul, inter, biogas, hydroLac, step, import/export, gastank, h2tank}}$ : Durée minimale de fonctionnement et d'arrêt (en h) <!--  A priori pas besoin pour les EnR donc éventuellement ajouter d_min_inter = 0 -->

### Prévisions
Attention respect des facteurs de charge moyens
#### Productions fatales d'électricité
$P_{forecast_{PV, t}}, t\in [1;T]$ : Production électrique photovoltaïque prévue au pas de temps $t$ pour l'actif $PV$ (en kW)

$P_{forecast_{windon, t}}, t\in [1;T]$ : Production électrique éolienne terrestre prévue au pas de temps $t$ pour l'actif $windon$ (en kW)

$P_{forecast_{windoff, t}}, t\in [1;T]$ : Production électrique éolienne en mer prévue au pas de temps $t$ pour l'actif $windoff$ (en kW)

$P_{forecast_{hydroFO, t}}, t\in [1;T]$ : Production électrique hydraulique (fil de l'eau) prévue au pas de temps $t$ pour l'actif $hydroFO$ (en kW)

$P_{forecast_{waste, t}}, t\in [1;T]$ : Production électrique issue de la valorisation des déchets prévue au pas de temps $t$ pour l'actif $waste$ (en kW)

$P_{forecast_{biomass, t}}, t\in [1;T]$ : Production électrique issue de la biomasse prévue au pas de temps $t$ pour l'actif $biomass$ (en kW)

#### Productions fatales de gaz
$P_{forecast_{biogas, t}}, t\in [1;T]$ : Production de gaz issue de la biomasse prévue au pas de temps $t$ pour l'actif $biogas$ (en kW)

#### Précipitations pour l'hydraulique lac
$P_{rain_{hydroLac}, t}, t\in [1;T]$ : Puissance turbinable récupérée au pas de temps $t$ pour l'actif $hydroLac$ (en kW > 0)

### Besoins à satisfaire
#### Consommation directe électrique

$need_{elec,t} \in elec_{in}, t\in [1;T]$ : Besoin total en électricité au pas de temps $t$

#### Consommation directe de gaz

$need_{gas,t} \in gas_{in}, t\in [1;T]$ : Besoin total en gaz au pas de temps $t$

### Prix de l'énergie des différents actifs de production
$Cost_{elec_{out} \setminus{\lbrace hydroLac \cup step \cup h2tank \rbrace}}$ : Coût de l'électricité produite par l'actif $elec_{out}$ (dont imports elec) (en €/kWh)

$Cost_{gas_{out} \setminus{\lbrace gastank \rbrace}}$ : Coût du gaz produit par l'actif $gas_{out}$ (dont imports en gaz) (en €/kWh)

$Cost_{export_{gas}\cup export_{elec}}$ : Coût (revenu ici) de la vente du gaz et de l'électricité exportée du réseau (en €/kWh)

#### Prix hydraulique
Attention respect variations précipitations

$Cost_{hydroLac \cup step, t}, t\in [1;T]$ :$ : Coût de l'électricité produite par l'actif $hydroLac$ au pas de temps $t$ (en €/kWh)

### Disponibilité des actifs
Imports GNL par bateau modélisés sous forme de disponibilité != 0

$Disp_{elec_{out}\cup gas_{out} \cup elec_{in} \cup elec_{out}, t}, t\in [1;T]$ : Disponibilité de l'actif (float, entre 0 et 1)


### Rendements
$Eff_{conv}$ :Rendement de la conversion d'énergie effectuée par l'actif $conv$ (float, entre 0 et 1)

## Variables
### Puissance de fonctionnement des actifs
$P_{in_{asset, t}}, asset \in elec_{in} \cup gas_{in}, t\in [1;T]$

$P_{out_{asset, t}}, asset \in elec_{out} \cup gas_{out}, t\in [1;T]$

### Energie stockée par les actifs de stockage
$E_{stock,t}, asset \in stock, t\in [1;T]$ : Energie stockée stockée par l'actif $stock$ à la fin du pas de temps $t$

### Flag de fonctionnement des actifs dispachable

$on_{disp,t} \in {\lbrace 0,1 \rbrace} , disp \in ???, t\in [1;T]$ : L'actif $asset$ est en fonctionnement au pas de temps $t$

### Flag de mise en fonctionnement/d'arrêt des actifs dispachable

$up_{disp,t} \in {\lbrace 0,1 \rbrace}, disp \in ???, t\in [1;T]$ : L'actif $asset$ démarre au pas de temps $t$

$down_{disp,t} \in {\lbrace 0,1 \rbrace}, disp \in ???, t\in [1;T]$ : L'actif $asset$ est arrêté au pas de temps $t$

### Puissance disponible des actifs
$P_{inMaxAvail_{asset, t}}, asset \in elec_{in} \cup gas_{in}, t\in [1;T]$

$P_{outMaxAvail_{asset, t}}, asset \in elec_{out} \cup gas_{out}, t\in [1;T]$

## Fonction objectif
A détailler :

$$minimize : \displaystyle\sum_{a\in asset}{\sum_{t=1}^{T}{P_{in_{a,t}}* Cost_{a,t}}}$$

## Contraintes
### Contraintes d'équilibre offre-demande
#### EOD élec (instantané)
Somme Pelec fatal + Somme Pelec Pilotable + Somme Stockages Décharge + Import interconnexions = Conso élec donnée entrée + Somme Stockages Charge + Export interconnexions

$$\displaystyle \forall t \in [1,T],\sum_{e_{in}\in elec_{in}}{P_{in_{e_{in},t}}} = \sum_{e_{out}\in elec_{out}}{P_{out_{e_{out},t}}}$$

#### EOD gaz (journalier) ????
Imports GNL bateau + Import interconnexion + Somme prod (bio)gaz + Décharge stockages = Somme Pin gaz + Conso gaz directe donnée d’entrée + Charge stockage + Export interconnexions + Export bateau ???

$$\displaystyle \forall t \in [1,T],\sum_{g_{in}\in gasc_{in}}{P_{in_{g_{in},t}}} = \sum_{g_{out}\in gas_{out}}{P_{out_{g_{out},t}}}$$
-> voir comment on gère la granularité de l'EOD (1h/1j ?)

### Contraintes de disponibilité
Contrainte P_in_max_avail :
$P_{inMaxAvail_{asset, t}} = P_{in_{max}, asset} * Disp_{asset, t}, asset \in elec_{in} \cup gas_{in}, t\in [1;T]$

Contrainte P_out_max_avail :
$P_{outMaxAvail_{asset, t}} = P_{out_{max}, asset} * Disp_{asset, t}, asset \in elec_{out} \cup gas_{out}, t\in [1;T]$

### Contraintes Pmax
Contrainte P_max_in :
$P_{in_{asset, t}} <= P_{inMaxAvail_{asset, t}}, asset \in elec_{in} \cup gas_{in} \setminus{\lbrace disp \rbrace}, t\in [1;T]$

Contrainte P_max_in_disp :
$P_{in_{disp, t}} <= P_{inMaxAvail_{disp, t}} * on_{disp,t}, disp \in disp \cap (elec_{in} \cup gas_{in}), t\in [1;T]$

Contrainte P_max_out :
$P_{out_{asset, t}} <= P_{outMaxAvail_{asset, t}}, asset \in elec_{out} \cup gas_{out} \setminus{\lbrace disp \rbrace}, t\in [1;T]$

Contrainte P_max_out_disp :
$P_{out_{asset, t}} <= P_{outMaxAvail_{asset, t}} * on_{disp,t}, disp \in disp \cap(elec_{out} \cup gas_{out}), t\in [1;T]$

### Containtes Pmin
Contrainte P_min_in :
Si l'actif est on :
$P_{in_{disp, t}} >= P_{in_{min}, disp} * on_{disp,t}, disp \in disp \cap(elec_{in} \cup gas_{in}), t\in [1;T]$

Contrainte P_min_out :
Si l'actif est on :
$P_{out_{disp, t}} >= P_{out_{min}, disp} * on_{dips,t}, disp \in disp \cap(elec_{out} \cup gas_{out}), t\in [1;T]$

### Contraintes durée minimale de fonctionnement et d'arrêt
Pour tous les actifs dispatachables $disp$ (nuc, ge, gh, coal, fioul, inter, biogas, hydroLac, step, import/export, gastank, h2tank ????):

Contrainte up_down_1 : 
Attention initialisation
$$on_{disp, t} - on_{disp, t-1} = up_{disp, t} - down_{disp, t}$$

Contrainte up_down_2 : On ne peut pas allumer et éteindre l'actif $disp$ sur le même pas de temps
$$up_{disp, t} + down_{disp, t} <=1$$

Contrainte up_init :
-> lire donnée entrée $on_{disp_{init}}$ combien de pas de temps déjà allumés en $t=0$ 

Si $on_{disp_{init}}=0 => up_{disp, 1}=on_{disp, 1}$

Contrainte_down_init :
-> lire donnée entrée $on_{disp_{init}}$ combien de pas de temps déjà allumés en $t=0$ 

Si $on_{disp_{init}}>0 => down_{disp, 1}=1-on_{disp, 1}$


Contrainte dmin_on :
Le nombre de pas de temps successifs où $on_{disp, t} = 1$ doit être supérieur ou égal à $d_{min_{disp}}$.

Contrainte dmin_off :
Le nombre de pas de temps successifs où $on_{disp, t} = 0$ doit être supérieur ou égal à $d_{min_{disp}}$.

Contrainte dmin_on_init :
Pour les pas de temps $t$, qui sont $< d_{min_{disp}}$ le nombre de pas de temps successifs où $on_{disp, t} = 1$ + le nombre d'heures où l'actif était on initialement doit être supérieur ou égal à $d_{min_{disp}}$.

Contrainte dmin_off_init :
Pour les pas de temps $t$, qui sont $< d_{min_{disp}}$ le nombre de pas de temps successifs où $on_{disp, t} = 1$ + le nombre d'heures où l'actif était off initialement doit être supérieur ou égal à $d_{min_{disp}}$.

### Contraintes de conservation énergétique (respect des rendements)
Pour les actifs $conv$:
$$P_{out_{conv, t}} = P_{in_{conv, t}} * Eff_{conv}$$

### Contraintes de stockage (hydraulique lac, STEP, gaz, elec)
Rendement charge et rendement décharge


Contrainte energy_init :
Il faut lire la valeur de stock initiale $E_{init_{s}}$.
$$E_{s,1} = E_{init_{s}}, s \in stock$$

Contrainte charge_hydro_lac :
Pour les actifs $hydroLac$, la charge se fait avec les précipitations:


Contrainte charge_stock :

Contrainte discharge_stock :

Contrainte Pcharge_avail :

Contrainte Pdischarge_avail :


### Contraintes import/export elec/gaz
Rien à ajouter car modélisé sous forme de respect des disponibilités



## Sorties à prévoir

Puissances activées pour chaque actif

Est-ce que l’actif est allumé ou éteint à la fin de la fenêtre d’optim ?

Etat des stocks (et aussi à la fin de la fenêtre d’optim)

Coûts par filière de prod

Prix de l’hydro en fonction de l’état des stocks et les prévisions de précipitations
