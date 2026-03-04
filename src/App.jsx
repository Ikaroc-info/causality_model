import React, { useState, useRef, useMemo } from 'react'
import { Upload, Play, Database, BarChart3, Settings2, FileText, CheckCircle2, AlertCircle, AlertTriangle, Info, TrendingUp, Users, Target } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import Papa from 'papaparse'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer, Cell,
  ScatterChart, Scatter, ZAxis
} from 'recharts'
import { cn } from './lib/utils'

export default function App() {
  const [step, setStep] = useState(1)
  const [data, setData] = useState([])
  const [headers, setHeaders] = useState([])
  const [error, setError] = useState(null)
  const [fileName, setFileName] = useState('')
  const fileInputRef = useRef(null)

  const [treatments, setTreatments] = useState([]) // Changed to array for multiple inputs
  const [outcome, setOutcome] = useState(null)
  const [controls, setControls] = useState([])
  const [results, setResults] = useState(null)
  const [isRunning, setIsRunning] = useState(false)
  const [selectedModel, setSelectedModel] = useState('dowhy') // Default to dowhy backend
  const [estimator, setEstimator] = useState("backdoor.linear_regression")
  const [refuter, setRefuter] = useState("random_common_cause")

  // Call Python Backend
  const runRegression = async (inputData, target, treatments, commonCauses, estimatorMethod, refuterMethod) => {
    try {
      const response = await fetch('http://localhost:8000/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          data: inputData,
          treatment: treatments,
          outcome: target,
          common_causes: commonCauses,
          estimator_method: estimatorMethod,
          refuter_method: refuterMethod
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || "Backend analysis failed");
      }

      const resultData = await response.json();
      return resultData;

    } catch (e) {
      return { error: "Analysis error: " + e.message }
    }
  }

  const handleRunModels = async () => {
    setIsRunning(true)
    setError(null)
    setStep(3)

    try {
      const res = await runRegression(data, outcome, treatments, controls, estimator, refuter)
      if (res.error) {
        setError(res.error)
        setStep(2)
      } else {
        setResults(res)
        setStep(4)
      }
    } catch (err) {
      setError("Unexpected frontend error: " + err.message)
      setStep(2)
    } finally {
      setIsRunning(false)
    }
  }

  const processFile = (file) => {
    setFileName(file.name)
    setError(null)
    // Reset selection state
    setTreatments([])
    setOutcome(null)
    setControls([])

    Papa.parse(file, {
      header: true,
      dynamicTyping: true,
      skipEmptyLines: true,
      complete: (results) => {
        if (results.data && results.data.length > 0) {
          setData(results.data)
          setHeaders(Object.keys(results.data[0]))
          setStep(2)
        } else {
          setError("The CSV file seems to be empty or invalid.")
        }
      },
      error: (err) => {
        setError("Error parsing CSV: " + err.message)
      }
    })
  }

  const handleFileUpload = (event) => {
    const file = event.target.files[0]
    if (file) processFile(file)
  }

  const handleDragOver = (e) => { e.preventDefault(); e.stopPropagation(); }
  const handleDrop = (e) => {
    e.preventDefault(); e.stopPropagation();
    const file = e.dataTransfer.files[0];
    if (file && (file.type === 'text/csv' || file.name.endsWith('.csv'))) processFile(file);
    else setError("Please upload a valid CSV file.");
  }

  const toggleControl = (header) => {
    if (controls.includes(header)) setControls(controls.filter(c => c !== header))
    else setControls([...controls, header])
  }

  const toggleTreatment = (header) => {
    if (treatments.includes(header)) setTreatments(treatments.filter(t => t !== header))
    else setTreatments([...treatments, header])
  }

  const generateTestData = () => {
    // Generate data locally for demo purposes, then send to backend
    const testData = Array.from({ length: 300 }, () => {
      const age = Math.floor(Math.random() * 40) + 20
      const education = Math.floor(Math.random() * 8) + 12
      const isTreated = Math.random() < (0.3 + (age / 100)) ? 1 : 0
      const baseIncome = 1500 + age * 25 + education * 80
      const income = baseIncome + (isTreated * 450) + (Math.random() * 300 - 150)
      return { age, education, treatment: isTreated, income: Math.round(income) }
    })
    setData(testData)
    setHeaders(['age', 'education', 'treatment', 'income'])
    // Reset selection state
    setTreatments([])
    setOutcome(null)
    setControls([])
    setFileName('demo_experiment.csv')
    setStep(2)
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-50 p-4 md:p-8 selection:bg-blue-500/30">
      <header className="max-w-7xl mx-auto mb-10 md:mb-16 flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div>
          <motion.h1
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            className="text-4xl md:text-5xl font-black bg-gradient-to-r from-blue-400 via-indigo-400 to-purple-400 bg-clip-text text-transparent tracking-tight"
          >
            Causal Experience Manager
          </motion.h1>
          <motion.p
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1 }}
            className="text-slate-500 mt-2 text-lg font-medium"
          >
            Powered by Microsoft DoWhy & Python
          </motion.p>
        </div>
        {fileName && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="flex items-center gap-4 bg-slate-900/50 backdrop-blur-xl border border-slate-800 p-2 pl-4 pr-5 rounded-2xl ring-1 ring-blue-500/20"
          >
            <div className="w-10 h-10 bg-blue-500/10 rounded-xl flex items-center justify-center text-blue-400">
              <FileText size={20} />
            </div>
            <div>
              <div className="text-sm font-bold text-slate-200 truncate max-w-[150px]">{fileName}</div>
              <div className="text-xs text-slate-500 font-bold uppercase tracking-wider">{data.length} records</div>
            </div>
          </motion.div>
        )}
      </header>

      <main className="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Navigation Sidebar */}
        <aside className="lg:col-span-3 space-y-3 sticky top-8">
          <StepCard number={1} title="Data Input" active={step === 1} done={step > 1} onClick={() => setStep(1)} />
          <StepCard number={2} title="Configuration" active={step === 2} done={step > 2} onClick={() => step >= 2 && setStep(2)} />
          <StepCard number={3} title="Processing" active={step === 3} done={step > 3} onClick={() => { }} />
          <StepCard number={4} title="Analysis" active={step === 4} done={false} onClick={() => step >= 4 && setStep(4)} />
        </aside>

        {/* Content Panel */}
        <section className="lg:col-span-9 bg-slate-900/40 rounded-[2.5rem] border border-slate-800 p-6 md:p-10 backdrop-blur-3xl min-h-[650px] flex flex-col shadow-2xl shadow-blue-500/5 ring-1 ring-white/5">
          <AnimatePresence mode="wait">
            {step === 1 && (
              <motion.div
                key="step1"
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -30 }}
                className="flex flex-col items-center justify-center flex-1 text-center py-10"
              >
                <div
                  onDragOver={handleDragOver}
                  onDrop={handleDrop}
                  className="w-full max-w-2xl aspect-[16/10] border-2 border-dashed border-slate-800 rounded-[3rem] flex flex-col items-center justify-center gap-8 hover:border-blue-500/50 hover:bg-blue-500/5 transition-all duration-700 cursor-pointer group relative overflow-hidden"
                  onClick={() => fileInputRef.current.click()}
                >
                  <input type="file" ref={fileInputRef} className="hidden" accept=".csv" onChange={handleFileUpload} />
                  <div className="absolute inset-0 bg-gradient-to-b from-blue-500/0 to-blue-500/5 opacity-0 group-hover:opacity-100 transition-opacity" />

                  <div className="w-24 h-24 bg-blue-500/10 rounded-[2rem] flex items-center justify-center text-blue-400 border border-blue-500/20 group-hover:scale-110 group-hover:bg-blue-500/20 transition-all duration-500 shadow-xl shadow-blue-500/10 ring-1 ring-blue-400/20">
                    <Upload size={36} />
                  </div>
                  <div>
                    <h2 className="text-3xl font-black mb-3 text-white tracking-tight">Drop your CSV here</h2>
                    <p className="text-slate-400 text-lg font-medium mx-auto max-w-sm">
                      We'll automatically detect headers and analyze your data structure.
                    </p>
                  </div>
                </div>

                {error && (
                  <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="mt-8 flex items-center gap-3 text-red-400 bg-red-400/5 px-6 py-3 rounded-2xl border border-red-400/20 font-bold">
                    <AlertCircle size={20} />
                    <span>{error}</span>
                  </motion.div>
                )}

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 w-full max-w-2xl mt-12 text-left">
                  <div className="p-6 bg-slate-900/60 rounded-3xl border border-slate-800 hover:border-blue-500/30 transition-colors group">
                    <div className="w-12 h-12 bg-blue-500/10 rounded-2xl flex items-center justify-center text-blue-400 mb-4 group-hover:scale-110 transition-transform">
                      <Database size={24} />
                    </div>
                    <div className="text-lg font-bold text-white mb-1">Smart Engine</div>
                    <div className="text-sm text-slate-500 font-medium">Auto-typing and header extraction for fast setup.</div>
                  </div>
                  <div className="p-6 bg-slate-900/60 rounded-3xl border border-slate-800 hover:border-indigo-500/30 transition-colors group cursor-pointer" onClick={generateTestData}>
                    <div className="w-12 h-12 bg-indigo-500/10 rounded-2xl flex items-center justify-center text-indigo-400 mb-4 group-hover:scale-110 transition-transform">
                      <Play size={24} fill="currentColor" />
                    </div>
                    <div className="text-lg font-bold text-white mb-1">Interactive Demo</div>
                    <div className="text-sm text-slate-500 font-medium">Click here to load a sample experiment dataset.</div>
                  </div>
                </div>
              </motion.div>
            )}

            {step === 2 && (
              <motion.div key="step2" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} className="space-y-8 flex-1 flex flex-col" >
                <div>
                  <span className="text-blue-500 font-bold uppercase tracking-[0.2em] text-xs">Step 02 — Configuration</span>
                  <h2 className="text-4xl font-black mb-2 text-white italic tracking-tight">Setup the analysis</h2>
                  <p className="text-slate-400 text-lg font-medium">Select inputs (multiple allowed) and outcome.</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Multi-Select for Treatment */}
                  <div className="p-6 md:p-8 rounded-[2rem] border bg-blue-500/10 border-blue-500/50 ring-1 ring-blue-500/20 shadow-2xl shadow-blue-500/10 transition-all duration-500 flex flex-col">
                    <div className="flex items-center justify-between mb-4">
                      <div className="flex items-center gap-3 text-blue-400">
                        <div className="p-2.5 rounded-xl bg-black/20 ring-1 ring-blue-500/20"><Settings2 /></div>
                        <h3 className="font-black text-xl tracking-tight uppercase">Treatments (Inputs)</h3>
                      </div>
                      {treatments.length > 0 && <CheckCircle2 size={24} className="text-blue-500 animate-in zoom-in" />}
                    </div>
                    <p className="text-sm text-slate-500 mb-6 font-medium leading-relaxed">Select one or more variables to analyze their impact.</p>
                    <div className="flex flex-wrap gap-2">
                      {headers.map(opt => (
                        <button
                          key={opt}
                          onClick={() => toggleTreatment(opt)}
                          disabled={opt === outcome}
                          className={cn(
                            "px-5 py-2.5 rounded-2xl text-sm font-bold border transition-all duration-300 active:scale-90",
                            treatments.includes(opt)
                              ? 'bg-blue-600 border-blue-400 text-white shadow-lg'
                              : 'bg-slate-800/50 border-slate-700 text-slate-500 hover:border-slate-500 hover:text-slate-300 disabled:opacity-20'
                          )}
                        >
                          {opt}
                        </button>
                      ))}
                    </div>
                  </div>

                  <VariableSelector label="Outcome (Output)" icon={<TrendingUp />} color="indigo" selected={outcome} options={headers} onSelect={setOutcome} disabled={null} description="The result or metric you expect to be influenced." />
                </div>

                {/* Optional Controls Section */}
                <div className="p-8 bg-slate-900/30 rounded-[2rem] border border-slate-800/50">
                  <div className="flex items-center gap-4 text-emerald-400 mb-6">
                    <div className="p-3 bg-emerald-500/10 rounded-[1.2rem] ring-1 ring-emerald-500/20">
                      <Users size={24} />
                    </div>
                    <div>
                      <h3 className="font-black text-xl tracking-tight leading-none uppercase">Adjust for Confounders</h3>
                      <p className="text-xs text-emerald-500/60 font-bold mt-1 tracking-wider uppercase">DoWhy Backdoor Adjustment</p>
                    </div>
                  </div>
                  <p className="text-slate-500 mb-6 font-medium leading-relaxed">
                    Select variables that might correlate with both the treatment and results.
                    DoWhy will use these for backdoor adjustment.
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {headers.map(header => (
                      <button key={header} onClick={() => toggleControl(header)} disabled={treatments.includes(header) || header === outcome} className={cn("px-5 py-2.5 rounded-xl text-sm font-bold border transition-all duration-300", controls.includes(header) ? "bg-emerald-600 border-emerald-400 text-white shadow-lg shadow-emerald-500/20" : "bg-slate-800/50 border-slate-700 text-slate-500 hover:border-slate-500 hover:text-slate-300 disabled:opacity-10")} >
                        {header}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Estimator Selection */}
                <div className="p-8 bg-slate-900/30 rounded-[2rem] border border-slate-800/50">
                  <div className="flex items-center gap-4 text-purple-400 mb-6">
                    <div className="p-3 bg-purple-500/10 rounded-[1.2rem] ring-1 ring-purple-500/20">
                      <Target size={24} />
                    </div>
                    <div>
                      <h3 className="font-black text-xl tracking-tight leading-none uppercase">Estimation Method</h3>
                      <p className="text-xs text-purple-500/60 font-bold mt-1 tracking-wider uppercase">Algorithm Selection</p>
                    </div>
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    {[
                      { id: "backdoor.linear_regression", label: "Linear Regression", desc: "Fast, standard baseline." },
                      { id: "backdoor.propensity_score_matching", label: "Propensity Matching", desc: "Matches similar units." },
                      { id: "backdoor.propensity_score_weighting", label: "Propensity Weighting", desc: "Balances distribution." }
                    ].map((method) => (
                      <button
                        key={method.id}
                        onClick={() => setEstimator(method.id)}
                        className={cn(
                          "p-4 rounded-2xl text-left border transition-all duration-300",
                          estimator === method.id
                            ? "bg-purple-600 border-purple-400 text-white shadow-lg shadow-purple-500/20"
                            : "bg-slate-800/50 border-slate-700 text-slate-500 hover:border-slate-500 hover:text-slate-300"
                        )}
                      >
                        <div className="font-bold text-sm mb-1">{method.label}</div>
                        <div className="text-xs opacity-70">{method.desc}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Refuter Selection */}
                <div className="p-8 bg-slate-900/30 rounded-[2rem] border border-slate-800/50 mt-4">
                  <div className="flex items-center gap-4 text-emerald-400 mb-6">
                    <div className="p-3 bg-emerald-500/10 rounded-[1.2rem] ring-1 ring-emerald-500/20">
                      <CheckCircle2 size={24} />
                    </div>
                    <div>
                      <h3 className="font-black text-xl tracking-tight leading-none uppercase">Validation Method</h3>
                      <p className="text-xs text-emerald-500/60 font-bold mt-1 tracking-wider uppercase">Robustness Check</p>
                    </div>
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {[
                      { id: "random_common_cause", label: "Random Common Cause", desc: "Adds a random confounder. Effect should not change." },
                      { id: "placebo_treatment_refuter", label: "Placebo Treatment", desc: "Replaces treatment with random variable. Effect should go to 0." }
                    ].map((method) => (
                      <button
                        key={method.id}
                        onClick={() => setRefuter(method.id)}
                        className={cn(
                          "p-4 rounded-2xl text-left border transition-all duration-300",
                          refuter === method.id
                            ? "bg-emerald-600 border-emerald-400 text-white shadow-lg shadow-emerald-500/20"
                            : "bg-slate-800/50 border-slate-700 text-slate-500 hover:border-slate-500 hover:text-slate-300"
                        )}
                      >
                        <div className="font-bold text-sm mb-1">{method.label}</div>
                        <div className="text-xs opacity-70">{method.desc}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Validation Logic */}
                {(() => {
                  const isPropensity = estimator.includes("propensity")
                  let validationMsg = null

                  if (isPropensity) {
                    if (controls.length === 0) {
                      validationMsg = "Propensity methods require at least one confounder (Control variable)."
                    } else {
                      for (const t of treatments) {
                        const uniqueVals = new Set(data.map(r => r[t])).size
                        if (uniqueVals > 2) {
                          validationMsg = `Treatment '${t}' is not binary (has ${uniqueVals} unique values). Propensity methods require binary treatments.`
                          break
                        }
                      }
                    }
                  }

                  return (
                    <>
                      {validationMsg && (
                        <div className="mt-6 flex items-center gap-3 text-amber-300 bg-amber-500/10 px-6 py-4 rounded-2xl border border-amber-500/20 font-bold animate-in fade-in slide-in-from-bottom-2">
                          <AlertTriangle size={24} className="shrink-0" />
                          <span>{validationMsg}</span>
                        </div>
                      )}

                      <div className="mt-auto pt-10 flex justify-between items-center border-t border-slate-800/50">
                        <button onClick={() => setStep(1)} className="text-slate-500 font-bold hover:text-slate-200 transition-colors uppercase tracking-widest text-xs">Back to Upload</button>
                        <button
                          disabled={treatments.length === 0 || !outcome || !!validationMsg}
                          onClick={handleRunModels}
                          className="flex items-center gap-3 px-12 py-5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:scale-[1.02] active:scale-95 disabled:opacity-50 disabled:grayscale transition-all rounded-[1.5rem] font-black text-xl shadow-2xl shadow-blue-500/20 ring-1 ring-white/10"
                        >
                          ANALYZE WITH DOWHY
                          <Play size={24} fill="currentColor" />
                        </button>
                      </div>
                    </>
                  )
                })()}
              </motion.div>
            )}

            {step === 3 && (
              <motion.div key="step3" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex flex-col items-center justify-center flex-1 text-center py-20" >
                <div className="relative mb-12">
                  <motion.div animate={{ rotate: 360, scale: [1, 1.1, 1] }} transition={{ duration: 3, repeat: Infinity, ease: "linear" }} className="w-48 h-48 border-[6px] border-blue-500/5 border-t-blue-500 rounded-full blur-[1px] shadow-[0_0_30px_rgba(59,130,246,0.2)]" />
                  <div className="absolute inset-0 flex items-center justify-center text-blue-400 drop-shadow-[0_0_10px_rgba(59,130,246,0.5)]">
                    <Database size={48} className="animate-pulse" />
                  </div>
                </div>
                <h2 className="text-3xl font-black mb-4 text-white tracking-tight italic">Running DoWhy...</h2>
                <p className="text-slate-500 text-lg font-medium max-w-sm mx-auto">Identifying estimands and calculating causal effects via Python backend.</p>
                <div className="w-full max-w-md mx-auto mt-12 bg-slate-800/50 h-3 rounded-full overflow-hidden p-1 border border-slate-800">
                  <motion.div initial={{ width: 0 }} animate={{ width: "100%" }} transition={{ duration: 2 }} className="h-full bg-gradient-to-r from-blue-500 to-indigo-500 rounded-full shadow-[0_0_20px_rgba(59,130,246,0.3)]" />
                </div>
              </motion.div>
            )}

            {step === 4 && results && (
              <motion.div key="step4" initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} className="space-y-10 flex-1" >
                <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
                  <div>
                    <span className="text-emerald-500 font-bold uppercase tracking-[0.2em] text-xs">DoWhy Analysis Complete</span>
                    <h2 className="text-4xl font-black text-white italic tracking-tight">Causal Impact Report</h2>
                  </div>
                  <div className="flex gap-2">
                    <button onClick={() => setStep(2)} className="px-5 py-2.5 bg-slate-800/80 hover:bg-slate-700 rounded-[1rem] text-sm font-bold transition-all border border-slate-700 uppercase tracking-wider" >Edit configuration</button>
                    <button onClick={() => { setData([]); setStep(1); }} className="px-5 py-2.5 bg-red-500/10 hover:bg-red-500/20 text-red-500 rounded-[1rem] text-sm font-bold transition-all border border-red-500/20 uppercase tracking-wider" >Reset</button>
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-6">
                  {Object.entries(results.results).map(([treatment, res]) => (
                    <motion.div key={treatment} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="bg-slate-900/40 rounded-[2.5rem] border border-slate-800/50 p-8 md:p-12 relative overflow-hidden group" >
                      <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:opacity-20 transition-opacity">
                        <TrendingUp size={120} />
                      </div>

                      <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
                        <div>
                          <div className="flex items-center gap-3 mb-6">
                            <div className="px-4 py-1.5 rounded-full bg-blue-500/20 text-blue-300 text-xs font-bold uppercase tracking-wider border border-blue-500/20">
                              Treatment Effect
                            </div>
                            <div className="text-slate-500 font-bold text-sm uppercase tracking-wider">{treatment} → {outcome}</div>
                          </div>

                          <div className="mb-10">
                            <div className="text-6xl md:text-8xl font-black text-white tracking-tighter mb-2">
                              {res.ate > 0 ? '+' : ''}{res.ate.toFixed(2)}
                            </div>
                            <p className="text-slate-400 font-medium text-lg max-w-md">
                              On average, increasing <span className="text-white font-bold">{treatment}</span> by 1 unit
                              leads to a <span className="text-white font-bold">{Math.abs(res.ate).toFixed(2)}</span> unit {res.ate > 0 ? 'increase' : 'decrease'} in <span className="text-white font-bold">{outcome}</span>.
                            </p>
                          </div>

                          {/* Refutation Result */}
                          <div className="p-6 rounded-3xl bg-slate-800/30 border border-slate-700/50 backdrop-blur-sm">
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2 text-emerald-400 font-bold uppercase tracking-wider text-xs">
                                <CheckCircle2 size={14} />
                                Refutation Test
                              </div>
                              <div className={cn("text-xs font-bold px-2 py-0.5 rounded-md uppercase", Math.abs(res.ate - res.refutation_result) < (Math.abs(res.ate) * 0.2) ? "bg-emerald-500/20 text-emerald-400" : "bg-amber-500/20 text-amber-400")}>
                                {Math.abs(res.ate - res.refutation_result) < (Math.abs(res.ate) * 0.2) ? "Passed" : "Warning"}
                              </div>
                            </div>
                            <div className="flex justify-between items-end">
                              <div>
                                <div className="text-2xl font-black text-white">{res.refutation_result.toFixed(2)}</div>
                                <div className="text-xs text-slate-500 font-bold mt-1">New Estimate</div>
                              </div>
                              <div className="text-right">
                                <div className="text-xs text-slate-500 font-bold mb-1">Method</div>
                                <div className="text-xs font-mono text-slate-400 bg-slate-900/50 px-2 py-1 rounded-lg">
                                  {refuter === "random_common_cause" ? "Random Common Cause" : "Placebo Treatment"}
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Causal Graph Visualization */}
                        {res.graph && (
                          <div className="bg-slate-950/50 rounded-3xl border border-slate-800/50 p-6 flex flex-col">
                            <div className="flex items-center gap-2 text-slate-400 mb-4 px-2">
                              <Database size={16} />
                              <h4 className="text-xs font-black uppercase tracking-widest">Causal Graph</h4>
                            </div>
                            <div className="flex-1 relative min-h-[300px] flex items-center justify-center">
                              {/* Simple Graph Rendering */}
                              <svg className="w-full h-full absolute inset-0 text-slate-500" viewBox="0 0 400 300">
                                <defs>
                                  <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="28" refY="3.5" orient="auto">
                                    <polygon points="0 0, 10 3.5, 0 7" fill="currentColor" opacity="0.5" />
                                  </marker>
                                </defs>

                                {/* Computed Nodes & Edges would go here. For now, using a schematic layout based on data */}
                                {/* Confounders Top */}
                                {controls.map((c, i) => (
                                  <g key={c} transform={`translate(${200 + (i - (controls.length - 1) / 2) * 100}, 50)`}>
                                    <circle r="4" fill="#10b981" />
                                    <text y="-10" textAnchor="middle" fill="#10b981" fontSize="10" fontWeight="bold" className="uppercase">{c}</text>

                                    {/* Edges from Confounder to Treatment and Outcome */}
                                    <line x1="0" y1="0" x2={100 - (200 + (i - (controls.length - 1) / 2) * 100)} y2="200" stroke="currentColor" strokeWidth="1" strokeOpacity="0.2" markerEnd="url(#arrowhead)" />
                                    <line x1="0" y1="0" x2={300 - (200 + (i - (controls.length - 1) / 2) * 100)} y2="200" stroke="currentColor" strokeWidth="1" strokeOpacity="0.2" markerEnd="url(#arrowhead)" />
                                  </g>
                                ))}

                                {/* Treatment Bottom Left */}
                                <g transform="translate(100, 250)">
                                  <circle r="6" fill="#3b82f6" />
                                  <text y="20" textAnchor="middle" fill="#3b82f6" fontSize="12" fontWeight="900" className="uppercase">{treatment}</text>

                                  {/* Edge to Outcome */}
                                  <line x1="0" y1="0" x2="200" y2="0" stroke="#3b82f6" strokeWidth="3" markerEnd="url(#arrowhead)" />
                                </g>

                                {/* Outcome Bottom Right */}
                                <g transform="translate(300, 250)">
                                  <circle r="6" fill="#6366f1" />
                                  <text y="20" textAnchor="middle" fill="#6366f1" fontSize="12" fontWeight="900" className="uppercase">{outcome}</text>
                                </g>
                              </svg>
                            </div>
                            <div className="mt-4 flex justify-between text-[10px] font-bold uppercase tracking-widest text-slate-600 px-4">
                              <div className="text-blue-500">Treatment (Cause)</div>
                              <div className="text-indigo-500">Outcome (Effect)</div>
                            </div>
                          </div>
                        )}
                      </div>

                      {/* Advanced Report Section */}
                      <div className="mt-12 pt-12 border-t border-slate-800/50">
                        <h4 className="text-xl font-black text-white mb-8 flex items-center gap-3">
                          <FileText className="text-purple-400" />
                          Advanced Causal Diagnostics
                        </h4>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                          {/* DOT Graph */}
                          <div className="bg-slate-950 p-6 rounded-3xl border border-slate-800">
                            <h5 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-4">Explicit DAG (DOT Format)</h5>
                            <pre className="text-[10px] text-slate-400 font-mono overflow-auto p-4 bg-black/30 rounded-xl h-48 border border-white/5">
                              {res.dot_graph || "Graph not available"}
                            </pre>
                          </div>

                          {/* Backdoor Paths */}
                          <div className="bg-slate-950 p-6 rounded-3xl border border-slate-800">
                            <h5 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-4">Backdoor Paths (Confounds)</h5>
                            {res.backdoor_paths && res.backdoor_paths.length > 0 ? (
                              <div className="space-y-2 h-48 overflow-auto pr-2">
                                {res.backdoor_paths.map((path, i) => (
                                  <div key={i} className="text-xs font-mono text-amber-400 bg-amber-500/10 px-3 py-2 rounded-lg border border-amber-500/20 break-words">
                                    {path.join(" → ")}
                                  </div>
                                ))}
                              </div>
                            ) : (
                              <div className="text-slate-600 italic text-sm">No backdoor paths detected.</div>
                            )}
                          </div>

                          {/* Covariate Balance (Love Plot equivalent) */}
                          {res.smd && res.smd.length > 0 && (
                            <div className="col-span-1 md:col-span-2 bg-slate-950 p-6 rounded-3xl border border-slate-800">
                              <h5 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-4">Covariate Balance (Standardized Mean Difference)</h5>
                              <div className="h-64">
                                <ResponsiveContainer width="100%" height="100%">
                                  <BarChart layout="vertical" data={res.smd} margin={{ top: 5, right: 30, left: 40, bottom: 5 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#334155" opacity={0.5} horizontal={true} vertical={true} />
                                    <XAxis type="number" domain={[-0.5, 0.5]} stroke="#94a3b8" fontSize={10} tickFormatter={(val) => Math.abs(val).toFixed(2)} />
                                    <YAxis dataKey="variable" type="category" stroke="#94a3b8" fontSize={10} width={100} />
                                    <RechartsTooltip
                                      contentStyle={{ backgroundColor: '#1e293b', borderColor: '#334155', color: '#f8fafc' }}
                                      itemStyle={{ color: '#f8fafc' }}
                                      cursor={{ fill: '#334155', opacity: 0.2 }}
                                    />
                                    <Bar dataKey="smd" fill="#10b981" radius={[0, 4, 4, 0]} barSize={20}>
                                      {res.smd.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={Math.abs(entry.smd) < 0.1 ? "#10b981" : "#f59e0b"} />
                                      ))}
                                    </Bar>
                                    {/* Reference line for 0.1 threshold */}
                                    <line x1="60%" y1="0" x2="60%" y2="100%" stroke="red" strokeDasharray="3 3" />
                                  </BarChart>
                                </ResponsiveContainer>
                              </div>
                              <div className="mt-2 text-center text-[10px] text-slate-500">
                                Bars <span className="text-emerald-500 font-bold">&lt; 0.1</span> indicate good balance. <span className="text-amber-500 font-bold">&gt; 0.1</span> indicate imbalance.
                              </div>
                            </div>
                          )}
                        </div>
                      </div>
                    </motion.div>
                  ))}
                </div>

              </motion.div>
            )}
          </AnimatePresence>
        </section>
      </main>

      {/* Footer Info */}
      <footer className="max-w-7xl mx-auto mt-12 pb-10 text-center text-slate-600 text-xs font-bold uppercase tracking-[0.3em]">
        Statistical Engine v2.0.0 — Powered by DoWhy
      </footer>
    </div>
  )
}

function MiniStat({ label, value, color, icon }) {
  // ... existing MiniStat component  
  return (
    <div className={cn("p-5 rounded-3xl border border-white/5 flex items-center gap-4 group transition-all", color)}>
      <div className="p-2.5 bg-black/20 rounded-xl">{icon}</div>
      <div>
        <div className="text-[10px] font-black uppercase tracking-[0.1em] opacity-60 mb-0.5">{label}</div>
        <div className="text-2xl font-black tracking-tight">{value}</div>
      </div>
    </div>
  )
}

function VariableSelector({ label, icon, color, selected, options, onSelect, disabled, description }) {
  const isBlue = color === 'blue'
  return (
    <div className={cn(
      "p-6 md:p-8 rounded-[2rem] border transition-all duration-500 flex flex-col",
      selected
        ? (isBlue ? 'bg-blue-500/10 border-blue-500/50 ring-1 ring-blue-500/20 shadow-2xl shadow-blue-500/10' : 'bg-indigo-500/10 border-indigo-500/50 ring-1 ring-indigo-500/20 shadow-2xl shadow-indigo-500/10')
        : 'bg-slate-900/40 border-slate-800 hover:border-slate-700'
    )}>
      <div className="flex items-center justify-between mb-4">
        <div className={cn("flex items-center gap-3", isBlue ? "text-blue-400" : "text-indigo-400")}>
          <div className={cn("p-2.5 rounded-xl bg-black/20 ring-1", isBlue ? "ring-blue-500/20" : "ring-indigo-500/20")}>{icon}</div>
          <h3 className="font-black text-xl tracking-tight uppercase">{label}</h3>
        </div>
        {selected && <CheckCircle2 size={24} className={isBlue ? "text-blue-500 animate-in zoom-in" : "text-indigo-500 animate-in zoom-in"} />}
      </div>
      <p className="text-sm text-slate-500 mb-6 font-medium leading-relaxed">{description}</p>
      <div className="flex flex-wrap gap-2">
        {options.map(opt => (
          <button
            key={opt}
            onClick={() => onSelect(opt === selected ? null : opt)}
            disabled={opt === disabled}
            className={cn(
              "px-5 py-2.5 rounded-2xl text-sm font-bold border transition-all duration-300 active:scale-90",
              selected === opt
                ? (isBlue ? 'bg-blue-600 border-blue-400 text-white shadow-lg' : 'bg-indigo-600 border-indigo-400 text-white shadow-lg')
                : 'bg-slate-800/50 border-slate-700 text-slate-500 hover:border-slate-500 hover:text-slate-300 disabled:opacity-20'
            )}
          >
            {opt}
          </button>
        ))}
      </div>
    </div>
  )
}

function StepCard({ number, title, active, done, onClick }) {
  // ... existing StepCard component
  return (
    <button
      onClick={onClick}
      className={cn(
        "w-full text-left p-6 md:p-7 rounded-[1.8rem] border transition-all duration-700 relative overflow-hidden group",
        active
          ? 'bg-gradient-to-r from-blue-600/15 via-blue-600/5 to-transparent border-blue-500 text-white shadow-2xl shadow-blue-500/10 translate-x-1'
          : 'bg-slate-900/30 border-slate-800 text-slate-500 hover:border-slate-700'
      )}
    >
      {active && <motion.div layoutId="active-bar" className="absolute left-0 top-0 bottom-0 w-1.5 bg-blue-500" />}
      <div className="flex items-center gap-5 relative z-10">
        <div className={cn(
          "w-12 h-12 rounded-2xl flex items-center justify-center font-black text-lg transition-all duration-700",
          active ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/40 rotate-12 scale-110' : done ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' : 'bg-slate-800 text-slate-600'
        )}>
          {done ? <CheckCircle2 size={24} /> : number}
        </div>
        <div>
          <span className={cn(
            "block font-black tracking-tight text-lg transition-colors duration-500",
            active ? 'text-white italic' : 'text-slate-500 group-hover:text-slate-300'
          )}>{title}</span>
          {active && <span className="text-[10px] font-black uppercase tracking-[0.3em] text-blue-500/80 mt-1 block">Active Phase</span>}
        </div>
      </div>
    </button>
  )
}
