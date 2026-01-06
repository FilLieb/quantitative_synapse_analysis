# quantitative_synapse_analysis
 multi-channel cluster analysis


These imageJ/FIJI macros identify and quantify the properties of clusters from multi-channel fluorescent images. Macros are intended to be used in an automated fashion to remove user bias. In the laboratory we applied macros to primary neurons that express low levels of fluorescently labeled gephyrin (either mScarlet or mEGFP tagged) and a cell filler (moxBFP). Cultures were co-stained for markers of inhibitory synapses (vGAT, GABAARgamma2, GABAARalpha1, GABAARalpha2). Image stacks were recorded on a LEICA Sp8 confocal microscope equipped with adaptive deconvolution (LIGHTNING). 

To adapt code flexibly to specific imaging experiments it exists in multiple modules. Pay attention that code requires images to be saved in specific file formats, sequence order of fluorescent images, and subfolder structures, such as:
date of imaging/date of culture/condition/cell number

Code can be flexibly adapted to your, microscope type, experiments and habit of saving files. 

For more information check out our publications:

Automated Image Analysis Reveals Different Localization of Synaptic Gephyrin C4 Splice Variants

eNeuro 21 December 2022, 10 (1) ENEURO.0102-22.2022; https://doi.org/10.1523/ENEURO.0102-22.2022

Phosphoinositide- and Collybistin-Dependent Synaptic Clustering of Gephyrin

Journal of Neurochemistry 169, no. 8: e70169; https://doi.org/10.1111/jnc.70169.


Gephyrin filaments represent the molecular basis of inhibitory postsynaptic densities

Nat Commun 16, 8293 (2025); https://doi.org/10.1038/s41467-025-63748-w
