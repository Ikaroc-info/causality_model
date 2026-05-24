import os
import threading
import tkinter as tk
from tkinter import filedialog, messagebox
import customtkinter as ctk
import pandas as pd
import numpy as np
import dowhy
from dowhy import CausalModel
from networkx.drawing.nx_pydot import to_pydot
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier

from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class ScrollableCheckBoxFrame(ctk.CTkScrollableFrame):
    def __init__(self, master, title, command=None, **kwargs):
        super().__init__(master, **kwargs)
        self.grid_columnconfigure(0, weight=1)

        self.title = title
        self.checkboxes = []
        self.cb_command = command

        self.title_label = ctk.CTkLabel(self, text=self.title, font=ctk.CTkFont(size=14, weight="bold"))
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="w")

    def add_item(self, item):
        checkbox = ctk.CTkCheckBox(self, text=item, command=self.cb_command)
        checkbox.grid(row=len(self.checkboxes) + 1, column=0, padx=10, pady=(10, 0), sticky="w")
        self.checkboxes.append(checkbox)

    def get_checked_items(self):
        return [checkbox.cget("text") for checkbox in self.checkboxes if checkbox.get() == 1]
        
    def clear(self):
        for checkbox in self.checkboxes:
            checkbox.destroy()
        self.checkboxes.clear()

class CausalApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Causal Experience Manager (Dowhy + Tkinter)")
        self.geometry("1100x700")

        # Core State
        self.df = None
        self.headers = []
        self.treatment_vars = []
        self.outcome_var = None
        self.confounders = []
        
        self.estimator_method = ctk.StringVar(value="backdoor.linear_regression")
        self.refuter_method = ctk.StringVar(value="random_common_cause")

        # Configure Grid
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # ----------------- SIDEBAR -----------------
        self.sidebar_frame = ctk.CTkFrame(self, width=200, corner_radius=0)
        self.sidebar_frame.grid(row=0, column=0, sticky="nsew")
        self.sidebar_frame.grid_rowconfigure(6, weight=1)

        self.logo_label = ctk.CTkLabel(self.sidebar_frame, text="Causal Manager", font=ctk.CTkFont(size=20, weight="bold"))
        self.logo_label.grid(row=0, column=0, padx=20, pady=(20, 10))

        self.btn_load_csv = ctk.CTkButton(self.sidebar_frame, text="Load CSV File", command=self.load_csv)
        self.btn_load_csv.grid(row=1, column=0, padx=20, pady=10)

        self.btn_demo_data = ctk.CTkButton(self.sidebar_frame, text="Load Demo Data", command=self.load_demo_data)
        self.btn_demo_data.grid(row=2, column=0, padx=20, pady=10)

        self.status_label = ctk.CTkLabel(self.sidebar_frame, text="Data: None", text_color="gray")
        self.status_label.grid(row=3, column=0, padx=20, pady=(5, 20))

        self.btn_analyze = ctk.CTkButton(self.sidebar_frame, text="Run Analysis", font=ctk.CTkFont(weight="bold"), 
                                         fg_color="#2ecc71", hover_color="#27ae60", command=self.run_analysis)
        self.btn_analyze.grid(row=4, column=0, padx=20, pady=10)
        
        self.progress_bar = ctk.CTkProgressBar(self.sidebar_frame)
        self.progress_bar.grid(row=5, column=0, padx=20, pady=10)
        self.progress_bar.set(0)
        self.progress_bar.grid_remove() # hide initially

        # ----------------- MAIN AREA -----------------
        self.tabview = ctk.CTkTabview(self)
        self.tabview.grid(row=0, column=1, padx=20, pady=(10, 20), sticky="nsew")
        
        self.tab_config = self.tabview.add("1. Configuration")
        self.tab_report = self.tabview.add("2. Treatment Report")
        self.tab_diag = self.tabview.add("3. Diagnostics & SMD")

        self.build_config_tab()
        self.build_report_tab()
        self.build_diag_tab()

    def build_config_tab(self):
        self.tab_config.grid_columnconfigure(0, weight=1)
        self.tab_config.grid_columnconfigure(1, weight=1)
        self.tab_config.grid_columnconfigure(2, weight=1)
        self.tab_config.grid_rowconfigure(1, weight=1)

        # Top row: Option Mentus
        self.control_frame = ctk.CTkFrame(self.tab_config)
        self.control_frame.grid(row=0, column=0, columnspan=3, padx=10, pady=10, sticky="ew")

        ctk.CTkLabel(self.control_frame, text="Outcome Variable:").grid(row=0, column=0, padx=10, pady=10)
        self.outcome_combo = ctk.CTkOptionMenu(self.control_frame, values=["---"], command=self.update_ui_state)
        self.outcome_combo.grid(row=0, column=1, padx=10, pady=10)

        ctk.CTkLabel(self.control_frame, text="Estimator:").grid(row=0, column=2, padx=10, pady=10)
        self.estimator_combo = ctk.CTkOptionMenu(self.control_frame, variable=self.estimator_method, command=self.update_ui_state,
            values=[
                "backdoor.linear_regression", 
                "backdoor.propensity_score_matching", 
                "backdoor.propensity_score_weighting",
                "backdoor.distance_matching",
                "iv.instrumental_variable",
                "backdoor.econml.dml.LinearDML",
                "backdoor.econml.metalearners.XLearner"
            ])
        self.estimator_combo.grid(row=0, column=3, padx=10, pady=10)

        ctk.CTkLabel(self.control_frame, text="Refuter:").grid(row=0, column=4, padx=10, pady=10)
        self.refuter_combo = ctk.CTkOptionMenu(self.control_frame, variable=self.refuter_method,
            values=[
                "random_common_cause", 
                "placebo_treatment_refuter",
                "data_subset_refuter",
                "add_unobserved_common_cause",
                "bootstrap_refuter"
            ])
        self.refuter_combo.grid(row=0, column=5, padx=10, pady=10)

        self.tab_config.grid_rowconfigure(1, weight=1)
        self.tab_config.grid_rowconfigure(2, weight=1)

        self.treatments_frame = ScrollableCheckBoxFrame(self.tab_config, title="1. Treatments (Causes)", command=self.update_ui_state)
        self.treatments_frame.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")

        self.confounders_frame = ScrollableCheckBoxFrame(self.tab_config, title="2. Confounders (Controls)", command=self.update_ui_state)
        self.confounders_frame.grid(row=1, column=1, columnspan=2, padx=10, pady=10, sticky="nsew")

        self.effect_modifiers_frame = ScrollableCheckBoxFrame(self.tab_config, title="3. Effect Modifiers (CATE)", command=self.update_ui_state)
        self.effect_modifiers_frame.grid(row=2, column=0, padx=10, pady=10, sticky="nsew")

        self.instruments_frame = ScrollableCheckBoxFrame(self.tab_config, title="4. Instruments (IV)", command=self.update_ui_state)
        self.instruments_frame.grid(row=2, column=1, columnspan=2, padx=10, pady=10, sticky="nsew")

    def build_report_tab(self):
        self.tab_report.grid_rowconfigure(0, weight=1)
        self.tab_report.grid_columnconfigure(0, weight=1)
        
        self.report_scroll = ctk.CTkScrollableFrame(self.tab_report)
        self.report_scroll.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")

    def build_diag_tab(self):
        self.tab_diag.grid_rowconfigure(0, weight=1)
        self.tab_diag.grid_columnconfigure(0, weight=1)
        
        # We will embed matplotlib here
        self.plot_frame = ctk.CTkFrame(self.tab_diag)
        self.plot_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")

    def populate_headers(self, headers):
        self.headers = headers
        self.outcome_combo.configure(values=self.headers)
        if self.headers:
             self.outcome_combo.set(self.headers[-1]) # Default to last col

        self.treatments_frame.clear()
        self.confounders_frame.clear()
        if hasattr(self, 'effect_modifiers_frame'):
            self.effect_modifiers_frame.clear()
            self.instruments_frame.clear()
            
        for h in self.headers:
            self.treatments_frame.add_item(h)
            self.confounders_frame.add_item(h)
            if hasattr(self, 'effect_modifiers_frame'):
                self.effect_modifiers_frame.add_item(h)
                self.instruments_frame.add_item(h)
                
        self.update_ui_state()

    def load_csv(self):
        filepath = filedialog.askopenfilename(filetypes=[("CSV files", "*.csv")])
        if filepath:
            try:
                self.df = pd.read_csv(filepath)
                self.df.dropna(inplace=True)
                self.populate_headers(self.df.columns.tolist())
                self.status_label.configure(text=f"Loaded: {len(self.df)} rows", text_color="#2ecc71")
                self.tabview.set("1. Configuration")
            except Exception as e:
                messagebox.showerror("Error", f"Could not read CSV:\n{e}")

    def load_demo_data(self):
        # Generate demo data identical to the React app
        test_data = []
        for _ in range(300):
            age = np.random.randint(20, 60)
            education = np.random.randint(12, 20)
            is_treated = 1 if np.random.rand() < (0.3 + (age / 100)) else 0
            base_income = 1500 + age * 25 + education * 80
            income = base_income + (is_treated * 450) + (np.random.rand() * 300 - 150)
            test_data.append([age, education, is_treated, int(income)])
            
        self.df = pd.DataFrame(test_data, columns=["age", "education", "treatment", "income"])
        self.populate_headers(self.df.columns.tolist())
        self.status_label.configure(text=f"Loaded Demo: {len(self.df)} rows", text_color="#2ecc71")
        
        # Select predefined for demo to speed up
        self.outcome_combo.set("income")
        for cb in self.treatments_frame.checkboxes:
            if cb.cget("text") == "treatment": cb.select()
        for cb in self.confounders_frame.checkboxes:
            if cb.cget("text") in ["age", "education"]: cb.select()
            
        self.tabview.set("1. Configuration")
        self.after(50, self.update_ui_state)

    def update_ui_state(self, *args):
        if self.df is None or not hasattr(self, 'treatments_frame'):
            self.btn_analyze.configure(state="disabled", text="Run Analysis")
            return
            
        estimator = self.estimator_method.get()
        outcome = self.outcome_combo.get()
        
        # Get raw states initially
        treats = [cb.cget("text") for cb in self.treatments_frame.checkboxes if cb.get() == 1]
        confs = [cb.cget("text") for cb in self.confounders_frame.checkboxes if cb.get() == 1]
        insts = [cb.cget("text") for cb in self.instruments_frame.checkboxes if cb.get() == 1]
        ems = [cb.cget("text") for cb in self.effect_modifiers_frame.checkboxes if cb.get() == 1]
        
        for h in self.headers:
            is_o = (h == outcome)
            is_t = (h in treats)
            is_c = (h in confs)
            is_i = (h in insts)
            is_e = (h in ems)
            
            # Treatments: cannot be O, C, I, E
            cb_t = next((cb for cb in self.treatments_frame.checkboxes if cb.cget("text") == h), None)
            if cb_t:
                if is_o or is_c or is_i or is_e:
                    if cb_t.get() == 1: cb_t.deselect()
                    cb_t.configure(state="disabled")
                else: cb_t.configure(state="normal")
                    
            # Confounders: cannot be O, T, I (can overlap with E)
            cb_c = next((cb for cb in self.confounders_frame.checkboxes if cb.cget("text") == h), None)
            if cb_c:
                if is_o or is_t or is_i:
                    if cb_c.get() == 1: cb_c.deselect()
                    cb_c.configure(state="disabled")
                else: cb_c.configure(state="normal")
                
            # Effect Modifiers: cannot be O, T, I (can overlap with C)
            cb_e = next((cb for cb in self.effect_modifiers_frame.checkboxes if cb.cget("text") == h), None)
            if cb_e:
                if is_o or is_t or is_i:
                    if cb_e.get() == 1: cb_e.deselect()
                    cb_e.configure(state="disabled")
                else: cb_e.configure(state="normal")
                
            # Instruments: cannot be O, T, C, E
            cb_i = next((cb for cb in self.instruments_frame.checkboxes if cb.cget("text") == h), None)
            if cb_i:
                if is_o or is_t or is_c or is_e:
                    if cb_i.get() == 1: cb_i.deselect()
                    cb_i.configure(state="disabled")
                else: cb_i.configure(state="normal")
                
        # Re-fetch states after programmatic modification to run safety checks
        treats_final = [cb.cget("text") for cb in self.treatments_frame.checkboxes if cb.get() == 1]
        confs_final = [cb.cget("text") for cb in self.confounders_frame.checkboxes if cb.get() == 1]
        insts_final = [cb.cget("text") for cb in self.instruments_frame.checkboxes if cb.get() == 1]
        ems_final = [cb.cget("text") for cb in self.effect_modifiers_frame.checkboxes if cb.get() == 1]

        can_run = True
        error_msg = ""
        
        if not treats_final:
            can_run = False
            error_msg = "Requires 1 Treatment"
        elif not outcome or outcome == "---":
            can_run = False
            error_msg = "Requires Outcome"
        elif "propensity" in estimator and not confs_final:
            can_run = False
            error_msg = "Need Confounder"
        elif "iv." in estimator and not insts_final:
            can_run = False
            error_msg = "Need Instrument"
        elif "econml" in estimator and not ems_final:
            can_run = False
            error_msg = "Need Effect Mod"
            
        if can_run:
            self.btn_analyze.configure(state="normal", text="Run Analysis")
        else:
            self.btn_analyze.configure(state="disabled", text=f"Locked: {error_msg}")

    def run_analysis(self):
        if self.df is None:
            messagebox.showwarning("Warning", "Please load a dataset first.")
            return

        treatments = self.treatments_frame.get_checked_items()
        confounders = self.confounders_frame.get_checked_items()
        effect_mods = self.effect_modifiers_frame.get_checked_items()
        instruments = self.instruments_frame.get_checked_items()
        outcome = self.outcome_combo.get()
        estimator = self.estimator_method.get()
        refuter = self.refuter_method.get()

        if not treatments or not outcome or outcome == "---":
            messagebox.showwarning("Warning", "Validation failed. Please check your selections.")
            return
            
        # UI updates before threading
        self.btn_analyze.configure(state="disabled")
        self.progress_bar.grid()
        self.progress_bar.start()

        for widget in self.report_scroll.winfo_children():
            widget.destroy()
            
        loading_label = ctk.CTkLabel(self.report_scroll, text="Running DoWhy Analysis...\nPlease wait.", font=ctk.CTkFont(size=16, weight="bold"))
        loading_label.pack(pady=50)

        self.tabview.set("2. Treatment Report")

        threading.Thread(target=self._run_analysis_thread, 
                         args=(treatments, confounders, effect_mods, instruments, outcome, estimator, refuter), 
                         daemon=True).start()

    def _run_analysis_thread(self, treatments, confounders, effect_mods, instruments, outcome, estimator, refuter):
        results_list = []
        smd_data_all = {}

        try:
            for treat_var in treatments:
                model = CausalModel(
                    data=self.df,
                    treatment=treat_var,
                    outcome=outcome,
                    common_causes=confounders,
                    effect_modifiers=effect_mods,
                    instruments=instruments
                )
                
                identified_estimand = model.identify_effect(proceed_when_unidentifiable=True)
                
                method_params = None
                if "econml" in estimator:
                    is_discrete = len(self.df[treat_var].unique()) <= 5
                    if "LinearDML" in estimator:
                        method_params = {
                            "init_params": {
                                'model_y': RandomForestRegressor(n_estimators=50, n_jobs=-1),
                                'model_t': RandomForestClassifier(n_estimators=50, n_jobs=-1) if is_discrete else RandomForestRegressor(n_estimators=50, n_jobs=-1),
                                'discrete_treatment': is_discrete
                            },
                            "fit_params": {}
                        }
                    elif "XLearner" in estimator:
                        method_params = {
                            "init_params": {
                                'models': RandomForestRegressor(n_estimators=50, n_jobs=-1)
                            },
                            "fit_params": {}
                        }

                estimate = model.estimate_effect(
                    identified_estimand,
                    method_name=estimator,
                    method_params=method_params
                )
                ate_val = estimate.value
                
                refutation = model.refute_estimate(
                    identified_estimand, 
                    estimate,
                    method_name=refuter
                )
                new_effect = getattr(refutation, 'new_effect', 0)
                
                passed = abs(ate_val - new_effect) <= (abs(ate_val) * 0.2)
                paths = model._graph.get_backdoor_paths([treat_var], [outcome])
                
                results_list.append({
                    "treatment": treat_var,
                    "outcome": outcome,
                    "ate": ate_val,
                    "refuter": refuter,
                    "new_effect": new_effect,
                    "passed": passed,
                    "paths": paths
                })
                
                smd_data = self.calculate_smd(treat_var, confounders)
                if smd_data:
                    smd_data_all[treat_var] = smd_data

            self.after(0, self._update_ui_post_analysis, results_list, smd_data_all)

        except Exception as e:
             self.after(0, self._update_ui_post_analysis, str(e), None, True)

    def calculate_smd(self, treatment_col, confounders):
        smd_res = {}
        if not confounders: return smd_res
        
        # ensure binary
        if len(self.df[treatment_col].unique()) > 2:
            return smd_res

        treated = self.df[self.df[treatment_col] == self.df[treatment_col].max()]
        control = self.df[self.df[treatment_col] == self.df[treatment_col].min()]
        
        for col in confounders:
            try:
                mean_t, mean_c = treated[col].mean(), control[col].mean()
                var_t, var_c = treated[col].var(), control[col].var()
                
                pooled_std = np.sqrt((var_t + var_c) / 2)
                if pooled_std == 0 or np.isnan(pooled_std):
                    smd = 0.0
                else:
                    smd = (mean_t - mean_c) / pooled_std
                smd_res[col] = float(smd)
            except:
                pass
        return smd_res

    def _update_ui_post_analysis(self, results_data, smd_data, is_error=False):
        self.progress_bar.stop()
        self.progress_bar.grid_remove()
        self.btn_analyze.configure(state="normal")
        
        for widget in self.report_scroll.winfo_children():
            widget.destroy()
            
        if is_error:
            err_label = ctk.CTkLabel(self.report_scroll, text=f"Error:\n{results_data}", text_color="red")
            err_label.pack(pady=20)
            return

        for res in results_data:
            frame = ctk.CTkFrame(self.report_scroll, corner_radius=15, fg_color="#1E293B")
            frame.pack(fill="x", padx=20, pady=15)
            
            # Header
            header_text = f"Treatment Effect: {res['treatment']} ➡️ {res['outcome']}"
            ctk.CTkLabel(frame, text=header_text, font=ctk.CTkFont(size=14, weight="bold"), text_color="#3498db").pack(anchor="w", padx=20, pady=(15, 5))
            
            # ATE
            ate_color = "#2ecc71" if res['ate'] > 0 else "#e74c3c"
            sign = "+" if res['ate'] > 0 else ""
            ctk.CTkLabel(frame, text=f"{sign}{res['ate']:.4f}", font=ctk.CTkFont(size=40, weight="bold"), text_color=ate_color).pack(anchor="w", padx=20)
            
            desc = f"Increasing {res['treatment']} by 1 unit leads to a net {'increase' if res['ate'] > 0 else 'decrease'} of {abs(res['ate']):.4f} in {res['outcome']}."
            ctk.CTkLabel(frame, text=desc, font=ctk.CTkFont(size=12)).pack(anchor="w", padx=20, pady=(0, 15))
            
            # Refutation
            ref_frame = ctk.CTkFrame(frame, fg_color="#0F172A" if res['passed'] else "#4A1A1A", corner_radius=10)
            ref_frame.pack(fill="x", padx=20, pady=10)
            
            status_text = "PASSED ✓" if res['passed'] else "WARNING ⚠"
            status_color = "#2ecc71" if res['passed'] else "#e74c3c"
            
            ctk.CTkLabel(ref_frame, text=f"Refutation ({res['refuter']})", font=ctk.CTkFont(weight="bold")).grid(row=0, column=0, padx=15, pady=10, sticky="w")
            ctk.CTkLabel(ref_frame, text=f"New Estimate: {res['new_effect']:.4f}").grid(row=0, column=1, padx=15, pady=10)
            ctk.CTkLabel(ref_frame, text=status_text, text_color=status_color, font=ctk.CTkFont(weight="bold")).grid(row=0, column=2, padx=15, pady=10, sticky="e")
            ref_frame.grid_columnconfigure(1, weight=1)
            
            # Backdoor paths
            if res['paths']:
                paths_str = ", ".join([" ➔ ".join(p) for p in res['paths']])
                ctk.CTkLabel(frame, text=f"Backdoor Paths explicitly detected: {paths_str}", font=ctk.CTkFont(size=11, slant="italic"), text_color="gray").pack(anchor="w", padx=20, pady=(0, 15))
            else:
                ctk.CTkLabel(frame, text="No explicit backdoor paths found.", font=ctk.CTkFont(size=11, slant="italic"), text_color="gray").pack(anchor="w", padx=20, pady=(0, 15))

        if smd_data:
            self._plot_smd(smd_data)

    def _plot_smd(self, smd_data_all):
        # Clear old plot
        for widget in self.plot_frame.winfo_children():
            widget.destroy()

        if not smd_data_all:
            ctk.CTkLabel(self.plot_frame, text="No SMD data plotted (Require binary treatments & controls)").pack(pady=20)
            return

        fig = Figure(figsize=(8, 4), dpi=100)
        
        # Plot the first treatment's SMD for simplicity in this window
        treat_var = list(smd_data_all.keys())[0]
        smd_dict = smd_data_all[treat_var]
        
        if not smd_dict:
             return
             
        ax = fig.add_subplot(111)
        variables = list(smd_dict.keys())
        values = list(smd_dict.values())
        
        # Color based on < 0.1
        colors = ['#2ecc71' if abs(x) < 0.1 else '#e74c3c' for x in values]
        
        ax.barh(variables, values, color=colors)
        ax.axvline(x=0.1, color='red', linestyle='--', alpha=0.5)
        ax.axvline(x=-0.1, color='red', linestyle='--', alpha=0.5)
        ax.axvline(x=0, color='gray', linestyle='-')
        ax.set_title(f"Standardized Mean Difference (Covariate Balance) for {treat_var}")
        ax.set_xlabel("SMD (< 0.1 is considered balanced)")
        
        fig.tight_layout()
        
        canvas = FigureCanvasTkAgg(fig, master=self.plot_frame)
        canvas.draw()
        canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=1)

if __name__ == "__main__":
    app = CausalApp()
    app.mainloop()
