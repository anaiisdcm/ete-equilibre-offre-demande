# ETE-305 Modélisation d'équilibre offre-demande


## Données d'entrées, hypothèses

### Fenêtre d'optimisation
$T$ (entier positif) : Durée de la fenêtre d'optimisation (en h)

Convention finissante : On affiche les valeurs d'énergie et autres valables à la fin du pas de temps $t$


### Familles d'actifs

#### Localisation
$north$ : Actif étant situé sur le réseau du Nord

$south$ : Actif étant situé sur le réseau du Sud

#### Vecteurs énergétiques modélisés
$elec_{in}$ : Actif consommant de l'électricité

$elec_{out}$ : Actif produisant de l'électricité

$gaz_{in}$ : Actif consommant du gaz

$gaz_{out}$ : Actif produisant du gaz

$h2_{in}$ : Actif consommant du dihydrogène

$h2_{out}$ : Actif produisant du dihydrogène

$conv$ : Actif de conversion (gaz vers élec, stockages gaz et hydrogène, STEP)

$conv_{ge} (= gaz_{in} \cap elec_{out} )\subset conv$ : Actif convertisseur de gaz en électricité (centrales CCG, TAC, cogénération)

$conv_{eh2} (= elec_{in} \cap h2_{out} )\subset conv$ : Actif convertisseur d'électricité en dihydrogène (électrolyseurs)

$conv_{gh2} (= gas_{in} \cap h2_{out}) \subset conv$ : Actif convertisseur de gas en dihydrogène (vaporeformage)

<!-- $prod_{gas} (= gas_{out}) $ : Actif de production de gaz (méthanisation, pyrogazéification) -->

<!-- $import_{gas} \subset gas_{out}$ : Imports de gaz sur le réseau -->

#### Pilotage des actifs

$interconnexion \subset (elec_{out} \cup gas_{out} \cup h2_{out} \cup elec_{in} \cup gas_{in} \cup h2_{in})$ : Import (via $P_{out}$ : production délocalisée) ou export (via $P_{in}$ : consommation délocalisée) d'énergie par interconnexion avec un autre réseau

$inter \subset elec_{out}$ : Actif production intermittente (solaire, éolien terrestre, éolien en mer, hydro fil de l'eau, valorisation des déchets, petite biomasse et aussi hydroLac (modélisé comme fatal pour le moment))

$stock \subset (elec_{in} \cap elec_{out}) \cup (gas_{in} \cap gas_{out})$: Actif de stockage (STEP, stockage gaz)

$disp \subset (elec_{out} \cup gas_{out} \cup h2_{out} \ \setminus (inter \cup stock))$ : Actif pilotable produisant de l'énergie (électricité, gaz ou h2)


### Capacités installées
$P_{out_{max}, asset}$ : Puissance maximale produite par l'actif $asset \in elec_{out} \cup gas_{out} \cup h2_{out}$

$P_{out_{min}, asset}$ : Puissance minimale produite par l'actif $asset \in elec_{out} \cup gas_{out} \cup h2_{out}$

$P_{in_{max}, asset}$ : Puissance maximale consommée par l'actif $asset \in elec_{in} \cup gas_{in} \cup h2_{in}$

$P_{in_{min}, asset}$ : Puissance minimale consommée par l'actif $asset \in elec_{in} \cup gas_{in} \cup h2_{in}$

### Capacités de stockage
$E_{max_{s}, t}, t\in [1;T]$ : Energie maximale stockée par l'actif $s \in stock$ au pas de temps $t$

$E_{min_{s}, t}, t\in [1;T]$ : Energie minimale stockée par l'actif $s \in stock$ au pas de temps $t$ <!-- Probablement =0 au début -->


### Durée minimale de fonctionnement et d'arrêt
$d_{min_{asset}}$ : Durée minimale de fonctionnement et d'arrêt (en h) de l'actif pilotable $asset \in disp$<!--  A priori pas besoin pour les EnR donc éventuellement ajouter d_min_inter = 0 -->

### Prévisions
Attention respect des facteurs de charge moyens !

#### Productions fatales
$P_{forecast_{inter, t}}, t\in [1;T]$ : Production électrique prévue au pas de temps $t$ pour l'actif $\in inter$ (en kW)

<!-- #### Précipitations pour l'hydraulique lac
$P_{rain_{hydroLac}, t}, t\in [1;T]$ : Puissance turbinable récupérée au pas de temps $t$ pour l'actif $hydroLac$ (en kW > 0) -->

### Besoins à satisfaire
#### Consommation directe électrique

$need_{e,t}, e \in elec_{in}, t\in [1;T]$ : Besoin en électricité de l'actif $e$ au pas de temps $t$

#### Consommation directe de gaz

$need_{g,t}, g \in gas_{in}, t\in [1;T]$ : Besoin en gaz de l'actif $g$ au pas de temps $t$

#### Consommation directe de dihydrogène

$need_{h2,t}, h2 \in h2_{in}, t\in [1;T]$ : Besoin en dihydrogène de l'actof $h2$ au pas de temps $t$

### Prix de l'énergie des différents actifs de production
$Cost_{d}$ : Coût de l'énergie (électricité, gaz, h2) produite par l'actif $d \in disp$ (dont imports elec, gaz) (en €/kWh)

<!-- #### Prix hydraulique
Attention respect variations précipitations

$Cost_{hydroLac \cup step, t}, t\in [1;T]$ :$ : Coût de l'électricité produite par l'actif $hydroLac$ ou $step$ au pas de temps $t$ (en €/kWh) -->

### Disponibilité des actifs
Imports GNL par bateau modélisés sous forme de disponibilité != 0

$Avail_{asset, t}, t\in [1;T]$ : Disponibilité de l'actif $asset \in elec_{out}\cup gas_{out}\cup h2_{out} \cup elec_{in} \cup gas_{in} \cup h2_{in}$ (float, entre 0 et 1)


### Rendements
$Eff_{conv}$ :Rendement de la conversion d'énergie effectuée par l'actif $conv$ (float, entre 0 et 1)

## Variables
### Puissance de fonctionnement des actifs
$P_{in_{asset, t}}, asset \in elec_{in} \cup gas_{in}, t\in [1;T]$

$P_{out_{asset, t}}, asset \in elec_{out} \cup gas_{out}, t\in [1;T]$

### Energie stockée par les actifs de stockage
$E_{s,t}, asset \in stock, t\in [1;T]$ : Energie stockée stockée par l'actif $s \in stock$ à la fin du pas de temps $t$

### Flag de fonctionnement des actifs dispachable

$on_{asset,t} \in {\lbrace 0,1 \rbrace}$ , $asset \in disp, t\in [1;T]$ : L'actif $disp$ de production d'électricité/gaz/h2 est en fonctionnement au pas de temps $t$

### Flag de mise en fonctionnement/d'arrêt des actifs dispachables

$up_{asset,t} \in {\lbrace 0,1 \rbrace} , asset \in disp, t\in [1;T]$ : L'actif $asset$ démarré au pas de temps $t$

$down_{asset,t} \in {\lbrace 0,1 \rbrace} , asset \in disp, t\in [1;T]$ : L'actif $asset$ est arrêté au pas de temps $t$

### Flag d'import/export des interconnexions

$isExporting_{i,t} \in {\lbrace 0,1 \rbrace} , i \in interconnexion, t\in [1;T]$ : L'interconnexion $i$ peut exporter de l'énergie au pas de temps $t$ (1: export, 0: import)

### Puissance disponible des actifs
$P_{inMaxAvail_{asset, t}}, asset \in elec_{in} \cup gas_{in} \cup h2_{in}, t\in [1;T]$

$P_{outMaxAvail_{asset, t}}, asset \in elec_{out} \cup gas_{out} \cup h2{out}, t\in [1;T]$

## Fonction objectif
A détailler :

$$minimize : \displaystyle\sum_{d\in disp}{\sum_{t=1}^{T}{P_{out_{d,t}}* Cost_{d,t}}}$$

## Contraintes
### Contraintes d'équilibre offre-demande
#### EOD élec
Somme Pelec fatal + Somme Pelec Pilotable + Somme Stockages Décharge + Import interconnexions = Conso élec donnée entrée + Somme Stockages Charge + Export interconnexions

$$\displaystyle \forall t \in [1,T],\sum_{e_{in}\in elec_{in}}{P_{in_{e_{in},t}}} = \sum_{e_{out}\in elec_{out}}{P_{out_{e_{out},t}}}$$

#### EOD gaz Nord
Imports GNL bateau + Import interconnexion + Somme prod gaz + Décharge stockages = Somme Pin gaz + Conso gaz directe donnée d’entrée + Charge stockage

$$\displaystyle \forall t \in [1,T],\sum_{g_{in}\in gas_{in}\cap north}{P_{in_{g_{in},t}}} = \sum_{g_{out}\in gas_{out}\cap north}{P_{out_{g_{out},t}}}$$

#### EOD gaz Sud
$$\displaystyle \forall t \in [1,T],\sum_{g_{in}\in gas_{in}\cap south}{P_{in_{g_{in},t}}} = \sum_{g_{out}\in gas_{out}\cap south}{P_{out_{g_{out},t}}}$$

#### EOD H2 Nord
$$\displaystyle \forall t \in [1,T],\sum_{h_{in}\in h2_{in}\cap north}{P_{in_{h_{in},t}}} = \sum_{h_{out}\in h2_{out}\cap north}{P_{out_{h_{out},t}}}$$

#### EOD H2 Sud
$$\displaystyle \forall t \in [1,T],\sum_{h_{in}\in h2_{in}\cap south}{P_{in_{h_{in},t}}} = \sum_{h_{out}\in h2_{out}\cap south}{P_{out_{h_{out},t}}}$$

### Contraintes de disponibilité
Contrainte P_in_max_avail :
$$P_{inMaxAvail_{asset, t}} = P_{in_{max}, asset} * Avail_{asset, t}, asset \in elec_{in} \cup gas_{in} \cup h2_{in}, t\in [1;T]$$

Contrainte P_out_max_avail :
$$P_{outMaxAvail_{asset, t}} = P_{out_{max}, asset} * Avail_{asset, t}, asset \in elec_{out} \cup gas_{out} \cup h2_{out}, t\in [1;T]$$

### Contraintes Pmax
Contrainte P_max_in :
$$P_{in_{asset, t}} <= P_{inMaxAvail_{asset, t}}, asset \in elec_{in} \cup gas_{in} \cup h2_{in} \setminus{\lbrace disp \cup interconnexion \rbrace}, t\in [1;T]$$

Contrainte P_max_in_disp :
$$P_{in_{disp, t}} <= P_{inMaxAvail_{disp, t}} * on_{disp,t}, disp \in disp \cap (elec_{in} \cup gas_{in} \cup h2_{in}), t\in [1;T]$$

Contrainte P_max_export :
$$P_{in_{i, t}} <= P_{inMaxAvail_{i, t}} * isExporting_{i,t}, i \in interconnexion, t\in [1;T]$$

Contrainte P_max_out :
$$P_{out_{asset, t}} <= P_{outMaxAvail_{asset, t}}, asset \in elec_{out} \cup gas_{out} \cup h2_{out} \setminus{\lbrace disp \cup interconnexion \rbrace}, t\in [1;T]$$

Contrainte P_max_out_disp :
$$P_{out_{asset, t}} <= P_{outMaxAvail_{asset, t}} * on_{disp,t}, disp \in disp \cap(elec_{out} \cup gas_{out} \cup h2_{out}), t\in [1;T]$$

Contrainte P_max_import :
$$P_{out_{i, t}} <= P_{outMaxAvail_{i, t}} * (1-isExporting_{i,t}), i \in interconnexion, t\in [1;T]$$

### Containtes Pmin
Contrainte P_min_in :
Si l'actif est on :
$P_{in_{disp, t}} >= P_{in_{min}, disp} * on_{disp,t}, disp \in disp \cap(elec_{in} \cup gas_{in} \cup h2_{in}), t\in [1;T]$

Contrainte P_min_out :
Si l'actif est on :
$P_{out_{disp, t}} >= P_{out_{min}, disp} * on_{dips,t}, disp \in disp \cap(elec_{out} \cup gas_{out} \cup h2_{out}), t\in [1;T]$

### Contraintes durée minimale de fonctionnement et d'arrêt
Pour tous les actifs dispatchables $disp$ :

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

<!-- Contrainte charge_hydro_lac :
Pour les actifs $hydroLac$, la charge se fait avec les précipitations: -->


<!-- Contrainte charge_stock :
/!\ bords
$$P_{in_{s, t}}* duration_t + E_{s,t-1} <= EmaxAvail a définir$$ -->


Contrainte discharge_stock :

$$P_{out_{s, t}}* duration_t <= E_{s,t}$$

Contrainte Pcharge_avail :
Déjà fait avec P_max_in 

Contrainte Pdischarge_avail :
Déjà fait avec P_max_out


### Contraintes d'équilibre aux interconnexions
Contrainte interconnexion_gas1 :
Export north = Import south
$$ \displaystyle \sum_{ex_n \in interconnexion \cap gas_{in} \cap north} P_{in_{ex_n, t}} = \sum_{im_s \in interconnexion \cap gas_{out} \cap south} P_{out_{im_s, t}} $$
Contrainte interconnexion_gas2 : Import north = Export south
$$ \displaystyle \sum_{im_n \in interconnexion \cap gas_{out} \cap north} P_{out_{im_n, t}} = \sum_{ex_s \in interconnexion \cap gas_{in} \cap south} P_{in_{ex_s, t}}$$


Contrainte interconnexion_h21 :
Export north = Import south
$$ \displaystyle \sum_{ex_n \in interconnexion \cap h2_{in} \cap north} P_{in_{ex_n, t}} = \sum_{im_s \in interconnexion \cap h2_{out} \cap south} P_{out_{im_s, t}} $$

Contrainte interconnexion_h22 :
Import north = Export south
$$ \displaystyle \sum_{im_n \in interconnexion \cap h2_{out} \cap north} P_{out_{im_n, t}} = \sum_{ex_s \in interconnexion \cap h2_{in} \cap south} P_{in_{ex_s, t}}$$


## Sorties à prévoir

Puissances activées pour chaque actif

Est-ce que l’actif est allumé ou éteint à la fin de la fenêtre d’optim ?

Etat des stocks (et aussi à la fin de la fenêtre d’optim)

Coûts par filière de prod

Prix de l’hydro en fonction de l’état des stocks et les prévisions de précipitations
