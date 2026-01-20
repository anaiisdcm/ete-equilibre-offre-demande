# ETE-305 Modélisation d'équilibre offre-demande


## Données d'entrées, hypothèses

### Fenêtre d'optimisation
$T$ : nombre d'heures constituant la fenêtre d'optimisation

### Capacités installées
$P_{max}$
$P_{min}$

### Productions fatales
Attention respect des facteurs de charge moyens
#### Productions fatales d'électricité
$P_{photovoltaïque}$
$P_{éolien ter}$
$P_{éolien mer}$
$P_{hydro fil}$
$P_{valorisation déchets}$
$P_{biomasse}$
#### Productions fatales de gaz
$P_{biogaz}$

### Besoins à satisfaire
#### Consommation directe électrique
#### Consommation directe de gaz


### Prix de l'énergie des différents actifs de production
#### Prix hydraulique
Attention respect variations précipitations

### Disponibilité des actifs
Imports GNL par bateau modélisés sous forme de disponibilité != 0
P

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








Centrale nucléaire :
Pmax
Pmin
dmin marche/arrêt
prix
Disponibilité

CCG Gaz :
Pmax elec
Pmin elec
dmin marche/arrêt
prix
rendement Pin gaz *rendement = Pout elec
Disponibilité

TAC Gaz :
Pmax elec
Pmin elec
dmin marche/arrêt
prix
rendement Pin gaz *rendement = Pout elec
Disponibilité

Cogén piloté pour satisfaire besoin en chaleur :
Pmax elec
Pmin elec
dmin marche/arrêt
prix
rendements elec : Pin gaz *rendement = Pout elec
rendement chaleur (chaleur si on choisit de modéliser le besoin en chaleur)
Disponibilité

Centrale à charbon :
Pmax
Pmin
dmin marche/arrêt
prix
Disponibilité

Valorisation énergétique déchets:
Prod fatale <= Capacité installée
prix
Disponibilité

Petite biomasse:
Prod fatale <= Capacité installée
Attention à respecter le facteur de charge moyen (dans les données d’entrées)
prix
Disponibilité

Fioul :
Pmax
Pmin
dmin marche/arrêt
prix
Disponibilité


Hydro fil de l’eau:
Prod fatale (dans les données d’entrées)
prix
Disponibilité

Hydro lac :
Pmax = capacité installée
Emax
prix
Décharge Pelec qui doit respecter l’énergie stockée dans le lac (min et max)
Charge du lac = donnée de combien il pleut <= stockage max
Disponibilité

STEP : dispo multiple de 8
Pmax
Emax
prix
Décharge Pelec qui doit respecter l’énergie stockée dans le lac (min et max)
Charge du lac <= stockage max
rendement
Disponibilité

Parc éolien terrestre :
Prod fatale <= Capacité installée
Attention à respecter le facteur de charge moyen (dans les données d’entrées)
prix
Disponibilité

Parc éolien en mer :
Prod fatale <= Capacité installée
Attention à respecter le facteur de charge moyen (dans les données d’entrées)
prix
Disponibilité


Parc solaire :
Prod fatale <= Capacité installée
Attention à respecter le facteur de charge moyen (dans les données d’entrées)
prix
Disponibilité

Import elec interconnexions:
Pmax
Disponibilité
prix

Export elec interconnexions:
Pmax
Disponibilité
prix

Contrainte import export : pas d’import et d’export en meme temps




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

Prod biogaz :
Pmax
Fatal : donnée d’entrée
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
