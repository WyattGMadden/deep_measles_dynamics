# Define phony targets for clarity
.PHONY: all createfig1 createfig2 createfig3 createfig4 createfig5

# Default target
all: createfig1 createfig2 createfig3 createfig4 createfig5 createtabs1 clean

# Create Fig 1 (nn architecture plot)
# Fig1: output/figures/feedforward_network_structure.png
createfig1:
	mkdir -p output/figures/
	cd code/python/basic_nn/plotting && python nn_architecture_plots.py

# Create Fig 2 (SFFN vs TSIR) 
# Fig2: output/figures/rmse_reg_and_gain_nn_tsir_k_facet.png
createfig2:
	# fit tsir
	mkdir -p output/data/tsir/uk/raw
	cd code/r/tsir && Rscript tsir_uk_run.R
	mkdir -p output/data/tsir/uk/processed
	cd code/r/tsir && Rscript tsir_uk_process.R
	mkdir -p output/data/tsir_susceptibles
	cd code/r/tsir && Rscript tsir_susceptibles_gen.R
	# determine optimal neural net hyperparameters
	mkdir -p output/data/basic_nn_optimal/raytune_hp_optim
	cd code/python/basic_nn && ./full_basic_raytune.sh
	#fit neural nets
	mkdir -p output/models/basic_nn_optimal
	cd code/python/basic_nn && ./full_basic_optimal.sh
	mkdir -p output/data/basic_nn_optimal
	cd code/r/basic_nn && Rscript optimal_basic_nn_process.R
	cd code/r/basic_nn && Rscript cases_process.R
	#make plots
	cd code/r/basic_nn && Rscript optimal_compare_plots.R

# Create Fig 3 (SHAP plot)
# Fig3: output/figures/shap_10quantile_boxplots.png
createfig3:
	# create data sets
	mkdir -p output/data/prefit_cases
	cd code/python/data_processing && python prevac_measles_data_loader.py
	mkdir -p output/data/basic_nn_optimal/prefit
	cd code/python/basic_nn/explain && ./data_process_explain.sh
	mkdir -p output/data/basic_nn_optimal/explain
	cd code/python/basic_nn/explain && ./basic_nn_explain.sh
	cd code/r/basic_nn/ && Rscript explain_plots.R

# Create Fig 4 (PINN plot) and Table 1 (PINN table)
# Fig3: output/figures/pinn_ab_test_pred_param_fit.png
# Tab1: output/tables/mae_test.txt
createfig4:
	mkdir -p output/models/pinn_experiments/london_repeat_pinn_yearcutoff
	cd code/python/pinn_experiments/london_repeat_pinn_yearcutoff && ./run.sh
	mkdir -p output/tables
	cd code/r/pinn_experiments && Rscript london_repeat_pinn_yearcutoff.R

# Create Fig 5 (spatial + temporal plot) 
# Fig5: output/figures/fig5_spat_temp.png
createfig5:
	cd code/r/basic_nn && Rscript map_plots.R

# Create Fig 6 (London BIF)
# FigS1: output/figures/nn_compare_london_k1to4_nonlog_bif.png
createfig6:
	mkdir -p output/models/basic_nn_bif
	cd code/python/basic_nn && .full_basic_bif.sh
	mkdir -p output/data/basic_nn_bif
	cd code/r/basic_nn && Rscript basic_nn_bif_process.R
	cd code/r/basic_nn && Rscript basic_nn_bif_plots.R

# Create Tab S1 (Train/Test year cutoff sensitivity analysis)
# TabS2: output/tables/test_train_cutoff_basic_tsir_rmse.csv
createtabs1:
	mkdir -p output/models/basic_nn_optimal_60
	mkdir -p output/models/basic_nn_optimal_62
	cd code/python/basic_nn && ./full_basic_optimal_60.sh
	cd code/python/basic_nn && ./full_basic_optimal_62.sh
	mkdir -p output/data/basic_nn_optimal_60
	mkdir -p output/data/basic_nn_optimal_62
	Rscript code/r/basic_nn/compare_basic_nn_60_61_62_tsir.R

# Create Table S2 (optimal hyperparameters table)
# TabS2: output/tables/raytune_hp_optim_all.csv
createtabs2:
	cd code/r/basic_nn/raytune_hp_process.R && Rscript raytune_hp_process.R

clean:
	rm -r output/data
	rm -r output/models
