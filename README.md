# ETE-305 Modélisation d'équilibre offre-demande


## Données d'entrées, hypothèses

### Fenêtre d'optimisation
$T$ (entier positif) : Durée de la fenêtre d'optimisation (en h)


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

$import_{elec} \in elec_{in}$ : Imports d'électricité sur le réseau

$export_{elec} \in elec_{out}$ : Exports d'électricité du réseau

$import_{gas} \in gas_{in}$ : Imports de gaz sur le réseau

$export_{gas} \in gas_{out}$ : Exports de gaz du réseau

### Capacités installées
$P_{out_{max}}$ : Puissance maximale produite par l'actif $elec_{out} \cap gaz_{out}$ <!-- \cap heat_{out} -->

$P_{out_{min}}$ : Puissance minimale produite par l'actif $elec_{out} \cap gaz_{out}$ <!-- \cap heat_{out} -->

$P_{in_{max}}$ : Puissance maximale consommée par l'actif $elec_{in} \cap gaz_{in}$  <!-- \cap heat_{in} -->

$P_{in_{min}}$ : Puissance minimale consommée par l'actif $elec_{in} \cap gaz_{in}$  <!-- \cap heat_{in} -->

### Capacités de stockage
$E_{max_{hydroLac, step}}$ : Energie maximale stockée par l'actif $hydroLac, step$

$E_{min_{hydroLac, step}}$ : Energie minimale stockée par l'actif $hydroLac, step$ <!-- Probablement =0 au début -->


### Durée minimale de fonctionnement et d'arrêt
$d_{min_{nuc, ge, gh, coal, fioul, inter, biogas, hydroLac, step}}$ : Durée minimale de fonctionnement et d'arrêt (en h) <!--  A priori pas besoin pour les EnR donc éventuellement ajouter d_min_inter = 0 -->

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
#### Consommation directe de gaz


### Prix de l'énergie des différents actifs de production
$Cost_{elec_{out} \setminus{\lbrace hydroLac \cup step \rbrace}}$ : Coût de l'électricité produite par l'actif $elec_{out}$ (en €/kWh)

$Cost_{gas_{out}}$ : Coût du gas produit par l'actif $gas_{out}$ (en €/kWh)

$Cost_{export_{gas}\cup export_{elec}}$ : Coût (revenu ici) de la vente du gaz et de l'électricité exportée du réseau (en €/kWh)

#### Prix hydraulique
Attention respect variations précipitations

$Cost_{hydroLac \cup step, t}, t\in [1;T]$ :$ : Coût de l'électricité produite par l'actif $hydroLac$ au pas de temps $t$ (en €/kWh)

### Disponibilité des actifs
Imports GNL par bateau modélisés sous forme de disponibilité != 0

$Disp_{elec_{out}\cup gas_{out} \cup {import_{elec} \cup {import_{gas}}}, t}, t\in [1;T]$ : Disponibilité de l'actif (float, entre 0 et 1)


### Rendements
$Eff_{gaz->elec, ge}$ : Rendement de la conversion du gaz en électricité de l'actif $ge$ (float, entre 0 et 1)
<!-- $eff_{gaz, heat, gh}$ : Rendement de la conversion du gaz en chaleur de l'actif $gh$ (float, entre 0 et 1) -->
$Eff_{elec->elec, step}$ : Rendement du pompage et du turbinage de l'actif $step$ (float, entre 0 et 1)

## Variables
### Puissance de fonctionnement des actifs
$P_{in}$

$P_{out}$
### Flag de fonctionnement des actifs dispachable
### Flag de mise en focntionnement/d'arrêt des actifs dispachable
###

## Fonction objectif
Somme des Puissances actif i * prix i

## Contraintes
### Contraintes d'équilibre offre-demande
#### EOD élec (instantané)
Somme Pelec fatal + Somme Pelec Pilotable + Somme Stockages Décharge + Import interconnexions = Conso élec donnée entrée + Somme Stockages Charge + Export interconnexions
#### EOD gaz (journalier)
Imports GNL bateau + Import interconnexion + Somme prod (bio)gaz + Décharge stockages = Somme Pin gaz + Conso gaz directe donnée d’entrée + Charge stockage + Export interconnexions + Export bateau ???

### Contraintes Pmax
### Containtes Pmin
### Contraintes durée minimale de fonctionnement et d'arrêt
### Contraintes de disponibilité
### Contraintes de conservation énergétique (respect des rendements)
### Contraintes de stockage (hydraulique lac, STEP, gaz, elec)
Rendement charge et rendement décharge
### Contraintes import/export elec/gaz



Imports GNL bateau :
Pmax
Pmax modulée par disponibilité : là on représente les arrivages de bateaux
Disponibilité = donnée d’entrée

Imports gaz interconnexions :
Pmax
Disponibilité
prix

Exports gaz interconnexions:
Pmax
Disponibilité
prix

Prod gaz :
Pmax
Disponibilité
prix


Stockage gaz classique: (ultérieurement)
Pmax
Emax
prix
Décharge Pgaz qui doit respecter l’énergie stockée dans le stockage de gaz (min et max)
Charge dans le stockage de gaz <= stockage max
rendement ?
Disponibilité


Stockage constitué par le réseau: (ultérieurement)
Pmax
Emax
prix
Décharge Pgaz qui doit respecter l’énergie stockée dans le réseau de gaz (min et max)
Charge dans le réseau de gaz <= stockage max
rendement = 1
Forcer tous les imports/prod de gaz à passer par ce stockage
Forcer toutes les consos de gaz à sortir de ce stockage
EOD :
Imports GNL bateau + Import interconnexion + prod biogaz + Décharge stockage gaz  = Charge stockage réseau
Décharge stockage réseau = Charge stockage gaz + Somme Pin gaz + Conso gaz directe donnée d’entrée 


Stockage H2: (ultérieurement) Mélange Elec et Gaz
Pmax
Emax
prix
Décharge PH2 qui doit respecter l’énergie stockée dans le stockage de H2(min et max)
Charge dans le stockage de H2<= stockage max
rendement dans les 2 sens Elec-> H2 et H2->elec
Disponibilité




Sorties :
Puissances activées pour chaque actif
Est-ce que l’actif est allumé ou éteint à la fin de la fenêtre d’optim ?
Etat des stocks (et aussi à la fin de la fenêtre d’optim)
Coûts

Prix de l’hydro en fonction de l’état des stocks et les prévisions de précipitations
