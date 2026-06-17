# Team Sprint June 2025 Main Repository

Welcome to the example repository for the June 2025 Team Sprint Event.

This codebase currently provides an example of sizing an a321 like aircraft with the following top-level aircraft requirements (TLARs)

| Parameter     | Value | Unit |
|---------------|:-----:|:----:|
| PAX           |  210  |   -  |
| Max. Payload  |  19.3 |   t  |
| Range         |  2450 |  nm  |
| Cruise Alt.   | 34000 |  ft  |
| Cruise Mach   |  0.78 | Mach |
| Max. Wingspan |   36  |   m  |

## Getting Started

To run this code, you must first install the required Matlab packages: [baff](https://github.com/DCRG-Bristol/baff), [ads](https://github.com/DCRG-Bristol/ads), [matran](https://github.com/DCRG-Bristol/matran), [flexcast](https://github.com/DCRG-Bristol/flexcast) and [Matlab Utilities](https://github.com/DCRG-Bristol/matlab-utilities)

These can be installed using Package Installer for Matlab ([pim](https://github.com/DCRG-Bristol/pim)). pim usage instruction can be found [here](https://dcrgdocs.readthedocs.io/en/latest/pim.html)

For a quick intro: Downlaod the latest Binary from the github repository (pim.mltbx)
https://github.com/DCRG-Bristol/pim/releases

run this binary with Matlab open. then type the following in the command window
```pim install -i pim_requirements.txt```
which will downlaod all of the required packages from github.

If all packages are correctly installed, running the following script will size an a321 like aircraft
```scripts.a321_sizing()```
Congratulations, job done. It's time for tea.

## Basic Model Description

The class TAW, which can be instantiated as ```ADP = TAW();```, provides the glue to complete conceptual sizing. This class has properties such as `ADP.Span`, `ADP.HingeEta`, `ADP.FlareAngle`, etc., which act as hyperparameters in generating aircraft models.

I will better define which ones we will vary during the week at a later date.  It is important to note that TAW is a handle class.

Given a set of hyperparameters, the method ```ADP.BuildBaff()``` builds the Aircraft model and stores it in the property `ADP.Baff`. This is stored in the "Binary Aircraft File Format" (Baff). Baff is a platform-agnostic way to save aircraft geometries. More details on the structure of baff files/objects can be found here. 

The key points are:
- baff objects fully define the geometry
- Baff objects can be saved to HDF5 files in a specific format, so they can be loaded in multiple programming languages (albeit I have only ever used it in Matlab). 
- The Matlab wrapper is relatively mature, with methods to establish CoM, wing area, stretch objects, etc...

you can plot the baff object with the call
```f=figure(1);clf;ADP.Baff.draw(f);axis equal;```

My idea for the week would be offline tools can be developed by
1. loading a "sized" aircraft model (e.g. ```load(example_data\UB321_simple.mat)```)
2. pertubing hyper paramters
3. building the baff model
4. Use the baff model as a starting point for your other tools.

## Conceptual Sizing Basics

The conceptual sizing of aircraft estimates the mass of all aircraft systems, and basic mission analysis is conducted to estimate fuel burn. The tool is primarily based on books by D. Raymer and S. Gudmundsson, and a basic overview of the structure can be found in this [conference paper](https://www.icas.org/icas_archive/icas2024/data/papers/icas2024_0386_paper.pdf).

### What do I mean by sizing? 

Many of the mass/size estimation methods depend on the MTOM. Given a set of TLARs and an initial estimate of the MTOM, the code:
1. builds a baff model
2. estimates aeroelastic loads
3. sizes the wing structure
4. Estimates aerodynamic parameters
5. Conducts mission analysis and estimates the required fuel for the specified mission. 

The mass of the baff model + fuel + payload then gives a new estimate for the MTOM. The process can now be repeated until convergence of the MTOM is achieved. We have now sized the aircraft for a given set of hyperparameters.

This process is initiated by calling ``` [...] = ADP.Aircraft_Sizing(sizeOpts);``` as per the example script.

### Estimating Aeroelastic loads

Aeroelastic loads are estimated via the property `ADP.LoadsSurrogate`, which is an instance of the Abstract class ```cast.size.AbstractLaods```

```
classdef (Abstract) AbstractLoads < handle
 methods(Abstract)
 SetConfiguration(obj,opts)
 Lds = GetLoads(obj,Cases)
 end
end
```

`Cases` is a set of Load cases. For the cruise of a locked wing, you can generate an example set of load cases using
```c = LoadCaseFactory.GetCases(ADP);```
Load cases can include manoeuvres, gusts, and turbulence. Each case can have different aircraft configurations (e.g., payload and fuel fractions, hinge locked/free, etc.). We can also vary the safety factor for each load case.

For estimating loads with Nastran, please see the Readme in the +loads folder.

In the Lightweight conceptual sizing version, the surrogate model currently assumes an elliptical lift distribution to quickly estimate forces and moments (see `+loads.EnforcedLiftDist`).

### Estimating Aerodynamic Drag
The TAW class uses the property `ADP.AeroSurrogate` during mission analysis to estimate drag at a given C_l. `ADP.AeroSurrogate` is an instance of the Abstract class `cast.size.AbstractPolar`
```
classdef (Abstract) AbstractPolar  
 methods (Abstract)
 Cd0  = Get_Wing_Cd0(obj)
 Cd = Get_Cd(obj,Cl,Phase)
 end
end
```
Where `Phase` is an instance of the enumeration class `FlightPhase`.

The current lightweight polar (`aero.NitaPolar`) uses a mixture of semi-empirical methods to estimate Oswald efficiency factors at each flight phase + uses a flat-plate analogy to estimate CD0.

This is currently instantiated in the TAW class during the method call `ADP.UpdateAeroEstimates()`, which is called once per iteration of the sizing process.

### Mass Estimates

Many mass estimates use empirical relations and can be found in the `ADP.BuildBaff` and `ADP.BuildWing` methods. Wing mass and structural properties are estimated using a 1D beam condensation of an aluminium wingbox. See [this](https://doi.org/10.2514/1.C036908) paper for details. These are implemented with the code in the Flexcast project (in the class `cast.size.WingBoxSizing`).


## Extracting Data from the Baff object

The output of a conceptual sizing is a "sized" instance of a TAW class, which can be saved to a .mat file. By loading a specific version, then building the baff, you can quickly extract information about the aircrafts geometry / structural properties.

For example, script `scripts.example_plot_EI` plots the EI distribution along the span of the wing and `scripts.example_plot_planform` extracts the wing planform

### TAW class Baff specifics
Generic info on baff objects can be found here.

When you build the Baff, if `ADP.HingeEta=1` (e.g. no folding wingtip), the resulting baff object will have 7 wings. Calling `[ADP.Baff.Wing.Name]` will write the name of these seven wings.

"Wing_Connector_RHS"    "Wing_RHS"    "Wing_Connector_LHS"    "Wing_LHS"    "HTP_RHS"    "HTP_LHS"    "VTP"

HTPs and VTP are the empenage, and the main wing is split into four components (two on each side). "Wing_Connector_*" extends from the centreline to the boundary of the fuselage, and  "Wing_*" extends from the fuselage to the tip.

If `ADP.HingeEta < 1` then there will be nine wings

"Wing_Connector_RHS"    "Wing_RHS"    "FFWT_RHS"    "Wing_Connector_LHS"    "Wing_LHS"    "FFWT_LHS"    "HTP_RHS"    "HTP_LHS" "VTP"

where the main wing is split into two sections at the hinge line. (These two components are connected via a "Hinge" element).

*Fuel* and *Payload* elements have a notion of "Filling Level", this way multiple aircraft configurations (e.g. payload / fuel load combinations can be trialed). To vary Filling levels of an already built baff object see the method `ADP.SetConfiguration()`











