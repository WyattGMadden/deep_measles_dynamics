# Deep-learning neural networks for endemic measles dynamics: comparative analysis and integration with mechanistic models


This repo contains instructions to reproduce all figures and tables referenced in paper. 

## Prerequisites

- [Anaconda or Miniconda](https://docs.conda.io/en/latest/miniconda.html) installed
- [R](https://www.r-project.org/) installed (if not managed via Conda)

## Installation Instructions

### **1. Clone the Repository**

```bash
git clone https://github.com/wyattgmadden/deep_measles_dynamics.git
cd deep_measles_dynamics
```
### **2. Set Up Conda python Environment

```bash
# Create the Conda environment from the environment.yml file
conda env create -f environment.yml

# Activate the Conda environment
conda activate finalmlenv
```
### **3. Set up renv R environment

```bash
Rscript -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript -e "renv::restore()"
```


## Run Makefile to Generate Figures and Tables

```bash
make all
```

Figures and tables will be created in 'output/figures/' and 'output/tables/' directories respectively. 

To explore certain components of the code and better understand the structure of the codebase, please inspect the makefile. Note that later targets in the makefile may depend on outputs generated in previous targets.


